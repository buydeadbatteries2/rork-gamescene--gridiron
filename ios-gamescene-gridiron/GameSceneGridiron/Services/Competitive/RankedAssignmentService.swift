import Foundation
import Observation
import Supabase

// MARK: - Phase 14B — ranked assignment prefetch (offline policy A)
//
// Before a season game starts, the client must already hold a server
// assignment for it (MatchViewModel.init is synchronous and the game must be
// playable offline). The service prefetches at most
// `RankedAssignmentStore.maxPrefetched` assignments ahead of the next game,
// always flushing queued results first so the server's game window advances.
// No assignment at kickoff → the game is played normally but unranked.

nonisolated enum RankedAssignmentFetchResult: Sendable {
    case assigned(RankedAssignmentWire)
    /// Final for this request (season closed, game already recorded…).
    case rejected(reason: String)
    /// Offline / 401 / 429 / 5xx.
    case retryable(category: String)
}

protocol RankedAssignmentFetching: Sendable {
    func start(seasonID: UUID?, gameNumber: Int, difficulty: String) async -> RankedAssignmentFetchResult
}

struct SupabaseRankedAssignmentFetcher: RankedAssignmentFetching {
    static let functionName = "start-ranked-match"
    let client: SupabaseClient

    private struct Body: Encodable {
        let seasonID: UUID?
        let gameNumber: Int
        let difficulty: String
        enum CodingKeys: String, CodingKey {
            case seasonID = "season_id"
            case gameNumber = "game_number"
            case difficulty
        }
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            // season_id is always present: null asks the server for a NEW season.
            try container.encode(seasonID, forKey: .seasonID)
            try container.encode(gameNumber, forKey: .gameNumber)
            try container.encode(difficulty, forKey: .difficulty)
        }
    }

    private struct Response: Decodable {
        let status: String
        let assignment: RankedAssignmentWire?
    }

    private struct RejectedBody: Decodable {
        let reason: String?
    }

    func start(seasonID: UUID?, gameNumber: Int, difficulty: String) async -> RankedAssignmentFetchResult {
        guard let body = try? JSONEncoder().encode(Body(seasonID: seasonID, gameNumber: gameNumber, difficulty: difficulty)) else {
            return .rejected(reason: "encoding_failed")
        }
        do {
            let response: Response = try await client.functions.invoke(
                Self.functionName,
                options: FunctionInvokeOptions(headers: ["Content-Type": "application/json"], body: body)
            )
            guard response.status == "assigned", let assignment = response.assignment else {
                return .retryable(category: "unexpected_response")
            }
            return .assigned(assignment)
        } catch let FunctionsError.httpError(code, data) {
            let reason = (try? JSONDecoder().decode(RejectedBody.self, from: data))?.reason
            switch SupabaseCompetitiveSubmitter.classify(statusCode: code, reason: reason) {
            case .rejected(let reason): return .rejected(reason: reason)
            case .retryable(let category): return .retryable(category: category)
            case .verified: return .retryable(category: "unexpected_response")
            }
        } catch {
            return .retryable(category: "network")
        }
    }
}

/// What the prefetcher needs to know about the local season.
nonisolated struct RankedSeasonContext: Equatable, Sendable {
    let seasonNumber: Int
    /// Server season id, nil until game 1's assignment created it.
    let rankedSeasonID: UUID?
    /// Next unplayed game number (1–12).
    let nextGameNumber: Int
    let difficulty: DifficultyLevel
}

@MainActor
@Observable
final class RankedAssignmentService {
    static let shared = RankedAssignmentService()

    private(set) var store: RankedAssignmentStore
    private(set) var isRefreshing = false
    /// DEBUG-safe category of the last failed request.
    private(set) var lastErrorCategory: String?

    private let defaults: UserDefaults
    private let fetcher: (any RankedAssignmentFetching)?
    private let currentUserID: @MainActor () -> UUID?
    private let seasonContext: @MainActor () -> RankedSeasonContext?
    private let adoptSeasonID: @MainActor (UUID, Int) -> Void
    private let flushSubmissions: @MainActor () async -> Void
    private let now: () -> Date

    convenience init() {
        let provider = SupabaseClientProvider.shared
        let fetcher: (any RankedAssignmentFetching)? = provider.isConfigured
            ? provider.supabase.map { SupabaseRankedAssignmentFetcher(client: $0) }
            : nil
        self.init(
            defaults: .standard,
            fetcher: fetcher,
            currentUserID: {
                if case .authenticated(let profile) = AuthService.shared.state { return profile.authUserID }
                return nil
            },
            seasonContext: { SeasonManager.shared.rankedSeasonContext },
            adoptSeasonID: { id, number in SeasonManager.shared.adoptRankedSeasonID(id, seasonNumber: number) },
            flushSubmissions: { await CompetitiveSubmissionService.shared.flush() }
        )
    }

    init(
        defaults: UserDefaults,
        fetcher: (any RankedAssignmentFetching)?,
        currentUserID: @escaping @MainActor () -> UUID?,
        seasonContext: @escaping @MainActor () -> RankedSeasonContext?,
        adoptSeasonID: @escaping @MainActor (UUID, Int) -> Void,
        flushSubmissions: @escaping @MainActor () async -> Void = {},
        now: @escaping () -> Date = Date.init
    ) {
        self.defaults = defaults
        self.fetcher = fetcher
        self.currentUserID = currentUserID
        self.seasonContext = seasonContext
        self.adoptSeasonID = adoptSeasonID
        self.flushSubmissions = flushSubmissions
        self.now = now
        store = RankedAssignmentStore.load(defaults: defaults)
    }

    /// The assignment to play for this exact game, if one was prefetched and
    /// this build's catalog has every assigned case at the assigned version.
    func playableAssignment(seasonID: UUID?, gameNumber: Int, difficulty: DifficultyLevel) -> RankedAssignment? {
        guard let owner = currentUserID(), let seasonID,
              let assignment = store.playable(owner: owner, seasonID: seasonID, gameNumber: gameNumber, difficulty: difficulty, now: now()),
              assignment.matchesLocalCatalog() else { return nil }
        return assignment
    }

    /// The game finished (queued or unranked) — its consumption is recorded
    /// (Ranked-screen progress truth) and the assignment is spent.
    func consume(matchID: UUID) {
        store.consume(matchID: matchID)
        persist()
    }

    /// Server-truth state for the Ranked screen, straight from the assignment
    /// store — never the local solo season: the server season's difficulty and
    /// the next playable game (highest consumed + 1). Prefetched assignments
    /// are unplayed and never advance it. nil while no server season is known
    /// on this device (the caller then falls back to the local season).
    var rankedDisplayState: (seasonID: UUID, difficulty: DifficultyLevel, nextGameNumber: Int)? {
        guard let snapshot = store.snapshot, let level = DifficultyLevel(serverValue: snapshot.difficulty) else { return nil }
        return (snapshot.seasonID, level, min(12, max(1, snapshot.consumedGameNumber + 1)))
    }

    /// Flushes queued results, then tops the store up to at most
    /// `maxPrefetched` assignments starting at the next game.
    func refresh() async {
        guard !isRefreshing, let fetcher, let owner = currentUserID(), let context = seasonContext(),
              (1...12).contains(context.nextGameNumber) else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        await flushSubmissions()

        var seasonID = context.rankedSeasonID
        // Server truth wins: never prune below the SERVER season's next
        // playable game, even when the local season pointer has run ahead
        // (stale local ranked game-number cache).
        let serverNextGame = store.snapshot.map { min(12, max(1, $0.consumedGameNumber + 1)) }
        let pruneFloor = min(context.nextGameNumber, serverNextGame ?? context.nextGameNumber)
        store.prune(owner: owner, seasonID: seasonID, minGameNumber: pruneFloor, now: now())
        let last = min(12, context.nextGameNumber + RankedAssignmentStore.maxPrefetched - 1)
        /// Highest game the server called already-recorded during this pass.
        var recordedServerGame = 0
        for game in context.nextGameNumber...last {
            if let seasonID, store.has(owner: owner, seasonID: seasonID, gameNumber: game, now: now()) { continue }
            // Only game 1 may create a server season. A season started on a
            // pre-14B build stays unranked until the next season.
            if seasonID == nil && game != 1 { break }
            let result = await fetcher.start(seasonID: seasonID, gameNumber: game, difficulty: context.difficulty.serverValue)
            switch result {
            case .assigned(let wire):
                guard let assignment = wire.assignment(owner: owner),
                      assignment.gameNumber == game,
                      assignment.difficulty == context.difficulty.serverValue,
                      seasonID == nil || assignment.seasonID == seasonID else {
                    lastErrorCategory = "unexpected_response"
                    persist()
                    return
                }
                if seasonID == nil {
                    seasonID = assignment.seasonID
                    adoptSeasonID(assignment.seasonID, context.seasonNumber)
                }
                store.upsert(assignment)
                lastErrorCategory = nil
            case .rejected(let reason):
                lastErrorCategory = CompetitiveSubmissionQueue.safeCategory(reason)
                // Already recorded server-side: the server's consumption
                // truth advances the displayed progress, and the next game
                // may still be open.
                if reason == "game_already_recorded" {
                    recordedServerGame = max(recordedServerGame, game)
                    continue
                }
                store.prune(owner: owner, seasonID: seasonID, minGameNumber: pruneFloor, now: now())
                persist()
                return
            case .retryable(let category):
                lastErrorCategory = CompetitiveSubmissionQueue.safeCategory(category)
                store.prune(owner: owner, seasonID: seasonID, minGameNumber: pruneFloor, now: now())
                persist()
                return
            }
        }
        if recordedServerGame > 0 { store.recordServerConsumption(gameNumber: recordedServerGame) }
        store.prune(owner: owner, seasonID: seasonID, minGameNumber: pruneFloor, now: now())
        persist()
    }

    private func persist() {
        RankedAssignmentStore.save(store, defaults: defaults)
    }
}

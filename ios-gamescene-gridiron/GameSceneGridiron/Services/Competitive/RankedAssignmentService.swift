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
        Self.debugLog("request season_id=\(seasonID?.uuidString ?? "null (NEW SEASON)") game_number=\(gameNumber) difficulty=\(difficulty)")
        do {
            let response: Response = try await client.functions.invoke(
                Self.functionName,
                options: FunctionInvokeOptions(headers: ["Content-Type": "application/json"], body: body)
            )
            guard response.status == "assigned", let assignment = response.assignment else {
                Self.debugLog("http 200 with unexpected body status=\(response.status) — not treated as season creation")
                return .retryable(category: "unexpected_response")
            }
            Self.debugLog("assigned season=\(assignment.seasonID.uuidString) game=\(assignment.gameNumber) difficulty=\(assignment.difficulty) reused=\(assignment.reused ?? false)")
            return .assigned(assignment)
        } catch let FunctionsError.httpError(code, data) {
            let reason = (try? JSONDecoder().decode(RejectedBody.self, from: data))?.reason
            Self.debugLog("http \(code) reason=\(reason ?? "nil")")
            switch SupabaseCompetitiveSubmitter.classify(statusCode: code, reason: reason) {
            case .rejected(let reason): return .rejected(reason: reason)
            case .retryable(let category): return .retryable(category: category)
            case .verified: return .retryable(category: "unexpected_response")
            }
        } catch {
            Self.debugLog("transport failure (offline?)")
            return .retryable(category: "network")
        }
    }

    /// DEBUG-only diagnostics (never JWTs, keys, secrets or solutions) so
    /// ranked synchronization failures are diagnosable from the console.
    private static func debugLog(_ message: String) {
        #if DEBUG
        print("⟦start-ranked-match⟧ \(message)")
        #endif
    }

    /// Create-path log hook (service side): the selected UI difficulty and
    /// the fact that the request is a fresh null-season/game-1 request.
    static func debugLogCreate(_ message: String) {
        debugLog("create: \(message) → fresh request (season_id=null, game_number=1)")
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

/// THE canonical ranked state the UI renders. Backed by the server: every
/// refresh replaces it from server answers, and local caches never win.
nonisolated enum RankedSessionState: Equatable, Sendable {
    /// Entry — no server answer yet this session.
    case checking
    /// The server confirmed there is no active ranked season.
    case noSeason
    /// Server-backed active season: difficulty and next playable game are
    /// exactly what the server issued/verified.
    case active(seasonID: UUID, difficulty: DifficultyLevel, nextGameNumber: Int)
    /// The server could not be reached — cached state must not pose as truth.
    case unavailable
}

@MainActor
@Observable
final class RankedAssignmentService {
    static let shared = RankedAssignmentService()

    private(set) var store: RankedAssignmentStore
    private(set) var isRefreshing = false
    /// DEBUG-safe category of the last failed request.
    private(set) var lastErrorCategory: String?
    /// The one ranked state the UI observes (server-authoritative).
    private(set) var sessionState: RankedSessionState = .checking

    private let defaults: UserDefaults
    private let fetcher: (any RankedAssignmentFetching)?
    private let currentUserID: @MainActor () -> UUID?
    private let seasonContext: @MainActor () -> RankedSeasonContext?
    private let adoptSeasonID: @MainActor (UUID, Int) -> Void
    private let clearSeasonID: @MainActor () -> Void
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
            clearSeasonID: { SeasonManager.shared.clearRankedSeasonID() },
            flushSubmissions: { await CompetitiveSubmissionService.shared.flush() }
        )
    }

    init(
        defaults: UserDefaults,
        fetcher: (any RankedAssignmentFetching)?,
        currentUserID: @escaping @MainActor () -> UUID?,
        seasonContext: @escaping @MainActor () -> RankedSeasonContext?,
        adoptSeasonID: @escaping @MainActor (UUID, Int) -> Void,
        clearSeasonID: @escaping @MainActor () -> Void = {},
        flushSubmissions: @escaping @MainActor () async -> Void = {},
        now: @escaping () -> Date = Date.init
    ) {
        self.defaults = defaults
        self.fetcher = fetcher
        self.currentUserID = currentUserID
        self.seasonContext = seasonContext
        self.adoptSeasonID = adoptSeasonID
        self.clearSeasonID = clearSeasonID
        self.flushSubmissions = flushSubmissions
        self.now = now
        store = RankedAssignmentStore.load(defaults: defaults)
        sessionState = Self.state(from: store.snapshot, fallback: .checking)
    }

    /// The assignment to play for this exact game, if one was prefetched and
    /// this build's catalog has every assigned case at the assigned version.
    func playableAssignment(seasonID: UUID?, gameNumber: Int, difficulty: DifficultyLevel) -> RankedAssignment? {
        guard let owner = currentUserID(), let seasonID,
              let assignment = store.playable(owner: owner, seasonID: seasonID, gameNumber: gameNumber, difficulty: difficulty, now: now()),
              assignment.matchesLocalCatalog() else { return nil }
        return assignment
    }

    /// The game finished locally (queued or unranked) — the assignment is
    /// spent inventory only; progress advances when the server verifies.
    func consume(matchID: UUID) {
        store.consume(matchID: matchID)
        persist()
    }

    /// The server VERIFIED this match — the only path (besides the server
    /// reporting a game already recorded) that advances ranked progress.
    func markVerified(matchID: UUID) {
        store.markVerified(matchID: matchID)
        sessionState = Self.state(from: store.snapshot, fallback: .noSeason)
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

    private static func state(from snapshot: RankedAssignmentStore.Snapshot?, fallback: RankedSessionState) -> RankedSessionState {
        guard let snapshot, let level = DifficultyLevel(serverValue: snapshot.difficulty) else { return fallback }
        return .active(
            seasonID: snapshot.seasonID,
            difficulty: level,
            nextGameNumber: min(12, max(1, snapshot.consumedGameNumber + 1))
        )
    }

    /// Flushes queued results, then tops the store up to at most
    /// `maxPrefetched` assignments starting at the next game. Every exit
    /// publishes the server-backed `sessionState`.
    func refresh() async {
        guard !isRefreshing else { return }
        guard let fetcher else {
            sessionState = .unavailable
            return
        }
        guard let owner = currentUserID() else {
            // Guests have no ranked season server-side.
            sessionState = .noSeason
            return
        }
        let context = seasonContext()
        guard let context, (1...12).contains(context.nextGameNumber) else {
            sessionState = Self.state(from: store.snapshot, fallback: .noSeason)
            return
        }
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
                // The SERVER's difficulty is the ranked truth — a mismatch
                // with the local season is adopted, never rejected.
                guard let assignment = wire.assignment(owner: owner),
                      assignment.gameNumber == game,
                      seasonID == nil || assignment.seasonID == seasonID else {
                    lastErrorCategory = "unexpected_response"
                    sessionState = Self.state(from: store.snapshot, fallback: .unavailable)
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
                // The server says this ranked season is closed, unknown, or
                // the difficulty no longer matches what we asked with: the
                // local season pointer/difficulty is stale — wipe it so the
                // player goes through the fresh START flow (the server can
                // then create a brand-new season). Stale local state must
                // never pose as an active season.
                if reason == "season_closed" || reason == "season_not_found"
                    || reason == "season_difficulty_mismatch" {
                    store.clearSeason()
                    clearSeasonID()
                    sessionState = .noSeason
                    persist()
                    return
                }
                store.prune(owner: owner, seasonID: seasonID, minGameNumber: pruneFloor, now: now())
                sessionState = Self.state(from: store.snapshot, fallback: .noSeason)
                persist()
                return
            case .retryable(let category):
                lastErrorCategory = CompetitiveSubmissionQueue.safeCategory(category)
                store.prune(owner: owner, seasonID: seasonID, minGameNumber: pruneFloor, now: now())
                // Server unreachable: cached state must not pose as truth.
                sessionState = Self.state(from: store.snapshot, fallback: .unavailable)
                persist()
                return
            }
        }
        if recordedServerGame > 0 { store.recordServerConsumption(gameNumber: recordedServerGame) }
        store.prune(owner: owner, seasonID: seasonID, minGameNumber: pruneFloor, now: now())
        sessionState = Self.state(from: store.snapshot, fallback: .noSeason)
        persist()
    }

    /// Assignment the server issued for a NOT-YET-created ranked season
    /// (game 1, explicit difficulty), awaiting local season creation.
    private var pendingCreation: RankedAssignment?

    /// Server confirms a NEW ranked season at game 1 with ONLY the difficulty
    /// the player explicitly picked. Returns true when the server issued the
    /// game-1 assignment; the local season is created only after this.
    func createRankedSeason(difficulty: DifficultyLevel) async -> Bool {
        guard let fetcher, let owner = currentUserID() else {
            lastErrorCategory = "ranked_start_unavailable"
            return false
        }
        // FRESH request, built from the player's explicit choice only: no
        // season id, no stored game number, no local/solo difficulty.
        SupabaseRankedAssignmentFetcher.debugLogCreate("selected=\(difficulty.serverValue)")
        let result = await fetcher.start(seasonID: nil, gameNumber: 1, difficulty: difficulty.serverValue)
        switch result {
        case .assigned(let wire):
            guard let assignment = wire.assignment(owner: owner),
                  assignment.gameNumber == 1,
                  assignment.difficulty == difficulty.serverValue else {
                // Server refuses the requested difficulty — never substitute
                // another one; the player chooses again.
                lastErrorCategory = "ranked_start_difficulty_mismatch"
                return false
            }
            pendingCreation = assignment
            return true
        case .rejected(let reason):
            lastErrorCategory = CompetitiveSubmissionQueue.safeCategory(reason)
            return false
        case .retryable(let category):
            lastErrorCategory = CompetitiveSubmissionQueue.safeCategory(category)
            return false
        }
    }

    /// After the local season exists (server already confirmed creation),
    /// adopt the stashed game-1 assignment as ranked truth.
    func adoptCreatedSeason(seasonNumber: Int) {
        guard let assignment = pendingCreation else { return }
        pendingCreation = nil
        adoptSeasonID(assignment.seasonID, seasonNumber)
        store.upsert(assignment)
        sessionState = Self.state(from: store.snapshot, fallback: .noSeason)
        persist()
    }

    private func persist() {
        RankedAssignmentStore.save(store, defaults: defaults)
    }
}

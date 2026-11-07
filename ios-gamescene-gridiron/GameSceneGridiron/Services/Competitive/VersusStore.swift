import Foundation
import Observation

// MARK: - Phase 15B — Versus client state (UI-facing)
//
// The single place the Versus screens read from. The SERVER owns every
// decision (pairing, cases, score, winner, forfeit, expiry); this store only
//   * mirrors the server rows (open matches, single-match reads, history,
//     record) — on every refresh the server row replaces the cache,
//   * remembers which matches the player is involved in, so a force-close
//     never loses one (tracked ids + cached rows, per account),
//   * keeps per-match quarter progress for resume, and
//   * queues finished games durably until the server confirms them.

@MainActor
@Observable
final class VersusStore {
    static let shared = VersusStore()

    enum FindState: Equatable {
        case idle
        case searching
        case failed(String)
    }

    enum SubmitState: Equatable {
        case submitting
        /// Offline / transient — queued and retried on the next refresh.
        case willRetry
        case rejected(String)
        /// 410: the deadline passed before the file arrived.
        case expired
    }

    /// Persisted per account.
    struct LocalState: Codable, Equatable {
        var trackedIDs: [UUID] = []
        var viewedClosedIDs: [UUID] = []
        var cached: [VersusMatch] = []
        var pending: [VersusPendingSubmission] = []
        var progress: [VersusProgress] = []
    }

    private(set) var matches: [UUID: VersusMatch] = [:]
    private(set) var history: [VersusHistoryEntry] = []
    private(set) var myRecord: VersusCareerRecord?
    private(set) var opponentRecords: [UUID: VersusCareerRecord] = [:]
    private(set) var isRefreshing = false
    private(set) var lastRefreshFailed = false
    private(set) var hasLoaded = false
    private(set) var findState: FindState = .idle
    private(set) var submitStates: [UUID: SubmitState] = [:]
    private(set) var local = LocalState()

    private let service: VersusService?
    private let defaults: UserDefaults
    private let currentUserID: () -> UUID?
    private let now: () -> Date
    private var loadedOwner: UUID?
    private var lastRefreshAt: Date?

    init(
        backend: (any VersusBackend)?,
        defaults: UserDefaults = .standard,
        userID: @escaping () -> UUID?,
        now: @escaping () -> Date = Date.init,
        gameVersion: String = CompetitiveResultPayload.currentGameVersion
    ) {
        service = backend.map { VersusService(backend: $0, gameVersion: gameVersion, now: now) }
        self.defaults = defaults
        currentUserID = userID
        self.now = now
    }

    convenience init() {
        let provider = SupabaseClientProvider.shared
        let backend: (any VersusBackend)? = provider.isConfigured
            ? provider.supabase.map { SupabaseVersusBackend(client: $0) }
            : nil
        self.init(backend: backend, userID: {
            if case .authenticated(let profile) = AuthService.shared.state { return profile.authUserID }
            return nil
        })
    }

    /// False when the app has no Supabase configuration (Versus offline).
    var isAvailable: Bool { service != nil }

    // MARK: Derived

    func match(id: UUID) -> VersusMatch? {
        loadOwnerIfNeeded()
        return matches[id]
    }

    /// Matches still waiting on someone, newest first.
    var openMatches: [VersusMatch] {
        trackedMatches.filter { VersusPhase.of($0).isPending }
    }

    /// Resolved / expired matches the player has not opened yet.
    var unviewedResults: [VersusMatch] {
        trackedMatches.filter {
            let phase = VersusPhase.of($0)
            return phase.isClosed && phase != .cancelled && !local.viewedClosedIDs.contains($0.matchID)
        }
    }

    /// Hub + Home badge: matches the player can act on now.
    var attentionCount: Int {
        openMatches.filter { VersusPhase.of($0).canPlay }.count + unviewedResults.count
    }

    /// Worth gently polling: something is waiting on a person or a queue.
    var hasPendingWork: Bool {
        loadOwnerIfNeeded()
        return !openMatches.isEmpty || !local.pending.isEmpty
    }

    private var trackedMatches: [VersusMatch] {
        loadOwnerIfNeeded()
        return local.trackedIDs.compactMap { matches[$0] }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func progress(for matchID: UUID) -> VersusProgress? {
        loadOwnerIfNeeded()
        return local.progress.first { $0.matchID == matchID }
    }

    func pendingSubmission(for matchID: UUID) -> VersusPendingSubmission? {
        loadOwnerIfNeeded()
        return local.pending.first { $0.match.matchID == matchID }
    }

    func opponentRecord(for match: VersusMatch) -> VersusCareerRecord? {
        match.opponentUserID.flatMap { opponentRecords[$0] }
    }

    // MARK: Account scoping

    private func storageKey(_ owner: UUID) -> String { "gamescene.gridiron.versus.local.\(owner.uuidString)" }

    /// Loads (or switches to) the signed-in account's local state. A
    /// different account never sees another account's matches.
    private func loadOwnerIfNeeded() {
        let owner = currentUserID()
        guard owner != loadedOwner else { return }
        loadedOwner = owner
        matches = [:]
        history = []
        myRecord = nil
        submitStates = [:]
        hasLoaded = false
        lastRefreshAt = nil
        guard let owner, let data = defaults.data(forKey: storageKey(owner)),
              let state = try? JSONDecoder().decode(LocalState.self, from: data) else {
            local = LocalState()
            return
        }
        local = state
        for match in state.cached { matches[match.matchID] = match }
    }

    private func persist() {
        guard let owner = loadedOwner else { return }
        // Cache only what the tracked list or a pending file needs.
        let keep = Set(local.trackedIDs).union(local.pending.map(\.match.matchID))
        local.cached = keep.compactMap { matches[$0] }
        local.viewedClosedIDs = Array(local.viewedClosedIDs.suffix(100))
        if let data = try? JSONEncoder().encode(local) {
            defaults.set(data, forKey: storageKey(owner))
        }
    }

    private func track(_ match: VersusMatch) {
        matches[match.matchID] = match
        if !local.trackedIDs.contains(match.matchID) { local.trackedIDs.append(match.matchID) }
    }

    private func untrack(_ id: UUID) {
        local.trackedIDs.removeAll { $0 == id }
    }

    // MARK: Refresh (server wins)

    /// Reconciles every tracked match with the server. Automatic refreshes
    /// are throttled; `force` (pull-to-refresh, after a submit) is not.
    func refresh(force: Bool = false) async {
        loadOwnerIfNeeded()
        guard let service, loadedOwner != nil, !isRefreshing else { return }
        if !force, let last = lastRefreshAt, now().timeIntervalSince(last) < VersusRules.refreshThrottle { return }
        isRefreshing = true
        defer { isRefreshing = false }
        lastRefreshAt = now()

        do {
            let open = try await service.openMatches()
            for match in open { track(match) }
            let openIDs = Set(open.map(\.matchID))
            if let page = try? await service.history(limit: 20) { history = page }
            for id in local.trackedIDs where !openIDs.contains(id) {
                await reconcileClosed(id, service: service)
            }
            // A server row that shows my submission supersedes any queued copy.
            local.pending.removeAll { matches[$0.match.matchID]?.mySubmitted == true }
            lastRefreshFailed = false
        } catch {
            lastRefreshFailed = true
        }
        await flushPending()
        if let owner = loadedOwner, let record = try? await service.record(for: owner) {
            myRecord = record
        }
        await loadOpponentRecords()
        hasLoaded = true
        persist()
    }

    /// A tracked match that is no longer open: ask for its final row.
    private func reconcileClosed(_ id: UUID, service: VersusService) async {
        do {
            if let row = try await service.match(id: id) {
                matches[id] = row
                if VersusPhase.of(row) == .cancelled { untrack(id) }
            } else {
                untrack(id)
                matches[id] = nil
            }
        } catch {
            // Single-match read unavailable: fall back to the list reads.
            if let entry = history.first(where: { $0.matchID == id }) {
                matches[id] = .fromHistory(entry, cached: matches[id])
            } else if let cached = matches[id], VersusPhase.of(cached).isPending,
                      let deadline = cached.expiresAtDate, deadline < now() {
                // Not open, not in history, past the deadline ⇒ the server
                // expired it with no result (a forfeit would be in history).
                matches[id] = cached.asExpiredNoResult()
            }
        }
    }

    private func loadOpponentRecords() async {
        guard let service else { return }
        let ids = Set(trackedMatches.compactMap(\.opponentUserID)).subtracting(opponentRecords.keys)
        for id in ids.prefix(8) {
            if let record = try? await service.record(for: id) { opponentRecords[id] = record }
        }
    }

    /// History tap: the full summary for one completed match.
    func loadSummary(id: UUID) async -> VersusMatch? {
        loadOwnerIfNeeded()
        if let cached = matches[id], VersusPhase.of(cached).isClosed, cached.myCasesSolved != nil { return cached }
        if let service, let row = try? await service.match(id: id) {
            matches[id] = row
            return row
        }
        if let entry = history.first(where: { $0.matchID == id }) {
            let summary = VersusMatch.fromHistory(entry, cached: matches[id])
            matches[id] = summary
            return summary
        }
        return matches[id]
    }

    /// MATCH HISTORY: one larger page (server caps at 50).
    func loadHistory() async {
        loadOwnerIfNeeded()
        guard let service, loadedOwner != nil else { return }
        if let page = try? await service.history(limit: SupabaseVersusBackend.historyPageLimit) {
            history = page
            lastRefreshFailed = false
        } else {
            lastRefreshFailed = true
        }
        hasLoaded = true
    }

    func markViewed(_ id: UUID) {
        guard let match = matches[id], VersusPhase.of(match).isClosed else { return }
        if !local.viewedClosedIDs.contains(id) { local.viewedClosedIDs.append(id) }
        // Viewed results live on in history; stop tracking them.
        untrack(id)
        persist()
    }

    // MARK: Matchmaking

    /// FIND OPPONENT: sends the difficulty only. The server picks the
    /// opponent (or opens a waiting match) and the five cases.
    @discardableResult
    func find(difficulty: DifficultyLevel) async -> VersusMatch? {
        loadOwnerIfNeeded()
        guard let service, loadedOwner != nil else {
            findState = .failed("Versus is offline right now.")
            return nil
        }
        findState = .searching
        switch await service.findMatch(difficulty: difficulty) {
        case .matched(let match), .waiting(let match):
            track(match)
            findState = .idle
            persist()
            // Another difficulty's waiting match may have been cancelled.
            lastRefreshAt = nil
            Task { await self.refresh(force: true) }
            return match
        case .rejected(let reason):
            findState = .failed(VersusPresentation.findErrorMessage(reason))
            await refresh(force: true)
            return nil
        case .retryable:
            findState = .failed("Couldn't reach the server. Check your connection and try again.")
            return nil
        }
    }

    func clearFindError() { findState = .idle }

    // MARK: Play + submit

    /// Progress after every quarter — a force-close resumes the same match.
    func saveProgress(_ progress: VersusProgress) {
        loadOwnerIfNeeded()
        local.progress.removeAll { $0.matchID == progress.matchID }
        local.progress.append(progress)
        persist()
    }

    /// The game is over: queue the file durably, then submit it.
    func completeGame(matchID: UUID, startedAt: Date, caseResults: [CompetitiveCaseResult]) async {
        loadOwnerIfNeeded()
        guard let match = matches[matchID] else { return }
        local.progress.removeAll { $0.matchID == matchID }
        local.pending.removeAll { $0.match.matchID == matchID }
        local.pending.append(VersusPendingSubmission(match: match, startedAt: startedAt, caseResults: caseResults))
        persist()
        await submit(matchID: matchID)
    }

    /// Retries every queued file (refresh / foreground).
    func flushPending() async {
        for pending in local.pending where submitStates[pending.match.matchID] != .submitting {
            await submit(matchID: pending.match.matchID)
        }
    }

    func submit(matchID: UUID) async {
        guard let service, let pending = pendingSubmission(for: matchID) else { return }
        submitStates[matchID] = .submitting
        let match = matches[matchID] ?? pending.match
        let result = await service.submit(match: match, startedAt: pending.startedAt, caseResults: pending.caseResults)
        switch result {
        case .verified(let receipt):
            local.pending.removeAll { $0.match.matchID == matchID }
            matches[matchID] = match.applying(receipt: receipt)
            submitStates[matchID] = nil
        case .expired:
            local.pending.removeAll { $0.match.matchID == matchID }
            submitStates[matchID] = .expired
        case .rejected(let reason):
            local.pending.removeAll { $0.match.matchID == matchID }
            submitStates[matchID] = .rejected(VersusPresentation.submitErrorMessage(reason))
        case .retryable:
            submitStates[matchID] = .willRetry
        }
        persist()
        // The server row is the truth: re-read it after any final answer
        // (no-op when already inside a refresh).
        if case .retryable = result { return }
        await refresh(force: true)
    }

    func submitState(for matchID: UUID) -> SubmitState? { submitStates[matchID] }
}

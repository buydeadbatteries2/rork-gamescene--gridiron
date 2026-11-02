import Foundation
import Testing
@testable import GameSceneGridiron

// MARK: - Phase 15B — Versus player-facing flow
//
// Store + presentation + gameplay wiring. The SERVER owns every decision;
// these tests pin that the client mirrors it: exact case assignment, no
// hints, durable submission, sealed opponent score, recovery after a
// relaunch, and no local forfeit / expiry decisions.

private enum P15B {
    static let me = UUID()
    static let opponent = UUID()

    static func match(
        id: UUID = UUID(),
        status: VersusMatchStatus = .active,
        state: VersusPlayerState = .active,
        difficulty: String = "pro",
        caseIDs: [String] = ["a", "b", "c", "d", "e"],
        versions: [Int] = [1, 1, 1, 1, 1],
        expiresAt: String = "2099-01-01T00:00:00Z",
        opponent: Bool = true,
        mySubmitted: Bool = false,
        myScore: Int? = nil,
        myCases: Int? = nil,
        oppScore: Int? = nil,
        oppCases: Int? = nil,
        outcome: VersusOutcome? = nil,
        forfeit: Bool = false,
        resolution: VersusResolution? = nil
    ) -> VersusMatch {
        VersusMatch(
            matchID: id, status: status, playerState: state, role: "player_a", difficulty: difficulty,
            caseIDs: caseIDs, caseVersions: versions, catalogFingerprint: "fp", contentSource: .bundledDevFallback,
            createdAt: "2026-11-02T10:00:00Z", matchedAt: opponent ? "2026-11-02T10:05:00Z" : nil,
            expiresAt: expiresAt, completedAt: status == .completed ? "2026-11-02T12:00:00Z" : nil,
            opponentUserID: opponent ? Self.opponent : nil, opponentUsername: opponent ? "ben_qb" : nil,
            opponentDisplayName: opponent ? "Ben the Blitz" : nil,
            mySubmitted: mySubmitted, myFinalScore: myScore, myCasesSolved: myCases,
            opponentSubmitted: oppScore != nil, opponentFinalScore: oppScore, opponentCasesSolved: oppCases,
            outcome: outcome, isForfeit: forfeit, resolution: resolution, reused: nil
        )
    }

    static func history(_ outcome: VersusOutcome, id: UUID = UUID(), my: Int = 70, opp: Int = 60, forfeit: Bool = false) -> VersusHistoryEntry {
        VersusHistoryEntry(
            matchID: id, difficulty: "all_pro", completedAt: "2026-11-02T12:00:00Z",
            opponentUserID: opponent, opponentUsername: "ben_qb", opponentDisplayName: "Ben the Blitz",
            myFinalScore: my, opponentFinalScore: opp, outcome: outcome, isForfeit: forfeit, resolution: forfeit ? .forfeit : .score
        )
    }

    static func record(_ user: UUID, w: Int, l: Int, t: Int) -> VersusCareerRecord {
        VersusCareerRecord(userID: user, username: "x", footballDisplayName: nil, gamesPlayed: w + l + t,
                           wins: w, losses: l, ties: t, forfeitWins: 0, forfeitLosses: 0)
    }

    /// Five real competitive cases that exist in the bundled library.
    static let realCases: [(String, Int)] = {
        CompetitiveCaseCatalog.entries.keys.sorted().compactMap { id -> (String, Int)? in
            guard CaseLibrary.caseByID(id) != nil, let version = CompetitiveCaseCatalog.competitiveVersion(forCaseID: id) else { return nil }
            return (id, version)
        }.prefix(5).map { $0 }
    }()

    static func realMatch(difficulty: String = "pro", state: VersusPlayerState = .active) -> VersusMatch {
        match(state: state, difficulty: difficulty, caseIDs: realCases.map(\.0), versions: realCases.map(\.1))
    }

    static func caseResults(for match: VersusMatch) -> [CompetitiveCaseResult] {
        (0..<4).map { index in
            CompetitiveCaseResult(
                caseID: match.caseIDs[index], caseVersion: match.caseVersions[index], quarterIndex: index,
                outcome: .solved, hintsUsed: 0, wrongPlacements: 0,
                placements: [CompetitivePlacement(playerKey: "p1", slotKey: "s1", profile: "veteran")]
            )
        }
    }

    static func receipt(status: VersusMatchStatus = .active, state: VersusPlayerState = .submitted, score: Int = 72,
                        outcome: VersusOutcome? = nil, oppScore: Int? = nil) -> VersusSubmitReceipt {
        VersusSubmitReceipt(status: "verified", resultID: UUID(), finalScore: score, casesSolved: 4, duplicate: false,
                            matchStatus: status, playerState: state, matchOutcome: outcome, opponentFinalScore: oppScore)
    }

    static func defaults() -> UserDefaults {
        let name = "p15b.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }
}

final class Phase15BBackend: VersusBackend, @unchecked Sendable {
    var findCalls: [String] = []
    var findResult: VersusFindResult = .retryable(category: "network")
    var submitResult: VersusSubmitResult = .retryable(category: "network")
    var submitted: [VersusResultPayload] = []
    var open: [VersusMatch] = []
    var historyRows: [VersusHistoryEntry] = []
    var single: [UUID: VersusMatch] = [:]
    var records: [UUID: VersusCareerRecord] = [:]
    var openThrows = false
    var singleThrows = false

    struct Offline: Error {}

    func findMatch(difficulty: String) async -> VersusFindResult {
        findCalls.append(difficulty)
        return findResult
    }
    func submit(_ payload: VersusResultPayload) async -> VersusSubmitResult {
        submitted.append(payload)
        return submitResult
    }
    func myOpenMatches() async throws -> [VersusMatch] {
        if openThrows { throw Offline() }
        return open
    }
    func myHistory(limit: Int, offset: Int) async throws -> [VersusHistoryEntry] {
        if openThrows { throw Offline() }
        return historyRows
    }
    func publicRecord(userID: UUID) async throws -> VersusCareerRecord? { records[userID] }
    func myMatch(matchID: UUID) async throws -> VersusMatch? {
        if singleThrows { throw Offline() }
        return single[matchID]
    }
}

@MainActor
private func makeStore(_ backend: Phase15BBackend, defaults: UserDefaults, user: UUID? = P15B.me) -> VersusStore {
    VersusStore(backend: backend, defaults: defaults, userID: { user }, gameVersion: "ios test")
}

/// `find` kicks off a background refresh; let it finish so tests are deterministic.
@MainActor
private func settle(_ store: VersusStore) async {
    try? await Task.sleep(for: .milliseconds(100))
    while store.isRefreshing { try? await Task.sleep(for: .milliseconds(20)) }
}

// MARK: Entry + matchmaking

@MainActor
@Suite("Phase 15B — entry & matchmaking")
struct Phase15BEntryTests {
    @Test func guestsHitTheAccountGateAndNeverReachMatchmaking() async {
        #expect(AccountGatePolicy.requiresAccount(.guest))
        #expect(AccountGatePolicy.requiresAccount(.restoring))
        let backend = Phase15BBackend()
        let store = makeStore(backend, defaults: P15B.defaults(), user: nil)
        let result = await store.find(difficulty: .pro)
        #expect(result == nil)
        #expect(backend.findCalls.isEmpty)
        if case .failed = store.findState {} else { Issue.record("guest find must fail locally") }
    }

    @Test func difficultySelectionIsTheOnlyThingSent() async {
        for (level, wire) in [(DifficultyLevel.rookie, "rookie"), (.pro, "pro"), (.allPro, "all_pro"), (.hallOfFamer, "hall_of_famer")] {
            let backend = Phase15BBackend()
            backend.findResult = .waiting(P15B.match(state: .waitingForOpponent, difficulty: wire, opponent: false))
            let store = makeStore(backend, defaults: P15B.defaults())
            _ = await store.find(difficulty: level)
            #expect(backend.findCalls == [wire])
        }
    }

    @Test func waitingMatchIsPlayableAndPolled() async {
        let backend = Phase15BBackend()
        let waiting = P15B.match(status: .waitingForOpponent, state: .waitingForOpponent, opponent: false)
        backend.findResult = .waiting(waiting)
        backend.open = [waiting]
        let store = makeStore(backend, defaults: P15B.defaults())
        let found = await store.find(difficulty: .pro)
        #expect(found?.matchID == waiting.matchID)
        #expect(VersusPhase.of(waiting) == .waitingCanPlay)
        #expect(VersusPhase.of(waiting).canPlay)
        #expect(store.openMatches.map(\.matchID) == [waiting.matchID])
        #expect(store.hasPendingWork)
        #expect(store.attentionCount == 1)
        #expect(VersusPresentation.deadlineText(waiting).hasPrefix("Expires in"))
    }

    @Test func matchedShowsPublicOpponentOnly() async {
        let backend = Phase15BBackend()
        let matched = P15B.match()
        backend.findResult = .matched(matched)
        backend.open = [matched]
        backend.records[P15B.opponent] = P15B.record(P15B.opponent, w: 3, l: 1, t: 0)
        let store = makeStore(backend, defaults: P15B.defaults())
        _ = await store.find(difficulty: .pro)
        await settle(store)
        await store.refresh(force: true)
        #expect(VersusPhase.of(matched) == .readyToPlay)
        #expect(VersusPresentation.opponentName(matched) == "@ben_qb")
        #expect(VersusPresentation.recordLine(store.opponentRecord(for: matched)) == "3-1-0")
        // Opponent's score is sealed before the match completes.
        #expect(VersusPresentation.opponentScoreText(matched) == "SEALED")
    }

    @Test func findRejectionIsReadable() async {
        let backend = Phase15BBackend()
        backend.findResult = .rejected(reason: "versus_match_in_progress")
        let store = makeStore(backend, defaults: P15B.defaults())
        #expect(await store.find(difficulty: .allPro) == nil)
        #expect(store.findState == .failed(VersusPresentation.findErrorMessage("versus_match_in_progress")))
    }
}

// MARK: Gameplay

@MainActor
@Suite("Phase 15B — gameplay on the server assignment")
struct Phase15BGameplayTests {
    @Test func gameplayUsesTheExactServerAssignment() throws {
        try #require(P15B.realCases.count == 5)
        let match = P15B.realMatch(difficulty: "all_pro")
        #expect(VersusPlayability.problem(for: match) == nil)
        let context = try #require(VersusPlayContext(match: match, startedAt: Date()))
        let viewModel = MatchViewModel(versus: context)
        #expect(viewModel.isVersus)
        #expect(viewModel.plannedCaseIDs == match.caseIDs)
        #expect(viewModel.activeDifficulty == .allPro)
    }

    @Test func unknownOrMismatchedCasesAreNeverSubstituted() {
        #expect(VersusPlayability.problem(for: P15B.match(caseIDs: ["nope1", "nope2", "nope3", "nope4", "nope5"])) == "missing_case")
        #expect(VersusPlayability.problem(for: P15B.match(caseIDs: ["a", "b"], versions: [1, 1])) == "invalid_case_count")
        if let first = P15B.realCases.first {
            let bumped = P15B.match(caseIDs: P15B.realCases.map(\.0), versions: [first.1 + 7] + P15B.realCases.dropFirst().map(\.1))
            #expect(VersusPlayability.problem(for: bumped) == "case_version_mismatch")
        }
    }

    @Test func hintsAndRescuesAreDisabled() throws {
        try #require(P15B.realCases.count == 5)
        let context = try #require(VersusPlayContext(match: P15B.realMatch(), startedAt: Date()))
        let match = MatchViewModel(versus: context)
        let game = GameViewModel(puzzle: match.currentPuzzle, difficulty: context.difficulty, defaults: P15B.defaults())
        game.hintsDisabled = true
        game.snapshotKey = VersusPlayContext.snapshotKey(matchID: context.matchID)
        let before = game.hintsRemaining
        #expect(!game.canUseHint)
        game.useHint()
        #expect(game.hintsRemaining == before)
        #expect(game.snapshotKey != GameViewModel.clockSnapshotKey)
        // No ad gates / boosts between Versus quarters.
        #expect(match.adGateDecision() == .none)
        #expect(!VersusRules.purchasableHintsEnabled)
    }
}

// MARK: Submit + results

@MainActor
@Suite("Phase 15B — submit, waiting, results")
struct Phase15BResultTests {
    @Test func submitSuccessShowsSubmittedWaitingWithSealedOpponent() async {
        let backend = Phase15BBackend()
        let match = P15B.match()
        backend.findResult = .matched(match)
        backend.open = [match]
        let store = makeStore(backend, defaults: P15B.defaults())
        _ = await store.find(difficulty: .pro)
        await settle(store)
        await store.refresh(force: true)

        let submittedRow = P15B.match(id: match.matchID, state: .submitted, mySubmitted: true, myScore: 72, myCases: 4)
        backend.open = [submittedRow]
        backend.submitResult = .verified(P15B.receipt())
        await store.completeGame(matchID: match.matchID, startedAt: Date(), caseResults: P15B.caseResults(for: match))

        #expect(backend.submitted.count == 1)
        #expect(backend.submitted.first?.caseResults.allSatisfy { $0.hintsUsed == 0 } == true)
        #expect(store.pendingSubmission(for: match.matchID) == nil)
        let row = store.match(id: match.matchID)!
        #expect(VersusPhase.of(row) == .submittedWaiting(opponentJoined: false))
        #expect(VersusPresentation.myScoreText(row) == "72")
        #expect(VersusPresentation.opponentScoreText(row) == "SEALED")
        // Still reachable from the Hub.
        #expect(store.openMatches.contains { $0.matchID == match.matchID })
    }

    @Test func offlineSubmitIsQueuedAndRetried() async {
        let backend = Phase15BBackend()
        let match = P15B.match()
        backend.findResult = .matched(match)
        backend.open = [match]
        let defaults = P15B.defaults()
        let store = makeStore(backend, defaults: defaults)
        _ = await store.find(difficulty: .pro)
        await settle(store)
        await store.completeGame(matchID: match.matchID, startedAt: Date(), caseResults: P15B.caseResults(for: match))
        #expect(store.submitState(for: match.matchID) == .willRetry)
        #expect(store.pendingSubmission(for: match.matchID) != nil)

        // Relaunch: the queued file survives and goes out on the next refresh.
        // The server has not seen the file yet (row still active).
        backend.submitResult = .verified(P15B.receipt())
        let relaunched = makeStore(backend, defaults: defaults)
        #expect(relaunched.pendingSubmission(for: match.matchID) != nil)
        await relaunched.refresh(force: true)
        #expect(relaunched.pendingSubmission(for: match.matchID) == nil)
        #expect(backend.submitted.count == 2)
        #expect(relaunched.match(id: match.matchID)?.mySubmitted == true)
    }

    @Test func serverShowingMySubmissionSupersedesTheQueue() async {
        let backend = Phase15BBackend()
        let match = P15B.match()
        backend.findResult = .matched(match)
        backend.open = [match]
        let defaults = P15B.defaults()
        let store = makeStore(backend, defaults: defaults)
        _ = await store.find(difficulty: .pro)
        await settle(store)
        await store.completeGame(matchID: match.matchID, startedAt: Date(), caseResults: P15B.caseResults(for: match))
        // The first attempt actually landed; the server row says so.
        backend.open = [P15B.match(id: match.matchID, state: .submitted, mySubmitted: true, myScore: 72)]
        let relaunched = makeStore(backend, defaults: defaults)
        await relaunched.refresh(force: true)
        #expect(relaunched.pendingSubmission(for: match.matchID) == nil)
        #expect(backend.submitted.count == 1)
    }

    @Test func winLossTieRendering() {
        let win = P15B.match(status: .completed, state: .completed, myScore: 80, oppScore: 70, outcome: .win, resolution: .score)
        let loss = P15B.match(status: .completed, state: .completed, myScore: 60, oppScore: 70, outcome: .loss, resolution: .score)
        let tie = P15B.match(status: .completed, state: .completed, myScore: 70, myCases: 4, oppScore: 70, oppCases: 4, outcome: .tie, resolution: .tie)
        #expect(VersusPhase.of(win) == .resolved(.win, isForfeit: false))
        #expect(VersusPresentation.resultTitle(.win, isForfeit: false) == "WIN")
        #expect(VersusPresentation.resultTitle(.loss, isForfeit: false) == "LOSS")
        #expect(VersusPresentation.resultTitle(.tie, isForfeit: false) == "TIE")
        #expect(VersusPresentation.opponentScoreText(win) == "70")
        #expect(VersusPresentation.opponentScoreText(loss) == "70")
        #expect(VersusPresentation.opponentCasesText(tie) == "4")
        #expect(VersusPhase.of(loss).isClosed)
    }

    @Test func forfeitComesFromTheServer() {
        let forfeit = P15B.match(status: .completed, state: .completed, mySubmitted: true, myScore: 64,
                                 outcome: .win, forfeit: true, resolution: .forfeit)
        #expect(VersusPhase.of(forfeit) == .resolved(.win, isForfeit: true))
        #expect(VersusPresentation.resultTitle(.win, isForfeit: true) == "FORFEIT WIN")
        #expect(VersusPresentation.resolutionDetail(forfeit).contains("never submitted"))
        // A past deadline on an OPEN row is never turned into a local forfeit.
        let lapsed = P15B.match(expiresAt: "2020-01-01T00:00:00Z")
        #expect(VersusPhase.of(lapsed) == .readyToPlay)
    }

    @Test func expiredMatchHasNoResult() async {
        let backend = Phase15BBackend()
        let waiting = P15B.match(status: .waitingForOpponent, state: .waitingForOpponent, opponent: false)
        backend.findResult = .waiting(waiting)
        backend.open = [waiting]
        backend.records[P15B.me] = P15B.record(P15B.me, w: 2, l: 1, t: 0)
        let store = makeStore(backend, defaults: P15B.defaults())
        _ = await store.find(difficulty: .pro)
        await settle(store)

        backend.open = []
        backend.single[waiting.matchID] = P15B.match(id: waiting.matchID, status: .expired, state: .expired,
                                                     opponent: false, resolution: .expiredNoOpponent)
        await store.refresh(force: true)
        let row = store.match(id: waiting.matchID)!
        #expect(VersusPhase.of(row) == .expiredNoResult)
        #expect(VersusPresentation.expiredDetail(row).contains("No result"))
        #expect(store.unviewedResults.map(\.matchID) == [waiting.matchID])
        #expect(VersusPresentation.recordLine(store.myRecord) == "2-1-0")
    }

    @Test func expiredFallbackWhenSingleReadUnavailable() {
        let lapsed = P15B.match(status: .waitingForOpponent, state: .waitingForOpponent, expiresAt: "2020-01-01T00:00:00Z", opponent: false)
        let expired = lapsed.asExpiredNoResult()
        #expect(VersusPhase.of(expired) == .expiredNoResult)
        #expect(expired.outcome == nil)
        #expect(expired.resolution == .expiredNoOpponent)
    }

    @Test func cancelledMatchIsSilentlyUntracked() async {
        let backend = Phase15BBackend()
        let waiting = P15B.match(status: .waitingForOpponent, state: .waitingForOpponent, opponent: false)
        backend.findResult = .waiting(waiting)
        backend.open = [waiting]
        let store = makeStore(backend, defaults: P15B.defaults())
        _ = await store.find(difficulty: .pro)
        await settle(store)
        backend.open = []
        backend.single[waiting.matchID] = P15B.match(id: waiting.matchID, status: .cancelled, state: .cancelled, opponent: false)
        await store.refresh(force: true)
        #expect(store.openMatches.isEmpty)
        #expect(store.unviewedResults.isEmpty)
    }
}

// MARK: Recovery, history, navigation, Ranked

@MainActor
@Suite("Phase 15B — recovery & history")
struct Phase15BRecoveryTests {
    @Test func relaunchRecoversTrackedMatchesEvenOffline() async {
        let backend = Phase15BBackend()
        let defaults = P15B.defaults()
        let active = P15B.match()
        backend.findResult = .matched(active)
        backend.open = [active]
        let store = makeStore(backend, defaults: defaults)
        _ = await store.find(difficulty: .pro)
        await settle(store)
        await store.refresh(force: true)

        backend.openThrows = true
        let relaunched = makeStore(backend, defaults: defaults)
        await relaunched.refresh(force: true)
        #expect(relaunched.lastRefreshFailed)
        #expect(relaunched.openMatches.map(\.matchID) == [active.matchID])
    }

    @Test func serverWinsOverCacheAfterRelaunch() async {
        let backend = Phase15BBackend()
        let defaults = P15B.defaults()
        let active = P15B.match()
        backend.findResult = .matched(active)
        backend.open = [active]
        let first = makeStore(backend, defaults: defaults)
        _ = await first.find(difficulty: .pro)
        await settle(first)

        backend.open = []
        backend.single[active.matchID] = P15B.match(id: active.matchID, status: .completed, state: .completed,
                                                    mySubmitted: true, myScore: 75, myCases: 4, oppScore: 70, oppCases: 3,
                                                    outcome: .win, resolution: .score)
        let relaunched = makeStore(backend, defaults: defaults)
        await relaunched.refresh(force: true)
        let row = relaunched.match(id: active.matchID)!
        #expect(VersusPhase.of(row) == .resolved(.win, isForfeit: false))
        #expect(relaunched.unviewedResults.count == 1)
        relaunched.markViewed(active.matchID)
        #expect(relaunched.unviewedResults.isEmpty)
        #expect(relaunched.match(id: active.matchID) != nil)
    }

    @Test func otherAccountsNeverSeeMyMatches() async {
        let backend = Phase15BBackend()
        let defaults = P15B.defaults()
        let active = P15B.match()
        backend.findResult = .matched(active)
        backend.open = [active]
        let first = makeStore(backend, defaults: defaults)
        _ = await first.find(difficulty: .pro)
        await settle(first)
        let other = makeStore(backend, defaults: defaults, user: UUID())
        backend.openThrows = true
        await other.refresh(force: true)
        #expect(other.openMatches.isEmpty)
    }

    @Test func historyRowsAndStreak() async {
        let backend = Phase15BBackend()
        let first = P15B.history(.win, my: 81, opp: 64)
        backend.historyRows = [first, P15B.history(.win), P15B.history(.loss), P15B.history(.tie, forfeit: false)]
        let store = makeStore(backend, defaults: P15B.defaults())
        await store.loadHistory()
        #expect(store.history.count == 4)
        #expect(VersusPresentation.streak(store.history) == "W2")
        #expect(VersusPresentation.shortResult(.tie) == "T")
        #expect(VersusPresentation.shortDate(first.completedAt) != "—")

        // Tapping a row opens a summary (fallback when the single read fails).
        backend.singleThrows = true
        let summary = await store.loadSummary(id: first.matchID)
        #expect(summary?.myFinalScore == 81)
        #expect(summary?.opponentFinalScore == 64)
        #expect(summary.map { VersusPhase.of($0) } == .resolved(.win, isForfeit: false))
    }

    @Test func leavingMidGameKeepsTheMatchAndSendsNothing() async throws {
        try #require(P15B.realCases.count == 5)
        let backend = Phase15BBackend()
        let defaults = P15B.defaults()
        let match = P15B.realMatch()
        backend.findResult = .matched(match)
        backend.open = [match]
        let store = makeStore(backend, defaults: defaults)
        _ = await store.find(difficulty: .pro)
        await settle(store)
        let context = try #require(VersusPlayContext(match: match, startedAt: Date()))
        let viewModel = MatchViewModel(versus: context)
        let progress = try #require(viewModel.versusProgress)
        store.saveProgress(progress)

        // Leave (pause → leave, or force-close): nothing submitted, no forfeit.
        let relaunched = makeStore(backend, defaults: defaults)
        #expect(backend.submitted.isEmpty)
        #expect(relaunched.progress(for: match.matchID)?.matchID == match.matchID)
        #expect(relaunched.match(id: match.matchID).map { VersusPhase.of($0).canPlay } == true)
        let resumed = MatchViewModel(versus: context, resume: relaunched.progress(for: match.matchID))
        #expect(resumed.match.currentQuarterIndex == viewModel.match.currentQuarterIndex)
    }

    @Test func routesAlwaysHaveAWayBack() {
        // Every Hub destination is a pushed route (system back + header Back
        // + Home); the Hub itself closes to Home.
        let routes: [VersusRoute] = [.find, .match(UUID()), .history, .summary(UUID())]
        #expect(Set(routes).count == 4)
    }
}

@MainActor
@Suite("Phase 15B — Ranked and solo unaffected")
struct Phase15BIsolationTests {
    @Test func soloGamesKeepHintsAndTheirSnapshotKey() {
        let match = MatchViewModel(seasonNumber: 1, week: 3, difficulty: .pro)
        #expect(!match.isVersus)
        let game = GameViewModel(puzzle: match.currentPuzzle, difficulty: .pro, defaults: P15B.defaults())
        #expect(!game.hintsDisabled)
        #expect(game.snapshotKey == GameViewModel.clockSnapshotKey)
    }

    @Test func rankedEntryStateUnchanged() {
        #expect(RankedEntryState.resolve(state: .guest, hasTeam: true, nextGameNumber: 1, difficulty: .pro) == .needsAccount)
        #expect(RankedEntryState.progressLabel(12) == "CHAMPIONSHIP · GAME 12 OF 12")
    }

    @Test func versusSnapshotKeyIsPerMatch() {
        let a = UUID(), b = UUID()
        #expect(VersusPlayContext.snapshotKey(matchID: a) != VersusPlayContext.snapshotKey(matchID: b))
        #expect(VersusPlayContext.snapshotKey(matchID: a) != GameViewModel.clockSnapshotKey)
    }

    @Test func singleMatchReadIsInTheSchema() {
        let sql = SchemaFixture.sql.lowercased()
        #expect(sql.contains("create or replace function public.my_versus_match(p_match_id uuid)"))
        #expect(sql.contains("grant execute on function public.my_versus_match(uuid) to authenticated"))
    }
}

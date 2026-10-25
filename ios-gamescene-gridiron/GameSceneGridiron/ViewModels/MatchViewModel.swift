import SwiftUI

/// Drives the four-quarter game flow: quarter intros, live puzzles, quarter
/// results, optional overtime and the final verdict. Owns match-level state
/// only — per-quarter puzzle state stays inside `GameViewModel`.
@Observable
final class MatchViewModel {
    enum Phase: Hashable {
        case quarterIntro
        case playing
        case quarterResult
        case gameResult
    }

    private(set) var match: GameMatch = .fresh()
    private(set) var phase: Phase = .quarterIntro

    /// Puzzle registry for this game, indexed the same way as `GameMatch`.
    private let regulationPuzzles: [QuarterPuzzle]
    private let overtimePuzzle: QuarterPuzzle
    /// Roster identity maps per quarter (index 4 = overtime): puzzle player
    /// id → the user's actual franchise player. Variety of cases is untouched;
    /// only names and body assets adopt the persistent roster.
    private let identityMaps: [[String: RosterIdentity]]
    /// The case files' explicitly authored stat events per quarter (index 4 =
    /// overtime): case player key → the stat that scenario produced.
    private let statEventMaps: [[String: PlayerStat]]

    /// Whether this game belongs to the postseason (playoff/championship bonuses).
    private let isPlayoff: Bool
    /// True only for the championship final — adds the championship bonus.
    private let isChampionship: Bool
    /// The difficulty actually active for this game — every achievement that
    /// references difficulty reads this, never the live selection.
    let activeDifficulty: DifficultyLevel
    /// Stable identity for this game's reward transaction and its persisted
    /// investigation record. Season games derive it deterministically from the
    /// game context so a force-quit mid-investigation re-keys the quarter's
    /// saved state exactly; a fresh standalone replay gets a new id, so its
    /// reward can be claimed exactly once.
    private(set) var matchID = UUID()
    /// The game's Game Ball reward summary, built when the match completes.
    /// Display-only: each solved quarter was credited exactly once through
    /// the per-quarter transaction ledger the moment it was solved.
    private(set) var rewardBreakdown: MatchRewardBreakdown?
    /// Season context for the persisted record (nil = standalone). Supplied
    /// by the flow that created this view model.
    var matchSeasonNumber: Int?
    var matchWeek: Int?
    private let seasonNumber: Int
    private let week: Int
    /// Phase 14: competitive identity + per-case facts for ranked
    /// submission. Created once when a real season game starts (its match ID
    /// is persisted with the active-match record and never regenerated);
    /// nil for standalone games, which are never ranked.
    private(set) var competitive: CompetitiveMatchState?
    /// The ranked outcome built when the game completed (eligible payload or
    /// the reason it can't count). Local results never depend on it.
    private(set) var competitiveOutcome: CompetitivePayloadBuilder.Outcome?

    /// Draws the game's case files from the local puzzle library via the
    /// deterministic scheduler: no case repeats within a game, and across a
    /// 10-week regular season all 40 regulation cases are different. Each
    /// case is then adapted to the effective difficulty (selected level ×
    /// season stage) before conversion.
    /// - Parameters:
    ///   - seasonNumber: 0 for a standalone/quick game.
    ///   - week: 1–10 in the regular season; 11+ resolves playoff rotations.
    ///   - difficulty: overrides the persisted selection (tests/previews).
    ///   - resume: a saved active-investigation record for this exact game;
    ///     when it matches, the match resumes at the saved quarter.
    init(isPlayoff: Bool = false, isChampionship: Bool = false, seasonNumber: Int = 0, week: Int = 1, difficulty: DifficultyLevel? = nil, resume: ActiveMatchRecord? = nil) {
        self.isPlayoff = isPlayoff
        self.isChampionship = isChampionship
        self.seasonNumber = seasonNumber
        self.week = week
        // Changing the difficulty applies from the next unplayed game:
        // schedules are already persisted and completed games are never
        // regenerated, so only puzzles built after the change adapt.
        let selected = difficulty ?? DifficultyManager.shared.selected
        activeDifficulty = selected
        // Phase 11.6: season games are identity-stable — leaving and
        // reopening resumes the same investigation, quarter for quarter.
        if seasonNumber > 0 {
            competitive = .fresh()
            matchID = Self.stableMatchID(
                seasonNumber: seasonNumber, week: week,
                isPlayoff: isPlayoff, isChampionship: isChampionship
            )
        }
        let target = DifficultyResolver.target(selected: selected, stage: .forWeek(week))
        let ids = CaseScheduler.gameCaseIDs(seasonNumber: seasonNumber, week: week)
        var maps: [[String: RosterIdentity]] = []
        var statMaps: [[String: PlayerStat]] = []
        if isPlayoff {
            regulationPuzzles = (0..<4).map {
                let (puzzle, map) = Self.resolveWithRoster(ids.regulation[$0], quarterIndex: $0, target: target)
                maps.append(map)
                statMaps.append(CaseLibrary.statEvents(forCaseID: ids.regulation[$0]))
                return Self.intensified(puzzle)
            }
            let (overtime, overtimeMap) = Self.resolveWithRoster(ids.overtime, quarterIndex: 4, target: target)
            maps.append(overtimeMap)
            statMaps.append(CaseLibrary.statEvents(forCaseID: ids.overtime))
            overtimePuzzle = Self.intensified(overtime)
        } else {
            var regulation: [QuarterPuzzle] = []
            for index in 0..<4 {
                let (puzzle, map) = Self.resolveWithRoster(ids.regulation[index], quarterIndex: index, target: target)
                maps.append(map)
                statMaps.append(CaseLibrary.statEvents(forCaseID: ids.regulation[index]))
                regulation.append(puzzle)
            }
            regulationPuzzles = regulation
            let (overtime, overtimeMap) = Self.resolveWithRoster(ids.overtime, quarterIndex: 4, target: target)
            maps.append(overtimeMap)
            statMaps.append(CaseLibrary.statEvents(forCaseID: ids.overtime))
            overtimePuzzle = overtime
        }
        identityMaps = maps
        statEventMaps = statMaps
        // Resume path: a saved record for this exact game restores the match
        // (quarters already decided, running totals) instead of starting over.
        if let resume, Self.matchesContext(resume, seasonNumber: seasonNumber, week: week, isPlayoff: isPlayoff, isChampionship: isChampionship) {
            match = resume.match
            matchID = resume.matchID
            // Same competitive identity as before the exit; a record saved
            // before ranked play existed can never be ranked.
            if seasonNumber > 0 {
                competitive = resume.competitive ?? .legacyResume()
            }
        }
    }

    /// Deterministic per-game identity: stable across app launches so the
    /// persisted investigation record and the quarter snapshot re-key exactly.
    private static func stableMatchID(seasonNumber: Int, week: Int, isPlayoff: Bool, isChampionship: Bool) -> UUID {
        let hash = SeededGenerator.hash([
            "gridiron-match", String(seasonNumber), String(week),
            isPlayoff ? "po" : "reg", isChampionship ? "final" : "semi",
        ])
        var bytes = [UInt8](repeating: 0, count: 16)
        for (index, byte) in withUnsafeBytes(of: hash.bigEndian, Array.init).prefix(8).enumerated() {
            bytes[index] = byte
        }
        let secondary = SeededGenerator.hash(["gridiron-match-2", String(seasonNumber), String(week)])
        for (index, byte) in withUnsafeBytes(of: secondary.bigEndian, Array.init).prefix(8).enumerated() {
            bytes[index + 8] = byte
        }
        return UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
                           bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]))
    }

    private static func matchesContext(_ record: ActiveMatchRecord, seasonNumber: Int, week: Int, isPlayoff: Bool, isChampionship: Bool) -> Bool {
        ActiveInvestigationStore.matches(
            record, seasonNumber: seasonNumber, week: week,
            isPlayoff: isPlayoff, isChampionship: isChampionship
        )
    }

    /// Resolves a scheduled case id, adapts it to the difficulty target and
    /// dresses its missing players in the franchise roster's identities;
    /// falls back to the first library case if the id cannot be found (never
    /// expected — covered by tests).
    private static func resolveWithRoster(_ id: String, quarterIndex: Int, target: DifficultyTarget) -> (QuarterPuzzle, [String: RosterIdentity]) {
        let map = RosterManager.shared.identityAssignments(forCaseID: id)
        let adapted = CaseLibrary.caseByID(id).map { CaseDifficultyAdapter.adapt($0, to: target) }
        let puzzle = adapted.map { CaseLibrary.puzzle(for: $0, quarterIndex: quarterIndex) }
            ?? CaseLibrary.puzzle(for: CaseLibrary.all[0], quarterIndex: quarterIndex)
        return (puzzle.withRosterIdentities(map), map)
    }

    nonisolated static func intensified(_ puzzle: QuarterPuzzle) -> QuarterPuzzle {
        QuarterPuzzle(
            id: puzzle.id,
            index: puzzle.index,
            quarterLabel: puzzle.quarterLabel,
            title: puzzle.title,
            introHeading: puzzle.introHeading,
            introBody: puzzle.introBody,
            startingLives: max(2, puzzle.startingLives - 1),
            startingHints: max(1, puzzle.startingHints - 1),
            visiblePlayers: puzzle.visiblePlayers,
            missingPlayers: puzzle.missingPlayers,
            evidence: puzzle.evidence,
            slots: puzzle.slots,
            clues: puzzle.clues,
            hints: puzzle.hints,
            solutions: puzzle.solutions
        )
    }

    var currentPuzzle: QuarterPuzzle {
        match.isOvertime ? overtimePuzzle : regulationPuzzles[match.currentQuarterIndex]
    }

    var currentQuarterNumber: Int { match.currentQuarterIndex + 1 }

    /// True when the quarter that just finished was the last thing before the verdict.
    var shouldShowGameResult: Bool { match.isComplete }

    var nextButtonTitle: String {
        match.isComplete ? "VIEW GAME RESULT" : "NEXT QUARTER"
    }

    /// Last Chance (rewarded life) ledger key for the quarter about to be
    /// played — unique per match and quarter, persisted in the wallet.
    var currentLastChanceKey: String {
        "\(matchID.uuidString)-q\(match.currentQuarterIndex)"
    }

    // MARK: Game leaders

    /// Aggregated box line leaders for this game's solved cases, ranked by
    /// weighted impact. Portraits are decorated from the roster.
    var gameLeaders: [StatLeader] {
        StatAwardEngine.leaderBoard(from: match.statEvents).map { leader in
            var decorated = leader
            decorated.bodyAssetID = RosterManager.shared.player(withID: leader.id)?.bodyAssetID
            return decorated
        }
    }

    /// The game's Player of the Game — same ranking the roster records use,
    /// so the result screen and the player's resume always agree.
    var playerOfTheGame: StatLeader? {
        guard let id = StatAwardEngine.playerOfTheGameID(from: match.statEvents) else { return nil }
        return gameLeaders.first { $0.id == id }
    }

    // MARK: Flow

    func startGame() {
        match = .fresh()
        matchID = UUID()
        rewardBreakdown = nil
        // A standalone replay is never ranked.
        competitive = nil
        competitiveOutcome = nil
        phase = .quarterIntro
        // A fresh standalone game supersedes any stale saved investigation.
        ActiveInvestigationStore.clear()
    }

    func beginQuarter() {
        Haptics.tick()
        phase = .playing
        persistActiveInvestigation()
    }

    /// Persists the live game so leaving mid-investigation (pause → Leave,
    /// app exit) resumes this exact game and quarter on return. Standalone
    /// games persist too; only context-matched records ever resume.
    private func persistActiveInvestigation() {
        guard let seasonNumber = matchSeasonNumber, let week = matchWeek else { return }
        ActiveInvestigationStore.save(ActiveMatchRecord(
            seasonNumber: seasonNumber,
            week: week,
            isPlayoff: isPlayoff,
            isChampionship: isChampionship,
            matchID: matchID,
            match: match,
            competitive: competitive
        ))
    }

    /// Records match progress after each quarter so a mid-match exit resumes
    /// at the right point. Cleared once the game completes — a finished game
    /// is never re-entered.
    private func persistActiveInvestigation(afterAdvance: Bool) {
        guard matchSeasonNumber != nil else { return }
        if match.isComplete {
            ActiveInvestigationStore.clear()
        } else {
            persistActiveInvestigation()
        }
    }

    /// Called when `GameViewModel` reaches a verdict. Reads the finished quarter's
    /// stats from the puzzle view model and stores them at match level. Stat
    /// events are only produced for solved quarters — wrong answers never
    /// touch player statistics.
    func finishQuarter(with viewModel: GameViewModel) {
        guard viewModel.result != .inProgress else { return }
        let outcome: QuarterOutcome = viewModel.result == .won ? .solved : .failed
        let map = identityMaps[min(viewModel.puzzleIndex, identityMaps.count - 1)]
        let caseStats = statEventMaps[min(viewModel.puzzleIndex, statEventMaps.count - 1)]
        let events = outcome == .solved
            ? StatAwardEngine.events(from: viewModel.placements, identities: map, caseStats: caseStats)
            : []
        match.recordQuarter(
            index: viewModel.puzzleIndex,
            label: viewModel.puzzle.quarterLabel,
            isOvertime: viewModel.puzzleIndex >= GameMatch.regulationQuarters,
            outcome: outcome,
            correctPlacements: viewModel.placements.count,
            wrongPlacements: viewModel.rejectionCount,
            livesLost: viewModel.puzzle.startingLives - viewModel.lives,
            hintsUsed: viewModel.usedHints.count,
            statEvents: events,
            appearedFranchiseIDs: Set(map.values.map(\.franchisePlayerID))
        )
        if outcome == .solved {
            awardQuarterReward(quarterIndex: viewModel.puzzleIndex)
        }
        recordCompetitiveCase(viewModel, outcome: outcome)
        if match.isComplete {
            rewardBreakdown = MatchRewardBreakdown.forMatch(
                match,
                isPlayoff: isPlayoff,
                isChampionship: isChampionship,
                transactionID: "match-\(matchID.uuidString)"
            )
        }
        // Safe-break achievement event (quarter result): a solved quarter in a
        // real game — training never reaches MatchViewModel.
        if outcome == .solved {
            AchievementCoordinator.quarterSolved(
                livesLost: viewModel.puzzle.startingLives - viewModel.lives,
                hintsUsed: viewModel.usedHints.count,
                isOvertime: viewModel.puzzleIndex >= GameMatch.regulationQuarters,
                difficulty: activeDifficulty
            )
        }
        withAnimation(.easeInOut(duration: 0.3)) {
            phase = match.isComplete ? .gameResult : .quarterResult
        }
        // Ranked submission is queued durably BEFORE the active record is
        // cleared, so a kill right after the verdict can't lose it.
        if match.isComplete {
            submitCompetitiveResultIfEligible()
        }
        // The quarter snapshot is cleared by the finished GameViewModel; the
        // match record advances (or clears on completion) for a clean resume.
        persistActiveInvestigation(afterAdvance: true)
    }

    // MARK: Competitive facts (Phase 14)

    /// Appends the finished case's facts (replacing any earlier entry for the
    /// same quarter so a re-finished quarter never double-counts).
    private func recordCompetitiveCase(_ viewModel: GameViewModel, outcome: QuarterOutcome) {
        guard var state = competitive else { return }
        let caseID = viewModel.puzzle.id
        let version = CompetitiveCaseCatalog.competitiveVersion(forCaseID: caseID)
        state.caseResults.removeAll { $0.quarterIndex == viewModel.puzzleIndex }
        state.caseResults.append(CompetitiveCaseResult(
            caseID: caseID,
            caseVersion: version,
            quarterIndex: viewModel.puzzleIndex,
            outcome: outcome,
            hintsUsed: viewModel.consumedHintCount,
            wrongPlacements: viewModel.rejectionCount,
            placements: viewModel.competitivePlacements
        ))
        if version == nil, state.ineligibleReason == nil {
            state.ineligibleReason = .unknownCaseVersion
        }
        competitive = state
    }

    /// QA/debug paths that fabricate a result call this first — such a game
    /// can never be ranked.
    func markCompetitiveIneligible(_ reason: CompetitiveIneligibility) {
        guard var state = competitive else { return }
        state.ineligibleReason = state.ineligibleReason ?? reason
        competitive = state
    }

    /// Pure payload build for this finished game (tests call it directly).
    func competitivePayload(userID: UUID?, seasonID: UUID?, seasonDifficulty: DifficultyLevel?, completedAt: Date = Date()) -> CompetitivePayloadBuilder.Outcome {
        CompetitivePayloadBuilder.build(
            state: competitive,
            match: match,
            seasonNumber: seasonNumber,
            gameNumber: week,
            activeDifficulty: activeDifficulty,
            seasonDifficulty: seasonDifficulty,
            seasonID: seasonID,
            userID: userID,
            completedAt: completedAt
        )
    }

    private func submitCompetitiveResultIfEligible() {
        guard competitive != nil, competitiveOutcome == nil else { return }
        var userID: UUID?
        if case .authenticated(let profile) = AuthService.shared.state { userID = profile.authUserID }
        let seasons = SeasonManager.shared
        let outcome = competitivePayload(
            userID: userID,
            seasonID: seasons.competitiveSeasonID,
            seasonDifficulty: seasons.activeSeasonDifficulty
        )
        competitiveOutcome = outcome
        CompetitiveSubmissionService.shared.handle(outcome)
    }

    // MARK: Game Ball economy (Phase 11.7)

    /// Awards the solved quarter's +1 Game Ball exactly once — the wallet's
    /// transaction ledger keys on this match + quarter, so a resumed or
    /// re-finished quarter can never pay twice. Failed quarters pay 0.
    private func awardQuarterReward(quarterIndex: Int) {
        PlayerWallet.shared.earn(
            amount: EconomyConfig.standard.quarterSolvedReward,
            kind: .quarterSolved,
            transactionID: "quarter-\(matchID.uuidString)-q\(quarterIndex)"
        )
    }

    // MARK: Forced-ad gates (Phase 11.7)

    /// True for the user's first regular-season game — no forced ads while
    /// they learn the game.
    var isFirstSeasonGame: Bool {
        seasonNumber == 1 && week == 1 && !isPlayoff
    }

    /// The forced-ad gate for the transition after the quarter that just
    /// finished (regulation or into overtime). Pure policy, fed from the
    /// wallet's per-game forced-ad ledger.
    func adGateDecision() -> AdGateDecision {
        let lastOutcome = match.overtimeRecord?.outcome ?? match.quarterRecords.last?.outcome
        return AdGatePolicy.decision(
            quarterWon: lastOutcome == .solved,
            isOvertimeTransition: match.needsOvertime,
            isAdFree: PurchaseManager.shared.hasAdFree,
            forcedAdsShown: PlayerWallet.shared.forcedAdCount(for: matchID.uuidString),
            isTraining: false,
            isFirstSeasonGame: isFirstSeasonGame
        )
    }

    /// Records a forced ad that actually played in this game (against the
    /// per-game cap).
    func recordForcedAdShown() {
        _ = PlayerWallet.shared.recordForcedAd(for: matchID.uuidString)
    }

    /// Spends the ad-skip cost. Returns false when the balance can't cover
    /// it — the WATCH AD route is always available instead.
    @discardableResult
    func skipAd(cost: Int) -> Bool {
        PlayerWallet.shared.spend(amount: cost, kind: .adSkip)
    }

    /// Opens the forced-gate flow (called once when the gate overlay is
    /// raised). Exactly one completion is accepted afterward.
    func beginGateAdFlow() {
        isGateAdPending = true
    }

    /// Bookkeeping when a forced-gate ad attempt resolves. Only an ad that
    /// actually played counts against the per-game cap — an unavailable or
    /// failed interstitial never charges, never counts, never blocks: the
    /// player simply continues. A duplicate completion (stray callback,
    /// foreground replay) is ignored — a quarter can never advance twice.
    @discardableResult
    func finishGateAdAttempt(with result: ForcedAdResult) -> Bool {
        guard isGateAdPending else { return false }
        isGateAdPending = false
        if result == .shown {
            recordForcedAdShown()
        }
        continueFlow()
        return true
    }

    private var isGateAdPending = false

    /// True when the natural-break interstitial after the finished game is
    /// allowed by the same per-game cap (it counts toward the 2-ad limit).
    var canShowPostGameInterstitial: Bool {
        !PurchaseManager.shared.hasAdFree
            && PlayerWallet.shared.forcedAdCount(for: matchID.uuidString) < EconomyConfig.standard.maxForcedAdsPerGame
    }

    /// From the quarter-result screen: either the next quarter intro or the verdict.
    func continueFlow() {
        Haptics.tick()
        AudioManager.shared.play(.buttonPress)
        phase = match.isComplete ? .gameResult : .quarterIntro
    }
}

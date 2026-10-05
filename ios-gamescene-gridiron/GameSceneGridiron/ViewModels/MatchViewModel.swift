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
    /// Stable identity for this game's reward transaction. A fresh game (replay)
    /// gets a new id, so its reward can be claimed exactly once.
    private(set) var matchID = UUID()
    /// The game's Game Ball reward, granted once when the match completes.
    private(set) var rewardBreakdown: MatchRewardBreakdown?

    /// Draws the game's case files from the local puzzle library via the
    /// deterministic scheduler: no case repeats within a game, and across a
    /// 10-week regular season all 40 regulation cases are different.
    /// - Parameters:
    ///   - seasonNumber: 0 for a standalone/quick game.
    ///   - week: 1–10 in the regular season; 11+ resolves playoff rotations.
    init(isPlayoff: Bool = false, isChampionship: Bool = false, seasonNumber: Int = 0, week: Int = 1) {
        self.isPlayoff = isPlayoff
        self.isChampionship = isChampionship
        let ids = CaseScheduler.gameCaseIDs(seasonNumber: seasonNumber, week: week)
        var maps: [[String: RosterIdentity]] = []
        var statMaps: [[String: PlayerStat]] = []
        if isPlayoff {
            regulationPuzzles = (0..<4).map {
                let (puzzle, map) = Self.resolveWithRoster(ids.regulation[$0], quarterIndex: $0)
                maps.append(map)
                statMaps.append(CaseLibrary.statEvents(forCaseID: ids.regulation[$0]))
                return Self.intensified(puzzle)
            }
            let (overtime, overtimeMap) = Self.resolveWithRoster(ids.overtime, quarterIndex: 4)
            maps.append(overtimeMap)
            statMaps.append(CaseLibrary.statEvents(forCaseID: ids.overtime))
            overtimePuzzle = Self.intensified(overtime)
        } else {
            var regulation: [QuarterPuzzle] = []
            for index in 0..<4 {
                let (puzzle, map) = Self.resolveWithRoster(ids.regulation[index], quarterIndex: index)
                maps.append(map)
                statMaps.append(CaseLibrary.statEvents(forCaseID: ids.regulation[index]))
                regulation.append(puzzle)
            }
            regulationPuzzles = regulation
            let (overtime, overtimeMap) = Self.resolveWithRoster(ids.overtime, quarterIndex: 4)
            maps.append(overtimeMap)
            statMaps.append(CaseLibrary.statEvents(forCaseID: ids.overtime))
            overtimePuzzle = overtime
        }
        identityMaps = maps
        statEventMaps = statMaps
    }

    /// Resolves a scheduled case id and dresses its missing players in the
    /// franchise roster's identities; falls back to the first library case if
    /// the id cannot be found (never expected — covered by tests).
    private static func resolveWithRoster(_ id: String, quarterIndex: Int) -> (QuarterPuzzle, [String: RosterIdentity]) {
        let map = RosterManager.shared.identityAssignments(forCaseID: id)
        let puzzle = CaseLibrary.puzzle(id: id, quarterIndex: quarterIndex)
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
        phase = .quarterIntro
    }

    func beginQuarter() {
        Haptics.tick()
        phase = .playing
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
        if match.isComplete {
            grantMatchReward()
        }
        withAnimation(.easeInOut(duration: 0.3)) {
            phase = match.isComplete ? .gameResult : .quarterResult
        }
    }

    /// Grants the game's Game Ball reward exactly once — losing never
    /// subtracts anything, and the wallet's transaction ledger makes a double
    /// claim impossible.
    private func grantMatchReward() {
        let breakdown = MatchRewardBreakdown.forMatch(
            match,
            isPlayoff: isPlayoff,
            isChampionship: isChampionship,
            transactionID: "match-\(matchID.uuidString)"
        )
        rewardBreakdown = breakdown
        PlayerWallet.shared.claimMatchReward(breakdown)
    }

    /// From the quarter-result screen: either the next quarter intro or the verdict.
    func continueFlow() {
        Haptics.tick()
        AudioManager.shared.play(.buttonPress)
        phase = match.isComplete ? .gameResult : .quarterIntro
    }
}

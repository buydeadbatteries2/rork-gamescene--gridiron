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

    /// Draws the game's case files from the local puzzle library via the
    /// deterministic scheduler: no case repeats within a game, and across a
    /// 10-week regular season all 40 regulation cases are different.
    /// - Parameters:
    ///   - seasonNumber: 0 for a standalone/quick game.
    ///   - week: 1–10 in the regular season; 11+ resolves playoff rotations.
    init(isPlayoff: Bool = false, seasonNumber: Int = 0, week: Int = 1) {
        let ids = CaseScheduler.gameCaseIDs(seasonNumber: seasonNumber, week: week)
        if isPlayoff {
            regulationPuzzles = (0..<4).map {
                Self.intensified(Self.resolve(ids.regulation[$0], quarterIndex: $0))
            }
            overtimePuzzle = Self.intensified(Self.resolve(ids.overtime, quarterIndex: 4))
        } else {
            regulationPuzzles = (0..<4).map { Self.resolve(ids.regulation[$0], quarterIndex: $0) }
            overtimePuzzle = Self.resolve(ids.overtime, quarterIndex: 4)
        }
    }

    /// Resolves a scheduled case id; falls back to the first library case if
    /// the id cannot be found (never expected — covered by tests).
    private static func resolve(_ id: String, quarterIndex: Int) -> QuarterPuzzle {
        CaseLibrary.puzzle(id: id, quarterIndex: quarterIndex)
            ?? CaseLibrary.puzzle(for: CaseLibrary.all[0], quarterIndex: quarterIndex)
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

    // MARK: Flow

    func startGame() {
        match = .fresh()
        phase = .quarterIntro
    }

    func beginQuarter() {
        Haptics.tick()
        phase = .playing
    }

    /// Called when `GameViewModel` reaches a verdict. Reads the finished quarter's
    /// stats from the puzzle view model and stores them at match level.
    func finishQuarter(with viewModel: GameViewModel) {
        guard viewModel.result != .inProgress else { return }
        let outcome: QuarterOutcome = viewModel.result == .won ? .solved : .failed
        match.recordQuarter(
            index: viewModel.puzzleIndex,
            label: viewModel.puzzle.quarterLabel,
            isOvertime: viewModel.puzzleIndex >= GameMatch.regulationQuarters,
            outcome: outcome,
            correctPlacements: viewModel.placements.count,
            wrongPlacements: viewModel.rejectionCount,
            livesLost: viewModel.puzzle.startingLives - viewModel.lives,
            hintsUsed: viewModel.usedHints.count
        )
        withAnimation(.easeInOut(duration: 0.3)) {
            phase = match.isComplete ? .gameResult : .quarterResult
        }
    }

    /// From the quarter-result screen: either the next quarter intro or the verdict.
    func continueFlow() {
        Haptics.tick()
        AudioManager.shared.play(.buttonPress)
        phase = match.isComplete ? .gameResult : .quarterIntro
    }
}

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

    /// Playoff games reuse the handcrafted quarters under postseason pressure:
    /// one less life and one less hint per quarter (floors 2 / 1). The puzzle
    /// logic itself never changes.
    init(isPlayoff: Bool = false) {
        if isPlayoff {
            regulationPuzzles = MatchPuzzles.regulation.map(Self.intensified)
            overtimePuzzle = Self.intensified(MatchPuzzles.overtime)
        } else {
            regulationPuzzles = MatchPuzzles.regulation
            overtimePuzzle = MatchPuzzles.overtime
        }
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

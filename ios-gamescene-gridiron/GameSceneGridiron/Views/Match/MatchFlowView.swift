import SwiftUI

/// Owns one full game: quarter intro → live quarter → quarter result → …
/// → optional overtime → final verdict. The Home screen presents this full screen.
struct MatchFlowView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var matchViewModel = MatchViewModel()
    @State private var quarterViewModel: GameViewModel?

    var body: some View {
        ZStack {
            switch matchViewModel.phase {
            case .quarterIntro:
                QuarterIntroView(
                    puzzle: matchViewModel.currentPuzzle,
                    isOvertime: matchViewModel.match.isOvertime,
                    onBegin: beginQuarter
                )
                .transition(.opacity)

            case .playing:
                if let quarterViewModel {
                    GameplayView(
                        viewModel: quarterViewModel,
                        matchViewModel: matchViewModel,
                        onQuit: { dismiss() },
                        onQuarterComplete: { matchViewModel.finishQuarter(with: $0) }
                    )
                    .id(matchViewModel.match.currentQuarterIndex)
                    .transition(.opacity)
                }

            case .quarterResult:
                if let quarterViewModel {
                    QuarterResultView(
                        viewModel: quarterViewModel,
                        matchViewModel: matchViewModel,
                        onContinue: { matchViewModel.continueFlow() }
                    )
                    .transition(.opacity)

                }

            case .gameResult:
                MatchResultView(
                    matchViewModel: matchViewModel,
                    onPlayAgain: playAgain,
                    onHome: { dismiss() }
                )
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: matchViewModel.phase)
    }

    private func beginQuarter() {
        quarterViewModel = GameViewModel(puzzle: matchViewModel.currentPuzzle)
        matchViewModel.beginQuarter()
    }

    private func playAgain() {
        quarterViewModel = nil
        matchViewModel.startGame()
    }
}

#Preview {
    MatchFlowView()
}

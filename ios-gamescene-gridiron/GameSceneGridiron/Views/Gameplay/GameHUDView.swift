import SwiftUI

/// Top HUD: quarter tag, lives, hints, pause — plus the regulation progress track.
struct GameHUDView: View {
    let viewModel: GameViewModel
    var matchViewModel: MatchViewModel?
    let onPause: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 10) {
                Text(viewModel.puzzle.quarterLabel)
                    .font(Theme.typewriterBold(22, relativeTo: .title3))
                    .foregroundStyle(Theme.paperInk)
                    .frame(width: 64, height: 46)
                    .paperCard(cornerRadius: 3)
                    .rotationEffect(.degrees(-2))
                    .accessibilityLabel(viewModel.puzzle.index < GameMatch.regulationQuarters
                        ? "Quarter \(viewModel.puzzle.index + 1)"
                        : "Overtime")

            Spacer(minLength: 0)

            LivesView(lives: viewModel.lives, maxLives: viewModel.puzzle.startingLives)

            Spacer(minLength: 0)

            Button {
                viewModel.useHint()
            } label: {
                Image(systemName: "lightbulb.max")
                    .symbolEffect(.bounce, value: viewModel.hintsRemaining)
            }
            .buttonStyle(HUDButtonStyle())
            .overlay(alignment: .topTrailing) {
                Text("\(viewModel.hintsRemaining)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 20, height: 20)
                    .background(viewModel.hintsRemaining > 0 ? Theme.bronze : Color.gray, in: .circle)
                    .overlay { Circle().strokeBorder(Theme.ink, lineWidth: 1.5) }
                    .offset(x: 6, y: -6)
                    .allowsHitTesting(false)
            }
            .opacity(viewModel.hintsRemaining > 0 ? 1 : 0.5)
            .accessibilityLabel("Use hint, \(viewModel.hintsRemaining) remaining")

            Button(action: onPause) {
                Image(systemName: "pause.fill")
            }
            .buttonStyle(HUDButtonStyle())
            .accessibilityLabel("Pause")
            }

            if let matchViewModel {
                QuarterProgressTrack(match: matchViewModel.match)
            }
        }
    }
}

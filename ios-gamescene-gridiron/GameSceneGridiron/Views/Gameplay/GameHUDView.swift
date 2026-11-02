import SwiftUI

/// Top HUD: quarter tag, lives, hints, pause — plus the regulation progress track.
struct GameHUDView: View {
    let viewModel: GameViewModel
    var matchViewModel: MatchViewModel?
    /// Tutorial: a soft pulsing halo teaches what the hint button does.
    var highlightHint: Bool = false
    /// Tutorial-only header exit control (safe exit path from the TRAINING CASE).
    var trainingExit: (() -> Void)? = nil
    let onPause: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 10) {
                Text(viewModel.puzzle.quarterLabel)
                    .font(Theme.typewriterBold(22, relativeTo: .title3))
                    .foregroundStyle(Theme.paperInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                    .padding(.horizontal, 4)
                    .frame(width: 64, height: 46)
                    .paperCard(cornerRadius: 3)
                    .rotationEffect(.degrees(-2))
                    .accessibilityLabel(viewModel.puzzle.index < GameMatch.regulationQuarters
                        ? "Quarter \(viewModel.puzzle.index + 1)"
                        : "Overtime")

            Spacer(minLength: 0)

            LivesView(lives: viewModel.lives, maxLives: viewModel.puzzle.startingLives)

            Spacer(minLength: 0)

            if viewModel.hintsDisabled {
                // Versus: the hint button is visibly off — no count, no offer.
                Image(systemName: "lightbulb.slash")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.paper.opacity(0.45))
                    .frame(width: 46, height: 46)
                    .background(Theme.charcoal.opacity(0.6), in: .circle)
                    .accessibilityLabel("Hints disabled in Versus")
            } else {
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
                .overlay {
                    if highlightHint {
                        PulsingHalo()
                            .padding(-4)
                            .allowsHitTesting(false)
                    }
                }
                .accessibilityLabel("Use hint, \(viewModel.hintsRemaining) remaining")
            }

            Button(action: onPause) {
                Image(systemName: "pause.fill")
            }
            .buttonStyle(HUDButtonStyle())
            .accessibilityLabel("Pause")

            if let trainingExit {
                Button(action: trainingExit) {
                    Image(systemName: "xmark")
                }
                .buttonStyle(HUDButtonStyle())
                .accessibilityLabel("Exit training")
            }
            }

            if let matchViewModel {
                QuarterProgressTrack(match: matchViewModel.match)
            }

            if viewModel.hintsDisabled {
                VersusHintsDisabledChip()
            }

            // Hall of Famer pressure: play clock + timeouts. Untimed modes
            // never see this strip.
            if viewModel.isTimed {
                PlayClockStrip(viewModel: viewModel)
            }
        }
    }
}

/// Small, unobtrusive Versus marker under the HUD.
struct VersusHintsDisabledChip: View {
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "lightbulb.slash.fill")
                .font(.system(size: 9, weight: .bold))
            Text("HINTS DISABLED — COMPETITIVE CASE")
                .font(.system(size: 10, weight: .heavy).width(.condensed))
                .tracking(1)
        }
        .foregroundStyle(Theme.goldLight.opacity(0.85))
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Theme.ink.opacity(0.55), in: .capsule)
        .overlay { Capsule().strokeBorder(Theme.gold.opacity(0.3), lineWidth: 1) }
        .accessibilityLabel("Hints disabled. Competitive case.")
    }
}

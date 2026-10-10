import SwiftUI

/// The short cinematic intro: wordmark, the premise line, the four-verb creed
/// and BEGIN. Kept deliberately short — this is a doorway, not a manual.
struct IntroView: View {
    let onBegin: () -> Void

    @State private var hasAppeared: Bool = false

    private var fadeAnimation: Animation? {
        Motion.isReduced ? nil : .easeOut(duration: 0.8).delay(0.2)
    }

    var body: some View {
        ZStack {
            DeskBackground()

            VStack(spacing: 26) {
                Spacer()

                GSLogoView()
                    .opacity(hasAppeared ? 1 : 0)
                    .scaleEffect(hasAppeared || Motion.isReduced ? 1 : 0.94)

                VStack(spacing: 12) {
                    Text("GAMESCENE: GRIDIRON")
                        .font(Theme.display(27))
                        .tracking(2)
                        .foregroundStyle(Theme.goldGradient)
                        .multilineTextAlignment(.center)

                    Text("Every play leaves evidence.")
                        .font(Theme.typewriter(17, relativeTo: .title3))
                        .foregroundStyle(Theme.paperInk)
                        .multilineTextAlignment(.center)
                }
                .opacity(hasAppeared ? 1 : 0)

                Rectangle()
                    .fill(Theme.bronze.opacity(0.5))
                    .frame(width: 54, height: 1.5)
                    .opacity(hasAppeared ? 1 : 0)

                Text("Study the field. Read the clues.\nPlace the players. Solve the case.")
                    .font(Theme.typewriter(14, relativeTo: .callout))
                    .foregroundStyle(Theme.paperInkSoft)
                    .lineSpacing(4)
                    .multilineTextAlignment(.center)
                    .opacity(hasAppeared ? 1 : 0)

                Spacer()

                Button {
                    Haptics.pickUp()
                    AudioManager.shared.play(.profileSelect)
                    onBegin()
                } label: {
                    Text("BEGIN")
                        .font(.system(size: 16, weight: .heavy).width(.condensed))
                        .tracking(3)
                        .padding(.horizontal, 54)
                }
                .buttonStyle(GoldCapsuleButtonStyle())
                .padding(.bottom, 44)
                .opacity(hasAppeared ? 1 : 0)
            }
        }
        .onAppear {
            withAnimation(fadeAnimation) { hasAppeared = true }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("GameScene: Gridiron. Every play leaves evidence. Study the field, read the clues, place the players, solve the case.")
    }
}

#Preview {
    IntroView(onBegin: {})
        .preferredColorScheme(.dark)
}

import SwiftUI

/// The stable ids of every one-time contextual tooltip (persisted via
/// `TutorialManager`; each appears exactly once unless tutorial data resets).
enum ContextualTooltip {
    static let gameBalls = "gameBalls"
    static let teamScreen = "teamScreen"
    static let playerStats = "playerStats"
    static let postseason = "postseason"
}

/// One-time contextual tooltip: a pinned paper note with typewriter copy and a
/// GOT IT button. Presentation is gated by `TutorialManager` tooltip ids —
/// each appears exactly once unless tutorial data is reset.
struct FirstTimeTooltip: View {
    let text: String
    var onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)

            VStack(spacing: 14) {
                Text("DID YOU KNOW?")
                    .font(.system(size: 11, weight: .heavy).width(.condensed))
                    .tracking(2)
                    .foregroundStyle(Theme.bronzeDeep)

                Text(text)
                    .font(Theme.typewriter(14, relativeTo: .callout))
                    .foregroundStyle(Theme.paperInk)
                    .lineSpacing(3)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    Haptics.tick()
                    AudioManager.shared.play(.buttonPress)
                    onDismiss()
                } label: {
                    Text("GOT IT")
                        .font(.system(size: 13, weight: .heavy).width(.condensed))
                        .tracking(1.5)
                        .foregroundStyle(Theme.ink)
                        .frame(maxWidth: .infinity, minHeight: 40)
                }
                .buttonStyle(GoldCapsuleButtonStyle())
            }
            .padding(18)
            .paperCard(cornerRadius: 6)
            .shadow(color: .black.opacity(0.7), radius: 18, y: 10)
            .padding(.horizontal, 36)
            .accessibilityElement(children: .combine)
        }
        .transition(.opacity)
    }
}

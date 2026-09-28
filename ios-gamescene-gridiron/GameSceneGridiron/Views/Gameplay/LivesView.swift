import SwiftUI

/// Hearts for the current quarter only.
struct LivesView: View {
    let lives: Int
    let maxLives: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<maxLives, id: \.self) { index in
                let isAlive = index < lives
                Image(systemName: isAlive ? "heart.fill" : "heart.slash")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(isAlive ? AnyShapeStyle(heartGradient) : AnyShapeStyle(Color.white.opacity(0.22)))
                    .shadow(color: isAlive ? Theme.heart.opacity(0.55) : .clear, radius: 6)
                    .scaleEffect(isAlive ? 1 : 0.82)
                    .contentTransition(.symbolEffect(.replace))
                    .animation(.spring(response: 0.35, dampingFraction: 0.5), value: isAlive)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 46)
        .background(Color.black.opacity(0.35), in: .capsule)
        .overlay { Capsule().strokeBorder(Theme.gold.opacity(0.18), lineWidth: 1) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(lives) of \(maxLives) lives left this quarter")
    }

    private var heartGradient: LinearGradient {
        LinearGradient(colors: [Color(hex: 0xFF6A5E), Theme.heart, Color(hex: 0x9E231B)], startPoint: .top, endPoint: .bottom)
    }
}

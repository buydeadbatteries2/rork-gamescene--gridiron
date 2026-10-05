import SwiftUI

/// Subtle current-difficulty tag used on the season screen and the pregame
/// brief — a small dark capsule with gold condensed type, matching the week
/// chip. The gameplay HUD stays untouched.
struct DifficultyBadge: View {
    let level: DifficultyLevel

    var body: some View {
        Text(level.title)
            .font(.system(size: 9, weight: .heavy).width(.condensed))
            .tracking(1.6)
            .foregroundStyle(Theme.goldLight)
            .padding(.horizontal, 9)
            .padding(.vertical, 3)
            .background(Color.black.opacity(0.6), in: .capsule)
            .accessibilityLabel("Difficulty: \(level.title)")
    }
}

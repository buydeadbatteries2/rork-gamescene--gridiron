import SwiftUI

/// The premium ACHIEVEMENT UNLOCKED notification. Mounted once at the app root;
/// reads `AchievementManager.shared`. Unlocks only ever queue at safe breaks
/// (quarter result, match result, season completion), so this never interrupts
/// a live drag/drop — but the popup still waits for a tap or its timer before
/// the next one slides up.
struct AchievementPopupView: View {
    @State private var achievementManager = AchievementManager.shared
    @State private var isVisible = false
    @State private var glow = false

    private var achievement: Achievement? { achievementManager.currentPopup }

    var body: some View {
        VStack {
            if let achievement {
                card(for: achievement)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .id(achievement.id)
            }
            Spacer()
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: achievement?.id)
        .task(id: achievement?.id) {
            guard let achievement else { return }
            // Metallic treatment: short sting + success haptic on arrival.
            AudioManager.shared.play(.caseSolved)
            Haptics.success()
            isVisible = true
            _ = achievement
            try? await Task.sleep(for: .seconds(4.6))
            dismiss()
        }
    }

    private func dismiss() {
        withAnimation(.easeOut(duration: 0.3)) { isVisible = false }
        achievementManager.dismissPopup()
    }

    // MARK: Card

    private func card(for achievement: Achievement) -> some View {
        HStack(spacing: 14) {
            medallion(for: achievement)

            VStack(alignment: .leading, spacing: 3) {
                Text("ACHIEVEMENT UNLOCKED")
                    .font(.system(size: 9, weight: .black).width(.condensed))
                    .tracking(2)
                    .foregroundStyle(Theme.gold)
                Text(achievement.name)
                    .font(.system(size: 19, weight: .black).width(.compressed))
                    .tracking(0.8)
                    .foregroundStyle(Theme.goldGradient)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(achievement.detail)
                    .font(Theme.typewriter(11, relativeTo: .caption))
                    .foregroundStyle(Theme.paperInkSoft)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                if achievement.reward > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "sportscourt.fill")
                            .font(.system(size: 9, weight: .bold))
                        Text("+\(achievement.reward) GAME BALLS")
                            .font(.system(size: 9, weight: .black).width(.condensed))
                            .tracking(1.2)
                    }
                    .foregroundStyle(Theme.goldLight)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "xmark")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Theme.paperInkSoft.opacity(0.7))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background(cardBackground)
        .clipShape(.rect(cornerRadius: 10))
        .overlay { RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.goldGradient, lineWidth: 1.4) }
        .shadow(color: Theme.gold.opacity(glow && !Motion.isReduced ? 0.45 : 0.18), radius: glow ? 26 : 14, y: 6)
        .shadow(color: .black.opacity(0.6), radius: 16, y: 8)
        .padding(.horizontal, 18)
        .padding(.top, 54)
        .onTapGesture { dismiss() }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Achievement unlocked: \(achievement.name). \(achievement.detail)")
    }

    /// Brushed-metal plate: layered gradients with a top sheen, like an
    /// engraved case plaque under the desk lamp.
    private var cardBackground: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: 0x2A2318), Color(hex: 0x1B160E), Color(hex: 0x241D12)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            LinearGradient(
                colors: [Color.white.opacity(0.14), .clear],
                startPoint: .top,
                endPoint: .center
            )
            RadialGradient(
                colors: [Theme.gold.opacity(0.22), .clear],
                center: UnitPoint(x: 0.5, y: -0.3),
                startRadius: 5,
                endRadius: 220
            )
        }
        .overlay {
            if !Motion.isReduced {
                // Subtle breathing glow behind the border.
                RoundedRectangle(cornerRadius: 10)
                    .fill(Theme.gold.opacity(0.001))
                    .shadow(color: Theme.gold.opacity(0.5), radius: 8)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { glow = true }
                    }
            }
        }
    }

    private func medallion(for achievement: Achievement) -> some View {
        ZStack {
            Circle()
                .fill(Theme.goldGradient)
            Circle()
                .stroke(Theme.bronzeDeep, lineWidth: 2)
                .padding(2)
            Image(systemName: achievement.symbol)
                .font(.system(size: 21, weight: .bold))
                .foregroundStyle(Theme.ink)
        }
        .frame(width: 50, height: 50)
        .shadow(color: Theme.gold.opacity(0.5), radius: 8)
        .accessibilityHidden(true)
    }
}

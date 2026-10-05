import SwiftUI

// MARK: - Game Ball icon & wallet widgets

/// The Game Ball currency icon — a gold football, used consistently everywhere
/// the currency appears (wallet, rewards, shop, prices).
struct GameBallIcon: View {
    var size: CGFloat = 14

    var body: some View {
        Image(systemName: "football.fill")
            .font(.system(size: size, weight: .semibold))
            .foregroundStyle(Theme.goldGradient)
            .shadow(color: Theme.gold.opacity(0.4), radius: 3)
    }
}

/// Compact wallet pill: football icon + balance. Used on Home and in the shop.
struct WalletPill: View {
    let amount: Int
    var label: String = "GAME BALLS"

    var body: some View {
        HStack(spacing: 6) {
            GameBallIcon(size: 13)
            Text("\(amount)")
                .font(Theme.condensed(17))
                .monospacedDigit()
                .foregroundStyle(Theme.paperInk)
            Text(label)
                .font(Theme.condensed(9))
                .tracking(1.2)
                .foregroundStyle(Theme.goldLight)
        }
        .padding(.horizontal, 12)
        .frame(height: 38)
        .background(Color.black.opacity(0.55), in: .capsule)
        .overlay { Capsule().strokeBorder(Theme.gold.opacity(0.35), lineWidth: 1) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label.lowercased()): \(amount)")
    }
}

/// Hint pill matching the wallet pill's shape for the Home strip.
struct HintPill: View {
    let count: Int

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.goldGradient)
            Text("\(count)")
                .font(Theme.condensed(17))
                .monospacedDigit()
                .foregroundStyle(Theme.paperInk)
            Text("HINTS")
                .font(Theme.condensed(9))
                .tracking(1.2)
                .foregroundStyle(Theme.goldLight)
        }
        .padding(.horizontal, 12)
        .frame(height: 38)
        .background(Color.black.opacity(0.55), in: .capsule)
        .overlay { Capsule().strokeBorder(Theme.gold.opacity(0.35), lineWidth: 1) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Hints: \(count)")
    }
}

// MARK: - Count-up

/// Animates an integer counting up from `from` to `to` with soft haptic ticks —
/// the cinematic wallet-fill for postgame rewards.
struct CountUpNumber: View {
    let from: Int
    let to: Int
    var duration: Double = 0.9
    var size: CGFloat = 30

    @State private var displayed: Int = 0
    @State private var hasStarted = false

    var body: some View {
        Text("\(displayed)")
            .font(.system(size: size, weight: .black).width(.compressed))
            .monospacedDigit()
            .foregroundStyle(Theme.goldLight)
            .contentTransition(.numericText())
            .task(id: to) { await animate() }
            .accessibilityValue("\(to)")
    }

    private func animate() async {
        let start = hasStarted ? displayed : from
        hasStarted = true
        guard to != start else {
            displayed = to
            return
        }
        let steps = max(1, min(24, abs(to - start)))
        for step in 1...steps {
            try? await Task.sleep(for: .seconds(duration / Double(steps)))
            displayed = start + Int((Double(to - start) * Double(step) / Double(steps)).rounded())
            Haptics.soft()
        }
    }
}

import SwiftUI

// MARK: - Rewarded-video offer overlays

/// Shared chrome for the two rewarded-video offers: a dimmed backdrop over the
/// live quarter with a pinned manila card. Buttons stay disabled while the ad
/// plays; the reward is granted only after the SDK's reward callback.
private struct RewardedOfferLayout<Content: View>: View {
    let heading: String
    let headingColor: AnyShapeStyle
    @ViewBuilder let content: Content

    var body: some View {
        ZStack {
            Color.black.opacity(0.72).ignoresSafeArea()
            VStack(spacing: 16) {
                Text(heading)
                    .font(.system(size: 40, weight: .black).width(.compressed))
                    .tracking(1)
                    .foregroundStyle(headingColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .padding(.horizontal, 20)
                    .padding(.top, 18)

                content
                    .padding(.horizontal, 18)
                    .padding(.bottom, 18)
            }
            .frame(maxWidth: 320)
            .paperCard(cornerRadius: 4)
            .overlay(alignment: .top) { PushPin().offset(y: -9) }
            .padding(.top, 9)
            .shadow(color: .black.opacity(0.8), radius: 24, y: 12)
            .padding(24)
        }
        .transition(.opacity)
    }
}

/// "NEED A HINT?" — offered when the player presses Hint with 0 hints left.
/// WATCH VIDEO grants exactly 1 hint through the reward callback; the Game
/// Ball shortcut is a plain purchase with the same confirmation wording.
struct HintOfferOverlay: View {
    let isWatching: Bool
    let canAffordHint: Bool
    let hintCost: Int
    let onWatch: () -> Void
    let onBuy: () -> Void
    let onCancel: () -> Void

    var body: some View {
        RewardedOfferLayout(
            heading: "NEED A HINT?",
            headingColor: AnyShapeStyle(Theme.goldGradient)
        ) {
            VStack(spacing: 14) {
                Text("Watch a short video to receive 1 Hint.")
                    .font(Theme.typewriter(14, relativeTo: .subheadline))
                    .foregroundStyle(Theme.paperInk)
                    .multilineTextAlignment(.center)

                Button {
                    Haptics.pickUp()
                    onWatch()
                } label: {
                    HStack(spacing: 10) {
                        if isWatching {
                            ProgressView()
                                .tint(Theme.ink)
                        } else {
                            Image(systemName: "play.rectangle.fill")
                                .font(.system(size: 16, weight: .bold))
                        }
                        Text(isWatching ? "WATCHING…" : "WATCH VIDEO")
                            .font(.system(size: 16, weight: .heavy).width(.compressed))
                            .tracking(1)
                    }
                    .frame(maxWidth: .infinity, minHeight: 52)
                }
                .buttonStyle(GoldCapsuleButtonStyle())
                .disabled(isWatching)
                .accessibilityHint("Rewards one hint")

                if canAffordHint {
                    Button {
                        Haptics.tick()
                        onBuy()
                    } label: {
                        HStack(spacing: 8) {
                            GameBallIcon(size: 12)
                            Text("USE \(hintCost) GAME BALLS TO ADD 1 HINT?")
                                .font(.system(size: 12, weight: .heavy).width(.condensed))
                                .tracking(0.8)
                        }
                        .foregroundStyle(Theme.paperInk)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .overlay { Capsule().strokeBorder(Theme.bronze.opacity(0.7), lineWidth: 1.2) }
                        .contentShape(.capsule)
                    }
                    .buttonStyle(PressableButtonStyle(playsPressSound: true))
                    .disabled(isWatching)
                }

                Button(action: onCancel) {
                    Text("CANCEL")
                        .font(.system(size: 13, weight: .semibold))
                        .tracking(2)
                        .foregroundStyle(Theme.paperInkSoft)
                        .frame(maxWidth: .infinity, minHeight: 40)
                }
                .disabled(isWatching)
            }
        }
    }
}

/// "LAST CHANCE" — offered once per quarter when the final heart is lost.
/// A completed rewarded ad grants exactly +1 heart and resumes the quarter;
/// accepting the loss finishes the quarter normally.
struct LastChanceOverlay: View {
    let isWatching: Bool
    let onWatch: () -> Void
    let onAccept: () -> Void

    var body: some View {
        RewardedOfferLayout(
            heading: "LAST CHANCE",
            headingColor: AnyShapeStyle(Theme.danger)
        ) {
            VStack(spacing: 14) {
                HStack(spacing: 6) {
                    Image(systemName: "heart.slash")
                        .foregroundStyle(Theme.heart)
                    Text("Watch a video for one more attempt?")
                        .font(Theme.typewriter(14, relativeTo: .subheadline))
                        .foregroundStyle(Theme.paperInk)
                }
                .multilineTextAlignment(.center)

                Button {
                    Haptics.pickUp()
                    onWatch()
                } label: {
                    HStack(spacing: 10) {
                        if isWatching {
                            ProgressView()
                                .tint(Theme.ink)
                        } else {
                            Image(systemName: "heart.fill")
                                .foregroundStyle(Theme.heart)
                        }
                        Text(isWatching ? "WATCHING…" : "WATCH VIDEO — +1 LIFE")
                            .font(.system(size: 16, weight: .heavy).width(.compressed))
                            .tracking(1)
                    }
                    .frame(maxWidth: .infinity, minHeight: 52)
                }
                .buttonStyle(GoldCapsuleButtonStyle())
                .disabled(isWatching)
                .accessibilityHint("Rewards one extra life this quarter")

                Button {
                    Haptics.warning()
                    onAccept()
                } label: {
                    Text("ACCEPT QUARTER LOSS")
                        .font(.system(size: 14, weight: .heavy).width(.condensed))
                        .tracking(1.5)
                        .foregroundStyle(Theme.danger)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .overlay {
                            Capsule().strokeBorder(Theme.danger.opacity(0.55), lineWidth: 1.4)
                        }
                        .contentShape(.capsule)
                }
                .buttonStyle(PressableButtonStyle())
                .disabled(isWatching)
            }
        }
    }
}

/// Small confirmation before spending Game Balls on a hint.
struct HintPurchaseConfirmation: View {
    let hintCost: Int
    let balance: Int
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: 14) {
                Text("USE \(hintCost) GAME BALLS\nTO ADD 1 HINT?")
                    .font(.system(size: 22, weight: .black).width(.compressed))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.paperInk)

                HStack(spacing: 8) {
                    GameBallIcon(size: 12)
                    Text("Balance: \(balance)")
                        .font(Theme.typewriter(12, relativeTo: .caption))
                        .foregroundStyle(Theme.paperInkSoft)
                }

                Button {
                    Haptics.success()
                    onConfirm()
                } label: {
                    Text("CONFIRM")
                        .font(.system(size: 15, weight: .heavy).width(.condensed))
                        .tracking(2)
                        .frame(maxWidth: .infinity, minHeight: 46)
                }
                .buttonStyle(GoldCapsuleButtonStyle())

                Button(action: onCancel) {
                    Text("CANCEL")
                        .font(.system(size: 12, weight: .semibold))
                        .tracking(2)
                        .foregroundStyle(Theme.paperInkSoft)
                }
            }
            .padding(20)
            .frame(maxWidth: 300)
            .paperCard(cornerRadius: 4)
            .overlay(alignment: .top) { PushPin().offset(y: -9) }
            .padding(.top, 9)
            .padding(24)
        }
        .transition(.opacity)
    }
}

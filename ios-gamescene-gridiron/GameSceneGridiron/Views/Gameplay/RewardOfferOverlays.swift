import SwiftUI

// MARK: - Rewarded / gate overlays

/// Shared chrome for the rewarded offers and forced-ad gates: a dimmed
/// backdrop over the live quarter with a pinned manila card. Buttons stay
/// disabled while the ad plays; the reward is granted only after the SDK's
/// reward callback.
private struct RewardedOfferLayout<Content: View>: View {
    let heading: String
    let headingColor: AnyShapeStyle
    var subheading: String? = nil
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

                if let subheading {
                    Text(subheading)
                        .font(Theme.typewriter(13, relativeTo: .subheadline))
                        .foregroundStyle(Theme.paperInkSoft)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 22)
                }

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

/// "NEED A HINT?" — offered when the player presses Hint with nothing
/// payable in the wallet. WATCH VIDEO grants exactly 1 hint through the
/// reward callback; the Shop path covers a wallet that can't cover the
/// Game Ball price.
struct HintOfferOverlay: View {
    let isWatching: Bool
    let canAffordHint: Bool
    let hintCost: Int
    let onWatch: () -> Void
    let onBuy: () -> Void
    let onOpenShop: () -> Void
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
                } else {
                    Button {
                        Haptics.tick()
                        onOpenShop()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "cart.fill")
                                .font(.system(size: 13, weight: .bold))
                            Text("OPEN SHOP — NEED \(hintCost) GAME BALLS")
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
                    .accessibilityHint("Opens the shop to earn or buy Game Balls")
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

/// "LAST CHANCE" — the full rescue offer when the final heart is gone:
/// WATCH VIDEO (once per quarter), USE HINT (payable hint → simplified
/// lead + one attempt), or TAKE THE LOSS.
struct LastChanceOverlay: View {
    let isWatching: Bool
    let canOfferHint: Bool
    let onWatch: () -> Void
    let onUseHint: () -> Void
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
                    Text("One more attempt at this quarter?")
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
                        Text(isWatching ? "WATCHING…" : "WATCH VIDEO")
                            .font(.system(size: 16, weight: .heavy).width(.compressed))
                            .tracking(1)
                    }
                    .frame(maxWidth: .infinity, minHeight: 52)
                }
                .buttonStyle(GoldCapsuleButtonStyle())
                .disabled(isWatching)
                .accessibilityHint("Rewards one extra attempt this quarter")

                if canOfferHint {
                    Button {
                        Haptics.tick()
                        onUseHint()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "lightbulb.fill")
                                .font(.system(size: 13, weight: .bold))
                            Text("USE HINT — SIMPLIFIES A CLUE")
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
                    .accessibilityHint("Simplifies a clue and grants one more attempt")
                }

                Button {
                    Haptics.warning()
                    onAccept()
                } label: {
                    Text("TAKE THE LOSS")
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

/// "NEED SOME HELP?" — the post-video stage: the rewarded rescue already
/// failed, so the only way out is a hint rescue or the loss. Never a second
/// video.
struct PostVideoRescueOverlay: View {
    let canOfferHint: Bool
    let onUseHint: () -> Void
    let onAccept: () -> Void

    var body: some View {
        RewardedOfferLayout(
            heading: "NEED SOME HELP?",
            headingColor: AnyShapeStyle(Theme.danger)
        ) {
            VStack(spacing: 14) {
                Text("The video rescue didn't land. Simplify a clue for one final attempt.")
                    .font(Theme.typewriter(14, relativeTo: .subheadline))
                    .foregroundStyle(Theme.paperInk)
                    .multilineTextAlignment(.center)

                if canOfferHint {
                    Button {
                        Haptics.tick()
                        onUseHint()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "lightbulb.fill")
                                .font(.system(size: 13, weight: .bold))
                            Text("USE HINT")
                                .font(.system(size: 15, weight: .heavy).width(.condensed))
                                .tracking(1)
                        }
                        .frame(maxWidth: .infinity, minHeight: 52)
                    }
                    .buttonStyle(GoldCapsuleButtonStyle())
                    .accessibilityHint("Simplifies a clue and grants one final attempt")
                }

                Button {
                    Haptics.warning()
                    onAccept()
                } label: {
                    Text("TAKE QUARTER LOSS")
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
            }
        }
    }
}

/// Forced full-screen gate between quarters / into overtime. WATCH AD is the
/// always-free route; Game Balls only skip the ad. Never shown for a lost
/// quarter, an ad-free owner, or after the per-game cap.
struct AdGateOverlay: View {
    let skipCost: Int
    let isOvertime: Bool
    let isWatching: Bool
    let canAffordSkip: Bool
    let onWatch: () -> Void
    let onSkip: () -> Void

    private var heading: String { isOvertime ? "OVERTIME" : "INTERMISSION" }
    private var subheading: String {
        isOvertime
            ? "The game is tied. One more case decides it."
            : "A short break before the next quarter."
    }

    var body: some View {
        RewardedOfferLayout(
            heading: heading,
            headingColor: AnyShapeStyle(Theme.goldGradient),
            subheading: subheading
        ) {
            VStack(spacing: 14) {
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
                        Text(isWatching ? "WATCHING…" : (isOvertime ? "WATCH AD TO CONTINUE" : "WATCH AD"))
                            .font(.system(size: 16, weight: .heavy).width(.compressed))
                            .tracking(1)
                    }
                    .frame(maxWidth: .infinity, minHeight: 52)
                }
                .buttonStyle(GoldCapsuleButtonStyle())
                .disabled(isWatching)
                .accessibilityHint("Always free — continues to the next quarter")

                if canAffordSkip {
                    Button {
                        Haptics.tick()
                        onSkip()
                    } label: {
                        HStack(spacing: 8) {
                            GameBallIcon(size: 12)
                            Text("SKIP AD — \(skipCost) GAME BALLS")
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
                    .accessibilityHint("Spends Game Balls to skip the advertisement")
                }
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
                Text("USE \(hintCost) GAME BALLS\nto add 1 hint?")
                    .font(.system(size: 22, weight: .black).width(.compressed))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.paperInk)
                    .textCase(.uppercase)

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

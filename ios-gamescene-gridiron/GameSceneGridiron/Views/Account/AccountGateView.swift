import SwiftUI

/// ACCOUNT REQUIRED gate — the reusable front door for every future online
/// competition surface (leaderboards, versus, factions, faction wars, cloud
/// sync). Offers CREATE ACCOUNT / SIGN IN / NOT NOW. No competition feature is
/// wired up yet; screens will present this gate before their first online call
/// whenever `AccountGatePolicy.requiresAccount(auth.state)` is true.
struct AccountGateView: View {
    @Environment(\.dismiss) private var dismiss

    /// Which future feature is asking — shown in the stamp line.
    let featureName: String?
    /// Called when the user picks NOT NOW (the feature stays closed).
    var onNotNow: (() -> Void)?

    init(featureName: String? = nil, onNotNow: (() -> Void)? = nil) {
        self.featureName = featureName
        self.onNotNow = onNotNow
    }

    var body: some View {
        ZStack {
            DeskBackground()

            VStack(spacing: 18) {
                stamp
                card
            }
            .padding(.horizontal, 22)
        }
        .preferredColorScheme(.dark)
    }

    private var stamp: some View {
        VStack(spacing: 8) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Theme.goldGradient)
                .frame(width: 66, height: 66)
                .background(Color.black.opacity(0.5), in: .circle)
                .overlay { Circle().strokeBorder(Theme.gold.opacity(0.45), lineWidth: 1.2) }
            Text("ACCOUNT REQUIRED")
                .font(.system(size: 24, weight: .black).width(.compressed))
                .tracking(2)
                .foregroundStyle(Theme.goldGradient)
            if let featureName {
                Text("CLEARANCE NEEDED FOR \(featureName.uppercased())")
                    .font(Theme.typewriter(10, relativeTo: .caption2))
                    .tracking(1.4)
                    .foregroundStyle(Theme.paperInkSoft)
            }
        }
    }

    private var card: some View {
        VStack(spacing: 4) {
            HStack(spacing: 7) {
                Image(systemName: "person.text.rectangle")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.bronzeDeep)
                Text("PLAYER FILE")
                    .font(.system(size: 11, weight: .heavy).width(.condensed))
                    .tracking(2)
                    .foregroundStyle(Theme.paperInkSoft)
                Spacer(minLength: 0)
            }
            .padding(.bottom, 8)

            Text("CREATE OR SIGN INTO YOUR GAMESCENE ACCOUNT TO USE ONLINE COMPETITION.")
                .font(Theme.typewriter(12, relativeTo: .callout))
                .foregroundStyle(Theme.paperInk)
                .lineSpacing(3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 12)

            NavigationLink {
                CreateAccountView()
            } label: {
                Text("CREATE ACCOUNT")
                    .font(.system(size: 14, weight: .heavy).width(.condensed))
                    .tracking(1.8)
                    .foregroundStyle(Theme.ink)
                    .frame(maxWidth: .infinity, minHeight: 46)
                    .background(Theme.goldGradient, in: .capsule)
                    .contentShape(.capsule)
            }
            .buttonStyle(PressableButtonStyle(playsPressSound: true))
            .accessibilityLabel("Create account")

            NavigationLink {
                SignInView()
            } label: {
                Text("SIGN IN")
                    .font(.system(size: 14, weight: .heavy).width(.condensed))
                    .tracking(1.8)
                    .foregroundStyle(Theme.paperInk)
                    .frame(maxWidth: .infinity, minHeight: 46)
                    .overlay { Capsule().strokeBorder(Theme.paperInk.opacity(0.4), lineWidth: 1.2) }
                    .contentShape(.capsule)
            }
            .buttonStyle(PressableButtonStyle(playsPressSound: true))
            .accessibilityLabel("Sign in")

            Button {
                Haptics.tick()
                onNotNow?()
                dismiss()
            } label: {
                Text("NOT NOW")
                    .font(.system(size: 12, weight: .heavy).width(.condensed))
                    .tracking(1.8)
                    .foregroundStyle(Theme.paperInkSoft)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(.capsule)
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityLabel("Not now")
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .background {
            PaperSurface(cornerRadius: 8, darkness: 0.04)
                .shadow(color: .black.opacity(0.6), radius: 16, y: 10)
        }
        .overlay(alignment: .top) {
            PushPin(size: 18).offset(y: -8)
        }
        .rotationEffect(.degrees(-0.5))
        .accessibilityElement(children: .contain)
    }
}

#Preview {
    NavigationStack { AccountGateView(featureName: "Leaderboards") }
}

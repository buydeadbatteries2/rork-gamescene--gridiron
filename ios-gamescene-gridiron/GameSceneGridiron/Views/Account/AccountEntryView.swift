import SwiftUI

/// ACCOUNT ENTRY — the case-file styled front door for GameScene accounts.
/// CREATE ACCOUNT / SIGN IN / CONTINUE AS GUEST. Guests keep full solo access;
/// online competition features will require an account later.
struct AccountEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var auth = AuthService.shared

    var body: some View {
        ZStack {
            DeskBackground()

            ScrollView {
                VStack(spacing: 18) {
                    header
                    folderCard
                    guestNote
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
        }
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "person.crop.badge.key.fill")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(Theme.goldGradient)
                .frame(width: 68, height: 68)
                .background(Color.black.opacity(0.5), in: .circle)
                .overlay { Circle().strokeBorder(Theme.gold.opacity(0.45), lineWidth: 1.2) }
            Text("PLAYER FILE")
                .font(.system(size: 28, weight: .black).width(.compressed))
                .tracking(2)
                .foregroundStyle(Theme.goldGradient)
            Text("GAME SCENE · GRIDIRON CREDENTIALS")
                .font(Theme.typewriter(10, relativeTo: .caption2))
                .tracking(1.4)
                .foregroundStyle(Theme.paperInkSoft)
        }
        .padding(.bottom, 6)
    }

    private var folderCard: some View {
        VStack(spacing: 4) {
            sectionHeader("OPEN OR START A PLAYER FILE")

            NavigationLink {
                CreateAccountView()
            } label: {
                entryRow(
                    symbol: "person.badge.plus",
                    title: "CREATE ACCOUNT",
                    detail: "New GameScene player file",
                    emphasized: true
                )
            }
            .buttonStyle(PressableButtonStyle(playsPressSound: true))

            NavigationLink {
                SignInView()
            } label: {
                entryRow(
                    symbol: "tray.full",
                    title: "SIGN IN",
                    detail: "Resume an existing player file"
                )
            }
            .buttonStyle(PressableButtonStyle(playsPressSound: true))

            Divider().overlay(Theme.paperInk.opacity(0.14)).padding(.vertical, 8)

            Button {
                Haptics.pickUp()
                AudioManager.shared.play(.buttonPress)
                auth.continueAsGuest()
                dismiss()
            } label: {
                entryRow(
                    symbol: "figure.walk",
                    title: "CONTINUE AS GUEST",
                    detail: "Play solo — no account needed"
                )
            }
            .buttonStyle(PressableButtonStyle(playsPressSound: true))
            .accessibilityLabel("Continue as guest")
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
        .rotationEffect(.degrees(-0.4))
        .accessibilityElement(children: .contain)
    }

    private func entryRow(symbol: String, title: String, detail: String, emphasized: Bool = false) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(emphasized ? Theme.ink : Theme.goldLight)
                .frame(width: 38, height: 38)
                .background(emphasized ? AnyShapeStyle(Theme.goldGradient) : AnyShapeStyle(Color.black.opacity(0.4)), in: .circle)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .black).width(.compressed))
                    .tracking(1)
                    .foregroundStyle(Theme.paperInk)
                Text(detail)
                    .font(Theme.typewriter(11, relativeTo: .caption))
                    .foregroundStyle(Theme.paperInkSoft)
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.paperInk.opacity(0.4))
        }
        .padding(.vertical, 10)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
    }

    private var guestNote: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.seal")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.gold)
            Text("GUESTS KEEP EVERYTHING LOCAL — TUTORIAL, FRANCHISE, SEASONS, ROSTER, STATS AND TROPHY ROOM.")
                .font(.system(size: 9, weight: .heavy).width(.condensed))
                .tracking(1.2)
                .foregroundStyle(Theme.paperInkSoft.opacity(0.8))
                .multilineTextAlignment(.center)
            Text("ONLINE COMPETITION WILL REQUIRE AN ACCOUNT.")
                .font(.system(size: 9, weight: .heavy).width(.condensed))
                .tracking(1.2)
                .foregroundStyle(Theme.paperInkSoft.opacity(0.55))
                .multilineTextAlignment(.center)
        }
        .lineSpacing(2)
        .padding(.horizontal, 16)
    }

    private func sectionHeader(_ title: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: "folder.badge.gearshape")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Theme.bronzeDeep)
            Text(title)
                .font(.system(size: 11, weight: .heavy).width(.condensed))
                .tracking(2)
                .foregroundStyle(Theme.paperInkSoft)
            Spacer(minLength: 0)
        }
        .padding(.bottom, 8)
        .accessibilityAddTraits(.isHeader)
    }
}

#Preview {
    NavigationStack { AccountEntryView() }
}

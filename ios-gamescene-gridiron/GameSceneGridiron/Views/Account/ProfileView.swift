import SwiftUI

/// PROFILE / ACCOUNT — signed-in and guest state, identity, franchise, and the
/// account actions (sign out, reset password, delete-account placeholder).
struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var auth = AuthService.shared
    @State private var teamStore = TeamStore.shared
    @State private var isShowingSignIn = false
    @State private var isShowingResetPassword = false
    @State private var didSignOut = false

    var body: some View {
        ZStack {
            DeskBackground()
            ScrollView {
                VStack(spacing: 16) {
                    header
                    identityCard
                    if isRecoveryPending {
                        recoveryCard
                    }
                    actionsCard
                }
                .padding(.horizontal, 20)
                .padding(.top, 22)
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
        }
        .preferredColorScheme(.dark)
        .navigationDestination(isPresented: $isShowingSignIn) {
            AccountEntryView()
        }
        .sheet(isPresented: $isShowingResetPassword) {
            ResetPasswordView()
                .preferredColorScheme(.dark)
        }
        .onDisappear {
            if didSignOut { dismiss() }
        }
    }

    private var header: some View {
        Text("PLAYER FILE")
            .font(.system(size: 26, weight: .black).width(.compressed))
            .tracking(1.8)
            .foregroundStyle(Theme.goldGradient)
    }

    private var profile: UserProfile? {
        if case .authenticated(let profile) = auth.state { return profile }
        return nil
    }

    private var isSignedIn: Bool {
        profile != nil || isRecoveryPending
    }

    private var isRecoveryPending: Bool {
        if case .needsProfileRecovery = auth.state { return true }
        return false
    }

    private var identityCard: some View {
        VStack(spacing: 10) {
            sectionHeader(isSignedIn ? "SIGNED IN" : "GUEST")

            if let profile {
                identityRow(symbol: "person.fill", title: profile.username.uppercased(), detail: "USERNAME")
                identityRow(symbol: "signature", title: profile.footballDisplayName.isEmpty ? profile.username.uppercased() : profile.footballDisplayName.uppercased(), detail: "JERSEY NAME")
                identityRow(symbol: "user.text.rectangle", title: "\(profile.firstName) \(profile.lastName)".trimmingCharacters(in: .whitespaces), detail: "ACCOUNT NAME")
            } else {
                HStack(spacing: 12) {
                    Image(systemName: "figure.walk")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Theme.goldLight)
                        .frame(width: 38, height: 38)
                        .background(Color.black.opacity(0.4), in: .circle)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("PLAYING AS GUEST")
                            .font(.system(size: 15, weight: .black).width(.compressed))
                            .tracking(1)
                            .foregroundStyle(Theme.paperInk)
                        Text("Full solo access — progress lives on this device")
                            .font(Theme.typewriter(11, relativeTo: .caption))
                            .foregroundStyle(Theme.paperInkSoft)
                    }
                    Spacer(minLength: 0)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Playing as guest")
            }

            Divider().overlay(Theme.paperInk.opacity(0.14)).padding(.vertical, 4)

            identityRow(
                symbol: "shield.lefthalf.filled",
                title: teamStore.userTeam?.displayName.uppercased() ?? "NO FRANCHISE",
                detail: "FRANCHISE"
            )
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .background {
            PaperSurface(cornerRadius: 8, darkness: 0.04)
                .shadow(color: .black.opacity(0.6), radius: 16, y: 10)
        }
        .overlay(alignment: .top) {
            PushPin(size: 18).offset(y: -8)
        }
        .rotationEffect(.degrees(-0.35))
        .accessibilityElement(children: .contain)
    }

    private func identityRow(symbol: String, title: String, detail: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Theme.goldLight)
                .frame(width: 36, height: 36)
                .background(Color.black.opacity(0.4), in: .circle)
            VStack(alignment: .leading, spacing: 2) {
                Text(detail)
                    .font(.system(size: 9, weight: .heavy).width(.condensed))
                    .tracking(1.2)
                    .foregroundStyle(Theme.paperInkSoft)
                Text(title.isEmpty ? "—" : title)
                    .font(.system(size: 15, weight: .black).width(.compressed))
                    .tracking(1)
                    .foregroundStyle(Theme.paperInk)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(detail) \(title)")
    }

    /// Partial-failure recovery: auth account exists, profile row creation
    /// failed earlier. Retrying is an idempotent upsert — never a duplicate.
    private var recoveryCard: some View {
        VStack(spacing: 10) {
            sectionHeader("FILE RECOVERY")
            Text("YOUR ACCOUNT EXISTS BUT THE PLAYER FILE DIDN'T FINISH SYNCING.")
                .font(Theme.typewriter(11, relativeTo: .caption))
                .foregroundStyle(Theme.paperInk)
                .lineSpacing(2)
            Button {
                Haptics.pickUp()
                Task { await auth.retryProfileCreation() }
            } label: {
                Text(auth.isWorking ? "SYNCING…" : "FINISH PLAYER FILE")
                    .font(.system(size: 13, weight: .heavy).width(.condensed))
                    .tracking(1.6)
                    .foregroundStyle(Theme.ink)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(Theme.goldGradient, in: .capsule)
                    .contentShape(.capsule)
            }
            .buttonStyle(PressableButtonStyle(playsPressSound: false))
            .disabled(auth.isWorking)
            .accessibilityLabel("Finish player file")
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background {
            PaperSurface(cornerRadius: 8, darkness: 0.12)
                .shadow(color: .black.opacity(0.6), radius: 14, y: 8)
        }
        .overlay {
            CautionTape(stripeWidth: 5)
                .frame(height: 6)
                .frame(maxWidth: .infinity)
                .offset(y: -2)
                .clipShape(.rect(cornerRadius: 8))
        }
        .rotationEffect(.degrees(0.4))
    }

    private var actionsCard: some View {
        VStack(spacing: 4) {
            sectionHeader("ACCOUNT ACTIONS")

            if profile != nil {
                actionRow(symbol: "key.horizontal", title: "RESET PASSWORD", detail: "Email a reset link") {
                    isShowingResetPassword = true
                }

                // Future DELETE ACCOUNT — real deletion needs a Supabase
                // function (auth admin deletion) that doesn't exist yet. Never
                // faked.
                actionRow(symbol: "trash", title: "DELETE ACCOUNT", detail: "Coming soon", disabled: true) {}
            } else {
                actionRow(symbol: "person.badge.plus", title: "CREATE ACCOUNT", detail: "Keep progress with an account") {
                    isShowingSignIn = true
                }
            }

            Divider().overlay(Theme.paperInk.opacity(0.14)).padding(.vertical, 6)

            if auth.state != .guest {
                Button {
                    Haptics.pickUp()
                    Task {
                        await auth.signOut()
                        didSignOut = true
                    }
                } label: {
                    Text(auth.isWorking ? "SIGNING OUT…" : "SIGN OUT")
                        .font(.system(size: 14, weight: .heavy).width(.condensed))
                        .tracking(1.8)
                        .foregroundStyle(Theme.paperInk)
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .overlay { Capsule().strokeBorder(Theme.paperInk.opacity(0.4), lineWidth: 1.2) }
                        .contentShape(.capsule)
                }
                .buttonStyle(PressableButtonStyle(playsPressSound: true))
                .disabled(auth.isWorking)
                .accessibilityLabel("Sign out")
                Text("YOUR SEASON, ROSTER, GAME BALLS AND TROPHIES STAY ON THIS DEVICE.")
                    .font(.system(size: 8.5, weight: .heavy).width(.condensed))
                    .tracking(1.1)
                    .foregroundStyle(Theme.paperInkSoft.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .padding(.top, 6)
            } else if profile == nil {
                Text("LOCAL SOLO DATA IS NEVER REMOVED BY ACCOUNT ACTIONS.")
                    .font(.system(size: 8.5, weight: .heavy).width(.condensed))
                    .tracking(1.1)
                    .foregroundStyle(Theme.paperInkSoft.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }
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
        .rotationEffect(.degrees(0.3))
        .accessibilityElement(children: .contain)
    }

    private func actionRow(symbol: String, title: String, detail: String, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tick()
            action()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(disabled ? Theme.paperInkSoft.opacity(0.4) : Theme.goldLight)
                    .frame(width: 36, height: 36)
                    .background(Color.black.opacity(0.4), in: .circle)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 14, weight: .black).width(.compressed))
                        .tracking(1)
                        .foregroundStyle(disabled ? Theme.paperInkSoft : Theme.paperInk)
                    Text(detail)
                        .font(Theme.typewriter(10.5, relativeTo: .caption))
                        .foregroundStyle(Theme.paperInkSoft)
                }
                Spacer(minLength: 8)
                Text(disabled ? "SOON" : "OPEN")
                    .font(.system(size: 9, weight: .black).width(.condensed))
                    .tracking(1.2)
                    .foregroundStyle(Theme.paperInkSoft.opacity(0.7))
            }
            .padding(.vertical, 9)
            .contentShape(.rect)
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(disabled)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
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
        .padding(.bottom, 6)
        .accessibilityAddTraits(.isHeader)
    }
}

/// NEW PASSWORD form — shown after the reset email's deep link returns (the
/// callback session authorizes exactly this update), or from the profile.
struct ResetPasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var auth = AuthService.shared
    @State private var password = ""
    @State private var confirmPassword = ""

    var body: some View {
        ZStack {
            DeskBackground()
            ScrollView {
                VStack(spacing: 16) {
                    Image(systemName: "key.fill")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(Theme.goldGradient)
                    Text("SET NEW PASSWORD")
                        .font(.system(size: 24, weight: .black).width(.compressed))
                        .tracking(1.6)
                        .foregroundStyle(Theme.goldGradient)

                    SecureField("NEW PASSWORD", text: $password)
                        .authFieldStyle(error: nil)
                    SecureField("CONFIRM NEW PASSWORD", text: $confirmPassword)
                        .authFieldStyle(error: nil)

                    Button {
                        Haptics.pickUp()
                        Task {
                            if await auth.updatePassword(password, confirm: confirmPassword) {
                                try? await Task.sleep(for: .seconds(1))
                                dismiss()
                            }
                        }
                    } label: {
                        Text(auth.isWorking ? "UPDATING…" : "UPDATE PASSWORD")
                            .font(.system(size: 14, weight: .heavy).width(.condensed))
                            .tracking(1.8)
                            .foregroundStyle(Theme.ink)
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background(Theme.goldGradient, in: .capsule)
                            .opacity(auth.isWorking ? 0.6 : 1)
                            .contentShape(.capsule)
                    }
                    .buttonStyle(PressableButtonStyle(playsPressSound: false))
                    .disabled(auth.isWorking)
                    .accessibilityLabel("Update password")

                    if let message = auth.lastUserMessage {
                        Text(message)
                            .font(Theme.typewriter(11, relativeTo: .caption))
                            .foregroundStyle(Theme.paperInk)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 28)
            }
            .scrollIndicators(.hidden)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
    }
}

#Preview {
    NavigationStack { ProfileView() }
}

import SwiftUI

/// SIGN IN — email/password for an existing GameScene player file. Errors are
/// always the sanitized, friendly copy from AuthService — never raw SDK text.
struct SignInView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var auth = AuthService.shared

    @State private var email = ""
    @State private var password = ""
    @State private var didSubmitSuccessfully = false
    @State private var isShowingForgotPassword = false

    var body: some View {
        ZStack {
            DeskBackground()
            ScrollView {
                VStack(spacing: 16) {
                    header
                    formCard
                    forgotPasswordButton
                    submitButton
                    if let message = auth.lastUserMessage {
                        Text(message)
                            .font(Theme.typewriter(11, relativeTo: .caption))
                            .foregroundStyle(Theme.paperInk)
                            .multilineTextAlignment(.center)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 14)
                            .frame(maxWidth: .infinity)
                            .background(Color.black.opacity(0.35), in: .rect(cornerRadius: 6))
                            .overlay { RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.gold.opacity(0.3), lineWidth: 1) }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
        }
        .preferredColorScheme(.dark)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isShowingForgotPassword) {
            ForgotPasswordView()
                .preferredColorScheme(.dark)
        }
        .onDisappear {
            if didSubmitSuccessfully { dismiss() }
        }
    }

    private var header: some View {
        VStack(spacing: 4) {
            Image(systemName: "folder.badge.person.crop")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Theme.goldGradient)
            Text("OPEN PLAYER FILE")
                .font(.system(size: 26, weight: .black).width(.compressed))
                .tracking(1.8)
                .foregroundStyle(Theme.goldGradient)
            Text("PICK UP WHERE YOUR INVESTIGATION LEFT OFF")
                .font(Theme.typewriter(9.5, relativeTo: .caption2))
                .tracking(1.2)
                .foregroundStyle(Theme.paperInkSoft)
        }
        .padding(.bottom, 4)
    }

    private var formCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 7) {
                Image(systemName: "key")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.bronzeDeep)
                Text("CREDENTIALS")
                    .font(.system(size: 11, weight: .heavy).width(.condensed))
                    .tracking(2)
                    .foregroundStyle(Theme.paperInkSoft)
                Spacer(minLength: 0)
            }
            TextField("EMAIL", text: $email)
                .authFieldStyle(error: nil)
                .keyboardType(.emailAddress)
                .submitLabel(.next)
            SecureField("PASSWORD", text: $password)
                .authFieldStyle(error: nil)
                .submitLabel(.go)
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
        .rotationEffect(.degrees(-0.35))
    }

    private var forgotPasswordButton: some View {
        Button {
            Haptics.tick()
            isShowingForgotPassword = true
        } label: {
            Text("FORGOT PASSWORD?")
                .font(.system(size: 11, weight: .heavy).width(.condensed))
                .tracking(1.6)
                .foregroundStyle(Theme.goldLight)
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel("Forgot password")
    }

    private var submitButton: some View {
        Button {
            Haptics.pickUp()
            Task { didSubmitSuccessfully = await auth.signIn(email: email, password: password) }
        } label: {
            Text(auth.isWorking ? "OPENING…" : "SIGN IN")
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
        .accessibilityLabel("Sign in")
    }
}

/// FORGOT PASSWORD — email in, Supabase's reset email out. The link returns
/// into the app through the gamescene:// callback.
struct ForgotPasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var auth = AuthService.shared
    @State private var email = ""
    @State private var didSend = false

    var body: some View {
        ZStack {
            DeskBackground()
            ScrollView {
                VStack(spacing: 16) {
                    Image(systemName: "arrowshape.turn.up.right")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(Theme.goldGradient)
                    Text("RESET PASSWORD")
                        .font(.system(size: 24, weight: .black).width(.compressed))
                        .tracking(1.6)
                        .foregroundStyle(Theme.goldGradient)
                    Text("WE'LL MAIL A RESET LINK TIED TO YOUR PLAYER FILE.")
                        .font(Theme.typewriter(10, relativeTo: .caption))
                        .tracking(1)
                        .foregroundStyle(Theme.paperInkSoft)
                        .multilineTextAlignment(.center)

                    TextField("EMAIL", text: $email)
                        .authFieldStyle(error: nil)
                        .keyboardType(.emailAddress)
                        .padding(.horizontal, 4)

                    Button {
                        Haptics.pickUp()
                        Task { didSend = await auth.sendPasswordReset(email: email) }
                    } label: {
                        Text(auth.isWorking ? "SENDING…" : "SEND RESET LINK")
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
                    .accessibilityLabel("Send reset link")

                    if didSend {
                        Text("CHECK YOUR INBOX. THE LINK RETURNS HERE TO SET A NEW PASSWORD.")
                            .font(.system(size: 9, weight: .heavy).width(.condensed))
                            .tracking(1.2)
                            .foregroundStyle(Theme.paperInkSoft)
                            .multilineTextAlignment(.center)
                    }
                    if let message = auth.lastUserMessage {
                        Text(message)
                            .font(Theme.typewriter(11, relativeTo: .caption))
                            .foregroundStyle(Theme.paperInk)
                            .multilineTextAlignment(.center)
                    }

                    Button {
                        Haptics.tick()
                        dismiss()
                    } label: {
                        Text("CLOSE")
                            .font(.system(size: 12, weight: .heavy).width(.condensed))
                            .tracking(1.6)
                            .foregroundStyle(Theme.paperInk)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .overlay { Capsule().strokeBorder(Theme.paperInk.opacity(0.4), lineWidth: 1.2) }
                            .contentShape(.capsule)
                    }
                    .buttonStyle(PressableButtonStyle(playsPressSound: true))
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
    NavigationStack { SignInView() }
}

import SwiftUI

/// CREATE ACCOUNT — the new player-file form. Validation runs locally before
/// any submission; passwords live only inside the request payload.
struct CreateAccountView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var auth = AuthService.shared

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var username = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var fieldErrors = SignUpFieldErrors()
    @State private var didSubmitSuccessfully = false

    /// The derived "J. Hudson" preview — never typed by the user.
    private var footballDisplayNamePreview: String {
        FootballDisplayName.derive(firstName: firstName, lastName: lastName)
    }

    var body: some View {
        ZStack {
            DeskBackground()
            ScrollView {
                VStack(spacing: 16) {
                    header
                    formCard
                    previewCard
                    submitButton
                    if let message = auth.lastUserMessage {
                        messageBanner(message)
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
        .onDisappear {
            if didSubmitSuccessfully { dismiss() }
        }
    }

    private var header: some View {
        VStack(spacing: 4) {
            Text("NEW PLAYER FILE")
                .font(.system(size: 26, weight: .black).width(.compressed))
                .tracking(1.8)
                .foregroundStyle(Theme.goldGradient)
            Text("EACH FILE GETS ONE IDENTITY — YOURS IS YOURS FOREVER")
                .font(Theme.typewriter(9.5, relativeTo: .caption2))
                .tracking(1.2)
                .foregroundStyle(Theme.paperInkSoft)
        }
    }

    private var formCard: some View {
        VStack(spacing: 12) {
            sectionHeader("IDENTITY")
            field("FIRST NAME", text: $firstName, error: fieldErrors.firstName)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.next)
            field("LAST NAME", text: $lastName, error: fieldErrors.lastName)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.next)

            Divider().overlay(Theme.paperInk.opacity(0.14)).padding(.vertical, 4)

            sectionHeader("USERNAME")
            field("USERNAME", text: $username, error: fieldErrors.username)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.next)
            Text("3–20 CHARACTERS · LETTERS, NUMBERS, UNDERSCORE · NO SPACES")
                .font(.system(size: 8.5, weight: .heavy).width(.condensed))
                .tracking(1.2)
                .foregroundStyle(Theme.paperInkSoft.opacity(0.7))
                .frame(maxWidth: .infinity, alignment: .leading)

            Divider().overlay(Theme.paperInk.opacity(0.14)).padding(.vertical, 4)

            sectionHeader("CREDENTIALS")
            field("EMAIL", text: $email, error: fieldErrors.email)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
                .submitLabel(.next)
            SecureField ("PASSWORD", text: $password)
                .authFieldStyle(error: fieldErrors.password)
                .submitLabel(.next)
            if let error = fieldErrors.password {
                fieldError(error)
            }
            SecureField ("CONFIRM PASSWORD", text: $confirmPassword)
                .authFieldStyle(error: fieldErrors.confirmPassword)
                .submitLabel(.done)
            if let error = fieldErrors.confirmPassword {
                fieldError(error)
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
        .rotationEffect(.degrees(0.35))
    }

    /// Live "J. Hudson" preview — the abbreviated identity derives itself.
    @ViewBuilder
    private var previewCard: some View {
        if !footballDisplayNamePreview.isEmpty {
            HStack(spacing: 10) {
                Image(systemName: "signature")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.gold)
                VStack(alignment: .leading, spacing: 2) {
                    Text("JERSEY NAME — AUTO-FILLED")
                        .font(.system(size: 9, weight: .heavy).width(.condensed))
                        .tracking(1.2)
                        .foregroundStyle(Theme.paperInkSoft)
                    Text(footballDisplayNamePreview.uppercased())
                        .font(.system(size: 17, weight: .black).width(.compressed))
                        .tracking(1.2)
                        .foregroundStyle(Theme.paperInk)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(Theme.gold.opacity(0.08), in: .rect(cornerRadius: 6))
            .overlay { RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.gold.opacity(0.25), lineWidth: 1) }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Jersey name \(footballDisplayNamePreview)")
        }
    }

    private var submitButton: some View {
        Button {
            Haptics.pickUp()
            AudioManager.shared.play(.buttonPress)
            fieldErrors = AccountValidator.validate(SignUpDraft(
                firstName: firstName, lastName: lastName, username: username,
                email: email, password: password, confirmPassword: confirmPassword
            ))
            guard fieldErrors.isEmpty else { return }
            Task { didSubmitSuccessfully = await auth.createAccount(SignUpDraft(
                firstName: firstName, lastName: lastName, username: username,
                email: email, password: password, confirmPassword: confirmPassword
            )) }
        } label: {
            Text(auth.isWorking ? "FILING…" : "CREATE ACCOUNT")
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
        .accessibilityLabel("Create account")
    }

    private func messageBanner(_ message: String) -> some View {
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

    private func field(_ label: String, text: Binding<String>, error: String?) -> some View {
        VStack(spacing: 4) {
            TextField(label, text: text)
                .authFieldStyle(error: error)
                .submitLabel(.next)
            if let error { fieldError(error) }
        }
    }

    private func fieldError(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 8.5, weight: .heavy).width(.condensed))
            .tracking(1)
            .foregroundStyle(Theme.paperInkSoft.opacity(0.8))
            .frame(maxWidth: .infinity, alignment: .leading)
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
        .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Shared auth field styling

extension View {
    /// A typewriter-styled input slot — a typed line on the desk paper.
    func authFieldStyle(error: String?) -> some View {
        self
            .font(Theme.typewriter(14, relativeTo: .body))
            .foregroundStyle(Theme.paperInk)
            .textInputAutocapitalization(.never)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(Color.black.opacity(0.28), in: .rect(cornerRadius: 6))
            .overlay {
                RoundedRectangle(cornerRadius: 6).strokeBorder(
                    error != nil ? Theme.paperInk.opacity(0.6) : Theme.paperInk.opacity(0.28),
                    lineWidth: 1.2
                )
            }
    }
}

#Preview {
    NavigationStack { CreateAccountView() }
}

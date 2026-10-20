import Foundation
import Observation

// MARK: - AuthService
//
// Owns the GameScene session state machine. Views observe `state` — they never
// touch Supabase. Contracts:
//
// - Session restoration is explicit (`.restoring`): the app shows its loading
//   board until the state resolves, never flashing login/onboarding.
// - Guest mode is a first-class citizen: all solo features work without an
//   account, and signing up/signing out never erases local solo progress.
// - Signup is stepwise-safe: if Auth succeeds but profile creation fails, the
//   state becomes `.needsProfileRecovery` and the profile creation can be
//   retried (idempotent upsert — no duplicate accounts/profiles).
// - Confirm Email is DISABLED: a successful signup carries an active session,
//   and the player is signed in immediately. A nil-session signup is handled
//   defensively as a generic recoverable error — no confirmation-email flow.
// - Passwords exist only inside the request payload. They are never stored,
//   logged, or encoded into profiles.
// - After authentication, RevenueCat migrates to the Supabase Auth UUID as
//   its App User ID (never email/username) through the identity hooks.
@MainActor
@Observable
final class AuthService {
    static let shared = AuthService()

    private(set) var state: AuthSessionState = .restoring
    private(set) var isWorking = false
    /// Last sanitized, user-facing error message (never raw SDK text).
    private(set) var lastUserMessage: String?
    /// DEBUG diagnostic: the sanitized failure category of the last auth
    /// error (shown in the DEBUG message banner, never in RELEASE copy).
    private(set) var lastFailureCategory: String?
    /// The guarded-out-of-build notices (no Supabase secrets in this build).
    /// One source of truth — the UI renders these as the legible
    /// ONLINE ACCOUNT UNAVAILABLE status card instead of a plain banner.
    nonisolated static let unavailableNotice = "Accounts aren't available in this build — you can keep playing solo."
    nonisolated static let unavailableShortNotice = "Accounts aren't available in this build."
    /// True while the current message is the unavailable notice.
    var isShowingUnavailableNotice: Bool {
        lastUserMessage == Self.unavailableNotice || lastUserMessage == Self.unavailableShortNotice
    }

    /// Pure message classifier — lets views and tests distinguish the
    /// configuration guard from ordinary sanitized status/error copy.
    nonisolated static func isUnavailableNoticeMessage(_ message: String?) -> Bool {
        message == unavailableNotice || message == unavailableShortNotice
    }
    /// True when the reset deep link established a confirm-session — the UI
    /// should present the new-password form (dismissable by the form itself).
    var isAwaitingNewPassword = false

    private let authClient: (any AuthClientProtocol)?
    private let profiles: (any ProfileRepository)?

    /// Identity hooks — default wiring routes to RevenueCat:
    /// login with the Supabase Auth UUID on success, back to anonymous on
    /// sign-out. Tests inject spies instead.
    var onAuthenticated: ((UUID) async -> Void)?
    var onSignedOut: (() async -> Void)?

    private var defaults: UserDefaults

    /// Bounded backoff for the post-signup profile fetch: the trigger creates
    /// the row in the same transaction as the auth user, so it is normally
    /// visible immediately — the retries only absorb a short timing delay.
    /// Injectable so tests stay instant.
    nonisolated static let defaultProfileFetchRetryCount = 2
    nonisolated static let defaultProfileFetchRetryDelayMs = 400
    private(set) var profileFetchRetryCount = AuthService.defaultProfileFetchRetryCount
    private(set) var profileFetchRetryDelayMs = AuthService.defaultProfileFetchRetryDelayMs

    /// Test seam: shrink/flatten the bounded profile-fetch backoff.
    func configureProfileFetchRetry(count: Int, delayMs: Int) {
        profileFetchRetryCount = count
        profileFetchRetryDelayMs = delayMs
    }

    static let guestFlagKey = "gamescene.gridiron.isGuest"

    /// The production instance: live Supabase client + RevenueCat identity.
    init() {
        let provider = SupabaseClientProvider.shared
        defaults = .standard
        if provider.isConfigured, let client = provider.supabase {
            authClient = SupabaseAuthClientAdapter(client: client)
            profiles = SupabaseProfileRepository(client: client)
        } else {
            authClient = nil
            profiles = nil
        }
        onAuthenticated = { uuid in
            await PurchaseManager.shared.loginWithSupabaseIdentity(uuid.uuidString)
        }
        onSignedOut = {
            await PurchaseManager.shared.logoutToAnonymous()
        }
    }

    /// Injectable instance for tests / previews (nil clients = offline).
    init(
        authClient: (any AuthClientProtocol)?,
        profileRepository: (any ProfileRepository)?,
        defaults: UserDefaults,
        onAuthenticated: ((UUID) async -> Void)? = nil,
        onSignedOut: (() async -> Void)? = nil
    ) {
        self.authClient = authClient
        self.profiles = profileRepository
        self.defaults = defaults
        self.onAuthenticated = onAuthenticated
        self.onSignedOut = onSignedOut
    }

    var isSupabaseConfigured: Bool { authClient != nil }

    // MARK: Session restoration

    /// Runs at app start. Resolves to guest (no session / offline build /
    /// unreachable) or authenticated + profile. Never blocks the game.
    func restoreSession() async {
        lastUserMessage = nil
        guard let authClient, let profiles else {
            // No Supabase in this build: straight to local solo play.
            state = .guest
            return
        }
        do {
            guard let userID = try await authClient.restoreSessionUserID() else {
                state = .guest
                return
            }
            let profile = try await profiles.fetchProfile(userID: userID)
            if let profile {
                state = .authenticated(profile)
            } else {
                state = .needsProfileRecovery(Self.draftProfile(userID: userID, username: nil, firstName: nil, lastName: nil))
            }
        } catch {
            // Offline or backend hiccup: never block the game on it.
            lastUserMessage = AuthErrorMapper.failure(for: error).userMessage
            state = .guest
        }
    }

    // MARK: Guest

    /// CONTINUE AS GUEST — full solo access, no account required.
    func continueAsGuest() {
        defaults.set(true, forKey: Self.guestFlagKey)
        state = .guest
    }

    // MARK: Create account

    /// Validates locally first, then: Supabase Auth signup → profile
    /// upsert → authenticated state. A profile failure after a successful
    /// signup is recoverable — `.needsProfileRecovery` holds the draft profile
    /// and `retryProfileCreation` upserts it again (never duplicates).
    @discardableResult
    func createAccount(_ draft: SignUpDraft) async -> Bool {
        lastUserMessage = nil
        let errors = AccountValidator.validate(draft)
        guard errors.isEmpty else {
            lastUserMessage = "Check the highlighted fields."
            return false
        }
        guard let authClient, let profiles else {
            lastUserMessage = Self.unavailableNotice
            return false
        }
        // Best-effort pre-flight: a taken username surfaces as a readable
        // message BEFORE auth is consumed. The auth.users trigger remains the
        // atomic server-side authority; a probe failure never blocks signup.
        do {
            if !(try await profiles.isUsernameAvailable(draft.username)) {
                lastFailureCategory = "\(AuthFailure.usernameTaken)"
                lastUserMessage = AuthFailure.usernameTaken.userMessage
                return false
            }
        } catch {
            #if DEBUG
            print("[AuthDebug] username probe skipped: \(error)")
            #endif
        }

        isWorking = true
        defer { isWorking = false }

        do {
            let outcome = try await authClient.signUp(
                email: draft.email,
                password: draft.password,
                identity: AuthSignUpIdentity(
                    username: draft.username,
                    firstName: draft.firstName,
                    lastName: draft.lastName
                )
            )
            guard outcome.didCreateSession else {
                // DEFENSIVE ONLY: Confirm Email is disabled, so a successful
                // signup always carries an active session. If one is ever
                // missing (project misconfiguration, server anomaly), show a
                // generic recoverable error — NEVER the retired
                // CHECK YOUR EMAIL flow, and never a half-authenticated state.
                lastUserMessage = "YOUR ACCOUNT COULDN'T BE OPENED JUST NOW — TRY AGAIN IN A MOMENT."
                return false
            }
            // Immediate-session signup: the auth.users trigger already created
            // the profile. Fetch it by the session's UUID, tolerating a short
            // database timing delay with a small bounded backoff — never an
            // unbounded spin.
            var profile = try await profiles.fetchProfile(userID: outcome.userID)
            if profile == nil {
                for _ in 0..<profileFetchRetryCount {
                    try await Task.sleep(for: .milliseconds(profileFetchRetryDelayMs))
                    if let fetched = try await profiles.fetchProfile(userID: outcome.userID) {
                        profile = fetched
                        break
                    }
                }
            }
            if let profile {
                await establishAuthenticatedSession(profile)
                return true
            }
            // Still missing after the bounded retries (e.g. the trigger was
            // not yet applied): ONE idempotent recovery insert, then the
            // existing recovery path if that also fails. Never a duplicate.
            let profileDraft = Self.draftProfile(
                userID: outcome.userID,
                username: draft.username,
                firstName: draft.firstName,
                lastName: draft.lastName
            )
            do {
                try await profiles.ensureProfile(profileDraft)
            } catch {
                // Auth succeeded, profile write failed — recoverable, never
                // retried here automatically and never a duplicate account.
                lastUserMessage = AuthErrorMapper.failure(for: error).userMessage
                state = .needsProfileRecovery(profileDraft)
                return false
            }
            await establishAuthenticatedSession(profileDraft)
            return true
        } catch {
            let failure = AuthErrorMapper.failure(for: error)
            // DEBUG-only diagnostics for live smoke tests — the sanitized
            // category only; no payloads, emails, or SDK internals.
            #if DEBUG
            print("[AuthDebug] createAccount failure category: \(failure)")
            #endif
            lastFailureCategory = "\(failure)"
            lastUserMessage = failure.userMessage
            return false
        }
    }

    /// Retries profile creation after a partial signup failure. The upsert is
    /// keyed by the auth UUID, so retries are idempotent by construction.
    func retryProfileCreation() async {
        guard case .needsProfileRecovery(let profile) = state, let profiles else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            try await profiles.ensureProfile(profile)
            await establishAuthenticatedSession(profile)
        } catch {
            lastUserMessage = AuthErrorMapper.failure(for: error).userMessage
        }
    }

    // MARK: Sign in

    @discardableResult
    func signIn(email: String, password: String) async -> Bool {
        lastUserMessage = nil
        guard let authClient, let profiles else {
            lastUserMessage = Self.unavailableNotice
            return false
        }
        guard AccountValidator.isValidEmail(email), !password.isEmpty else {
            lastUserMessage = "Enter your email and password."
            return false
        }
        isWorking = true
        defer { isWorking = false }
        do {
            let userID = try await authClient.signIn(email: email, password: password)
            let profile = try await profiles.fetchProfile(userID: userID)
            if let profile {
                await establishAuthenticatedSession(profile)
                return true
            }
            // Valid account, missing profile row: recover, never dead-end.
            state = .needsProfileRecovery(Self.draftProfile(userID: userID, username: nil, firstName: nil, lastName: nil))
            return false
        } catch {
            lastUserMessage = AuthErrorMapper.failure(for: error).userMessage
            return false
        }
    }

    // MARK: Password reset

    /// FORGOT PASSWORD — triggers Supabase's email flow. The email contains a
    /// link that returns to the app via the gamescene:// callback.
    func sendPasswordReset(email: String) async -> Bool {
        lastUserMessage = nil
        guard let authClient else {
            lastUserMessage = Self.unavailableShortNotice
            return false
        }
        guard AccountValidator.isValidEmail(email) else {
            lastUserMessage = "Enter a valid email address."
            return false
        }
        isWorking = true
        defer { isWorking = false }
        do {
            try await authClient.sendPasswordReset(email: email)
            lastUserMessage = "CHECK YOUR EMAIL FOR THE RESET LINK"
            return true
        } catch {
            lastUserMessage = AuthErrorMapper.failure(for: error).userMessage
            return false
        }
    }

    /// Deep-link callback from the reset email (gamescene://…). Establishes
    /// the confirm-session inside the SDK and routes to the new-password form.
    func handleAuthCallback(url: URL) async {
        guard SupabaseClientProvider.isAuthCallbackURL(url), let authClient else { return }
        do {
            try await authClient.handleCallback(url: url)
            isAwaitingNewPassword = true
        } catch {
            lastUserMessage = AuthErrorMapper.failure(for: error).userMessage
        }
    }

    /// Sets the new password after the reset callback (and for signed-in users
    /// from the profile screen).
    func updatePassword(_ newPassword: String, confirm: String) async -> Bool {
        lastUserMessage = nil
        guard let authClient else {
            lastUserMessage = Self.unavailableShortNotice
            return false
        }
        guard newPassword.count >= 8, newPassword == confirm else {
            lastUserMessage = "At least 8 characters, and both entries must match."
            return false
        }
        isWorking = true
        defer { isWorking = false }
        do {
            try await authClient.updatePassword(newPassword)
            isAwaitingNewPassword = false
            lastUserMessage = "PASSWORD UPDATED"
            return true
        } catch {
            lastUserMessage = AuthErrorMapper.failure(for: error).userMessage
            return false
        }
    }

    // MARK: Sign out

    /// Signs out of Supabase and migrates RevenueCat back to anonymous, while
    /// preserving ALL local solo data (team, season, roster, Game Balls,
    /// hints, achievements, Trophy Room, settings). Only online-scoped session
    /// data is cleared.
    func signOut() async {
        lastUserMessage = nil
        do {
            try await authClient?.signOut()
        } catch {
            // The local session is cleared regardless — sign-out never fails
            // in the UI.
            lastUserMessage = AuthErrorMapper.failure(for: error).userMessage
        }
        await onSignedOut?()
        state = .guest
    }

    // MARK: Helpers

    private func establishAuthenticatedSession(_ profile: UserProfile) async {
        defaults.removeObject(forKey: Self.guestFlagKey)
        state = .authenticated(profile)
        await onAuthenticated?(profile.authUserID)
    }

    /// The initial profile draft for a fresh auth account. The football
    /// display name derives from the names; unknown names (recovery path)
    /// fall back to the username.
    private static func draftProfile(userID: UUID, username: String?, firstName: String?, lastName: String?) -> UserProfile {
        UserProfile(
            authUserID: userID,
            username: username ?? "PLAYER-\(userID.uuidString.prefix(6).uppercased())",
            firstName: firstName ?? "",
            lastName: lastName ?? ""
        )
    }
}

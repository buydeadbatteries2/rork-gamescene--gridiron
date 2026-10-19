import Foundation
import Supabase

// MARK: - Auth client abstraction
//
// The AuthService depends on this protocol, never on the Supabase SDK
// directly — tests inject mocks, and the SDK stays swappable.

/// Outcome of a signup. `didCreateSession` is false when the project requires
/// email confirmation (the account exists but the user must confirm first).
nonisolated struct AuthSignUpOutcome: Equatable, Sendable {
    let userID: UUID
    let didCreateSession: Bool
}

/// The identity values carried through signup user metadata. The auth.users
/// trigger (`public.handle_new_user`) turns them into the initial profile
/// row — with Confirm Email enabled there is NO session to insert with, so
/// metadata is the only channel. Never passwords or sensitive data.
nonisolated struct AuthSignUpIdentity: Equatable, Sendable {
    let username: String
    let firstName: String
    let lastName: String
}

protocol AuthClientProtocol: Sendable {
    func signUp(email: String, password: String, identity: AuthSignUpIdentity) async throws -> AuthSignUpOutcome
    func signIn(email: String, password: String) async throws -> UUID
    func restoreSessionUserID() async throws -> UUID?
    func signOut() async throws
    func sendPasswordReset(email: String) async throws
    /// Applies an auth callback deep link (password-reset return trip) so the
    /// SDK picks up the embedded session.
    func handleCallback(url: URL) async throws
    /// Updates the password for the currently authenticated user (the reset
    /// callback establishes a session for exactly this purpose).
    func updatePassword(_ newPassword: String) async throws
}

// MARK: - Supabase adapter

struct SupabaseAuthClientAdapter: AuthClientProtocol {
    let client: SupabaseClient

    func signUp(email: String, password: String, identity: AuthSignUpIdentity) async throws -> AuthSignUpOutcome {
        let response = try await client.auth.signUp(
            email: email,
            password: password,
            data: [
                "username": .string(identity.username),
                "first_name": .string(identity.firstName),
                "last_name": .string(identity.lastName),
            ]
        )
        return AuthSignUpOutcome(userID: response.user.id, didCreateSession: response.session != nil)
    }

    func signIn(email: String, password: String) async throws -> UUID {
        let session = try await client.auth.signIn(email: email, password: password)
        return session.user.id
    }

    func restoreSessionUserID() async throws -> UUID? {
        // Local keychain read — never a network call, works offline.
        client.auth.currentSession?.user.id
    }
    func signOut() async throws {
        try await client.auth.signOut()
    }

    func sendPasswordReset(email: String) async throws {
        // The dashboard redirect allowlist must contain the gamescene://
        // callback (reported in the phase notes — never invented here).
        try await client.auth.resetPasswordForEmail(email)
    }

    func handleCallback(url: URL) async throws {
        try await client.auth.handle(url)
    }

    func updatePassword(_ newPassword: String) async throws {
        try await client.auth.update(user: UserAttributes(password: newPassword))
    }
}

// MARK: - Supabase profile repository

/// The real `profiles`-table repository. All writes are keyed by the Supabase
/// Auth UUID (`id`, primary key):
///
/// * `fetchProfile` reads the signed-in user's PRIVATE row from
///   `public.profiles` (RLS: `auth.uid() = id` — other users' rows are
///   invisible to this query).
/// * `ensureProfile` is an idempotent two-step write: an insert-only upsert
///   (creates the row on first signup and on partial-failure retries — a
///   conflicting id is skipped, never duplicated) followed by an update of
///   account-owned fields only. Competitive stats are server-authoritative:
///   clients cannot write them (column privileges + trigger guard), and the
///   database derives football_display_name + username_normalized itself.
/// * Future `LeaderboardRepository` / `FactionRepository` conformances read
///   OTHER users through `public.public_profiles` (safe public columns only).
struct SupabaseProfileRepository: ProfileRepository {
    let client: SupabaseClient
    private let decoder: JSONDecoder

    init(client: SupabaseClient) {
        self.client = client
        // The SDK's PostgREST default encoder already writes ISO8601 dates;
        // our Codable types carry explicit snake_case keys for the table
        // columns, so a plain ISO8601 decoder matches them exactly.
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        self.decoder = d
    }

    func fetchProfile(userID: UUID) async throws -> UserProfile? {
        let response = try await client.from("profiles")
            .select()
            .eq("id", value: userID.uuidString)
            .limit(1)
            .execute()
        let profiles = try decoder.decode([UserProfile].self, from: response.data)
        return profiles.first
    }

    func ensureProfile(_ profile: UserProfile) async throws {
        // Step 1 — insert-only upsert: creates the row on first signup and on
        // partial-failure retries; an existing id is skipped (no duplicate).
        // Any stats in the payload are coerced to 0 server-side for client
        // inserts. A taken username still surfaces as a uniqueness error here.
        try await client.from("profiles")
            .upsert(profile, onConflict: "id", ignoreDuplicates: true)
            .execute()
        // Step 2 — account-owned fields only. Competitive stats are never
        // client-writable (column privileges + trigger guard server-side);
        // football_display_name and username_normalized are re-derived by the
        // database trigger.
        try await client.from("profiles")
            .update(ProfileUpdateFields.values(for: profile))
            .eq("id", value: profile.authUserID.uuidString)
            .execute()
    }

    func isUsernameAvailable(_ username: String) async throws -> Bool {
        let response = try await client.rpc(
            "is_username_available",
            params: UsernameProbe(requested: username)
        ).execute()
        return try JSONDecoder().decode(Bool.self, from: response.data)
    }
}

/// Parameter envelope for `public.is_username_available(text)` — the key
/// matches the SQL parameter name.
private struct UsernameProbe: Codable, Sendable {
    let requested: String
}

// MARK: - Friendly auth errors
//
// Raw Supabase/URLError text NEVER reaches the UI. Mapping runs on the
// sanitized error description so it stays pure and testable.

nonisolated enum AuthFailure: Equatable, Sendable {
    case invalidCredentials
    case emailAlreadyRegistered
    case emailNotConfirmed
    case usernameTaken
    case weakPassword
    case networkUnavailable
    case rateLimited
    case profileCreationFailed
    case unknown

    /// The single user-facing message for this failure.
    var userMessage: String {
        switch self {
        case .invalidCredentials: return "Email or password is incorrect."
        case .emailAlreadyRegistered: return "EMAIL ALREADY REGISTERED — an account already exists for this email. Try signing in instead."
        case .emailNotConfirmed: return "Confirm your email first — check your inbox."
        case .usernameTaken: return "USERNAME ALREADY TAKEN — choose another."
        case .weakPassword: return "Choose a stronger password (8+ characters, letters and numbers)."
        case .networkUnavailable: return "Can't reach the network. Your season is safe — try again when online."
        case .rateLimited: return "TOO MANY ATTEMPTS — please wait a few minutes before trying again."
        case .profileCreationFailed: return "Your account was created, but the player file could not be saved yet. Sign in again to finish setup."
        case .unknown: return "Something went wrong. Try again."
        }
    }
}

nonisolated enum AuthErrorMapper {
    /// Maps any thrown error to a sanitized, user-facing failure. Runs on the
    /// error's description — SDK internals never leak to the UI.
    static func failure(for error: Error) -> AuthFailure {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .timedOut, .cannotFindHost, .cannotConnectToHost, .networkConnectionLost, .dnsLookupFailed:
                return .networkUnavailable
            default:
                break
            }
        }
        // Postgres/PostgREST failures come from profile SQL, never auth —
        // categorize them so the DEBUG banner can tell the two apart.
        if error is PostgrestError { return .profileCreationFailed }
        let description = error.localizedDescription.lowercased()
        if description.contains("internet") || description.contains("network")
            || description.contains("offline") || description.contains("timed out") {
            return .networkUnavailable
        }
        if description.contains("invalid login credentials") { return .invalidCredentials }
        if description.contains("already registered") { return .emailAlreadyRegistered }
        if description.contains("email not confirmed") { return .emailNotConfirmed }
        // Supabase Auth wraps auth.users trigger failures as "Database error
        // saving new user". Our trigger's only expected failure is the
        // case-insensitive username collision (USERNAME_TAKEN), so this maps
        // to the readable taken-username message.
        if description.contains("database error saving new user") { return .usernameTaken }
        if description.contains("user already") || description.contains("username") { return .usernameTaken }
        if description.contains("password") && (description.contains("weak") || description.contains("at least")) {
            return .weakPassword
        }
        if description.contains("rate limit") || description.contains("too many") { return .rateLimited }
        return .unknown
    }
}

import Foundation

// MARK: - UserProfile
//
// The GameScene account/profile record. The Supabase Auth UUID is the ONLY
// canonical online identity — usernames and emails are never database
// relationship keys (username uniqueness is enforced case-insensitively on
// the normalized value, but the row's key is always the auth UUID).
//
// Privacy contract: first/last names are account data. Public online
// surfaces (leaderboards, factions, versus) use `username` and
// `footballDisplayName` only.
nonisolated struct UserProfile: Codable, Equatable, Sendable, Identifiable {
    /// The Supabase Auth UUID — also the profile row's primary key.
    let authUserID: UUID
    /// Preserved display capitalization (e.g. "GridironKing").
    var username: String
    /// Case-folded form used for global uniqueness ("gridironking").
    var usernameNormalized: String
    var firstName: String
    var lastName: String
    /// Derived "J. Hudson" — never typed by the user.
    var footballDisplayName: String
    var createdAt: Date
    var updatedAt: Date
    var selectedFranchiseID: UUID?
    var currentFactionID: UUID?
    var globalRating: Int
    var careerGamesPlayed: Int
    var careerWins: Int
    var careerLosses: Int
    var careerCasesSolved: Int
    var championships: Int

    var id: UUID { authUserID }

    init(
        authUserID: UUID,
        username: String,
        firstName: String,
        lastName: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        selectedFranchiseID: UUID? = nil,
        currentFactionID: UUID? = nil,
        globalRating: Int = 0,
        careerGamesPlayed: Int = 0,
        careerWins: Int = 0,
        careerLosses: Int = 0,
        careerCasesSolved: Int = 0,
        championships: Int = 0
    ) {
        self.authUserID = authUserID
        self.username = username
        self.usernameNormalized = UsernameRules.normalize(username)
        self.firstName = firstName
        self.lastName = lastName
        self.footballDisplayName = FootballDisplayName.derive(firstName: firstName, lastName: lastName)
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.selectedFranchiseID = selectedFranchiseID
        self.currentFactionID = currentFactionID
        self.globalRating = globalRating
        self.careerGamesPlayed = careerGamesPlayed
        self.careerWins = careerWins
        self.careerLosses = careerLosses
        self.careerCasesSolved = careerCasesSolved
        self.championships = championships
    }

    /// Snake-case keys matching the Supabase `profiles` table columns.
    enum CodingKeys: String, CodingKey {
        case id
        case username
        case usernameNormalized = "username_normalized"
        case firstName = "first_name"
        case lastName = "last_name"
        case footballDisplayName = "football_display_name"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case selectedFranchiseID = "selected_franchise_id"
        case currentFactionID = "current_faction_id"
        case globalRating = "global_rating"
        case careerGamesPlayed = "career_games_played"
        case careerWins = "career_wins"
        case careerLosses = "career_losses"
        case careerCasesSolved = "career_cases_solved"
        case championships
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        authUserID = try c.decode(UUID.self, forKey: .id)
        username = try c.decode(String.self, forKey: .username)
        usernameNormalized = try c.decode(String.self, forKey: .usernameNormalized)
        firstName = try c.decode(String.self, forKey: .firstName)
        lastName = try c.decode(String.self, forKey: .lastName)
        footballDisplayName = try c.decode(String.self, forKey: .footballDisplayName)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        updatedAt = try c.decode(Date.self, forKey: .updatedAt)
        selectedFranchiseID = try c.decodeIfPresent(UUID.self, forKey: .selectedFranchiseID)
        currentFactionID = try c.decodeIfPresent(UUID.self, forKey: .currentFactionID)
        globalRating = try c.decodeIfPresent(Int.self, forKey: .globalRating) ?? 0
        careerGamesPlayed = try c.decodeIfPresent(Int.self, forKey: .careerGamesPlayed) ?? 0
        careerWins = try c.decodeIfPresent(Int.self, forKey: .careerWins) ?? 0
        careerLosses = try c.decodeIfPresent(Int.self, forKey: .careerLosses) ?? 0
        careerCasesSolved = try c.decodeIfPresent(Int.self, forKey: .careerCasesSolved) ?? 0
        championships = try c.decodeIfPresent(Int.self, forKey: .championships) ?? 0
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(authUserID, forKey: .id)
        try c.encode(username, forKey: .username)
        try c.encode(usernameNormalized, forKey: .usernameNormalized)
        try c.encode(firstName, forKey: .firstName)
        try c.encode(lastName, forKey: .lastName)
        try c.encode(footballDisplayName, forKey: .footballDisplayName)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(updatedAt, forKey: .updatedAt)
        try c.encodeIfPresent(selectedFranchiseID, forKey: .selectedFranchiseID)
        try c.encodeIfPresent(currentFactionID, forKey: .currentFactionID)
        try c.encode(globalRating, forKey: .globalRating)
        try c.encode(careerGamesPlayed, forKey: .careerGamesPlayed)
        try c.encode(careerWins, forKey: .careerWins)
        try c.encode(careerLosses, forKey: .careerLosses)
        try c.encode(careerCasesSolved, forKey: .careerCasesSolved)
        try c.encode(championships, forKey: .championships)
    }
}

// MARK: - Username rules

/// Username contract: 3–20 characters, ASCII letters / numbers / underscore,
/// no spaces, no invisible or control characters. Uniqueness is enforced on
/// the normalized (case-folded) value — "GridironKing" and "gridironking"
/// cannot belong to two accounts.
nonisolated enum UsernameRules {
    static let min_length = 3
    static let max_length = 20

    static func isValid(_ username: String) -> Bool {
        guard username.count >= min_length, username.count <= max_length else { return false }
        // Strict ASCII set rules out spaces, control and invisible characters
        // by construction.
        return username.allSatisfy { char in
            char == "_" || (char.isASCII && (char.isLetter || char.isNumber))
        }
    }

    /// The case-folded uniqueness key for a username.
    static func normalize(_ username: String) -> String {
        username.lowercased()
    }
}

// MARK: - Football display name

/// Derives the public "first initial + last name" identity ("J. Hudson").
/// First and last names are stored in full on the account; the abbreviation
/// is never typed by the user.
nonisolated enum FootballDisplayName {
    static func derive(firstName: String, lastName: String) -> String {
        let first = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let last = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        switch (first.isEmpty, last.isEmpty) {
        case (true, true):
            return ""
        case (false, true):
            return first
        case (true, false):
            return last
        case (false, false):
            return "\(first.first!). \(last)"
        }
    }
}

// MARK: - Signup draft + validation

/// Everything the CREATE ACCOUNT form collects. Passwords live here for the
/// request duration only — never persisted, never logged, never encoded into
/// a profile.
nonisolated struct SignUpDraft: Sendable {
    var firstName: String = ""
    var lastName: String = ""
    var username: String = ""
    var email: String = ""
    var password: String = ""
    var confirmPassword: String = ""
}

/// Per-field validation errors for the CREATE ACCOUNT form (empty string =
/// field valid).
nonisolated struct SignUpFieldErrors: Equatable, Sendable {
    var firstName: String?
    var lastName: String?
    var username: String?
    var email: String?
    var password: String?
    var confirmPassword: String?

    var isEmpty: Bool {
        self == SignUpFieldErrors()
    }
}

nonisolated enum AccountValidator {
    /// Maximum length sanity bound for names (never persisted beyond this).
    private static let maxNameLength = 40

    static func validate(_ draft: SignUpDraft) -> SignUpFieldErrors {
        var errors = SignUpFieldErrors()
        let first = draft.firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let last = draft.lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        if first.isEmpty || first.count > maxNameLength { errors.firstName = "Enter your first name." }
        if last.isEmpty || last.count > maxNameLength { errors.lastName = "Enter your last name." }
        if !UsernameRules.isValid(draft.username) {
            errors.username = "3–20 characters: letters, numbers, underscore."
        }
        if !Self.isValidEmail(draft.email) { errors.email = "Enter a valid email address." }
        if draft.password.count < 8 {
            errors.password = "At least 8 characters."
        } else if !draft.password.contains(where: \.isLetter) || !draft.password.contains(where: \.isNumber) {
            errors.password = "Mix letters and numbers."
        }
        if draft.confirmPassword != draft.password { errors.confirmPassword = "Passwords do not match." }
        return errors
    }

    static func isValidEmail(_ email: String) -> Bool {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.contains("@"), trimmed.contains(".") else { return false }
        let parts = trimmed.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2 else { return false }
        return parts.allSatisfy { !$0.isEmpty && !$0.contains(where: { $0.isWhitespace }) }
    }
}

// MARK: - Session state + account gate

nonisolated enum AuthSessionState: Equatable, Sendable {
    /// Session restoration in flight — the app must not flash login screens.
    case restoring
    /// Local solo play, no account.
    case guest
    /// Signed in with a matching profile record.
    case authenticated(UserProfile)
    /// Supabase Auth succeeded but the profile record is missing — recoverable.
    case needsProfileRecovery(UserProfile)
}

/// Reusable online-feature gate: every future online competition surface
/// requires an authenticated account; all solo features work in every state.
nonisolated enum AccountGatePolicy {
    /// Online features (leaderboards, versus, factions, cloud sync) need an
    /// authenticated profile.
    static func canAccessOnlineFeatures(_ state: AuthSessionState) -> Bool {
        if case .authenticated = state { return true }
        return false
    }

    static func requiresAccount(_ state: AuthSessionState) -> Bool {
        !canAccessOnlineFeatures(state)
    }

    /// Solo play (tutorial, franchise, seasons, puzzles, roster, stats,
    /// local achievements) is never gated — any state past restoration plays.
    static func canPlaySolo(_ state: AuthSessionState) -> Bool {
        switch state {
        case .restoring: return false
        case .guest, .authenticated, .needsProfileRecovery: return true
        }
    }
}

import Foundation

// MARK: - Phase 15A — asynchronous 1-v-1 Versus (models only, no UI)
//
// The server owns everything that decides a Versus match: pairing, the five
// cases (snapshotted at creation, identical for both players), exact-solution
// verification, the score, the winner, expiry and forfeits. The client only
// ever sends a difficulty (find-versus-match) and raw per-case facts
// (submit-versus-result). These types decode what the server returns.

/// Gameplay rules that differ from solo play.
nonisolated enum VersusRules {
    /// No pay-to-win: purchasable hints are disabled in Versus. The server
    /// enforces this too (versus_config CHECK + VERSUS_HINTS_NOT_ALLOWED).
    static let purchasableHintsEnabled = false
    /// Matches the server's versus_config.min_versus_protocol.
    static let protocolVersion = 1
    /// Server default (versus_config.match_ttl_hours) — display only.
    static let defaultExpiryHours = 24
}

/// `versus_matches.status`.
nonisolated enum VersusMatchStatus: String, Codable, Hashable, Sendable {
    case waitingForOpponent = "waiting_for_opponent"
    case active
    case completed
    case expired
    case cancelled

    var isOpen: Bool { self == .waitingForOpponent || self == .active }
}

/// The match as seen by ONE player (server-computed `player_state`).
nonisolated enum VersusPlayerState: String, Codable, Hashable, Sendable {
    /// No opponent yet; I have not played.
    case waitingForOpponent = "waiting_for_opponent"
    /// No opponent yet; I already played.
    case submitted
    /// Opponent joined; I have not played.
    case active
    /// I played; the opponent has not.
    case opponentPending = "opponent_pending"
    case completed
    case expired
    case cancelled

    /// The player still has to play this match.
    var needsMyPlay: Bool { self == .waitingForOpponent || self == .active }
}

/// My result in a completed match.
nonisolated enum VersusOutcome: String, Codable, Hashable, Sendable {
    case win, loss, tie
}

/// How the server decided the match (tiebreak order is server-side).
nonisolated enum VersusResolution: String, Codable, Hashable, Sendable {
    case score
    case casesSolved = "cases_solved"
    case regulationQuarters = "regulation_quarters"
    case tie
    case forfeit
    case expiredUnplayed = "expired_unplayed"
    case expiredNoOpponent = "expired_no_opponent"
    case cancelled
}

/// Where the five cases came from. `bundledDevFallback` is the TEMPORARY
/// development fallback until server-only Versus content ships.
nonisolated enum VersusContentSource: String, Codable, Hashable, Sendable {
    case serverAssigned = "server_assigned"
    case bundledDevFallback = "bundled_dev_fallback"
}

/// One match row from find-versus-match or the my_versus_matches RPC (same
/// shape). Never contains solutions; the opponent's numbers are present only
/// once the match is completed.
nonisolated struct VersusMatch: Codable, Hashable, Sendable, Identifiable {
    let matchID: UUID
    let status: VersusMatchStatus
    let playerState: VersusPlayerState
    let role: String
    let difficulty: String
    let caseIDs: [String]
    let caseVersions: [Int]
    let catalogFingerprint: String?
    let contentSource: VersusContentSource
    let createdAt: String
    let matchedAt: String?
    let expiresAt: String
    let completedAt: String?
    let opponentUserID: UUID?
    let opponentUsername: String?
    let opponentDisplayName: String?
    let mySubmitted: Bool
    let myFinalScore: Int?
    let myCasesSolved: Int?
    let opponentSubmitted: Bool
    let opponentFinalScore: Int?
    let opponentCasesSolved: Int?
    let outcome: VersusOutcome?
    let isForfeit: Bool
    let resolution: VersusResolution?
    /// Set by find-versus-match when it returned an existing match.
    let reused: Bool?

    var id: UUID { matchID }
    var difficultyLevel: DifficultyLevel? { DifficultyLevel(serverValue: difficulty) }
    var expiresAtDate: Date? { RankedAssignmentWire.parseDate(expiresAt) }

    enum CodingKeys: String, CodingKey {
        case matchID = "match_id"
        case status
        case playerState = "player_state"
        case role
        case difficulty
        case caseIDs = "case_ids"
        case caseVersions = "case_versions"
        case catalogFingerprint = "catalog_fingerprint"
        case contentSource = "content_source"
        case createdAt = "created_at"
        case matchedAt = "matched_at"
        case expiresAt = "expires_at"
        case completedAt = "completed_at"
        case opponentUserID = "opponent_user_id"
        case opponentUsername = "opponent_username"
        case opponentDisplayName = "opponent_display_name"
        case mySubmitted = "my_submitted"
        case myFinalScore = "my_final_score"
        case myCasesSolved = "my_cases_solved"
        case opponentSubmitted = "opponent_submitted"
        case opponentFinalScore = "opponent_final_score"
        case opponentCasesSolved = "opponent_cases_solved"
        case outcome
        case isForfeit = "is_forfeit"
        case resolution
        case reused
    }
}

/// One completed match from my_versus_history.
nonisolated struct VersusHistoryEntry: Codable, Hashable, Sendable, Identifiable {
    let matchID: UUID
    let difficulty: String
    let completedAt: String?
    let opponentUserID: UUID?
    let opponentUsername: String?
    let opponentDisplayName: String?
    let myFinalScore: Int?
    let opponentFinalScore: Int?
    let outcome: VersusOutcome
    let isForfeit: Bool
    let resolution: VersusResolution?

    var id: UUID { matchID }

    enum CodingKeys: String, CodingKey {
        case matchID = "match_id"
        case difficulty
        case completedAt = "completed_at"
        case opponentUserID = "opponent_user_id"
        case opponentUsername = "opponent_username"
        case opponentDisplayName = "opponent_display_name"
        case myFinalScore = "my_final_score"
        case opponentFinalScore = "opponent_final_score"
        case outcome
        case isForfeit = "is_forfeit"
        case resolution
    }
}

/// Public Versus record of any player (versus_public_record). Public
/// identity only — never real names or email.
nonisolated struct VersusCareerRecord: Codable, Hashable, Sendable {
    let userID: UUID
    let username: String?
    let footballDisplayName: String?
    let gamesPlayed: Int
    let wins: Int
    let losses: Int
    let ties: Int
    let forfeitWins: Int
    let forfeitLosses: Int

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case username
        case footballDisplayName = "football_display_name"
        case gamesPlayed = "versus_games_played"
        case wins = "versus_wins"
        case losses = "versus_losses"
        case ties = "versus_ties"
        case forfeitWins = "versus_forfeit_wins"
        case forfeitLosses = "versus_forfeit_losses"
    }
}

/// Raw facts sent to submit-versus-result. No user id, no score, no winner:
/// the server derives all of that.
nonisolated struct VersusResultPayload: Encodable, Sendable {
    let matchID: UUID
    let startedAt: String
    let completedAt: String
    let caseResults: [CompetitiveCaseResult]
    let gameVersion: String
    let versusProtocol: Int

    enum CodingKeys: String, CodingKey {
        case matchID = "match_id"
        case startedAt = "started_at"
        case completedAt = "completed_at"
        case caseResults = "case_results"
        case gameVersion = "game_version"
        case versusProtocol = "versus_protocol"
    }

    /// Local pre-flight mirroring the server's structural rules, so an
    /// obviously invalid result is never sent. The server stays authoritative.
    func localRejection(for match: VersusMatch) -> String? {
        guard caseResults.count == 4 || caseResults.count == 5 else { return "invalid_case_count" }
        for (index, result) in caseResults.enumerated() {
            guard index < match.caseIDs.count, result.caseID == match.caseIDs[index] else { return "case_mismatch" }
            guard result.caseVersion == match.caseVersions[index] else { return "case_version_mismatch" }
            guard result.quarterIndex == index else { return "invalid_quarter_index" }
            if !VersusRules.purchasableHintsEnabled, result.hintsUsed > 0 { return "versus_hints_not_allowed" }
        }
        return nil
    }
}

/// submit-versus-result 200 body.
nonisolated struct VersusSubmitReceipt: Decodable, Hashable, Sendable {
    let status: String
    let resultID: UUID?
    let finalScore: Int?
    let casesSolved: Int?
    let duplicate: Bool
    let matchStatus: VersusMatchStatus?
    let playerState: VersusPlayerState?
    let matchOutcome: VersusOutcome?
    let opponentFinalScore: Int?

    enum CodingKeys: String, CodingKey {
        case status
        case resultID = "result_id"
        case finalScore = "final_score"
        case casesSolved = "cases_solved"
        case duplicate
        case matchStatus = "match_status"
        case playerState = "player_state"
        case matchOutcome = "match_outcome"
        case opponentFinalScore = "opponent_final_score"
    }
}

nonisolated enum VersusFindResult: Hashable, Sendable {
    /// Paired with an opponent (or the existing active match was returned).
    case matched(VersusMatch)
    /// No opponent yet — a waiting match with its five cases.
    case waiting(VersusMatch)
    /// Final for this request (match in progress, already waiting…).
    case rejected(reason: String)
    /// Offline / 401 / 429 / 5xx.
    case retryable(category: String)
}

nonisolated enum VersusSubmitResult: Hashable, Sendable {
    case verified(VersusSubmitReceipt)
    /// 410: the match expired before this result arrived; it never counts.
    case expired
    case rejected(reason: String)
    case retryable(category: String)
}

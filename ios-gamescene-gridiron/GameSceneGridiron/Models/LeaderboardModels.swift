import Foundation

// MARK: - Phase 14 — leaderboard value types
//
// Every number here was computed by the server from verified results. The
// client only formats it.

nonisolated enum LeaderboardBoard: String, CaseIterable, Hashable, Sendable, Identifiable {
    case weekly
    case allTime = "alltime"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .weekly: "WEEKLY"
        case .allTime: "ALL-TIME"
        }
    }

    var caption: String {
        switch self {
        case .weekly: "Best 10 verified games · Mon–Sun UTC"
        case .allTime: "Average of best 25 verified games"
        }
    }
}

nonisolated enum LeaderboardDifficultyFilter: String, CaseIterable, Hashable, Sendable, Identifiable {
    case all
    case rookie
    case pro
    case allPro = "all_pro"
    case hallOfFamer = "hall_of_famer"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "ALL"
        case .rookie: "ROOKIE"
        case .pro: "PRO"
        case .allPro: "ALL-PRO"
        case .hallOfFamer: "HALL OF FAMER"
        }
    }

    var difficulty: DifficultyLevel? {
        self == .all ? nil : DifficultyLevel(serverValue: rawValue)
    }
}

/// One leaderboard row (same shape for both boards).
nonisolated struct LeaderboardEntry: Codable, Hashable, Sendable, Identifiable {
    let rank: Int
    let userID: UUID
    let username: String
    let footballDisplayName: String
    let score: Double
    let gamesCounted: Int
    let totalGames: Int
    let averageScore: Double
    let wins: Int
    let quartersSolved: Int
    let hintsUsed: Int
    let wrongPlacements: Int
    let topDifficulty: String
    let isProvisional: Bool
    let firstReachedAt: Date?

    var id: UUID { userID }

    enum CodingKeys: String, CodingKey {
        case rank
        case userID = "user_id"
        case username
        case footballDisplayName = "football_display_name"
        case score
        case gamesCounted = "games_counted"
        case totalGames = "total_games"
        case averageScore = "average_score"
        case wins
        case quartersSolved = "quarters_solved"
        case hintsUsed = "hints_used"
        case wrongPlacements = "wrong_placements"
        case topDifficulty = "top_difficulty"
        case isProvisional = "is_provisional"
        case firstReachedAt = "first_reached_at"
    }

    var topDifficultyLevel: DifficultyLevel? { DifficultyLevel(serverValue: topDifficulty) }

    /// Podium medal for the top three.
    var podium: LeaderboardPodium? { LeaderboardPodium(rank: rank) }
}

nonisolated enum LeaderboardPodium: Int, Hashable, Sendable {
    case gold = 1
    case silver = 2
    case bronze = 3

    init?(rank: Int) { self.init(rawValue: rank) }
}

/// Pure display formatting (tested).
nonisolated enum LeaderboardFormat {
    /// WEEKLY: integer total. ALL-TIME: one decimal, "— PROVISIONAL" under
    /// the minimum game count.
    static func score(_ entry: LeaderboardEntry, board: LeaderboardBoard) -> String {
        switch board {
        case .weekly:
            return String(Int(entry.score.rounded()))
        case .allTime:
            let value = String(format: "%.1f", entry.score)
            return entry.isProvisional ? "\(value) — PROVISIONAL" : value
        }
    }

    static func difficultyBadge(_ serverValue: String) -> String {
        switch serverValue {
        case "rookie": "RK"
        case "pro": "PRO"
        case "all_pro": "AP"
        case "hall_of_famer": "HOF"
        default: "—"
        }
    }
}

/// A public player file — public_profiles columns only (never real names
/// or email).
nonisolated struct PublicPlayerFile: Codable, Hashable, Sendable, Identifiable {
    let id: UUID
    let username: String
    let footballDisplayName: String
    let globalRating: Int
    let careerGamesPlayed: Int
    let careerWins: Int
    let championships: Int

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case footballDisplayName = "football_display_name"
        case globalRating = "global_rating"
        case careerGamesPlayed = "career_games_played"
        case careerWins = "career_wins"
        case championships
    }
}

/// Validated username-search query (mirrors the server's 2–20 rule).
nonisolated enum PlayerSearchQuery {
    static let minLength = 2
    static let maxLength = 20
    static let resultLimit = 20

    /// The normalized query, or nil when it should not hit the network.
    static func normalized(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard (minLength...maxLength).contains(trimmed.count),
              trimmed.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "_") }) else { return nil }
        return trimmed
    }
}

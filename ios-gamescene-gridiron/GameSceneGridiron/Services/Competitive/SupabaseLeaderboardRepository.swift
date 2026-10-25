import Foundation
import Supabase

// MARK: - Supabase leaderboard repository (Phase 14)
//
// Reads ONLY through the authenticated SECURITY DEFINER functions
// (ranked_leaderboard / my_ranked_standing / search_public_profiles) and the
// public_profiles view — never the private profiles table, never another
// player's result rows.

struct SupabaseLeaderboardRepository: LeaderboardRepository {
    static let pageSize = 50
    let client: SupabaseClient

    private struct BoardParams: Encodable, Sendable {
        let p_board: String
        let p_difficulty: String
        let p_limit: Int
        let p_offset: Int
    }

    private struct StandingParams: Encodable, Sendable {
        let p_board: String
        let p_difficulty: String
    }

    private struct SearchParams: Encodable, Sendable {
        let p_query: String
        let p_limit: Int
    }

    func page(board: LeaderboardBoard, difficulty: LeaderboardDifficultyFilter, limit: Int, offset: Int) async throws -> [LeaderboardEntry] {
        let response = try await client.rpc("ranked_leaderboard", params: BoardParams(
            p_board: board.rawValue,
            p_difficulty: difficulty.rawValue,
            p_limit: min(max(limit, 1), Self.pageSize),
            p_offset: max(offset, 0)
        )).execute()
        return try LeaderboardDecoding.decoder().decode([LeaderboardEntry].self, from: response.data)
    }

    func myStanding(board: LeaderboardBoard, difficulty: LeaderboardDifficultyFilter) async throws -> LeaderboardEntry? {
        let response = try await client.rpc("my_ranked_standing", params: StandingParams(
            p_board: board.rawValue,
            p_difficulty: difficulty.rawValue
        )).execute()
        return try LeaderboardDecoding.decoder().decode([LeaderboardEntry].self, from: response.data).first
    }

    func searchPlayers(query: String, limit: Int) async throws -> [PublicPlayerFile] {
        guard let normalized = PlayerSearchQuery.normalized(query) else { return [] }
        let response = try await client.rpc("search_public_profiles", params: SearchParams(
            p_query: normalized,
            p_limit: min(max(limit, 1), PlayerSearchQuery.resultLimit)
        )).execute()
        return try LeaderboardDecoding.decoder().decode([PublicPlayerFile].self, from: response.data)
    }

    func playerFile(userID: UUID) async throws -> PublicPlayerFile? {
        let response = try await client.from("public_profiles")
            .select("id, username, football_display_name, global_rating, career_games_played, career_wins, championships")
            .eq("id", value: userID.uuidString)
            .limit(1)
            .execute()
        return try LeaderboardDecoding.decoder().decode([PublicPlayerFile].self, from: response.data).first
    }
}

/// Postgres timestamps arrive with or without fractional seconds.
nonisolated enum LeaderboardDecoding {
    static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            if let date = parse(raw) { return date }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unrecognized date")
        }
        return decoder
    }

    static func parse(_ raw: String) -> Date? {
        // Postgres sends up to 6 fractional digits; ISO8601DateFormatter is
        // only reliable with 3 — trim the extras (sub-millisecond is noise).
        var raw = raw
        if let dot = raw.firstIndex(of: "."), raw[dot...].dropFirst().prefix(while: \.isNumber).count > 3 {
            let digitsStart = raw.index(after: dot)
            let digitsEnd = raw[digitsStart...].firstIndex { !$0.isNumber } ?? raw.endIndex
            let keep = raw.index(digitsStart, offsetBy: 3)
            raw.removeSubrange(keep..<digitsEnd)
        }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: raw) { return date }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: raw)
    }
}

// MARK: - Short-lived cache

/// 60-second page cache so tab/filter flips don't refetch. Invalidated when
/// one of the player's own results is verified.
@MainActor
final class LeaderboardCache {
    static let shared = LeaderboardCache()
    static let lifetime: TimeInterval = 60

    struct Key: Hashable {
        let board: LeaderboardBoard
        let difficulty: LeaderboardDifficultyFilter
    }

    struct Snapshot {
        let entries: [LeaderboardEntry]
        let mine: LeaderboardEntry?
        let canLoadMore: Bool
        let fetchedAt: Date
    }

    private var storage: [Key: Snapshot] = [:]

    func snapshot(for key: Key, now: Date = Date()) -> Snapshot? {
        guard let snapshot = storage[key], now.timeIntervalSince(snapshot.fetchedAt) < Self.lifetime else { return nil }
        return snapshot
    }

    func store(_ snapshot: Snapshot, for key: Key) {
        storage[key] = snapshot
    }

    func invalidate() {
        storage.removeAll()
    }
}

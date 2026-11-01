import Foundation

// MARK: - Phase 14B — server-owned ranked assignments
//
// A ranked game is ALWAYS bound to a server assignment created by the
// `start-ranked-match` Edge Function: the server owns the season, picks the
// five cases (4 regulation + overtime) from the private catalog and issues a
// persistent match ID. The client only plays what it was assigned and later
// submits raw facts for that match ID. A game without an assignment is
// played normally but is never ranked (offline policy A).
//
// The assignment carries ONLY play data: no solutions, no adapter variant, no
// seed. Bundled case solutions are not secret either — ranked play is
// consistency-checked, not anti-cheat.

nonisolated struct RankedAssignment: Codable, Hashable, Sendable, Identifiable {
    let assignmentID: UUID
    /// Server-issued, persistent — the submission's `match_id`.
    let matchID: UUID
    /// Server season id (`ranked_seasons.season_id`).
    let seasonID: UUID
    /// 1–10 regular season, 11 semifinal, 12 championship.
    let gameNumber: Int
    /// Server enum value (rookie / pro / all_pro / hall_of_famer).
    let difficulty: String
    /// Five case ids: quarters 1–4, then overtime.
    let caseIDs: [String]
    let caseVersions: [Int]
    let issuedAt: Date
    let expiresAt: Date
    let catalogFingerprint: String
    /// The account the server issued it to (the JWT user) — only that
    /// account can ever play it ranked.
    let ownerUserID: UUID

    var id: UUID { matchID }

    static let caseCount = 5

    var regulationCaseIDs: [String] { Array(caseIDs.prefix(GameMatch.regulationQuarters)) }
    var overtimeCaseID: String? { caseIDs.count == Self.caseCount ? caseIDs[Self.caseCount - 1] : nil }

    /// Structurally sound: five distinct cases with matching versions.
    var isWellFormed: Bool {
        caseIDs.count == Self.caseCount && caseVersions.count == Self.caseCount
            && Set(caseIDs).count == Self.caseCount && (1...12).contains(gameNumber)
            && DifficultyLevel(serverValue: difficulty) != nil
    }

    /// Every assigned case exists locally at EXACTLY the assigned version
    /// (same content fingerprint the server catalog was exported from). A
    /// stale or newer app build can't play an assignment it would render
    /// differently — the game is then unranked instead.
    func matchesLocalCatalog(version: (String) -> Int? = CompetitiveCaseCatalog.competitiveVersion(forCaseID:)) -> Bool {
        guard isWellFormed else { return false }
        return zip(caseIDs, caseVersions).allSatisfy { version($0.0) == $0.1 }
    }

    /// Usable to START a ranked game for this exact context.
    func isPlayable(owner: UUID, seasonID: UUID, gameNumber: Int, difficulty: DifficultyLevel, now: Date) -> Bool {
        ownerUserID == owner && self.seasonID == seasonID && self.gameNumber == gameNumber
            && self.difficulty == difficulty.serverValue && expiresAt > now
    }
}

/// Pure, persisted set of prefetched assignments (offline policy A: at most
/// `maxPrefetched` ahead per owner).
nonisolated struct RankedAssignmentStore: Codable, Hashable, Sendable {
    private(set) var assignments: [RankedAssignment] = []

    /// Mirrors ranked_scoring_config.assignment_prefetch_games.
    static let maxPrefetched = 3

    func playable(owner: UUID, seasonID: UUID, gameNumber: Int, difficulty: DifficultyLevel, now: Date) -> RankedAssignment? {
        assignments
            .filter { $0.isPlayable(owner: owner, seasonID: seasonID, gameNumber: gameNumber, difficulty: difficulty, now: now) }
            .max { $0.issuedAt < $1.issuedAt }
    }

    func has(owner: UUID, seasonID: UUID, gameNumber: Int, now: Date) -> Bool {
        assignments.contains { $0.ownerUserID == owner && $0.seasonID == seasonID && $0.gameNumber == gameNumber && $0.expiresAt > now }
    }

    /// Adds or replaces (same season + game + owner) a server assignment.
    mutating func upsert(_ assignment: RankedAssignment) {
        guard assignment.isWellFormed else { return }
        assignments.removeAll {
            $0.matchID == assignment.matchID
                || ($0.ownerUserID == assignment.ownerUserID && $0.seasonID == assignment.seasonID
                    && $0.gameNumber == assignment.gameNumber)
        }
        assignments.append(assignment)
    }

    /// Drops an assignment once its game is finished (queued or unranked).
    mutating func remove(matchID: UUID) {
        assignments.removeAll { $0.matchID == matchID }
    }

    /// Keeps only live assignments of the given owner's current season for
    /// games not yet played, at most `maxPrefetched` (lowest games first).
    mutating func prune(owner: UUID?, seasonID: UUID?, minGameNumber: Int = 1, now: Date) {
        assignments.removeAll {
            $0.expiresAt <= now || $0.ownerUserID != owner || $0.seasonID != seasonID || $0.gameNumber < minGameNumber
        }
        assignments.sort { $0.gameNumber < $1.gameNumber }
        if assignments.count > Self.maxPrefetched {
            assignments = Array(assignments.prefix(Self.maxPrefetched))
        }
    }

    // MARK: Persistence

    static let key = "gamescene.gridiron.rankedAssignments.v1"

    static func load(defaults: UserDefaults = .standard) -> RankedAssignmentStore {
        guard let data = defaults.data(forKey: key),
              let store = try? CompetitiveResultPayload.decoder().decode(RankedAssignmentStore.self, from: data) else {
            return RankedAssignmentStore()
        }
        return store
    }

    static func save(_ store: RankedAssignmentStore, defaults: UserDefaults = .standard) {
        guard let data = try? CompetitiveResultPayload.encoder().encode(store) else { return }
        defaults.set(data, forKey: key)
    }
}

/// Wire shape of `start-ranked-match`'s `assignment` object.
nonisolated struct RankedAssignmentWire: Decodable, Sendable {
    let assignmentID: UUID
    let matchID: UUID
    let seasonID: UUID
    let gameNumber: Int
    let difficulty: String
    let caseIDs: [String]
    let caseVersions: [Int]
    let issuedAt: String
    let expiresAt: String
    let catalogFingerprint: String?
    let reused: Bool?

    enum CodingKeys: String, CodingKey {
        case assignmentID = "assignment_id"
        case matchID = "match_id"
        case seasonID = "season_id"
        case gameNumber = "game_number"
        case difficulty
        case caseIDs = "case_ids"
        case caseVersions = "case_versions"
        case issuedAt = "issued_at"
        case expiresAt = "expires_at"
        case catalogFingerprint = "catalog_fingerprint"
        case reused
    }

    /// Accepts ISO-8601 with or without fractional seconds.
    static func parseDate(_ raw: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: raw) { return date }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: raw)
    }

    func assignment(owner: UUID) -> RankedAssignment? {
        guard let issued = Self.parseDate(issuedAt), let expires = Self.parseDate(expiresAt) else { return nil }
        let value = RankedAssignment(
            assignmentID: assignmentID, matchID: matchID, seasonID: seasonID,
            gameNumber: gameNumber, difficulty: difficulty, caseIDs: caseIDs,
            caseVersions: caseVersions, issuedAt: issued, expiresAt: expires,
            catalogFingerprint: catalogFingerprint ?? "", ownerUserID: owner
        )
        return value.isWellFormed ? value : nil
    }
}

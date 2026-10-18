import Foundation

// MARK: - Faction limits
//
// A faction is a football starting lineup: exactly 11 members. Positions are
// season-scoped roster slots — NEVER a permanent property of UserProfile.
nonisolated enum FactionLimits {
    /// A faction fields a starting lineup: 11 members.
    static let maxMembers = 11

    /// The 11 season positions a faction roster can field.
    static let positions: [FactionPosition] = [
        .qb, .rb, .wr, .te, .ol, .de, .dt, .lb, .cb, .fs, .ss,
    ]
}

/// A faction-season position. Belongs to the roster slot, not the player.
nonisolated enum FactionPosition: String, Codable, CaseIterable, Sendable {
    case qb = "QB"
    case rb = "RB"
    case wr = "WR"
    case te = "TE"
    case ol = "OL"
    case de = "DE"
    case dt = "DT"
    case lb = "LB"
    case cb = "CB"
    case fs = "FS"
    case ss = "SS"
}

// MARK: - Factions

nonisolated struct Faction: Codable, Equatable, Sendable, Identifiable {
    let id: UUID
    var name: String
    var crestSymbol: String?
    var seasonWins: Int
    var seasonLosses: Int
    var createdAt: Date

    init(id: UUID = UUID(), name: String, crestSymbol: String? = nil, seasonWins: Int = 0, seasonLosses: Int = 0, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.crestSymbol = crestSymbol
        self.seasonWins = seasonWins
        self.seasonLosses = seasonLosses
        self.createdAt = createdAt
    }
}

/// A player inside a faction. Membership can be season-scoped on the server;
/// position is resolved through roster slots, never stored here.
nonisolated struct FactionMember: Codable, Equatable, Sendable {
    let factionID: UUID
    /// Canonical identity — always the Supabase Auth UUID.
    let authUserID: UUID
    var username: String
    var joinedAt: Date

    init(factionID: UUID, authUserID: UUID, username: String, joinedAt: Date = Date()) {
        self.factionID = factionID
        self.authUserID = authUserID
        self.username = username
        self.joinedAt = joinedAt
    }
}

/// One starting-lineup seat in a specific faction season. The display name is
/// SNAPSHOT at roster time so historical seasons preserve the identity the
/// player used then ("J. Hudson" stays "J. Hudson" even after a name change).
nonisolated struct FactionSeasonRosterSlot: Codable, Equatable, Sendable, Identifiable {
    let id: UUID
    let factionID: UUID
    let seasonID: UUID
    var position: FactionPosition
    let authUserID: UUID
    /// Snapshot — historical lineups never retroactively change.
    var footballDisplayNameSnapshot: String

    init(id: UUID = UUID(), factionID: UUID, seasonID: UUID, position: FactionPosition, authUserID: UUID, footballDisplayNameSnapshot: String) {
        self.id = id
        self.factionID = factionID
        self.seasonID = seasonID
        self.position = position
        self.authUserID = authUserID
        self.footballDisplayNameSnapshot = footballDisplayNameSnapshot
    }
}

// MARK: - Faction battles (faction wars)

nonisolated struct FactionBattle: Codable, Equatable, Sendable, Identifiable {
    let id: UUID
    let seasonID: UUID
    let round: Int
    let homeFactionID: UUID
    let awayFactionID: UUID
    var homeFactionScore: Int
    var awayFactionScore: Int
    var startsAt: Date
    var endsAt: Date

    init(id: UUID = UUID(), seasonID: UUID, round: Int, homeFactionID: UUID, awayFactionID: UUID, homeFactionScore: Int = 0, awayFactionScore: Int = 0, startsAt: Date = Date(), endsAt: Date = Date()) {
        self.id = id
        self.seasonID = seasonID
        self.round = round
        self.homeFactionID = homeFactionID
        self.awayFactionID = awayFactionID
        self.homeFactionScore = homeFactionScore
        self.awayFactionScore = awayFactionScore
        self.startsAt = startsAt
        self.endsAt = endsAt
    }
}

/// The roster a faction fields for one battle: at most 11 slots, one per
/// position, each snapshotting the member's display name at battle time.
nonisolated struct FactionBattleRoster: Codable, Equatable, Sendable {
    let battleID: UUID
    let factionID: UUID
    var slots: [FactionSeasonRosterSlot]

    init(battleID: UUID, factionID: UUID, slots: [FactionSeasonRosterSlot] = []) {
        self.battleID = battleID
        self.factionID = factionID
        self.slots = slots
    }

    var isFullLineup: Bool { slots.count == FactionLimits.maxMembers }

    var positionsUsed: Set<FactionPosition> { Set(slots.map(\.position)) }
}

// MARK: - Competitive seasons

nonisolated enum CompetitiveSeasonStatus: String, Codable, Sendable {
    case upcoming
    case active
    case completed
}

nonisolated struct CompetitiveSeason: Codable, Equatable, Sendable, Identifiable {
    let id: UUID
    var name: String
    var status: CompetitiveSeasonStatus
    var startsAt: Date
    var endsAt: Date

    init(id: UUID = UUID(), name: String, status: CompetitiveSeasonStatus, startsAt: Date, endsAt: Date) {
        self.id = id
        self.name = name
        self.status = status
        self.startsAt = startsAt
        self.endsAt = endsAt
    }
}

nonisolated struct CompetitiveSeasonMember: Codable, Equatable, Sendable {
    let seasonID: UUID
    /// Canonical identity — always the Supabase Auth UUID.
    let authUserID: UUID
    var rating: Int
    var joinedAt: Date

    init(seasonID: UUID, authUserID: UUID, rating: Int = 0, joinedAt: Date = Date()) {
        self.seasonID = seasonID
        self.authUserID = authUserID
        self.rating = rating
        self.joinedAt = joinedAt
    }
}

/// A server-assigned head-to-head case. The case identity is
/// SERVER-AUTHORITATIVE: clients never reroll competitive cases locally. The
/// assigned case must be `isCompetitiveEligible == true` with its authored
/// difficulty score intact.
nonisolated struct CompetitiveGameAssignment: Codable, Equatable, Sendable, Identifiable {
    let id: UUID
    let seasonID: UUID
    let round: Int
    let homeUserID: UUID
    let awayUserID: UUID
    /// Server-chosen case identifier from the 150-case library.
    let caseID: String
    /// Mirrors the case library's authored difficulty (1–100).
    let caseDifficultyScore: Int
    var startsAt: Date

    init(id: UUID = UUID(), seasonID: UUID, round: Int, homeUserID: UUID, awayUserID: UUID, caseID: String, caseDifficultyScore: Int, startsAt: Date = Date()) {
        self.id = id
        self.seasonID = seasonID
        self.round = round
        self.homeUserID = homeUserID
        self.awayUserID = awayUserID
        self.caseID = caseID
        self.caseDifficultyScore = caseDifficultyScore
        self.startsAt = startsAt
    }
}

nonisolated struct CompetitiveGameResult: Codable, Equatable, Sendable, Identifiable {
    let assignmentID: UUID
    /// Which side of the assignment the reporting user played.
    let authUserID: UUID
    var didSolve: Bool
    var secondsUsed: Int
    var hintsUsed: Int
    var scoreDelta: Int
    /// Store-verified transaction identity when a Game Ball fee was involved —
    /// results are never granted on client-claimed economics alone.
    var recordedAt: Date

    var id: UUID { assignmentID }

    init(assignmentID: UUID, authUserID: UUID, didSolve: Bool, secondsUsed: Int, hintsUsed: Int, scoreDelta: Int, recordedAt: Date = Date()) {
        self.assignmentID = assignmentID
        self.authUserID = authUserID
        self.didSolve = didSolve
        self.secondsUsed = secondsUsed
        self.hintsUsed = hintsUsed
        self.scoreDelta = scoreDelta
        self.recordedAt = recordedAt
    }
}

// MARK: - Faction daily progress

nonisolated struct FactionDailyProgress: Codable, Equatable, Sendable {
    let factionID: UUID
    let day: Date
    let authUserID: UUID
    var casesSolved: Int
    var points: Int

    init(factionID: UUID, day: Date, authUserID: UUID, casesSolved: Int = 0, points: Int = 0) {
        self.factionID = factionID
        self.day = day
        self.authUserID = authUserID
        self.casesSolved = casesSolved
        self.points = points
    }
}

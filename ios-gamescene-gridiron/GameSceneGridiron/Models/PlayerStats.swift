import Foundation

// MARK: - Stat kinds

/// Every statistic the franchise tracks. Stats are lightweight, positive-only
/// awards derived from solved puzzle cases — never simulated football plays
/// and never penalties for the user's wrong deductions.
nonisolated enum PlayerStat: String, Codable, Hashable, Sendable, CaseIterable {
    case gamesPlayed
    case tackles
    case sacks
    case pressures
    case stops
    case passBreakups
    case interceptions
    case coverageWins
    case receptions
    case bigPlays
    case successfulAssignments
    case successfulRuns
    case brokenTackles
    case keyBlocks
    case blocks
    case protectionWins
    case successfulReads
    case scrambleOpportunities
    case drivesSecured
    case playerOfTheGame

    /// Short boxed label, e.g. "TCK" on a roster card.
    var shortLabel: String {
        switch self {
        case .gamesPlayed: "GP"
        case .tackles: "TCK"
        case .sacks: "SCK"
        case .pressures: "PRS"
        case .stops: "STP"
        case .passBreakups: "PB"
        case .interceptions: "INT"
        case .coverageWins: "COV"
        case .receptions: "REC"
        case .bigPlays: "BIG"
        case .successfulAssignments: "ASG"
        case .successfulRuns: "RUN"
        case .brokenTackles: "BRK"
        case .keyBlocks: "KBLK"
        case .blocks: "BLK"
        case .protectionWins: "PROT"
        case .successfulReads: "READ"
        case .scrambleOpportunities: "SCR"
        case .drivesSecured: "DRV"
        case .playerOfTheGame: "POG"
        }
    }

    /// Full readable label, e.g. "Tackles" on the player detail screen.
    var fullLabel: String {
        switch self {
        case .gamesPlayed: "Games Played"
        case .tackles: "Tackles"
        case .sacks: "Sacks"
        case .pressures: "Pressures"
        case .stops: "Stops"
        case .passBreakups: "Pass Breakups"
        case .interceptions: "Interceptions"
        case .coverageWins: "Coverage Wins"
        case .receptions: "Receptions"
        case .bigPlays: "Big Plays"
        case .successfulAssignments: "Successful Assignments"
        case .successfulRuns: "Successful Runs"
        case .brokenTackles: "Broken Tackles"
        case .keyBlocks: "Key Blocks"
        case .blocks: "Blocks"
        case .protectionWins: "Protection Wins"
        case .successfulReads: "Successful Reads"
        case .scrambleOpportunities: "Scramble Opportunities"
        case .drivesSecured: "Drives Secured"
        case .playerOfTheGame: "Player of the Game"
        }
    }

    /// Franchise-record label, e.g. "Most Tackles — Season".
    var recordLabel: String {
        switch self {
        case .playerOfTheGame: "Most Player of the Game Awards — Season"
        default: "Most \(fullLabel) — Season"
        }
    }

    /// Weight used to score the Player of the Game (relative impact).
    var awardWeight: Int {
        switch self {
        case .interceptions: 4
        case .sacks, .bigPlays: 3
        case .tackles, .receptions, .pressures, .blocks: 1
        case .passBreakups, .coverageWins, .stops, .brokenTackles, .keyBlocks,
             .successfulRuns, .successfulReads, .drivesSecured: 2
        case .scrambleOpportunities, .successfulAssignments, .protectionWins,
             .gamesPlayed, .playerOfTheGame: 1
        }
    }

    /// Stats that are meaningful for a position, in display order.
    static func relevant(for position: FootballPosition) -> [PlayerStat] {
        switch position {
        case .qb: [.gamesPlayed, .successfulReads, .drivesSecured, .scrambleOpportunities]
        case .rb: [.gamesPlayed, .successfulRuns, .brokenTackles, .keyBlocks]
        case .wr, .te: [.gamesPlayed, .receptions, .bigPlays, .successfulAssignments]
        case .ol: [.gamesPlayed, .blocks, .protectionWins]
        case .dl: [.gamesPlayed, .tackles, .sacks, .pressures, .stops]
        case .lb: [.gamesPlayed, .tackles, .stops, .coverageWins, .sacks]
        case .cb, .fs, .ss: [.gamesPlayed, .tackles, .passBreakups, .interceptions, .coverageWins]
        }
    }

    /// Categories shown on the SEASON LEADERS board.
    static let leaderCategories: [PlayerStat] = [
        .tackles, .sacks, .interceptions, .receptions, .successfulReads
    ]

    /// Categories tracked as franchise records.
    static let recordCategories: [PlayerStat] = [
        .tackles, .sacks, .interceptions, .receptions, .successfulReads, .playerOfTheGame
    ]
}

// MARK: - Stat line

/// A player's stat totals: a flexible, Codable map of stat kind → value.
/// Used for both season and career totals.
nonisolated struct PlayerStatLine: Codable, Hashable, Sendable {
    private var values: [String: Int] = [:]

    init() {}

    func value(for stat: PlayerStat) -> Int { values[stat.rawValue] ?? 0 }

    mutating func add(_ stat: PlayerStat, _ count: Int = 1) {
        guard count > 0 else { return }
        values[stat.rawValue, default: 0] += count
    }

    mutating func merge(_ other: PlayerStatLine) {
        for (key, value) in other.values {
            values[key, default: 0] += value
        }
    }

    var hasContent: Bool { values.contains { $0.value > 0 } }

    /// Weighted impact score used for Player of the Game selection.
    func awardScore() -> Int {
        values.reduce(0) { total, entry in
            guard let stat = PlayerStat(rawValue: entry.key), stat != .gamesPlayed, stat != .playerOfTheGame else { return total }
            return total + entry.value * stat.awardWeight
        }
    }

    /// Compact summary of the top nonzero stats, e.g. "2 TCK • 1 SCK".
    /// Nil when the line holds nothing worth showing.
    func topSummary(limit: Int = 3) -> String? {
        let ranked = values
            .compactMap { (key, value) -> (label: String, value: Int, weight: Int)? in
                guard let stat = PlayerStat(rawValue: key), value > 0, stat != .gamesPlayed else { return nil }
                return (stat.shortLabel, value, stat.awardWeight)
            }
            .sorted {
                if $0.value * $0.weight != $1.value * $1.weight { return $0.value * $0.weight > $1.value * $1.weight }
                if $0.value != $1.value { return $0.value > $1.value }
                return $0.label < $1.label
            }
            .prefix(limit)
        guard !ranked.isEmpty else { return nil }
        return ranked.map { "\($0.value) \($0.label)" }.joined(separator: " • ")
    }
}

// MARK: - Stat events

/// One stat award tied to a specific franchise player, produced from a solved
/// puzzle placement. Only positive accomplishments — never negative marks.
nonisolated struct PlayerStatEvent: Hashable, Sendable {
    let franchisePlayerID: UUID
    let playerName: String
    let position: FootballPosition
    let stat: PlayerStat
    let count: Int

    init(franchisePlayerID: UUID, playerName: String, position: FootballPosition, stat: PlayerStat, count: Int = 1) {
        self.franchisePlayerID = franchisePlayerID
        self.playerName = playerName
        self.position = position
        self.stat = stat
        self.count = count
    }
}

// MARK: - Game log

/// One finished game as seen by a single roster player: when it happened,
/// against whom, the result and that player's stat line from the solved cases.
nonisolated struct PlayerGameLog: Codable, Hashable, Sendable, Identifiable {
    let id: UUID
    let seasonNumber: Int
    /// "W3", "SF" or "FINAL".
    let weekLabel: String
    let opponentName: String
    let isPlayoff: Bool
    let teamWon: Bool
    let wasPlayerOfGame: Bool
    let stats: PlayerStatLine

    init(
        id: UUID = UUID(),
        seasonNumber: Int,
        weekLabel: String,
        opponentName: String,
        isPlayoff: Bool,
        teamWon: Bool,
        wasPlayerOfGame: Bool,
        stats: PlayerStatLine
    ) {
        self.id = id
        self.seasonNumber = seasonNumber
        self.weekLabel = weekLabel
        self.opponentName = opponentName
        self.isPlayoff = isPlayoff
        self.teamWon = teamWon
        self.wasPlayerOfGame = wasPlayerOfGame
        self.stats = stats
    }

    /// "S2 · W3 — 2 TCK • 1 SCK" style caption.
    var caption: String {
        var parts = ["S\(seasonNumber) · \(weekLabel)", opponentName]
        if let summary = stats.topSummary() { parts.append(summary) }
        return parts.joined(separator: " — ")
    }
}

import Foundation

// MARK: - Championship trophy

/// A permanent record of one championship victory, snapshotted at the moment
/// it was won. Team name, logo, colors, record and difficulty are frozen here
/// on purpose: later franchise re-branding must never rewrite history.
nonisolated struct ChampionshipTrophy: Codable, Hashable, Sendable, Identifiable {
    /// One trophy per season — the stable, deduping identity.
    let seasonNumber: Int
    // Historical franchise snapshot (as it existed that season).
    let teamState: String
    let teamName: String
    let logoID: String
    let primaryColorHex: UInt32
    let secondaryColorHex: UInt32
    // Season facts.
    let regularSeasonRecord: String
    let difficulty: String
    let opponentName: String
    /// e.g. "3–1" or "3–2 OT".
    let resultLine: String
    let date: Date

    var id: String { "trophy-s\(seasonNumber)" }
    var displayName: String { "\(teamState) \(teamName)" }
}

// MARK: - Season archive

/// The permanent record of one completed season. Written once when the season
/// ends; starting a new season never erases it.
nonisolated struct SeasonArchiveEntry: Codable, Hashable, Sendable, Identifiable {
    let seasonNumber: Int
    let recordLine: String
    let wins: Int
    let losses: Int
    /// Final league position, 1-based.
    let standing: Int
    let totalTeams: Int
    let difficulty: String
    /// "MISSED PLAYOFFS", "LOST IN SEMIFINAL", "LOST THE CHAMPIONSHIP"
    /// or "GRIDIRON CHAMPIONS".
    let postseasonResult: String
    let date: Date

    var id: Int { seasonNumber }

    var isUndefeated: Bool { losses == 0 && wins == 10 }
    var isChampion: Bool { postseasonResult == Self.championResult }
    var finishedAbove500: Bool { wins > losses }

    static let championResult = "GRIDIRON CHAMPIONS"
    static let lostChampionshipResult = "LOST THE CHAMPIONSHIP"
    static let lostSemifinalResult = "LOST IN SEMIFINAL"
    static let missedPlayoffsResult = "MISSED PLAYOFFS"

    var standingLine: String {
        let suffix: String
        switch standing {
        case 1: suffix = "st"
        case 2: suffix = "nd"
        case 3: suffix = "rd"
        default: suffix = "th"
        }
        return "\(standing)\(suffix) Place"
    }
}

// MARK: - Franchise legacy

/// The full franchise legacy summary: dynasty history counters plus the
/// streak/case/honor figures the trophy room presents. Built by `LegacyStore`
/// from the roster's history, its own persisted counters and the roster.
nonisolated struct FranchiseLegacy: Hashable, Sendable {
    let seasonsPlayed: Int
    let totalWins: Int
    let totalLosses: Int
    let playoffAppearances: Int
    let championshipAppearances: Int
    let championshipsWon: Int
    /// Best regular-season record line, e.g. "10–0". nil before any season.
    let bestRecordLine: String?
    let currentWinStreak: Int
    let longestWinStreak: Int
    let totalCasesSolved: Int
    /// The player with the most career Player of the Game awards, if any.
    let mostPlayerOfTheGame: LegacyLeader?
}

/// A named honor leader (name + career Player of the Game count).
nonisolated struct LegacyLeader: Hashable, Sendable {
    let name: String
    let count: Int
}

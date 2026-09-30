import Foundation

/// Deterministic case scheduling. A season's 40 regulation quarters map onto
/// the library with no repeats inside a game and no repeats across the whole
/// regular season (each quarter band holds exactly 10 cases, one per week).
/// The same season number always produces the same schedule, so persisted
/// content can never reshuffle between app launches.
nonisolated enum CaseScheduler {
    /// The four regulation case ids for one game (Q1...Q4, band order).
    static func regulationCaseIDs(seasonNumber: Int, week: Int) -> [String] {
        (1...4).map { band in
            let pool = CaseLibrary.band(band)
            return pool[(rotation(seasonNumber: seasonNumber, band: band) + week - 1) % pool.count].id
        }
    }

    /// The overtime case id for one game. Band 5 has its own rotation, so an
    /// overtime case never repeats a case already played that game, and the
    /// ten overtime cases never repeat within a regular season.
    static func overtimeCaseID(seasonNumber: Int, week: Int) -> String {
        let pool = CaseLibrary.band(5)
        return pool[(rotation(seasonNumber: seasonNumber, band: 5) + week - 1) % pool.count].id
    }

    /// Full set for one game: four regulation ids plus the overtime case.
    static func gameCaseIDs(seasonNumber: Int, week: Int) -> (regulation: [String], overtime: String) {
        (regulationCaseIDs(seasonNumber: seasonNumber, week: week), overtimeCaseID(seasonNumber: seasonNumber, week: week))
    }

    /// All 40 regulation ids for one season (weeks 1...10 × Q1...Q4).
    static func seasonSchedule(seasonNumber: Int) -> [String] {
        (1...10).flatMap { week in regulationCaseIDs(seasonNumber: seasonNumber, week: week) }
    }

    /// Season-stable rotation offset for one band, seeded like the rest of the
    /// deterministic simulation.
    static func rotation(seasonNumber: Int, band: Int) -> Int {
        var rng = SeededGenerator(seed: SeededGenerator.hash(["gridiron-cases", String(seasonNumber), String(band)]))
        return Int(rng.next() % 10)
    }
}

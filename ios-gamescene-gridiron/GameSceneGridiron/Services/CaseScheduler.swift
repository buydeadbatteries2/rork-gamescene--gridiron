import Foundation

/// Deterministic case scheduling with difficulty ordering. Each quarter
/// band's ten cases are ordered easiest-first by their computed difficulty
/// rating (with a small seeded jitter per season for variety) — Game 1 draws
/// the band's gentlest case, Game 10 its hardest. The order is still a
/// bijection, so a season never repeats a regulation case, and the same
/// season number always produces the same schedule so persisted content can
/// never reshuffle between app launches.
nonisolated enum CaseScheduler {
    /// Difficulty-ordered case ids for one band in one season.
    static func bandOrder(seasonNumber: Int, band: Int) -> [String] {
        let pool = CaseLibrary.band(band)
        var rng = SeededGenerator(seed: SeededGenerator.hash(["gridiron-caseorder", String(seasonNumber), String(band)]))

        var ranked: [(String, Double)] = []
        ranked.reserveCapacity(pool.count)
        for puzzleCase in pool {
            let rating = CaseDifficultyProfile(of: puzzleCase).rating
            let jitter = (rng.nextDouble() * 0.08) - 0.04
            ranked.append((puzzleCase.id, rating + jitter))
        }

        ranked.sort { lhs, rhs in
            lhs.1 == rhs.1 ? lhs.0 < rhs.0 : lhs.1 < rhs.1
        }
        return ranked.map(\.0)
    }

    /// Schedule index for a scheduler week: weeks 1–10 walk the difficulty
    /// ramp; the postseason (11 = semifinal, 12 = championship) draws from the
    /// top of it — a genuine step up, never the season's gentlest content.
    private static func orderIndex(week: Int, poolSize: Int) -> Int {
        switch week {
        case 1...10: week - 1
        case 11: poolSize - 2
        default: poolSize - 1
        }
    }

    /// The four regulation case ids for one game (Q1...Q4, band order).
    static func regulationCaseIDs(seasonNumber: Int, week: Int) -> [String] {
        (1...4).map { band in
            let order = bandOrder(seasonNumber: seasonNumber, band: band)
            return order[orderIndex(week: week, poolSize: order.count)]
        }
    }

    /// The overtime case id for one game. Band 5 has its own difficulty
    /// order, so an overtime case never repeats a case already played that
    /// game, and the ten overtime cases never repeat within a regular season.
    static func overtimeCaseID(seasonNumber: Int, week: Int) -> String {
        let order = bandOrder(seasonNumber: seasonNumber, band: 5)
        return order[orderIndex(week: week, poolSize: order.count)]
    }

    /// Full set for one game: four regulation ids plus the overtime case.
    static func gameCaseIDs(seasonNumber: Int, week: Int) -> (regulation: [String], overtime: String) {
        (regulationCaseIDs(seasonNumber: seasonNumber, week: week), overtimeCaseID(seasonNumber: seasonNumber, week: week))
    }

    /// All 40 regulation ids for one season (weeks 1...10 × Q1...Q4).
    static func seasonSchedule(seasonNumber: Int) -> [String] {
        (1...10).flatMap { week in regulationCaseIDs(seasonNumber: seasonNumber, week: week) }
    }
}

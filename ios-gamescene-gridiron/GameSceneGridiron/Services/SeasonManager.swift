import Foundation
import Observation

// MARK: - Deterministic simulation

/// A tiny deterministic generator (SplitMix64). The same seed always produces
/// the same results, so a simulated CPU game never changes once computed — and
/// would reproduce identically even before it is stored.
nonisolated struct SeededGenerator: Sendable {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// Uniform double in 0...1.
    mutating func nextDouble() -> Double {
        Double(next() >> 11) * (1.0 / 9_007_199_254_740_992.0)
    }

    /// FNV-1a hash of a byte string — builds stable seeds from matchup identity.
    static func hash(_ values: [String]) -> UInt64 {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for value in values {
            for byte in value.utf8 {
                hash ^= UInt64(byte)
                hash = hash &* 0x0000_0100_0000_01B3
            }
            hash ^= 0x1F
            hash = hash &* 0x0000_0100_0000_01B3
        }
        return hash
    }
}

/// Lightweight local result generation for CPU-vs-CPU games. Hidden strength
/// ratings (1–5) bias the winner; scores follow the game's real rules:
/// winner solves 3–4 quarters, loser 0–1, or 2 when it goes to overtime.
nonisolated enum SeasonSim {
    /// Roughly one in five CPU games reaches overtime.
    static let overtimeChance = 0.20
    /// Chance the winner solves all four quarters instead of three.
    static let sweepChance = 0.45

    static func gameSeed(seasonNumber: Int, week: Int, homeID: UUID, awayID: UUID) -> UInt64 {
        SeededGenerator.hash([
            String(seasonNumber),
            String(week),
            homeID.uuidString,
            awayID.uuidString
        ])
    }

    /// Probability the home team wins, from hidden strengths + a home-field edge.
    static func homeWinProbability(homeStrength: Int, awayStrength: Int) -> Double {
        min(0.85, max(0.15, 0.5 + 0.08 * Double(homeStrength - awayStrength) + 0.06))
    }

    static func simulateGame(seasonNumber: Int, week: Int, home: GameTeam, away: GameTeam) -> GameResult {
        var rng = SeededGenerator(seed: gameSeed(seasonNumber: seasonNumber, week: week, homeID: home.id, awayID: away.id))
        let homeStrength = OpponentTeams.strength(of: home.id)
        let awayStrength = OpponentTeams.strength(of: away.id)
        let homeWins = rng.nextDouble() < homeWinProbability(homeStrength: homeStrength, awayStrength: awayStrength)
        let winner = homeWins ? home : away
        let loser = homeWins ? away : home

        let wentToOT = rng.nextDouble() < overtimeChance
        let winnerScore = wentToOT ? 3 : (rng.nextDouble() < sweepChance ? 4 : 3)
        let loserScore = wentToOT ? 2 : (rng.nextDouble() < 0.5 ? 1 : 0)

        return GameResult(
            winnerID: winner.id,
            loserID: loser.id,
            winnerScore: winnerScore,
            loserScore: loserScore,
            wentToOT: wentToOT
        )
    }

    /// Deterministically schedules the CPU-vs-CPU pairings for one week.
    /// Every opponent except the one facing the player plays; pairings rotate
    /// each week so the league table evolves naturally.
    static func cpuPairings(
        seasonNumber: Int,
        week: Int,
        restingID: UUID
    ) -> [(homeID: UUID, awayID: UUID)] {
        var others = OpponentTeams.all
            .map(\.id)
            .filter { $0 != restingID }
            .sorted { $0.uuidString < $1.uuidString }
        guard others.count >= 2 else { return [] }

        let rotation = SeededGenerator.hash([String(seasonNumber)]) % UInt64(others.count)
        let pivot = (Int(rotation) + week) % others.count
        others = Array(others[pivot...] + others[..<pivot])

        var pairs: [(UUID, UUID)] = []
        for index in stride(from: 0, to: others.count - 1, by: 2) {
            pairs.append((others[index], others[index + 1]))
        }
        // Alternate home/away by week so rematches switch venues.
        return week % 2 == 0 ? pairs : pairs.map { ($0.1, $0.0) }
    }
}

// MARK: - Season manager

/// Single source of truth for the whole season: schedule generation, current
/// week, match recording, CPU simulation, standings, playoffs and persistence.
/// All presentation reads from this object; no season logic lives in views.
@MainActor
@Observable
final class SeasonManager {
    static let shared = SeasonManager()

    static let storageKey = "gamescene.gridiron.season"

    /// Fictional season anchor: Week 1 kicks off on the first Saturday of
    /// September at 7:15 PM, one game per week. Purely fictional calendar.
    static let seasonStartYear = 2026
    static let seasonStartMonth = 9
    static let seasonStartDay = 5
    static let kickoffHour = 19
    static let kickoffMinute = 15

    private let defaults: UserDefaults
    private(set) var season: Season?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let loaded = Self.load(from: defaults)
        if let repaired = loaded.map(Self.repairCorruptedSeason) {
            season = repaired
            if repaired != loaded {
                // Persist the repair immediately so it survives restarts.
                persist()
            }
        } else {
            season = nil
        }
    }

    /// Repairs corrupted development seasons — e.g. one persisted with a
    /// missing/short schedule while postseason was already enabled at 0–0.
    /// Such a season is rebuilt as a fresh Week 1 regular season with zeroed
    /// records. Seasons with any played game or standings progress are
    /// legitimate and left untouched.
    private static func repairCorruptedSeason(_ season: Season) -> Season {
        let hasProgress = season.games.contains { $0.isPlayed }
            || season.standings.contains { $0.gamesPlayed > 0 }
        let looksCorrupted = !season.hasValidSchedule
            || season.phase != .regularSeason
            || season.bracket != nil
        guard !hasProgress, looksCorrupted else { return season }
        return generateSeason(userTeamID: season.userTeamID, seasonNumber: season.seasonNumber)
    }

    // MARK: Persistence

    private func persist() {
        guard let season else {
            defaults.removeObject(forKey: Self.storageKey)
            return
        }
        if let data = try? JSONEncoder().encode(season) {
            defaults.set(data, forKey: Self.storageKey)
        }
    }

    private static func load(from defaults: UserDefaults) -> Season? {
        guard let data = defaults.data(forKey: storageKey) else { return nil }
        return try? JSONDecoder().decode(Season.self, from: data)
    }

    // MARK: Lifecycle

    var hasActiveSeason: Bool { season != nil }

    /// Starts a new season (or advances to the next one). The user's franchise
    /// identity is never touched — only competition data resets.
    func startNewSeason(userTeam: GameTeam) {
        let nextNumber = (season?.seasonNumber ?? 0) + 1
        season = Self.generateSeason(userTeamID: userTeam.id, seasonNumber: nextNumber)
        persist()
    }

    /// Generates the 10-week schedule: every opponent once, weekly Saturday
    /// evening slots, home/away alternating, order seeded by season number.
    static func generateSeason(userTeamID: UUID, seasonNumber: Int) -> Season {
        var rng = SeededGenerator(seed: SeededGenerator.hash(["gridiron-schedule", String(seasonNumber)]))
        var opponents = OpponentTeams.all
        // Fisher–Yates with the seeded generator.
        for index in (1..<opponents.count).reversed() {
            let swap = Int(rng.next() % UInt64(index + 1))
            opponents.swapAt(index, swap)
        }

        let year = seasonStartYear + (seasonNumber - 1)
        var components = DateComponents()
        components.year = year
        components.month = seasonStartMonth
        components.day = seasonStartDay
        components.hour = kickoffHour
        components.minute = kickoffMinute
        let weekOne = Calendar.current.date(from: components) ?? Date()

        let games: [ScheduledGame] = (1...10).map { week in
            ScheduledGame(
                id: "w\(week)",
                week: week,
                date: Calendar.current.date(byAdding: .day, value: (week - 1) * 7, to: weekOne) ?? weekOne,
                opponentID: opponents[week - 1].id,
                isHome: week % 2 == 1,
                result: nil
            )
        }

        let teams = [userTeamID] + OpponentTeams.all.map(\.id)
        let standings = teams.map { LeagueStanding(teamID: $0) }

        return Season(seasonNumber: seasonNumber, userTeamID: userTeamID, games: games, standings: standings)
    }

    // MARK: Lookups

    func team(with id: UUID) -> GameTeam? {
        if id == season?.userTeamID { return nil }
        return OpponentTeams.team(with: id)
    }

    func name(for id: UUID) -> String {
        if id == season?.userTeamID { return "Your Team" }
        return OpponentTeams.team(with: id)?.displayName ?? "Unknown"
    }

    /// Standings ranked by the league rules.
    func rankedStandings() -> [LeagueStanding] {
        season?.sortedStandings { name(for: $0) } ?? []
    }

    /// 1-based league position of the user's team.
    var userStandingPosition: Int? {
        guard let season else { return nil }
        return Season.position(of: season.userTeamID, in: rankedStandings())
    }

    var currentGame: ScheduledGame? { season?.currentGame }

    var currentWeek: Int? { season?.currentWeek }

    // MARK: Recording regular-season games

    /// Records the player's finished match against the current opponent,
    /// simulates the rest of that week's CPU games and advances the season.
    /// Returns false when there is no playable game to record against.
    @discardableResult
    func recordUserMatch(_ match: GameMatch, opponent: GameTeam) -> Bool {
        guard let result = match.result,
              let game = currentGame,
              game.opponentID == opponent.id else { return false }

        let userScore = match.quartersSolved + (match.overtimeRecord?.outcome == .solved ? 1 : 0)
        let opponentScore = match.quartersFailed + (match.overtimeRecord?.outcome == .failed ? 1 : 0)
        return recordUserResult(
            isWin: result.isWin,
            userScore: userScore,
            opponentScore: opponentScore,
            wentToOT: match.overtimeRecord != nil
        )
    }

    /// Core recording entry point (also used by tests): stores the result,
    /// updates records and standings, simulates that week's CPU games and
    /// unlocks the next week — or moves the season into the postseason.
    @discardableResult
    func recordUserResult(isWin: Bool, userScore: Int, opponentScore: Int, wentToOT: Bool) -> Bool {
        guard var updated = season, let game = updated.currentGame else { return false }

        let result = GameResult.fromPerspective(
            teamID: updated.userTeamID,
            opponentID: game.opponentID,
            isWin: isWin,
            teamScore: userScore,
            opponentScore: opponentScore,
            wentToOT: wentToOT
        )
        updated.applyResult(result)
        if let index = updated.games.firstIndex(where: { $0.id == game.id }) {
            updated.games[index].result = result
        }

        simulateCPUWeek(week: game.week, restingID: game.opponentID, season: &updated)

        if updated.isRegularSeasonComplete {
            finishRegularSeason(&updated)
        }

        season = updated
        persist()
        return true
    }

    /// Simulates every CPU game scheduled for the given week (all opponents
    /// except the one that just faced the player).
    private func simulateCPUWeek(week: Int, restingID: UUID, season: inout Season) {
        for pairing in SeasonSim.cpuPairings(seasonNumber: season.seasonNumber, week: week, restingID: restingID) {
            guard let home = OpponentTeams.team(with: pairing.homeID),
                  let away = OpponentTeams.team(with: pairing.awayID) else { continue }
            let result = SeasonSim.simulateGame(seasonNumber: season.seasonNumber, week: week, home: home, away: away)
            season.applyResult(result)
        }
    }

    // MARK: Postseason

    /// Called once Week 10 is recorded. Seeds the top four teams into the
    /// bracket; if the player missed the cut, the entire postseason resolves
    /// locally and the season completes immediately.
    private func finishRegularSeason(_ season: inout Season) {
        let ranked = season.sortedStandings { name(for: $0) }
        let seeds = ranked.prefix(4).map(\.teamID)
        guard seeds.count == 4 else {
            season.phase = .complete
            return
        }

        let sf1 = PlayoffMatchup(seedA: 1, teamA: seeds[0], seedB: 4, teamB: seeds[3])
        let sf2 = PlayoffMatchup(seedA: 2, teamA: seeds[1], seedB: 3, teamB: seeds[2])
        var bracket = PlayoffBracket(semifinal1: sf1, semifinal2: sf2, championship: nil, championID: nil)

        // The CPU-vs-CPU semifinal resolves immediately; the player's own
        // semifinal waits for their game.
        if !sf1.has(teamID: season.userTeamID) {
            bracket.semifinal1.result = simulatePlayoffGame(matchup: sf1, seasonNumber: season.seasonNumber, stage: 1)
        }
        if !sf2.has(teamID: season.userTeamID) {
            bracket.semifinal2.result = simulatePlayoffGame(matchup: sf2, seasonNumber: season.seasonNumber, stage: 2)
        }

        if sf1.has(teamID: season.userTeamID) || sf2.has(teamID: season.userTeamID) {
            season.phase = .postseason
            season.bracket = bracket
        } else {
            // Player missed the playoffs: run the whole postseason locally.
            resolveChampionship(seasonNumber: season.seasonNumber, bracket: &bracket)
            season.phase = .complete
            season.bracket = bracket
        }
    }

    /// Builds the championship once both semifinals have results. When the
    /// player lost (or didn't qualify), the CPU championship is simulated and
    /// the season completes.
    private func resolveChampionship(seasonNumber: Int, bracket: inout PlayoffBracket) {
        guard let winner1 = bracket.semifinal1.winnerID, let winner2 = bracket.semifinal2.winnerID else { return }
        let seed1 = bracket.semifinal1.seed(for: winner1) ?? 1
        let seed2 = bracket.semifinal2.seed(for: winner2) ?? 2
        var championship = PlayoffMatchup(seedA: min(seed1, seed2), teamA: winner1, seedB: max(seed1, seed2), teamB: winner2, result: nil)
        championship.result = simulatePlayoffGame(matchup: championship, seasonNumber: seasonNumber, stage: 3)
        bracket.championship = championship
        bracket.championID = championship.result?.winnerID
    }

    private func simulatePlayoffGame(matchup: PlayoffMatchup, seasonNumber: Int, stage: Int) -> GameResult? {
        guard let home = OpponentTeams.team(with: matchup.teamA) ?? team(with: matchup.teamA),
              let away = OpponentTeams.team(with: matchup.teamB) ?? team(with: matchup.teamB),
              !(matchup.has(teamID: season?.userTeamID ?? UUID())) else { return nil }
        var rng = SeededGenerator(seed: SeededGenerator.hash(["gridiron-playoff", String(seasonNumber), String(stage), matchup.teamA.uuidString, matchup.teamB.uuidString]))
        let homeStrength = OpponentTeams.strength(of: matchup.teamA)
        let awayStrength = OpponentTeams.strength(of: matchup.teamB)
        let firstWins = rng.nextDouble() < min(0.85, max(0.15, 0.5 + 0.08 * Double(homeStrength - awayStrength)))
        let winner = firstWins ? matchup.teamA : matchup.teamB
        let loser = firstWins ? matchup.teamB : matchup.teamA
        let wentToOT = rng.nextDouble() < SeasonSim.overtimeChance
        return GameResult(
            winnerID: winner,
            loserID: loser,
            winnerScore: wentToOT ? 3 : (rng.nextDouble() < SeasonSim.sweepChance ? 4 : 3),
            loserScore: wentToOT ? 2 : (rng.nextDouble() < 0.5 ? 1 : 0),
            wentToOT: wentToOT
        )
    }

    /// Records the player's finished playoff match (semifinal or championship)
    /// against `opponent`, mirroring `recordUserMatch` for the regular season.
    @discardableResult
    func recordUserPlayoffMatch(_ match: GameMatch, opponent: GameTeam) -> Bool {
        guard let result = match.result else { return false }
        let userScore = match.quartersSolved + (match.overtimeRecord?.outcome == .solved ? 1 : 0)
        let opponentScore = match.quartersFailed + (match.overtimeRecord?.outcome == .failed ? 1 : 0)
        return recordUserPlayoffResult(
            isWin: result.isWin,
            userScore: userScore,
            opponentScore: opponentScore,
            wentToOT: match.overtimeRecord != nil
        )
    }

    /// Records the player's playoff game (semifinal or championship).
    @discardableResult
    func recordUserPlayoffResult(isWin: Bool, userScore: Int, opponentScore: Int, wentToOT: Bool) -> Bool {
        guard var updated = season, var bracket = updated.bracket, updated.phase == .postseason else { return false }
        let userTeamID = updated.userTeamID

        func makeResult(against opponentID: UUID) -> GameResult {
            GameResult.fromPerspective(
                teamID: userTeamID,
                opponentID: opponentID,
                isWin: isWin,
                teamScore: userScore,
                opponentScore: opponentScore,
                wentToOT: wentToOT
            )
        }

        if bracket.semifinal1.has(teamID: userTeamID), bracket.semifinal1.result == nil {
            bracket.semifinal1.result = makeResult(against: bracket.semifinal1.teamA == userTeamID ? bracket.semifinal1.teamB : bracket.semifinal1.teamA)
            if isWin {
                resolveChampionship(seasonNumber: updated.seasonNumber, bracket: &bracket)
            } else {
                // Run ends — resolve the remaining CPU championship for the record.
                resolveChampionship(seasonNumber: updated.seasonNumber, bracket: &bracket)
                updated.phase = .complete
            }
        } else if bracket.semifinal2.has(teamID: userTeamID), bracket.semifinal2.result == nil {
            bracket.semifinal2.result = makeResult(against: bracket.semifinal2.teamA == userTeamID ? bracket.semifinal2.teamB : bracket.semifinal2.teamA)
            if isWin {
                resolveChampionship(seasonNumber: updated.seasonNumber, bracket: &bracket)
            } else {
                resolveChampionship(seasonNumber: updated.seasonNumber, bracket: &bracket)
                updated.phase = .complete
            }
        } else if let championship = bracket.championship, championship.has(teamID: userTeamID), championship.result == nil {
            bracket.championship?.result = makeResult(against: championship.teamA == userTeamID ? championship.teamB : championship.teamA)
            bracket.championID = isWin ? userTeamID : (championship.teamA == userTeamID ? championship.teamB : championship.teamA)
            updated.phase = .complete
        } else {
            return false
        }

        updated.bracket = bracket
        season = updated
        persist()
        return true
    }

    /// True when the user's finished match should be recorded as a playoff game.
    func isUserPlayoffMatchPending() -> Bool {
        guard let season, season.phase == .postseason, let bracket = season.bracket else { return false }
        let userTeamID = season.userTeamID
        if bracket.semifinal1.has(teamID: userTeamID), bracket.semifinal1.result == nil { return true }
        if bracket.semifinal2.has(teamID: userTeamID), bracket.semifinal2.result == nil { return true }
        if let championship = bracket.championship, championship.has(teamID: userTeamID), championship.result == nil { return true }
        return false
    }

    /// The opponent of the user's pending playoff game, if any.
    var pendingPlayoffOpponentID: UUID? {
        guard let season, season.phase == .postseason, let bracket = season.bracket else { return nil }
        let userTeamID = season.userTeamID
        let pending = [bracket.semifinal1, bracket.semifinal2, bracket.championship]
            .compactMap { $0 }
            .first { $0.has(teamID: userTeamID) && $0.result == nil }
        guard let pending else { return nil }
        return pending.teamA == userTeamID ? pending.teamB : pending.teamA
    }

    /// The user's pending playoff matchup (for seeds display).
    var pendingPlayoffMatchup: PlayoffMatchup? {
        guard let season, season.phase == .postseason, let bracket = season.bracket else { return nil }
        let userTeamID = season.userTeamID
        return [bracket.semifinal1, bracket.semifinal2, bracket.championship]
            .compactMap { $0 }
            .first { $0.has(teamID: userTeamID) && $0.result == nil }
    }

    // MARK: Season summary

    var seasonResult: SeasonResult? {
        guard let season, season.phase == .complete else { return nil }
        return SeasonResult.summary(for: season, nameFor: { name(for: $0) })
    }

    // MARK: Convenience for the Home screen

    var userRecordLine: String? {
        guard let season else { return nil }
        return season.userStanding?.recordLine
    }

    var nextOpponent: GameTeam? {
        guard let opponentID = season?.currentGame?.opponentID else { return nil }
        return OpponentTeams.team(with: opponentID)
    }
}

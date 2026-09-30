import Foundation

// MARK: - Phase

/// Where the season is in its lifecycle.
nonisolated enum SeasonPhase: String, Codable, Hashable, Sendable {
    case regularSeason
    case postseason
    case complete
}

// MARK: - Results

/// A recorded result, expressed with the game's own rules: quarters solved,
/// never simulated football points. The winner solved 3–4 quarters; the loser
/// 0–1, or 2 when the game went to overtime (3–2 OT).
nonisolated enum GameOutcome: String, Codable, Hashable, Sendable {
    case win
    case loss
    case winOT
    case lossOT

    var isWin: Bool { self == .win || self == .winOT }
    var wentToOT: Bool { self == .winOT || self == .lossOT }
}

/// One finished game between two teams, stored from a neutral viewpoint.
nonisolated struct GameResult: Codable, Hashable, Sendable {
    let winnerID: UUID
    let loserID: UUID
    /// Quarters solved by the winner: 3 or 4.
    let winnerScore: Int
    /// Quarters solved by the loser: 0, 1, or 2 (2 = went to overtime).
    let loserScore: Int
    let wentToOT: Bool

    var scoreLine: String {
        wentToOT ? "\(winnerScore)–\(loserScore) OT" : "\(winnerScore)–\(loserScore)"
    }

    /// How this result reads from one team's point of view.
    func outcome(for teamID: UUID) -> GameOutcome {
        let isWin = teamID == winnerID
        switch (isWin, wentToOT) {
        case (true, false): return GameOutcome.win
        case (true, true): return GameOutcome.winOT
        case (false, false): return GameOutcome.loss
        case (false, true): return GameOutcome.lossOT
        }
    }

    /// Builds a result from one team's perspective (used for player matches).
    static func fromPerspective(
        teamID: UUID,
        opponentID: UUID,
        isWin: Bool,
        teamScore: Int,
        opponentScore: Int,
        wentToOT: Bool
    ) -> GameResult {
        GameResult(
            winnerID: isWin ? teamID : opponentID,
            loserID: isWin ? opponentID : teamID,
            winnerScore: isWin ? teamScore : opponentScore,
            loserScore: isWin ? opponentScore : teamScore,
            wentToOT: wentToOT
        )
    }
}

// MARK: - Schedule

/// One of the player's 10 scheduled regular-season games.
nonisolated struct ScheduledGame: Codable, Hashable, Sendable, Identifiable {
    let id: String
    /// 1...10.
    let week: Int
    /// Fictional season date (Saturday evening slot).
    let date: Date
    let opponentID: UUID
    let isHome: Bool
    var result: GameResult?

    var isPlayed: Bool { result != nil }
}

// MARK: - Standings

/// One team's running record. Overtime games count separately so match
/// history can surface OT results while the primary display stays "W–L".
nonisolated struct LeagueStanding: Codable, Hashable, Sendable, Identifiable {
    var id: String { teamID.uuidString }
    let teamID: UUID
    var wins = 0
    var losses = 0
    var otWins = 0
    var otLosses = 0

    var totalWins: Int { wins + otWins }
    var totalLosses: Int { losses + otLosses }
    var gamesPlayed: Int { totalWins + totalLosses }
    var recordLine: String { "\(totalWins)–\(totalLosses)" }

    /// Applies a result to the matching team side.
    mutating func apply(_ outcome: GameOutcome) {
        switch outcome {
        case .win: wins += 1
        case .loss: losses += 1
        case .winOT: otWins += 1
        case .lossOT: otLosses += 1
        }
    }
}

// MARK: - Playoffs

/// A single postseason game: two seeded teams and, once played, a result.
nonisolated struct PlayoffMatchup: Codable, Hashable, Sendable {
    let seedA: Int
    let teamA: UUID
    let seedB: Int
    let teamB: UUID
    var result: GameResult?

    func has(teamID: UUID) -> Bool { teamA == teamID || teamB == teamID }

    var winnerID: UUID? { result?.winnerID }
    var loserID: UUID? { result?.loserID }

    /// The seed a given team entered with.
    func seed(for teamID: UUID) -> Int? {
        teamA == teamID ? seedA : (teamB == teamID ? seedB : nil)
    }
}

/// The 4-team postseason: #1 vs #4 and #2 vs #3, winners to the championship.
nonisolated struct PlayoffBracket: Codable, Hashable, Sendable {
    var semifinal1: PlayoffMatchup
    var semifinal2: PlayoffMatchup
    /// Filled in once both semifinals have results.
    var championship: PlayoffMatchup?
    var championID: UUID?

    var isComplete: Bool { championID != nil }
}

// MARK: - Season

/// The full persisted season state: schedule, records and postseason.
/// All mutations go through `SeasonManager` so persistence stays consistent.
nonisolated struct Season: Codable, Hashable, Sendable {
    let seasonNumber: Int
    let userTeamID: UUID
    var phase: SeasonPhase = .regularSeason
    var games: [ScheduledGame]
    var standings: [LeagueStanding]
    var bracket: PlayoffBracket?
    /// Case-file ids for the 40 regulation quarters (weeks 1–10 × Q1–Q4),
    /// persisted so a reopening season never reshuffles already-scheduled
    /// content. nil on saves from before the case library existed.
    var scheduledCaseIDs: [String]?
    /// Overtime case ids already consumed this season.
    var usedOvertimeCaseIDs: [String]?

    // MARK: Queries

    /// The next unplayed regular-season game — the only playable one.
    var currentGame: ScheduledGame? { games.first { !$0.isPlayed } }

    var currentWeek: Int? { currentGame?.week }

    /// The schedule actually exists as the expected 10-game slate. An empty
    /// or corrupted schedule must NEVER evaluate as a finished season.
    var hasValidSchedule: Bool { games.count == 10 }

    /// Regular season is only complete with a valid 10-game schedule where
    /// every game has a result.
    var isRegularSeasonComplete: Bool {
        hasValidSchedule && games.allSatisfy(\.isPlayed)
    }

    func standing(for teamID: UUID) -> LeagueStanding? {
        standings.first { $0.teamID == teamID }
    }

    var userStanding: LeagueStanding? { standing(for: userTeamID) }

    /// Standings sorted by the league rules: wins first, then win rate,
    /// then OT wins, then alphabetical (names supplied by the caller).
    func sortedStandings(nameFor: (UUID) -> String) -> [LeagueStanding] {
        standings.sorted { a, b in
            if a.totalWins != b.totalWins { return a.totalWins > b.totalWins }
            let pctA = a.gamesPlayed == 0 ? 0 : Double(a.totalWins) / Double(a.gamesPlayed)
            let pctB = b.gamesPlayed == 0 ? 0 : Double(b.totalWins) / Double(b.gamesPlayed)
            if pctA != pctB { return pctA > pctB }
            if a.otWins != b.otWins { return a.otWins > b.otWins }
            return nameFor(a.teamID).localizedStandardCompare(nameFor(b.teamID)) == .orderedAscending
        }
    }

    /// Position (1-based) of a team within the given ranked list.
    static func position(of teamID: UUID, in ranked: [LeagueStanding]) -> Int? {
        ranked.firstIndex { $0.teamID == teamID }.map { $0 + 1 }
    }

    // MARK: Mutations

    /// Applies a finished game to both teams' records.
    mutating func applyResult(_ result: GameResult) {
        guard var winnerStanding = standing(for: result.winnerID),
              var loserStanding = standing(for: result.loserID) else { return }
        winnerStanding.apply(result.outcome(for: result.winnerID))
        loserStanding.apply(result.outcome(for: result.loserID))
        if let index = standings.firstIndex(where: { $0.teamID == result.winnerID }) {
            standings[index] = winnerStanding
        }
        if let index = standings.firstIndex(where: { $0.teamID == result.loserID }) {
            standings[index] = loserStanding
        }
    }
}

// MARK: - Season summary

/// End-of-season recap built from the finished season. No player statistics yet.
nonisolated struct SeasonResult: Hashable, Sendable {
    let seasonNumber: Int
    let finalRecord: String
    let finalStanding: Int
    let totalTeams: Int
    let qualifiedForPlayoffs: Bool
    let semifinalOutcome: GameOutcome?
    let reachedChampionship: Bool
    let championshipOutcome: GameOutcome?
    let wonChampionship: Bool
    let championID: UUID?

    static func summary(for season: Season, nameFor: (UUID) -> String) -> SeasonResult {
        let ranked = season.sortedStandings(nameFor: nameFor)
        let standing = Season.position(of: season.userTeamID, in: ranked) ?? ranked.count
        let record = season.userStanding?.recordLine ?? "0–0"

        var semifinalOutcome: GameOutcome?
        var reachedChampionship = false
        var championshipOutcome: GameOutcome?
        var wonChampionship = false
        let qualified = season.bracket?.semifinal1.has(teamID: season.userTeamID) == true
            || season.bracket?.semifinal2.has(teamID: season.userTeamID) == true

        if let bracket = season.bracket, qualified {
            let userSemi = [bracket.semifinal1, bracket.semifinal2].first { $0.has(teamID: season.userTeamID) }
            if let result = userSemi?.result {
                semifinalOutcome = result.outcome(for: season.userTeamID)
                if semifinalOutcome?.isWin == true {
                    reachedChampionship = true
                    if let champResult = bracket.championship?.result {
                        championshipOutcome = champResult.outcome(for: season.userTeamID)
                        wonChampionship = championshipOutcome?.isWin == true
                    }
                }
            }
        }

        return SeasonResult(
            seasonNumber: season.seasonNumber,
            finalRecord: record,
            finalStanding: standing,
            totalTeams: ranked.count,
            qualifiedForPlayoffs: qualified,
            semifinalOutcome: semifinalOutcome,
            reachedChampionship: reachedChampionship,
            championshipOutcome: championshipOutcome,
            wonChampionship: wonChampionship,
            championID: season.bracket?.championID
        )
    }
}

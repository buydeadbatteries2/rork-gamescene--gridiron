import Foundation

// MARK: - Franchise records

/// One franchise record: the best single-season value of a tracked stat,
/// who set it and when. Records persist across seasons — they only ever grow.
nonisolated struct FranchiseRecord: Codable, Hashable, Sendable {
    let value: Int
    let holderName: String
    let holderPosition: FootballPosition
    let seasonNumber: Int
}

/// The franchise record book.
nonisolated struct FranchiseRecords: Codable, Hashable, Sendable {
    private(set) var entries: [String: FranchiseRecord] = [:]

    init() {}

    func record(for stat: PlayerStat) -> FranchiseRecord? {
        entries[stat.rawValue]
    }

    /// Considers one player's current-season stats against the record book.
    /// A strictly greater value replaces the record with its new holder.
    mutating func consider(player: FranchisePlayer, seasonNumber: Int) {
        for stat in PlayerStat.recordCategories {
            let value = player.seasonStats.value(for: stat)
            guard value > 0 else { continue }
            if let current = entries[stat.rawValue], value <= current.value { continue }
            entries[stat.rawValue] = FranchiseRecord(
                value: value,
                holderName: player.displayName,
                holderPosition: player.position,
                seasonNumber: seasonNumber
            )
        }
    }
}

// MARK: - Franchise history

/// Light dynasty history: the franchise's cumulative footprint. Incremental
/// counters only — no elaborate dynasty management.
nonisolated struct FranchiseHistory: Codable, Hashable, Sendable {
    private(set) var seasonsPlayed = 0
    private(set) var wins = 0
    private(set) var losses = 0
    private(set) var playoffAppearances = 0
    private(set) var championshipAppearances = 0
    private(set) var championshipsWon = 0

    init() {}

    var recordLine: String { "\(wins)–\(losses)" }

    mutating func recordGame(isWin: Bool) {
        if isWin { wins += 1 } else { losses += 1 }
    }

    /// The user's semifinal appearance marks a playoff berth; winning it adds
    /// a championship appearance; winning the final adds a title.
    mutating func recordPlayoff(stage: FranchiseGameStage, isWin: Bool) {
        switch stage {
        case .regularSeason:
            break
        case .semifinal:
            playoffAppearances += 1
            if isWin { championshipAppearances += 1 }
        case .championship:
            if isWin { championshipsWon += 1 }
        }
    }

    mutating func completeSeason() {
        seasonsPlayed += 1
    }
}

// MARK: - Game stage

/// Which kind of game is being recorded — drives the history counters.
nonisolated enum FranchiseGameStage: String, Codable, Hashable, Sendable {
    case regularSeason
    case semifinal
    case championship
}

// MARK: - Franchise root

/// The persisted franchise: the 12-player roster plus records and history.
/// Everything lives in one Codable blob under a single UserDefaults key.
nonisolated struct Franchise: Codable, Hashable, Sendable {
    /// The `GameTeam.id` this roster belongs to.
    let teamID: UUID
    private(set) var players: [FranchisePlayer]
    private(set) var records: FranchiseRecords
    private(set) var history: FranchiseHistory

    init(teamID: UUID, players: [FranchisePlayer]) {
        self.teamID = teamID
        self.players = players
        self.records = FranchiseRecords()
        self.history = FranchiseHistory()
    }

    var allPlayers: [FranchisePlayer] { players }

    func player(withID id: UUID) -> FranchisePlayer? {
        players.player(withID: id)
    }

    func players(on side: TeamSide) -> [FranchisePlayer] {
        players.players(on: side)
    }

    /// The season-leader for one stat, if anyone holds a value.
    func leader(for stat: PlayerStat) -> FranchisePlayer? {
        players
            .filter { $0.seasonStats.value(for: stat) > 0 }
            .max { $0.seasonStats.value(for: stat) < $1.seasonStats.value(for: stat) }
    }

    mutating func applyEvents(_ events: [PlayerStatEvent]) {
        for event in events {
            guard let index = players.firstIndex(where: { $0.id == event.franchisePlayerID }) else { continue }
            players[index].apply(event)
        }
    }

    /// Files one finished game for every player who appeared: increments
    /// games played and appends that player's personal log entry.
    mutating func fileGameLogs(
        seasonNumber: Int,
        weekLabel: String,
        opponentName: String,
        isPlayoff: Bool,
        teamWon: Bool,
        playerOfTheGameID: UUID?,
        events: [PlayerStatEvent],
        appearedIDs: Set<UUID>
    ) {
        var linesByPlayer: [UUID: PlayerStatLine] = [:]
        for event in events {
            linesByPlayer[event.franchisePlayerID, default: PlayerStatLine()].add(event.stat, event.count)
        }

        for id in appearedIDs {
            guard let index = players.firstIndex(where: { $0.id == id }) else { continue }
            let log = PlayerGameLog(
                seasonNumber: seasonNumber,
                weekLabel: weekLabel,
                opponentName: opponentName,
                isPlayoff: isPlayoff,
                teamWon: teamWon,
                wasPlayerOfGame: id == playerOfTheGameID,
                stats: linesByPlayer[id] ?? PlayerStatLine()
            )
            players[index].recordGame(log)
        }
    }

    mutating func awardPlayerOfTheGame(_ playerID: UUID) {
        guard let index = players.firstIndex(where: { $0.id == playerID }) else { return }
        players[index].awardPlayerOfTheGame()
    }

    mutating func updateHistory(stage: FranchiseGameStage, isWin: Bool) {
        history.recordGame(isWin: isWin)
        history.recordPlayoff(stage: stage, isWin: isWin)
    }

    mutating func updateRecords(seasonNumber: Int) {
        for player in players {
            records.consider(player: player, seasonNumber: seasonNumber)
        }
    }

    mutating func completeSeason() {
        history.completeSeason()
        for index in players.indices {
            players[index].rollSeasonIntoCareer()
        }
    }
}

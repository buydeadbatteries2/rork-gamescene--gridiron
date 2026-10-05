import Foundation

// MARK: - Roster slots

/// The 12 permanent franchise slots: 6 offense + 6 defense. A slot pins a
/// player to a roster position label (DE vs DT, WR vs WR) while sharing the
/// underlying `FootballPosition` with the puzzle engine.
nonisolated enum RosterSlot: String, Codable, Hashable, Sendable, CaseIterable {
    case qb, rb, wr1, wr2, te, ol
    case de, dt, lb, cb, fs, ss

    var position: FootballPosition {
        switch self {
        case .qb: .qb
        case .rb: .rb
        case .wr1, .wr2: .wr
        case .te: .te
        case .ol: .ol
        case .de, .dt: .dl
        case .lb: .lb
        case .cb: .cb
        case .fs: .fs
        case .ss: .ss
        }
    }

    var side: TeamSide { position.side }

    /// Roster card label ("WR", "DE", "DT", …).
    var label: String {
        switch self {
        case .qb: "QB"
        case .rb: "RB"
        case .wr1, .wr2: "WR"
        case .te: "TE"
        case .ol: "OL"
        case .de: "DE"
        case .dt: "DT"
        case .lb: "LB"
        case .cb: "CB"
        case .fs: "FS"
        case .ss: "SS"
        }
    }

    static var offenseOrder: [RosterSlot] = [.qb, .rb, .wr1, .wr2, .te, .ol]
    static var defenseOrder: [RosterSlot] = [.de, .dt, .lb, .cb, .fs, .ss]
}

// MARK: - Franchise player

/// A permanent member of the user's 12-player franchise roster. Identities
/// persist across the whole season (and across seasons); Fast/Power/Veteran is
/// deliberately NOT stored here — profiles are per-case puzzle answers, never
/// fixed player attributes.
nonisolated struct FranchisePlayer: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let slot: RosterSlot
    let firstName: String
    let lastName: String
    /// Bundled imageset from the controlled 20-body art library.
    let bodyAssetID: String
    private(set) var seasonStats: PlayerStatLine
    private(set) var careerStats: PlayerStatLine
    private(set) var gameLogs: [PlayerGameLog]

    init(id: UUID = UUID(), slot: RosterSlot, firstName: String, lastName: String, bodyAssetID: String) {
        self.id = id
        self.slot = slot
        self.firstName = firstName
        self.lastName = lastName
        self.bodyAssetID = bodyAssetID
        self.seasonStats = PlayerStatLine()
        self.careerStats = PlayerStatLine()
        self.gameLogs = []
    }

    var position: FootballPosition { slot.position }
    var sideOfBall: TeamSide { slot.side }

    /// Full fictional name, e.g. "Marcus Reed".
    var fullName: String { "\(firstName) \(lastName)" }

    /// Roster-style display name: first initial + last name, e.g. "M. Reed".
    var displayName: String { "\(firstName.prefix(1)). \(lastName)" }

    var gamesPlayedThisSeason: Int { seasonStats.value(for: .gamesPlayed) }

    /// Applies one positive stat award to this player's current season.
    mutating func apply(_ event: PlayerStatEvent) {
        seasonStats.add(event.stat, event.count)
    }

    /// Marks a completed game: increments games played and files the log.
    mutating func recordGame(_ log: PlayerGameLog) {
        seasonStats.add(.gamesPlayed)
        gameLogs.append(log)
        if gameLogs.count > 40 {
            gameLogs.removeFirst(gameLogs.count - 40)
        }
    }

    /// Flags this player as the game's Player of the Game.
    mutating func awardPlayerOfTheGame() {
        seasonStats.add(.playerOfTheGame)
    }

    /// End-of-season roll: season totals fold into career totals, the season
    /// resets, the same player stays with the franchise.
    mutating func rollSeasonIntoCareer() {
        careerStats.merge(seasonStats)
        seasonStats = PlayerStatLine()
    }
}

// MARK: - Player index helpers

extension Array where Element == FranchisePlayer {
    nonisolated func player(withID id: UUID) -> FranchisePlayer? { first { $0.id == id } }
    nonisolated func players(on side: TeamSide) -> [FranchisePlayer] { filter { $0.sideOfBall == side } }
}

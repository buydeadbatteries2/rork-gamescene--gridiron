import Foundation
import Observation

// MARK: - Roster manager

/// Single source of truth for the persistent 12-player franchise roster, its
/// statistics, game logs, records and dynasty history. Everything persists
/// locally (UserDefaults JSON) and survives app restarts, season resets and
/// new seasons. Puzzle profiles (Fast/Power/Veteran) deliberately do NOT live
/// here — they are per-case answers, never player attributes.
@MainActor
@Observable
final class RosterManager {
    static let shared = RosterManager()

    static let storageKey = "gamescene.gridiron.franchise"

    private let defaults: UserDefaults
    private(set) var franchise: Franchise?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let loaded = Self.load(from: defaults) {
            franchise = loaded
        } else if defaults === UserDefaults.standard, let team = TeamStore.shared.userTeam {
            // Migration: franchises created before the roster existed get their
            // permanent 12 players on first launch. Never runs for injected
            // test suites.
            ensureRoster(for: team)
        }
    }

    var hasFranchise: Bool { franchise != nil }

    // MARK: Roster creation

    /// Guarantees a 12-player roster bound to `team`. Calling again for the
    /// same franchise (e.g. editing the team's look) never regenerates it.
    func ensureRoster(for team: GameTeam) {
        guard franchise?.teamID != team.id else { return }
        let players = Self.generatePlayers(teamID: team.id)
        franchise = Franchise(teamID: team.id, players: players)
        persist()
    }

    func player(withID id: UUID) -> FranchisePlayer? {
        franchise?.player(withID: id)
    }

    // MARK: Puzzle identity assignment

    /// Maps the case's missing-player keys onto real roster members. Each
    /// position draws from that position's roster queue in slot order (WR1
    /// before WR2, DE before DT); a position demanded more often than the
    /// roster carries it stays a one-off fictional player.
    func identityAssignments(forCaseID caseID: String) -> [String: RosterIdentity] {
        guard let franchise, let puzzleCase = CaseLibrary.caseByID(caseID) else { return [:] }
        return Self.identityAssignments(
            missing: puzzleCase.missing.map { (key: $0.key, position: $0.position) },
            players: franchise.allPlayers,
            caseID: caseID
        )
    }

    nonisolated static func identityAssignments(
        missing: [(key: String, position: FootballPosition)],
        players: [FranchisePlayer],
        caseID: String
    ) -> [String: RosterIdentity] {
        var queues: [FootballPosition: [FranchisePlayer]] = [:]
        for player in players {
            queues[player.position, default: []].append(player)
        }

        var assigned: [String: RosterIdentity] = [:]
        for entry in missing {
            guard var queue = queues[entry.position], let player = queue.first else { continue }
            queue.removeFirst()
            queues[entry.position] = queue
            assigned["\(caseID)-\(entry.key)"] = RosterIdentity(
                franchisePlayerID: player.id,
                fullName: player.fullName,
                shortName: player.displayName,
                position: entry.position,
                bodyAssetID: player.bodyAssetID
            )
        }
        return assigned
    }

    // MARK: Recording games

    /// Records one finished match into the franchise: stat awards, games
    /// played, per-player game logs, Player of the Game, the live record book
    /// and the dynasty history counters. No-ops without a franchise.
    func recordGame(
        stage: FranchiseGameStage,
        seasonNumber: Int,
        week: Int,
        opponentName: String,
        teamWon: Bool,
        events: [PlayerStatEvent],
        appearedIDs: Set<UUID>
    ) {
        guard var updated = franchise else { return }

        updated.applyEvents(events)

        let playerOfTheGameID = StatAwardEngine.playerOfTheGameID(from: events)
        if let playerOfTheGameID {
            updated.awardPlayerOfTheGame(playerOfTheGameID)
        }

        let weekLabel: String
        switch stage {
        case .regularSeason: weekLabel = "W\(week)"
        case .semifinal: weekLabel = "SF"
        case .championship: weekLabel = "FINAL"
        }

        updated.fileGameLogs(
            seasonNumber: seasonNumber,
            weekLabel: weekLabel,
            opponentName: opponentName,
            isPlayoff: stage != .regularSeason,
            teamWon: teamWon,
            playerOfTheGameID: playerOfTheGameID,
            events: events,
            appearedIDs: appearedIDs
        )

        updated.updateHistory(stage: stage, isWin: teamWon)
        updated.updateRecords(seasonNumber: seasonNumber)

        franchise = updated
        persist()
    }

    // MARK: Season lifecycle

    /// Called once when a new season starts: the record book gets a final
    /// pass, the finished season's totals roll into career stats, the season
    /// resets and the same 12 players stay with the franchise.
    func completeSeason(finishedSeasonNumber: Int) {
        guard var updated = franchise else { return }
        updated.updateRecords(seasonNumber: max(1, finishedSeasonNumber))
        updated.completeSeason()
        franchise = updated
        persist()
    }

    // MARK: Persistence

    private func persist() {
        guard let franchise else {
            defaults.removeObject(forKey: Self.storageKey)
            return
        }
        if let data = try? JSONEncoder().encode(franchise) {
            defaults.set(data, forKey: Self.storageKey)
        }
    }

    private static func load(from defaults: UserDefaults) -> Franchise? {
        guard let data = defaults.data(forKey: storageKey) else { return nil }
        return try? JSONDecoder().decode(Franchise.self, from: data)
    }

    // MARK: Deterministic roster generation

    private static func generatePlayers(teamID: UUID) -> [FranchisePlayer] {
        var rng = SeededGenerator(seed: SeededGenerator.hash([teamID.uuidString, "franchise-roster"]))
        var usedLastNames: Set<String> = []
        let rosterLastNames = Set(CaseRoster.pool.map { lastName(in: $0) })

        return RosterSlot.allCases.map { slot in
            let first = firstNames[Int(rng.next() % UInt64(firstNames.count))]
            var last = lastNames[Int(rng.next() % UInt64(lastNames.count))]
            // Never reuse a surname inside the roster, and never collide with
            // a one-off case-file player name in the same display.
            while usedLastNames.contains(last) || rosterLastNames.contains(last) {
                last = lastNames[(lastNames.firstIndex(of: last).map { $0 + 1 } ?? 0) % lastNames.count]
            }
            usedLastNames.insert(last)

            let bodies = bodyOptions(for: slot)
            let body = bodies[Int(rng.next() % UInt64(bodies.count))]
            return FranchisePlayer(slot: slot, firstName: first, lastName: last, bodyAssetID: body)
        }
    }

    private static func lastName(in fullName: String) -> String {
        fullName.split(separator: " ").last.map(String.init) ?? fullName
    }

    private static let firstNames: [String] = [
        "Marcus", "Devon", "Terrell", "Jalen", "Cole", "Andre", "Malik", "Trent",
        "Isaiah", "Kadeem", "Bryce", "Damon", "Elias", "Rashad", "Trey", "Omar",
        "Xavier", "Darius", "Kellen", "Micah", "Amos", "Grant", "Levi", "Noah",
        "Silas", "Jonah", "Wade", "Cecil", "Otis", "Emmett", "Harvey", "Landon",
        "Nolan", "Felix", "Tyrell", "Jerome", "Curtis", "Vaughn", "Miles", "Calvin",
        "Derek", "Owen", "Jamal", "Simeon", "Roman", "Idris", "Percy", "Zachary"
    ]

    private static let lastNames: [String] = [
        "Ashcombe", "Ashby", "Bexley", "Brennan", "Calloway", "Colton", "Crowder",
        "Duffy", "Dunmore", "Eastwick", "Ellery", "Ellis", "Farrow", "Frost",
        "Girard", "Granger", "Hayes", "Hollins", "Hollister", "Jessup", "Kingsley",
        "Kincaid", "Lockhart", "Lattimore", "Mercer", "Nakamura", "Pettis",
        "Prewitt", "Quill", "Rasmussen", "Rennick", "Rourke", "Sandoval", "Suggs",
        "Tandy", "Tolbert", "Underhill", "Vance", "Vaughn", "Warrick", "Weller",
        "Yarborough", "Bellamy", "Brooks", "Drummond", "Hutchins", "Kimbrough",
        "Okafor", "Holloway", "Malone", "Draughn", "Carter", "Reed", "Franks"
    ]

    /// Position-appropriate body options from the controlled 20-asset art
    /// library — never new art, and always visored/blank/brand-free.
    private static func bodyOptions(for slot: RosterSlot) -> [String] {
        switch slot {
        case .qb: ["quarterback_player", "football_player_blank_helmet"]
        case .rb: ["football_player_running_back", "football_player_running_back_2"]
        case .wr1, .wr2: ["football_player_render", "football_player_slot_receiver", "football_player_receiver"]
        case .te: ["football_player_blank_helmet_2", "football_player_blank_gear"]
        case .ol: ["football_lineman", "football_player_tackle", "football_player_lineman"]
        case .de: ["football_player_defensive_end", "football_player_render_2"]
        case .dt: ["football_player_tackle_2", "football_player_render_2"]
        case .lb: ["football_player_linebacker", "football_player_blank_helmet_3"]
        case .cb: ["football_player_backpedal", "football_player_cornerback", "football_player_blank_gear_2"]
        case .fs: ["football_player_blank_gear_2", "football_player_backpedal"]
        case .ss: ["football_player_cornerback", "football_player_backpedal"]
        }
    }
}

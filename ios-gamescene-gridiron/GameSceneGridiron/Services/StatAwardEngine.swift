import Foundation

// MARK: - Stat leader

/// One player's aggregated box line for a finished game.
nonisolated struct StatLeader: Identifiable, Hashable, Sendable {
    let id: UUID
    let name: String
    let position: FootballPosition
    let line: PlayerStatLine
    let score: Int
    /// Portrait asset, decorated by the view-model layer from the roster.
    var bodyAssetID: String?
}

// MARK: - Stat award engine

/// Converts solved puzzle placements into positive player statistics.
/// The engine only ever sees placements from solved cases — the caller (the
/// match view model) never feeds it failed quarters, so wrong answers can
/// never produce negative stats.
nonisolated enum StatAwardEngine {

    /// Stat events for one solved quarter. Every correctly placed franchise
    /// player earns exactly the stat the case file says occurred in that
    /// scenario (`caseStats`, keyed by the case's player key). The profile a
    /// case demanded describes WHY the player fit — it never decides WHAT
    /// statistically happened, so the same player answering Fast in one case
    /// and Power in another can earn different or identical events purely per
    /// case scenario. Placements whose case has no authored event fall back to
    /// a position-neutral base stat.
    static func events(
        from placements: [PlacedPlayer],
        identities: [String: RosterIdentity],
        caseStats: [String: PlayerStat] = [:]
    ) -> [PlayerStatEvent] {
        var events: [PlayerStatEvent] = []
        for placement in placements {
            guard let identity = identities[placement.player.id] else { continue }
            let stat = caseStats[identity.playerKey] ?? baseStat(position: identity.position)
            events.append(PlayerStatEvent(
                franchisePlayerID: identity.franchisePlayerID,
                playerName: identity.shortName,
                position: identity.position,
                stat: stat
            ))
        }
        return events
    }

    /// Position base stat for a solved placement.
    private static func baseStat(position: FootballPosition) -> PlayerStat {
        switch position {
        case .qb: .successfulReads
        case .rb: .successfulRuns
        case .wr, .te: .receptions
        case .ol: .blocks
        case .dl: .tackles
        case .lb: .tackles
        case .cb, .fs, .ss: .tackles
        }
    }

    /// Aggregated, ranked leaders from one game's stat events. Ranked by
    /// weighted score, ties broken by first appearance (deterministic).
    static func leaderBoard(from events: [PlayerStatEvent]) -> [StatLeader] {
        var order: [UUID] = []
        var lines: [UUID: PlayerStatLine] = [:]
        var names: [UUID: String] = [:]
        var positions: [UUID: FootballPosition] = [:]

        for event in events {
            if lines[event.franchisePlayerID] == nil { order.append(event.franchisePlayerID) }
            lines[event.franchisePlayerID, default: PlayerStatLine()].add(event.stat, event.count)
            names[event.franchisePlayerID] = event.playerName
            positions[event.franchisePlayerID] = event.position
        }

        let leaders = order.map { id in
            StatLeader(
                id: id,
                name: names[id] ?? "",
                position: positions[id] ?? .qb,
                line: lines[id] ?? PlayerStatLine(),
                score: (lines[id] ?? PlayerStatLine()).awardScore(),
                bodyAssetID: nil
            )
        }
        return leaders.sorted { $0.score > $1.score }
    }

    /// The game's Player of the Game: the top-ranked leader, when anyone
    /// produced stats at all.
    static func playerOfTheGameID(from events: [PlayerStatEvent]) -> UUID? {
        leaderBoard(from: events).first?.id
    }
}

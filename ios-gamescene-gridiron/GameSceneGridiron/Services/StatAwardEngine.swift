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
    /// player earns a position-appropriate base stat plus one variant-shaped
    /// accomplishment: the SAME player can earn different stats depending on
    /// the profile the case demanded.
    static func events(from placements: [PlacedPlayer], identities: [String: RosterIdentity]) -> [PlayerStatEvent] {
        var events: [PlayerStatEvent] = []
        for placement in placements {
            guard let identity = identities[placement.player.id] else { continue }
            let base = PlayerStatEvent(
                franchisePlayerID: identity.franchisePlayerID,
                playerName: identity.shortName,
                position: identity.position,
                stat: baseStat(position: identity.position)
            )
            events.append(base)
            if let bonus = variantStat(position: identity.position, variant: placement.variant) {
                events.append(PlayerStatEvent(
                    franchisePlayerID: identity.franchisePlayerID,
                    playerName: identity.shortName,
                    position: identity.position,
                    stat: bonus
                ))
            }
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

    /// Profile-shaped bonus stat: the football situation decides the stat, not
    /// the player — so no roster member is locked into one kind of production.
    private static func variantStat(position: FootballPosition, variant: PlayerVariant) -> PlayerStat? {
        switch position {
        case .qb:
            switch variant {
            case .fast: .scrambleOpportunities
            case .power, .veteran: .drivesSecured
            }
        case .rb:
            switch variant {
            case .fast: .successfulRuns
            case .power: .brokenTackles
            case .veteran: .keyBlocks
            }
        case .wr, .te:
            switch variant {
            case .fast: .bigPlays
            case .power: .receptions
            case .veteran: .successfulAssignments
            }
        case .ol:
            switch variant {
            case .fast: .protectionWins
            case .power: .blocks
            case .veteran: .protectionWins
            }
        case .dl:
            switch variant {
            case .fast: .sacks
            case .power: .stops
            case .veteran: .pressures
            }
        case .lb:
            switch variant {
            case .fast: .sacks
            case .power: .stops
            case .veteran: .coverageWins
            }
        case .cb, .fs, .ss:
            switch variant {
            case .fast: .passBreakups
            case .power: .coverageWins
            case .veteran: .interceptions
            }
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

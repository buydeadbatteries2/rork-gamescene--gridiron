import Foundation

/// The permanent, controlled player-art library: exactly 20 premium realistic
/// football bodies. Every athlete is fully geared — blank helmet, opaque dark
/// visor, blank jersey, no numbers, no logos, no brands, no visible skin or
/// face. All 20 were generated once against this contract and must not be
/// regenerated per team or per player: identity comes from position, name,
/// team colors and the Fast/Power/Veteran profile, never from new artwork.
nonisolated enum PlayerBodyCatalog {
    /// Visual archetype of a body — used to match the Fast/Power/Veteran
    /// gameplay profiles without generating new art.
    nonisolated enum BodyArchetype: String, Hashable, Sendable {
        case fast
        case power
        case veteran
    }

    nonisolated struct PlayerBody: Identifiable, Hashable, Sendable {
        /// Bundled asset name (`UIImage(named:)` / SwiftUI `Image`).
        let id: String
        let position: FootballPosition
        let archetype: BodyArchetype
        let summary: String
    }

    // 2 QB · 2 RB · 3 WR · 2 TE · 3 OL · 3 DL · 2 LB · 3 DB — exactly 20.
    static let all: [PlayerBody] = [
        PlayerBody(id: "quarterback_player", position: .qb, archetype: .veteran, summary: "Tall composed drop-back passer"),
        PlayerBody(id: "football_player_blank_helmet", position: .qb, archetype: .fast, summary: "Athletic dual-threat passer"),
        PlayerBody(id: "football_player_running_back", position: .rb, archetype: .power, summary: "Compact powerful runner"),
        PlayerBody(id: "football_player_running_back_2", position: .rb, archetype: .fast, summary: "Lean shifty change-of-pace back"),
        PlayerBody(id: "football_player_render", position: .wr, archetype: .fast, summary: "Tall lean field-stretcher"),
        PlayerBody(id: "football_player_slot_receiver", position: .wr, archetype: .fast, summary: "Small quick slot target"),
        PlayerBody(id: "football_player_receiver", position: .wr, archetype: .power, summary: "Big physical possession receiver"),
        PlayerBody(id: "football_player_blank_helmet_2", position: .te, archetype: .power, summary: "Heavy run-blocking tight end"),
        PlayerBody(id: "football_player_blank_gear", position: .te, archetype: .veteran, summary: "Athletic hybrid tight end"),
        PlayerBody(id: "football_lineman", position: .ol, archetype: .power, summary: "Massive anchor guard"),
        PlayerBody(id: "football_player_tackle", position: .ol, archetype: .power, summary: "Tall long-armed tackle"),
        PlayerBody(id: "football_player_lineman", position: .ol, archetype: .power, summary: "Broad stocky interior lineman"),
        PlayerBody(id: "football_player_tackle_2", position: .dl, archetype: .power, summary: "Huge interior bull rusher"),
        PlayerBody(id: "football_player_render_2", position: .dl, archetype: .power, summary: "Tall strong edge setter"),
        PlayerBody(id: "football_player_defensive_end", position: .dl, archetype: .fast, summary: "Explosive athletic end"),
        PlayerBody(id: "football_player_linebacker", position: .lb, archetype: .power, summary: "Thick inside tank"),
        PlayerBody(id: "football_player_blank_helmet_3", position: .lb, archetype: .fast, summary: "Fast pursuit linebacker"),
        PlayerBody(id: "football_player_backpedal", position: .cb, archetype: .fast, summary: "Tall lanky cover corner"),
        PlayerBody(id: "football_player_cornerback", position: .cb, archetype: .power, summary: "Compact physical press corner"),
        PlayerBody(id: "football_player_blank_gear_2", position: .cb, archetype: .veteran, summary: "Rangy deep-zone safety body")
    ]

    private static let byID: [String: PlayerBody] = {
        Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
    }()

    /// The asset pool for a position, ordered best-first. Safeties and corners
    /// share the defensive-back bodies.
    private static func pool(for position: FootballPosition) -> [PlayerBody] {
        switch position {
        case .qb: all.filter { $0.position == .qb }
        case .rb: all.filter { $0.position == .rb }
        case .wr: all.filter { $0.position == .wr }
        case .te: all.filter { $0.position == .te }
        case .ol: all.filter { $0.position == .ol }
        case .dl: all.filter { $0.position == .dl }
        case .lb: all.filter { $0.position == .lb }
        case .cb, .ss, .fs: all.filter { $0.position == .cb }
        }
    }

    /// Position-appropriate body asset, biased toward the player's profile:
    /// FAST → lean/agile bodies, POWER → broad/heavy bodies, VETERAN → the
    /// composed balanced body of that position group.
    static func bodyAsset(for position: FootballPosition, variant: PlayerVariant? = nil) -> String {
        let candidates = pool(for: position)
        guard let first = candidates.first else { return "football_player_render" }
        guard let variant else { return first.id }
        let archetype: BodyArchetype = switch variant {
        case .fast: .fast
        case .power: .power
        case .veteran: .veteran
        }
        return candidates.first { $0.archetype == archetype }?.id ?? first.id
    }

    /// True when the asset belongs to the controlled library.
    static func contains(_ assetName: String) -> Bool {
        byID[assetName] != nil
    }
}

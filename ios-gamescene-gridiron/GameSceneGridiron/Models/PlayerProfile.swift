import Foundation

// MARK: - Player profiles
//
// A player profile describes HOW a missing player is deployed in one specific
// case: the situation, not the person. Profiles are clue-language concepts —
// "the developing back", "the seasoned head", "recovery speed", "holds the
// point", "keeps biting on the first move" — and are fully separate from the
// GAME difficulty (`DifficultyLevel.rookie` is a game mode;
// `PlayerProfile.rookie` is a deployment choice inside a puzzle).
//
// `PlayerVariant` (fast / power / veteran) is the legacy internal spelling
// kept for any persisted or bridged data; profiles are the runtime truth.

nonisolated enum PlayerProfile: String, Codable, CaseIterable, Hashable, Identifiable, Sendable {
    case rookie
    case veteran
    case fast
    case powerful
    case overrated

    var id: String { rawValue }

    /// Legacy internal variant this profile maps onto, when one exists.
    /// `powerful` bridges to the legacy `power` spelling so older case data
    /// and any persisted blobs keep working untouched.
    var legacyVariant: PlayerVariant? {
        switch self {
        case .fast: .fast
        case .veteran: .veteran
        case .powerful: .power
        case .rookie, .overrated: nil
        }
    }

    /// Bridge from legacy case/persisted data.
    init(legacy: PlayerVariant) {
        self = switch legacy {
        case .fast: .fast
        case .power: .powerful
        case .veteran: .veteran
        }
    }

    var title: String {
        switch self {
        case .rookie: "Rookie"
        case .veteran: "Veteran"
        case .fast: "Fast"
        case .powerful: "Powerful"
        case .overrated: "Overrated"
        }
    }

    var symbol: String {
        switch self {
        case .rookie: "leaf.fill"
        case .veteran: "star.fill"
        case .fast: "bolt.fill"
        case .powerful: "dumbbell.fill"
        case .overrated: "star.slash.fill"
        }
    }

    var summary: String {
        switch self {
        case .rookie: "Young and still developing"
        case .veteran: "Experience and awareness"
        case .fast: "Speed and quickness"
        case .powerful: "Strength and physicality"
        case .overrated: "Reputation over execution"
        }
    }

    /// The body archetype used for card/field body selection.
    var bodyArchetype: PlayerBodyCatalog.BodyArchetype {
        switch self {
        case .fast: .fast
        case .powerful: .power
        case .rookie, .veteran, .overrated: .veteran
        }
    }

    // MARK: Profile pools by GAME difficulty

    /// Which profiles a player may pick from at the selected game difficulty.
    /// Rookie simplifies profile reasoning (Rookie/Veteran only), Pro adds the
    /// physical archetypes, and All-Pro / Hall of Famer open the full pool —
    /// Overrated included.
    static func pool(for difficulty: DifficultyLevel) -> [PlayerProfile] {
        switch difficulty {
        case .rookie: [.rookie, .veteran]
        case .pro: [.rookie, .veteran, .fast, .powerful]
        case .allPro, .hallOfFamer: PlayerProfile.allCases
        }
    }
}

// MARK: - Case adaptation mapping
//
// When a case authored for the full legacy pool is played at a difficulty
// whose pool is smaller, every profile requirement is remapped onto the
// available pool and every profile clue is re-verified with the solver —
// the answer option is never simply hidden while the old logic stays.

nonisolated enum ProfilePoolAdapter {
    /// Maps a legacy profile onto the pool. Identity whenever possible; at
    /// the two-profile Rookie pool, speed scenarios map to Rookie and power
    /// scenarios to Veteran.
    static func remap(_ profile: PlayerProfile, into pool: [PlayerProfile]) -> PlayerProfile {
        if pool.contains(profile) { return profile }
        switch profile {
        case .fast, .overrated: return pool.contains(.rookie) ? .rookie : (pool.first ?? .veteran)
        case .powerful: return pool.contains(.veteran) ? .veteran : (pool.first ?? .rookie)
        default: return pool.contains(.veteran) ? .veteran : (pool.first ?? .rookie)
        }
    }

    /// The opposite member of a two-profile pool (Rookie ↔ Veteran).
    static func other(in pool: [PlayerProfile], of profile: PlayerProfile) -> PlayerProfile {
        pool.first { $0 != profile } ?? profile
    }
}

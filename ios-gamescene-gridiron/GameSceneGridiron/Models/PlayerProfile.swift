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
    case underrated
    case elusive
    case reliable
    case technical

    var id: String { rawValue }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        if value == "power" { self = .powerful; return }
        guard let profile = Self(rawValue: value) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unknown player profile")
        }
        self = profile
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    /// Legacy internal variant this profile maps onto, when one exists.
    /// `powerful` bridges to the legacy `power` spelling so older case data
    /// and any persisted blobs keep working untouched.
    var legacyVariant: PlayerVariant? {
        switch self {
        case .fast: .fast
        case .veteran: .veteran
        case .powerful: .power
        case .rookie, .overrated, .underrated, .elusive, .reliable, .technical: nil
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
        case .underrated: "Underrated"
        case .elusive: "Elusive"
        case .reliable: "Reliable"
        case .technical: "Technical"
        }
    }

    var symbol: String {
        switch self {
        case .rookie: "leaf.fill"
        case .veteran: "star.fill"
        case .fast: "bolt.fill"
        case .powerful: "dumbbell.fill"
        case .overrated: "star.slash.fill"
        case .underrated: "sparkle.magnifyingglass"
        case .elusive: "arrow.triangle.branch"
        case .reliable: "checkmark.shield.fill"
        case .technical: "scope"
        }
    }

    var summary: String {
        switch self {
        case .rookie: "Young and still developing"
        case .veteran: "Experience and awareness"
        case .fast: "Speed and quickness"
        case .powerful: "Strength and physicality"
        case .overrated: "Reputation over execution"
        case .underrated: "Overlooked production beyond the reputation"
        case .elusive: "Changes direction and makes defenders miss"
        case .reliable: "Dependable execution, snap after snap"
        case .technical: "Precise footwork, hands and mechanics"
        }
    }

    /// The body archetype used for card/field body selection.
    var bodyArchetype: PlayerBodyCatalog.BodyArchetype {
        switch self {
        case .fast, .elusive: .fast
        case .powerful: .power
        case .rookie, .veteran, .overrated, .underrated, .reliable, .technical: .veteran
        }
    }

    // MARK: Profile pools by GAME difficulty

    /// Historical answer-adaptation contract, NOT the visible card options.
    /// Keep these shipped mappings for saved investigations and Ranked variant
    /// parity. Cards independently draw four choices from all nine profiles.
    /// Newly authored profiles pass through the adapter without remapping.
    static func pool(for difficulty: DifficultyLevel) -> [PlayerProfile] {
        switch difficulty {
        case .rookie: [.rookie, .veteran]
        case .pro: [.rookie, .veteran, .fast, .powerful]
        case .allPro, .hallOfFamer: [.rookie, .veteran, .fast, .powerful, .overrated]
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
        if pool.contains(profile) || [.underrated, .elusive, .reliable, .technical].contains(profile) { return profile }
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

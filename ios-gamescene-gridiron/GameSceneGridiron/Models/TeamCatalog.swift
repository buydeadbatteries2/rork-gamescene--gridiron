import Foundation

/// One selectable fictional logo in the team builder. Rendered as vector art by
/// `TeamLogoGlyph` — nothing here is an external brand.
nonisolated struct TeamLogoOption: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
}

/// One predefined uniform color.
nonisolated struct TeamColorOption: Identifiable, Hashable, Sendable {
    let name: String
    let hex: UInt32
    var id: String { name }
}

// MARK: - States

/// All 50 U.S. states with postal abbreviations, used to prefix team names.
nonisolated enum StateCatalog {
    static let states: [(name: String, abbreviation: String)] = [
        ("Alabama", "AL"), ("Alaska", "AK"), ("Arizona", "AZ"), ("Arkansas", "AR"),
        ("California", "CA"), ("Colorado", "CO"), ("Connecticut", "CT"), ("Delaware", "DE"),
        ("Florida", "FL"), ("Georgia", "GA"), ("Hawaii", "HI"), ("Idaho", "ID"),
        ("Illinois", "IL"), ("Indiana", "IN"), ("Iowa", "IA"), ("Kansas", "KS"),
        ("Kentucky", "KY"), ("Louisiana", "LA"), ("Maine", "ME"), ("Maryland", "MD"),
        ("Massachusetts", "MA"), ("Michigan", "MI"), ("Minnesota", "MN"), ("Mississippi", "MS"),
        ("Missouri", "MO"), ("Montana", "MT"), ("Nebraska", "NE"), ("Nevada", "NV"),
        ("New Hampshire", "NH"), ("New Jersey", "NJ"), ("New Mexico", "NM"), ("New York", "NY"),
        ("North Carolina", "NC"), ("North Dakota", "ND"), ("Ohio", "OH"), ("Oklahoma", "OK"),
        ("Oregon", "OR"), ("Pennsylvania", "PA"), ("Rhode Island", "RI"), ("South Carolina", "SC"),
        ("South Dakota", "SD"), ("Tennessee", "TN"), ("Texas", "TX"), ("Utah", "UT"),
        ("Vermont", "VT"), ("Virginia", "VA"), ("Washington", "WA"), ("West Virginia", "WV"),
        ("Wisconsin", "WI"), ("Wyoming", "WY")
    ]

    static var stateNames: [String] { states.map(\.name) }

    static func abbreviation(for state: String) -> String? {
        states.first { $0.name == state }?.abbreviation
    }
}

// MARK: - Team names

/// 50 original, generic team names. Deliberately avoids every existing
/// professional franchise name and close imitations of them.
nonisolated enum TeamNameCatalog {
    static let names: [String] = [
        "Cyber Wolves", "Scorpions", "Outlaws", "Phantoms", "Sentinels",
        "Thunder", "Vipers", "Night Hawks", "Renegades", "Blaze",
        "Stampede", "Cobras", "Warhorses", "Frost Kings", "Marshals",
        "Comets", "Bandits", "Talons", "Steel Boars", "Sea Serpents",
        "Hammerheads", "Mammoths", "Bulls", "Stallions", "Gladiators",
        "Rogues", "Lone Wolves", "Banshees", "Griffins", "Behemoths",
        "Cyclones", "Inferno", "Blizzard", "Hellcats", "Reapers",
        "Locomotives", "Privateers", "Marauders", "Sovereigns", "Leviathans",
        "Firebirds", "Eclipse", "Pulsars", "Vanguards", "Wardens",
        "Jackals", "Wildcats", "Bobcats", "Vultures", "Rattlers"
    ]
}

// MARK: - Logos

/// 50 original vector emblem choices: animals, creatures, technology, weather,
/// machines and abstract sports marks. All fictional and generic.
nonisolated enum LogoCatalog {
    static let logos: [TeamLogoOption] = [
        TeamLogoOption(id: "wolf", name: "Wolf"),
        TeamLogoOption(id: "hawk", name: "Hawk"),
        TeamLogoOption(id: "shark", name: "Shark"),
        TeamLogoOption(id: "serpent", name: "Serpent"),
        TeamLogoOption(id: "scorpion", name: "Scorpion"),
        TeamLogoOption(id: "bull", name: "Bull"),
        TeamLogoOption(id: "panther", name: "Panther"),
        TeamLogoOption(id: "bear", name: "Bear"),
        TeamLogoOption(id: "raven", name: "Raven"),
        TeamLogoOption(id: "lion", name: "Lion"),
        TeamLogoOption(id: "ram", name: "Ram"),
        TeamLogoOption(id: "boar", name: "Boar"),
        TeamLogoOption(id: "hound", name: "Hound"),
        TeamLogoOption(id: "owl", name: "Owl"),
        TeamLogoOption(id: "fox", name: "Fox"),
        TeamLogoOption(id: "stag", name: "Stag"),
        TeamLogoOption(id: "cobra", name: "Cobra"),
        TeamLogoOption(id: "stallion", name: "Stallion"),
        TeamLogoOption(id: "vulture", name: "Vulture"),
        TeamLogoOption(id: "jackal", name: "Jackal"),
        TeamLogoOption(id: "dragon", name: "Dragon"),
        TeamLogoOption(id: "griffin", name: "Griffin"),
        TeamLogoOption(id: "kraken", name: "Kraken"),
        TeamLogoOption(id: "phoenix", name: "Phoenix"),
        TeamLogoOption(id: "wraith", name: "Wraith"),
        TeamLogoOption(id: "robot", name: "Robot"),
        TeamLogoOption(id: "circuit", name: "Circuit"),
        TeamLogoOption(id: "gear", name: "Gear"),
        TeamLogoOption(id: "satellite", name: "Satellite"),
        TeamLogoOption(id: "drone", name: "Drone"),
        TeamLogoOption(id: "reactor", name: "Reactor"),
        TeamLogoOption(id: "piston", name: "Piston"),
        TeamLogoOption(id: "rocket", name: "Rocket"),
        TeamLogoOption(id: "lightning", name: "Lightning"),
        TeamLogoOption(id: "tornado", name: "Tornado"),
        TeamLogoOption(id: "snowflake", name: "Snowflake"),
        TeamLogoOption(id: "hurricane", name: "Hurricane"),
        TeamLogoOption(id: "comet", name: "Comet"),
        TeamLogoOption(id: "meteor", name: "Meteor"),
        TeamLogoOption(id: "eclipse", name: "Eclipse"),
        TeamLogoOption(id: "shield", name: "Shield"),
        TeamLogoOption(id: "helmet", name: "Helmet"),
        TeamLogoOption(id: "anvil", name: "Anvil"),
        TeamLogoOption(id: "cannon", name: "Cannon"),
        TeamLogoOption(id: "lighthouse", name: "Lighthouse"),
        TeamLogoOption(id: "star", name: "Star"),
        TeamLogoOption(id: "flame", name: "Flame"),
        TeamLogoOption(id: "wave", name: "Wave"),
        TeamLogoOption(id: "mountain", name: "Mountain"),
        TeamLogoOption(id: "compass", name: "Compass")
    ]

    static func contains(id: String) -> Bool {
        logos.contains { $0.id == id }
    }
}

// MARK: - Colors

/// 15 predefined uniform colors. The builder enforces primary ≠ secondary.
nonisolated enum ColorCatalog {
    static let colors: [TeamColorOption] = [
        TeamColorOption(name: "Black", hex: 0x1A1A1A),
        TeamColorOption(name: "White", hex: 0xF2F2F2),
        TeamColorOption(name: "Silver", hex: 0xC9CDD1),
        TeamColorOption(name: "Gold", hex: 0xD9B56E),
        TeamColorOption(name: "Red", hex: 0xC2412F),
        TeamColorOption(name: "Crimson", hex: 0x8E1F2F),
        TeamColorOption(name: "Orange", hex: 0xE2762D),
        TeamColorOption(name: "Yellow", hex: 0xF2C230),
        TeamColorOption(name: "Forest Green", hex: 0x2C6B3C),
        TeamColorOption(name: "Lime Green", hex: 0x7DB84F),
        TeamColorOption(name: "Royal Blue", hex: 0x2C5FB8),
        TeamColorOption(name: "Navy", hex: 0x1E2A4A),
        TeamColorOption(name: "Cyan", hex: 0x2FA8C9),
        TeamColorOption(name: "Purple", hex: 0x6B4FA0),
        TeamColorOption(name: "Pink", hex: 0xD96BA0)
    ]
}

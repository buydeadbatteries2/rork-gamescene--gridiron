import SwiftUI

/// A fictional football franchise: the player-created team or one of the fixed
/// opponents. Pure data — colors are stored as hex so the model stays Codable
/// and Sendable, ready for a future season/dynasty layer.
nonisolated struct GameTeam: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    let state: String
    let teamName: String
    /// Identifier into the bundled vector logo catalog (`TeamCatalog.logos`).
    let logoID: String
    let primaryColorHex: UInt32
    let secondaryColorHex: UInt32
    let isUserTeam: Bool

    init(
        id: UUID = UUID(),
        state: String,
        teamName: String,
        logoID: String,
        primaryColorHex: UInt32,
        secondaryColorHex: UInt32,
        isUserTeam: Bool
    ) {
        self.id = id
        self.state = state
        self.teamName = teamName
        self.logoID = logoID
        self.primaryColorHex = primaryColorHex
        self.secondaryColorHex = secondaryColorHex
        self.isUserTeam = isUserTeam
    }

    /// Full franchise name, e.g. "Virginia Cyber Wolves".
    var displayName: String { "\(state) \(teamName)" }

    var primaryColor: Color { Color(hex: primaryColorHex) }
    var secondaryColor: Color { Color(hex: secondaryColorHex) }

    /// Short HUD label, e.g. "VA CYBER WOLVES".
    var shortName: String {
        let stateAbbrev = StateCatalog.abbreviation(for: state) ?? String(state.prefix(3))
        return "\(stateAbbrev) \(teamName)".uppercased()
    }
}

// MARK: - Uniform kit

/// The concrete uniform colors a set of field tokens wears. Built from a
/// `GameTeam`, with an automatic light "away" treatment when two teams would
/// be indistinguishable on the field.
nonisolated struct TeamKit: Hashable, Sendable {
    let jersey: Color
    let helmet: Color
    let trim: Color
    let number: Color
    let isAlternate: Bool

    static let standard = TeamKit(
        jersey: Color(hex: 0x15120E),
        helmet: Color(hex: 0x15120E),
        trim: Theme.gold,
        number: Theme.goldLight,
        isAlternate: false
    )
}

// MARK: - Kit resolution

/// Decides which uniform treatment each side wears and guarantees the two
/// teams stay visually distinguishable on the dark turf.
nonisolated enum TeamKitResolver {
    /// Weighted RGB distance below which two kit colors are considered too
    /// close to tell apart at token size on a dark green field.
    static let similarityThreshold: Double = 0.22

    /// The user's kit is always their primary/secondary identity; the opponent
    /// switches to a light away treatment when the two primaries collide.
    static func kits(user: GameTeam, opponent: GameTeam) -> (user: TeamKit, opponent: TeamKit) {
        let userKit = standardKit(for: user)
        let opponentKit: TeamKit
        if areSimilar(user.primaryColorHex, opponent.primaryColorHex) || areSimilar(user.primaryColorHex, opponent.secondaryColorHex) {
            opponentKit = alternateKit(for: opponent)
        } else {
            opponentKit = standardKit(for: opponent)
        }
        return (userKit, opponentKit)
    }

    /// Primary identity kit: primary jersey/helmet, secondary trim.
    static func standardKit(for team: GameTeam) -> TeamKit {
        TeamKit(
            jersey: team.primaryColor,
            helmet: team.primaryColor,
            trim: team.secondaryColor,
            number: contrastColor(on: team.primaryColorHex),
            isAlternate: false
        )
    }

    /// Light away treatment: near-white jersey with the team's primary as trim,
    /// used only when the opponent would otherwise blend into the user's kit.
    static func alternateKit(for team: GameTeam) -> TeamKit {
        TeamKit(
            jersey: Color(hex: 0xE9ECEF),
            helmet: team.primaryColor,
            trim: team.primaryColor,
            number: Color(hex: 0x1A1A1A),
            isAlternate: true
        )
    }

    /// Perceptually weighted RGB distance in 0...1 — approximates how hard two
    /// colors are to tell apart at small sizes without pulling in a color library.
    static func colorDistance(_ a: UInt32, _ b: UInt32) -> Double {
        let dr = Double(Int((a >> 16) & 0xFF) - Int((b >> 16) & 0xFF)) / 255
        let dg = Double(Int((a >> 8) & 0xFF) - Int((b >> 8) & 0xFF)) / 255
        let db = Double(Int(a & 0xFF) - Int(b & 0xFF)) / 255
        return (0.3 * dr * dr + 0.59 * dg * dg + 0.11 * db * db).squareRoot()
    }

    static func areSimilar(_ a: UInt32, _ b: UInt32) -> Bool {
        colorDistance(a, b) < similarityThreshold
    }

    /// Black or white text/number color with enough contrast against `hex`.
    static func contrastColor(on hex: UInt32) -> Color {
        let r = Double((hex >> 16) & 0xFF)
        let g = Double((hex >> 8) & 0xFF)
        let b = Double(hex & 0xFF)
        let luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255
        return luminance > 0.55 ? Color(hex: 0x141414) : .white
    }
}

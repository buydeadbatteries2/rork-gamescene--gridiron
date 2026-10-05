import SwiftUI

/// Central design tokens for GameScene: Gridiron. See `.rork/DESIGN.md`.
/// Nonisolated: pure constants/functions, safe from any actor (team models use them).
nonisolated enum Theme {
    // MARK: Surfaces
    static let ink = Color(hex: 0x0E0C09)
    static let charcoal = Color(hex: 0x17140F)
    static let surface = Color(hex: 0x241E17)
    static let surfaceRaised = Color(hex: 0x2E271E)

    // MARK: Metals
    static let gold = Color(hex: 0xD9B56E)
    static let goldLight = Color(hex: 0xF0DDAA)
    static let bronze = Color(hex: 0xB8813A)
    static let bronzeDeep = Color(hex: 0x6E4A1F)
    static let silver = Color(hex: 0xC9CDD1)

    // MARK: Paper
    static let paper = Color(hex: 0xE3D5B3)
    static let paperDark = Color(hex: 0xC9B690)
    static let paperInk = Color(hex: 0x2A2118)
    static let paperInkSoft = Color(hex: 0x5C4D3A)

    // MARK: Field
    static let turf = Color(hex: 0x2E5A2A)
    static let turfDark = Color(hex: 0x1D3D1B)
    static let chalk = Color(hex: 0xF2F0E6)

    // MARK: Signals
    static let caution = Color(hex: 0xF2C230)
    static let danger = Color(hex: 0xC2412F)
    static let success = Color(hex: 0x7DB84F)
    static let heart = Color(hex: 0xE0443A)

    // MARK: Difficulty
    static let easy = Color(hex: 0x5E7A3A)
    static let medium = Color(hex: 0xA87A1E)
    static let hard = Color(hex: 0x9A3A2C)

    // MARK: Notebook marker highlights (soft highlighter pastels on paper)
    static let highlightEvidence = Color(hex: 0xF2B984)   // orange — physical evidence
    static let highlightDirection = Color(hex: 0xA8C6E8)  // blue — where on the field
    static let highlightPosition = Color(hex: 0xB7D6A5)   // green — who the clue is about
    static let highlightTrait = Color(hex: 0xEFD79A)      // gold — Fast / Power / Veteran flavor

    // MARK: Playbook accents
    // Numbered clue chips cycle through this palette (reference-style color coding).
    static let clueChipColors: [Color] = [
        Color(hex: 0xE0B23F),   // gold
        Color(hex: 0x4E8FD9),   // blue
        Color(hex: 0x63A86B),   // green
        Color(hex: 0xC2412F),   // red
        Color(hex: 0x9B76D8)    // purple
    ]

    static func clueChipColor(_ number: Int) -> Color {
        clueChipColors[(number - 1) % clueChipColors.count]
    }

    /// Profile chip colors: speed = blue, strength = red, experience = gold.
    static func variantColor(_ variant: PlayerVariant) -> Color {
        switch variant {
        case .fast: Color(hex: 0x4E8FD9)
        case .power: Color(hex: 0xC2412F)
        case .veteran: Color(hex: 0xD9B56E)
        }
    }

    static let goldGradient = LinearGradient(
        colors: [Color(hex: 0xF6E2A8), Color(hex: 0xD9B56E), Color(hex: 0x9C6B2C)],
        startPoint: .top,
        endPoint: .bottom
    )

    static let bronzeButton = LinearGradient(
        colors: [Color(hex: 0x6A4A22), Color(hex: 0x3A2812), Color(hex: 0x24180A)],
        startPoint: .top,
        endPoint: .bottom
    )

    // MARK: Type
    static func typewriter(_ size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom("AmericanTypewriter", size: size, relativeTo: style)
    }

    static func typewriterBold(_ size: CGFloat, relativeTo style: Font.TextStyle = .headline) -> Font {
        .custom("AmericanTypewriter-Bold", size: size, relativeTo: style)
    }

    static func display(_ size: CGFloat) -> Font {
        .system(size: size, weight: .black, design: .serif)
    }

    static func condensed(_ size: CGFloat, weight: Font.Weight = .heavy) -> Font {
        .system(size: size, weight: weight).width(.condensed)
    }

    // MARK: Position accents
    // Color-code roster cards and field tokens by position group (logo-free, purely
    // functional styling — see DESIGN.md). QB stays a neutral premium accent.
    static func positionAccent(_ position: FootballPosition) -> Color {
        switch position {
        case .wr, .cb: Color(hex: 0x4E8FD9)      // blue — skill corners/receivers
        case .rb: Color(hex: 0xE0B23F)           // gold — running backs
        case .te, .lb: Color(hex: 0x63A86B)      // green — hybrids and backers
        case .fs, .ss: Color(hex: 0x9B76D8)      // purple — deep coverage
        case .dl, .ol: Color(hex: 0xC77B3C)      // bronze-orange — trench
        case .qb: Color(hex: 0xC9CDD1)           // silver — neutral
        }
    }

    static func positionAccentGradient(_ position: FootballPosition) -> LinearGradient {
        let color = positionAccent(position)
        return LinearGradient(
            colors: [color, color.opacity(0.45)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

extension Color {
    nonisolated init(hex: UInt32, opacity: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }
}

import SwiftUI

/// Central design tokens for GameScene: Gridiron. See `.rork/DESIGN.md`.
enum Theme {
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
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }
}

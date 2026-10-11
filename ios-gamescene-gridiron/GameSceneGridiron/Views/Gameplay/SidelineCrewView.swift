import SwiftUI

/// Decorative far-sideline strip above the field: a darkened stand with a
/// suggestion of crowd, plus a row of simple vector players, coaches,
/// referees and photographers standing on the far boundary (the broadcast
/// look from the reference board). Purely decorative — never tappable.
struct SidelineCrewView: View {
    nonisolated enum CrewRole: CaseIterable {
        case player
        case coach
        case referee
        case photographer
    }

    /// Deterministic sideline crowd so the board looks identical every frame.
    static let lineup: [CrewRole] = [
        .player, .referee, .coach, .photographer, .coach, .player,
        .referee, .coach, .photographer, .player, .referee, .coach,
    ]

    var body: some View {
        Canvas { context, size in
            Self.drawStand(context: context, width: size.width, height: size.height)
            Self.drawCrew(context: context, width: size.width, height: size.height)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Stable pseudo-random in [0, 1) so the crowd never shuffles between renders.
    private static func jitter(_ seed: Int) -> CGFloat {
        CGFloat((sin(Double(seed) * 12.9898) * 43758.5453).truncatingRemainder(dividingBy: 1)).magnitude
    }

    /// Dark stadium band with blurred crowd dots and a chalk far-boundary line.
    private static func drawStand(context: GraphicsContext, width: CGFloat, height: CGFloat) {
        var band = Path()
        band.addRect(CGRect(x: 0, y: 0, width: width, height: height))
        context.fill(band, with: .linearGradient(
            Gradient(colors: [Color(hex: 0x111A12), Color(hex: 0x1B261B)]),
            startPoint: CGPoint(x: 0, y: 0),
            endPoint: CGPoint(x: 0, y: height)
        ))

        // Crowd suggestion: two loose rows of muted dots in the upper band.
        let dot = max(1.5, height * 0.09)
        for i in 0..<70 {
            let row = i % 2
            let x = width * ((CGFloat(i) + jitter(i)) / 36).truncatingRemainder(dividingBy: 1)
            let y = height * (0.14 + 0.34 * CGFloat(row)) + jitter(i + 40) * height * 0.1
            let shade = [Color.white.opacity(0.16), Color(hex: 0x8A93A6).opacity(0.22), Color(hex: 0x5A4632).opacity(0.3)][i % 3]
            let circle = Path(ellipseIn: CGRect(x: x - dot / 2, y: y, width: dot, height: dot))
            context.fill(circle, with: .color(shade))
        }

        // Far sideline chalk the crew stands on.
        var chalk = Path()
        chalk.move(to: CGPoint(x: 0, y: height - 1.4))
        chalk.addLine(to: CGPoint(x: width, y: height - 1.4))
        context.stroke(chalk, with: .color(Theme.chalk.opacity(0.5)), lineWidth: 1.4)
    }

    private static func drawCrew(context: GraphicsContext, width: CGFloat, height: CGFloat) {
        let count = lineup.count
        for (index, role) in lineup.enumerated() {
            let x = width * (0.05 + 0.9 * CGFloat(index) / CGFloat(count - 1))
            let stance: CGFloat = role == .photographer ? 0.55 : (0.68 + jitter(index + 7) * 0.14)
            let h = height * stance
            drawFigure(context: context, role: role, x: x, height: h, baseline: height - 1.5, seed: index)
        }
    }

    /// One stylized person: legs, torso, head, plus role gear. Drawn in a tiny
    /// box centered on `x` with the feet on `baseline`.
    private static func drawFigure(context: GraphicsContext, role: CrewRole, x: CGFloat, height: CGFloat, baseline: CGFloat, seed: Int) {
        let skin = [Color(hex: 0xC68B59), Color(hex: 0x8A5A38), Color(hex: 0xE0A870), Color(hex: 0x6E4526)][seed % 4]
        let torsoWidth = height * (role == .photographer ? 0.52 : 0.4)
        let legHeight = height * 0.34
        let torsoHeight = height * (role == .photographer ? 0.3 : 0.4)
        let headSize = height * 0.26

        // Ground shadow.
        let shadow = Path(ellipseIn: CGRect(x: x - torsoWidth * 0.8, y: baseline - height * 0.06, width: torsoWidth * 1.6, height: height * 0.1))
        context.fill(shadow, with: .color(.black.opacity(0.35)))

        let legColor = role == .referee ? Color(hex: 0x14161A) : Color(hex: 0x1D2430)
        for offset in [-torsoWidth * 0.28, torsoWidth * 0.28] {
            let leg = Path(roundedRect: CGRect(x: x + offset - torsoWidth * 0.14, y: baseline - legHeight, width: torsoWidth * 0.28, height: legHeight), cornerRadius: torsoWidth * 0.12)
            context.fill(leg, with: .color(legColor))
        }

        let torsoY = baseline - legHeight - torsoHeight
        let torsoColor: Color = {
            switch role {
            case .referee: return Color(hex: 0xE8EAEE)
            case .coach: return Color(hex: 0x222B3A)
            case .player: return Color(hex: 0x2A3346)
            case .photographer: return Color(hex: 0x39404C)
            }
        }()
        let torso = Path(roundedRect: CGRect(x: x - torsoWidth / 2, y: torsoY, width: torsoWidth, height: torsoHeight * 1.06), cornerRadius: torsoWidth * 0.3)
        context.fill(torso, with: .color(torsoColor))

        if role == .referee {
            for i in 0..<3 {
                let stripeY = torsoY + torsoHeight * (0.2 + 0.3 * CGFloat(i))
                var stripe = Path()
                stripe.move(to: CGPoint(x: x - torsoWidth / 2, y: stripeY))
                stripe.addLine(to: CGPoint(x: x + torsoWidth / 2, y: stripeY))
                context.stroke(stripe, with: .color(Color(hex: 0x14161A)), lineWidth: max(0.8, torsoWidth * 0.1))
            }
        }

        let headY = torsoY - headSize * 0.92
        if role == .player {
            // Helmeted: full dark shell with a facemask hint.
            let helmet = Path(ellipseIn: CGRect(x: x - headSize / 2, y: headY - headSize * 0.1, width: headSize, height: headSize))
            context.fill(helmet, with: .color(Color(hex: 0x1A2130)))
        } else {
            let head = Path(ellipseIn: CGRect(x: x - headSize / 2, y: headY, width: headSize, height: headSize))
            context.fill(head, with: .color(skin))
            if role != .photographer {
                let cap = Path(roundedRect: CGRect(x: x - headSize * 0.55, y: headY - headSize * 0.28, width: headSize * 1.1, height: headSize * 0.44), cornerRadius: headSize * 0.2)
                context.fill(cap, with: .color(role == .referee ? Color(hex: 0x14161A) : Color(hex: 0x2E3A50)))
            }
        }

        if role == .photographer {
            // Long lens aimed onto the field.
            let camera = Path(roundedRect: CGRect(x: x + torsoWidth * 0.3, y: torsoY + torsoHeight * 0.18, width: torsoWidth * 0.55, height: torsoHeight * 0.5), cornerRadius: torsoWidth * 0.08)
            context.fill(camera, with: .color(Color(hex: 0x101318)))
        }
    }
}

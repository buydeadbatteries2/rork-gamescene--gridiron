import SwiftUI

// MARK: - Glyph plumbing

/// A shape drawn in a fixed 100×100 design space and scaled to whatever frame
/// the glyph is placed in. Keeps every emblem resolution-independent.
nonisolated struct GlyphShape: Shape {
    let draw: @Sendable (inout Path) -> Void

    func path(in rect: CGRect) -> Path {
        var path = Path()
        draw(&path)
        var transform = CGAffineTransform(translationX: rect.minX, y: rect.minY)
        transform = transform.scaledBy(x: rect.width / 100, y: rect.height / 100)
        return path.applying(transform)
    }
}

/// Filled vector mark in one team color.
struct GlyphFill: View {
    let color: Color
    let draw: (inout Path) -> Void

    var body: some View {
        GlyphShape(draw: draw).fill(color)
    }
}

/// Stroked vector mark (rounded joins for a badge-like feel).
struct GlyphStroke: View {
    let color: Color
    var width: CGFloat = 7
    let draw: (inout Path) -> Void

    var body: some View {
        GlyphShape(draw: draw)
            .stroke(color, style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
    }
}

func poly(_ points: [(Double, Double)]) -> (inout Path) -> Void {
    { path in
        guard let first = points.first else { return }
        path.move(to: CGPoint(x: first.0, y: first.1))
        for point in points.dropFirst() {
            path.addLine(to: CGPoint(x: point.0, y: point.1))
        }
        path.closeSubpath()
    }
}

func strokeLine(_ points: [(Double, Double)], closed: Bool = false) -> (inout Path) -> Void {
    { path in
        guard let first = points.first else { return }
        path.move(to: CGPoint(x: first.0, y: first.1))
        for point in points.dropFirst() {
            path.addLine(to: CGPoint(x: point.0, y: point.1))
        }
        if closed { path.closeSubpath() }
    }
}

// MARK: - TeamLogoGlyph

/// Renders one of the 50 fictional catalog emblems as pure vector art using the
/// team's primary/secondary colors. Completely original — no real-world marks.
struct TeamLogoGlyph: View {
    let logoID: String
    let primary: Color
    let secondary: Color

    var body: some View {
        ZStack {
            switch logoID {
            case "wolf": wolf
            case "hawk": hawk
            case "shark": shark
            case "serpent": serpent
            case "scorpion": scorpion
            case "bull": bull
            case "panther": panther
            case "bear": bear
            case "raven": raven
            case "lion": lion
            case "ram": ram
            case "boar": boar
            case "hound": hound
            case "owl": owl
            case "fox": fox
            case "stag": stag
            case "cobra": cobra
            case "stallion": stallion
            case "vulture": vulture
            case "jackal": jackal
            case "dragon": dragon
            case "griffin": griffin
            case "kraken": kraken
            case "phoenix": phoenix
            case "wraith": wraith
            case "robot": robot
            case "circuit": circuit
            case "gear": gear
            case "satellite": satellite
            case "drone": drone
            case "reactor": reactor
            case "piston": piston
            case "rocket": rocket
            case "lightning": lightning
            case "tornado": tornado
            case "snowflake": snowflake
            case "hurricane": hurricane
            case "comet": comet
            case "meteor": meteor
            case "eclipse": eclipse
            case "shield": shield
            case "helmet": helmet
            case "anvil": anvil
            case "cannon": cannon
            case "lighthouse": lighthouse
            case "star": star
            case "flame": flame
            case "wave": wave
            case "mountain": mountain
            case "compass": compass
            default:
                Circle().fill(primary).frame(width: 60, height: 60)
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: Animals

    private var wolf: some View {
        ZStack {
            GlyphFill(color: primary, draw: poly([(32, 12), (44, 30), (56, 30), (68, 12), (76, 40), (50, 86), (24, 40)]))
            GlyphFill(color: secondary, draw: poly([(42, 44), (47, 44), (44.5, 49)]))
            GlyphFill(color: secondary, draw: poly([(53, 44), (58, 44), (55.5, 49)]))
            GlyphFill(color: secondary, draw: poly([(44, 58), (56, 58), (50, 72)]))
        }
    }

    private var hawk: some View {
        ZStack {
            GlyphFill(color: primary) { path in
                path.addEllipse(in: CGRect(x: 18, y: 22, width: 46, height: 46))
            }
            GlyphFill(color: primary, draw: poly([(58, 34), (90, 44), (60, 58)]))
            GlyphStroke(color: primary, width: 9, draw: strokeLine([(40, 66), (34, 90)]))
            GlyphFill(color: secondary) { path in
                path.addEllipse(in: CGRect(x: 34, y: 36, width: 11, height: 11))
            }
        }
    }

    private var shark: some View {
        ZStack {
            GlyphFill(color: primary, draw: poly([(10, 62), (55, 38), (90, 30), (72, 55), (88, 72), (52, 66)]))
            GlyphFill(color: primary, draw: poly([(46, 40), (58, 14), (64, 42)]))
            GlyphFill(color: secondary) { path in
                path.addEllipse(in: CGRect(x: 56, y: 44, width: 9, height: 9))
            }
            GlyphStroke(color: secondary, width: 4, draw: strokeLine([(30, 56), (38, 59), (30, 62)]))
        }
    }

    private var serpent: some View {
        ZStack {
            GlyphStroke(color: primary, width: 13) { path in
                path.move(to: CGPoint(x: 18, y: 84))
                path.addCurve(to: CGPoint(x: 50, y: 50), control1: CGPoint(x: 58, y: 84), control2: CGPoint(x: 30, y: 68))
                path.addCurve(to: CGPoint(x: 58, y: 26), control1: CGPoint(x: 70, y: 32), control2: CGPoint(x: 48, y: 34))
            }
            GlyphFill(color: primary) { path in
                path.addEllipse(in: CGRect(x: 44, y: 10, width: 30, height: 22))
            }
            GlyphFill(color: secondary) { path in
                path.addEllipse(in: CGRect(x: 52, y: 17, width: 6, height: 6))
            }
            GlyphFill(color: secondary, draw: poly([(72, 16), (86, 12), (80, 22)]))
        }
    }

    private var scorpion: some View {
        ZStack {
            GlyphStroke(color: primary, width: 10) { path in
                path.move(to: CGPoint(x: 44, y: 58))
                path.addQuadCurve(to: CGPoint(x: 72, y: 30), control: CGPoint(x: 74, y: 56))
            }
            GlyphFill(color: primary, draw: poly([(68, 30), (84, 18), (74, 36)]))
            GlyphFill(color: primary) { path in
                path.addEllipse(in: CGRect(x: 32, y: 52, width: 26, height: 22))
            }
            GlyphStroke(color: secondary, width: 7) { path in
                path.move(to: CGPoint(x: 32, y: 58))
                path.addQuadCurve(to: CGPoint(x: 8, y: 44), control: CGPoint(x: 18, y: 48))
                path.move(to: CGPoint(x: 34, y: 66))
                path.addQuadCurve(to: CGPoint(x: 10, y: 66), control: CGPoint(x: 20, y: 70))
            }
            GlyphFill(color: secondary) { path in
                path.addEllipse(in: CGRect(x: 40, y: 58, width: 5, height: 5))
            }
            GlyphFill(color: secondary) { path in
                path.addEllipse(in: CGRect(x: 48, y: 58, width: 5, height: 5))
            }
        }
    }

    private var bull: some View {
        ZStack {
            GlyphStroke(color: secondary, width: 9) { path in
                path.move(to: CGPoint(x: 34, y: 30))
                path.addQuadCurve(to: CGPoint(x: 8, y: 12), control: CGPoint(x: 16, y: 26))
                path.move(to: CGPoint(x: 66, y: 30))
                path.addQuadCurve(to: CGPoint(x: 92, y: 12), control: CGPoint(x: 84, y: 26))
            }
            GlyphFill(color: primary, draw: poly([(30, 26), (70, 26), (78, 52), (50, 90), (22, 52)]))
            GlyphFill(color: secondary) { path in
                path.addEllipse(in: CGRect(x: 36, y: 42, width: 8, height: 8))
            }
            GlyphFill(color: secondary) { path in
                path.addEllipse(in: CGRect(x: 56, y: 42, width: 8, height: 8))
            }
            GlyphFill(color: secondary) { path in
                path.addEllipse(in: CGRect(x: 38, y: 66, width: 24, height: 14))
            }
        }
    }

    private var panther: some View {
        ZStack {
            GlyphFill(color: primary, draw: poly([(22, 18), (40, 34), (60, 34), (78, 18), (82, 48), (50, 86), (18, 48)]))
            GlyphStroke(color: secondary, width: 5) { path in
                path.move(to: CGPoint(x: 34, y: 48))
                path.addLine(to: CGPoint(x: 44, y: 50))
                path.move(to: CGPoint(x: 66, y: 48))
                path.addLine(to: CGPoint(x: 56, y: 50))
            }
            GlyphFill(color: secondary, draw: poly([(44, 62), (56, 62), (50, 72)]))
        }
    }

    private var bear: some View {
        ZStack {
            GlyphFill(color: primary) { path in
                path.addEllipse(in: CGRect(x: 14, y: 14, width: 22, height: 22))
            }
            GlyphFill(color: primary) { path in
                path.addEllipse(in: CGRect(x: 64, y: 14, width: 22, height: 22))
            }
            GlyphFill(color: primary) { path in
                path.addEllipse(in: CGRect(x: 18, y: 28, width: 64, height: 60))
            }
            GlyphFill(color: secondary) { path in
                path.addEllipse(in: CGRect(x: 34, y: 46, width: 12, height: 12))
            }
            GlyphFill(color: secondary) { path in
                path.addEllipse(in: CGRect(x: 54, y: 46, width: 12, height: 12))
            }
            GlyphFill(color: secondary) { path in
                path.addEllipse(in: CGRect(x: 44, y: 68, width: 12, height: 9))
            }
        }
    }

    private var raven: some View {
        ZStack {
            GlyphStroke(color: primary, width: 11) { path in
                path.move(to: CGPoint(x: 8, y: 44))
                path.addQuadCurve(to: CGPoint(x: 50, y: 52), control: CGPoint(x: 28, y: 24))
                path.move(to: CGPoint(x: 92, y: 44))
                path.addQuadCurve(to: CGPoint(x: 50, y: 52), control: CGPoint(x: 72, y: 24))
            }
            GlyphFill(color: primary, draw: poly([(38, 46), (62, 46), (50, 78)]))
            GlyphFill(color: secondary) { path in
                path.addEllipse(in: CGRect(x: 46, y: 52, width: 8, height: 8))
            }
        }
    }

    private var lion: some View {
        ZStack {
            GlyphFill(color: primary) { path in
                let count = 12.0
                let inner = 24.0
                let outer = 40.0
                let step = 2 * Double.pi / count
                for index in 0..<12 {
                    let angle = Double(index) * step
                    let mid = angle + step / 2
                    path.move(to: CGPoint(x: 50 + inner * cos(angle), y: 50 + inner * sin(angle)))
                    path.addLine(to: CGPoint(x: 50 + outer * cos(mid), y: 50 + outer * sin(mid)))
                    path.addLine(to: CGPoint(x: 50 + inner * cos(angle + step), y: 50 + inner * sin(angle + step)))
                    path.closeSubpath()
                }
            }
            GlyphFill(color: secondary) { path in
                path.addEllipse(in: CGRect(x: 30, y: 30, width: 40, height: 40))
            }
            GlyphFill(color: primary) { path in
                path.addEllipse(in: CGRect(x: 39, y: 42, width: 7, height: 7))
            }
            GlyphFill(color: primary) { path in
                path.addEllipse(in: CGRect(x: 54, y: 42, width: 7, height: 7))
            }
            GlyphFill(color: primary, draw: poly([(46, 58), (54, 58), (50, 64)]))
        }
    }

    private var ram: some View {
        ZStack {
            GlyphStroke(color: secondary, width: 9) { path in
                path.move(to: CGPoint(x: 34, y: 36))
                path.addCurve(to: CGPoint(x: 36, y: 58), control1: CGPoint(x: 8, y: 34), control2: CGPoint(x: 8, y: 60))
                path.move(to: CGPoint(x: 66, y: 36))
                path.addCurve(to: CGPoint(x: 64, y: 58), control1: CGPoint(x: 92, y: 34), control2: CGPoint(x: 92, y: 60))
            }
            GlyphFill(color: primary, draw: poly([(36, 24), (64, 24), (68, 52), (50, 84), (32, 52)]))
            GlyphFill(color: secondary) { path in
                path.addEllipse(in: CGRect(x: 40, y: 42, width: 7, height: 7))
            }
            GlyphFill(color: secondary) { path in
                path.addEllipse(in: CGRect(x: 53, y: 42, width: 7, height: 7))
            }
        }
    }

    private var boar: some View {
        ZStack {
            GlyphFill(color: primary, draw: poly([(24, 30), (76, 30), (82, 58), (50, 84), (18, 58)]))
            GlyphFill(color: secondary) { path in
                path.addEllipse(in: CGRect(x: 38, y: 44, width: 8, height: 8))
            }
            GlyphFill(color: secondary) { path in
                path.addEllipse(in: CGRect(x: 54, y: 44, width: 8, height: 8))
            }
            GlyphFill(color: secondary) { path in
                path.addEllipse(in: CGRect(x: 42, y: 64, width: 16, height: 10))
            }
            GlyphStroke(color: secondary, width: 5, draw: strokeLine([(40, 74), (30, 84)]))
            GlyphStroke(color: secondary, width: 5, draw: strokeLine([(60, 74), (70, 84)]))
        }
    }

    private var hound: some View {
        ZStack {
            GlyphFill(color: secondary) { path in
                path.addEllipse(in: CGRect(x: 10, y: 30, width: 24, height: 44))
            }
            GlyphFill(color: secondary) { path in
                path.addEllipse(in: CGRect(x: 66, y: 30, width: 24, height: 44))
            }
            GlyphFill(color: primary) { path in
                path.addEllipse(in: CGRect(x: 28, y: 22, width: 44, height: 52))
            }
            GlyphFill(color: secondary) { path in
                path.addEllipse(in: CGRect(x: 38, y: 42, width: 9, height: 9))
            }
            GlyphFill(color: secondary) { path in
                path.addEllipse(in: CGRect(x: 53, y: 42, width: 9, height: 9))
            }
            GlyphFill(color: secondary) { path in
                path.addEllipse(in: CGRect(x: 45, y: 62, width: 10, height: 8))
            }
        }
    }

    private var owl: some View {
        ZStack {
            GlyphFill(color: primary, draw: poly([(24, 30), (38, 16), (50, 28), (62, 16), (76, 30), (76, 70), (50, 90), (24, 70)]))
            GlyphFill(color: secondary) { path in
                path.addEllipse(in: CGRect(x: 30, y: 36, width: 18, height: 18))
            }
            GlyphFill(color: secondary) { path in
                path.addEllipse(in: CGRect(x: 52, y: 36, width: 18, height: 18))
            }
            GlyphFill(color: primary) { path in
                path.addEllipse(in: CGRect(x: 36, y: 42, width: 7, height: 7))
            }
            GlyphFill(color: primary) { path in
                path.addEllipse(in: CGRect(x: 58, y: 42, width: 7, height: 7))
            }
            GlyphFill(color: secondary, draw: poly([(46, 62), (54, 62), (50, 74)]))
        }
    }

    private var fox: some View {
        ZStack {
            GlyphFill(color: primary, draw: poly([(22, 16), (40, 32), (60, 32), (78, 16), (84, 46), (50, 88), (16, 46)]))
            GlyphFill(color: secondary, draw: poly([(28, 48), (44, 48), (36, 64)]))
            GlyphFill(color: secondary, draw: poly([(56, 48), (72, 48), (64, 64)]))
            GlyphFill(color: secondary, draw: poly([(46, 60), (54, 60), (50, 70)]))
        }
    }

    private var stag: some View {
        ZStack {
            GlyphStroke(color: secondary, width: 6) { path in
                path.move(to: CGPoint(x: 38, y: 34))
                path.addLine(to: CGPoint(x: 26, y: 10))
                path.move(to: CGPoint(x: 32, y: 22))
                path.addLine(to: CGPoint(x: 18, y: 24))
                path.move(to: CGPoint(x: 34, y: 16))
                path.addLine(to: CGPoint(x: 26, y: 4))
                path.move(to: CGPoint(x: 62, y: 34))
                path.addLine(to: CGPoint(x: 74, y: 10))
                path.move(to: CGPoint(x: 68, y: 22))
                path.addLine(to: CGPoint(x: 82, y: 24))
                path.move(to: CGPoint(x: 66, y: 16))
                path.addLine(to: CGPoint(x: 74, y: 4))
            }
            GlyphFill(color: primary, draw: poly([(36, 30), (64, 30), (60, 60), (50, 88), (40, 60)]))
            GlyphFill(color: secondary) { path in
                path.addEllipse(in: CGRect(x: 41, y: 44, width: 6, height: 6))
            }
            GlyphFill(color: secondary) { path in
                path.addEllipse(in: CGRect(x: 53, y: 44, width: 6, height: 6))
            }
        }
    }

    private var cobra: some View {
        ZStack {
            GlyphFill(color: primary) { path in
                path.move(to: CGPoint(x: 50, y: 12))
                path.addCurve(to: CGPoint(x: 82, y: 66), control1: CGPoint(x: 84, y: 24), control2: CGPoint(x: 80, y: 46))
                path.addLine(to: CGPoint(x: 18, y: 66))
                path.addCurve(to: CGPoint(x: 50, y: 12), control1: CGPoint(x: 20, y: 46), control2: CGPoint(x: 16, y: 24))
                path.closeSubpath()
            }
            GlyphFill(color: secondary) { path in
                path.addEllipse(in: CGRect(x: 40, y: 34, width: 8, height: 8))
            }
            GlyphFill(color: secondary) { path in
                path.addEllipse(in: CGRect(x: 52, y: 34, width: 8, height: 8))
            }
            GlyphStroke(color: primary, width: 8) { path in
                path.move(to: CGPoint(x: 50, y: 64))
                path.addQuadCurve(to: CGPoint(x: 58, y: 88), control: CGPoint(x: 60, y: 74))
            }
        }
    }

    private var stallion: some View {
        ZStack {
            GlyphFill(color: primary, draw: poly([(30, 90), (34, 40), (46, 14), (74, 22), (78, 40), (62, 46), (52, 58), (48, 90)]))
            GlyphFill(color: primary, draw: poly([(46, 14), (58, 8), (74, 22), (64, 26)]))
            GlyphStroke(color: secondary, width: 7) { path in
                path.move(to: CGPoint(x: 36, y: 38))
                path.addQuadCurve(to: CGPoint(x: 46, y: 18), control: CGPoint(x: 32, y: 26))
            }
            GlyphFill(color: secondary) { path in
                path.addEllipse(in: CGRect(x: 62, y: 28, width: 7, height: 7))
            }
        }
    }

    private var vulture: some View {
        ZStack {
            GlyphFill(color: primary) { path in
                path.addEllipse(in: CGRect(x: 34, y: 20, width: 32, height: 32))
            }
            GlyphFill(color: primary, draw: poly([(60, 30), (88, 40), (62, 44)]))
            GlyphStroke(color: secondary, width: 7) { path in
                path.move(to: CGPoint(x: 34, y: 48))
                path.addLine(to: CGPoint(x: 26, y: 58))
                path.addLine(to: CGPoint(x: 34, y: 62))
                path.addLine(to: CGPoint(x: 28, y: 72))
                path.addLine(to: CGPoint(x: 38, y: 74))
                path.move(to: CGPoint(x: 66, y: 48))
                path.addLine(to: CGPoint(x: 74, y: 58))
                path.addLine(to: CGPoint(x: 66, y: 62))
                path.addLine(to: CGPoint(x: 72, y: 72))
                path.addLine(to: CGPoint(x: 62, y: 74))
            }
            GlyphFill(color: secondary) { path in
                path.addEllipse(in: CGRect(x: 44, y: 30, width: 8, height: 8))
            }
        }
    }

    private var jackal: some View {
        ZStack {
            GlyphFill(color: primary, draw: poly([(20, 8), (36, 34), (30, 52)]))
            GlyphFill(color: primary, draw: poly([(80, 8), (64, 34), (70, 52)]))
            GlyphFill(color: primary, draw: poly([(30, 34), (70, 34), (74, 56), (50, 88), (26, 56)]))
            GlyphFill(color: secondary) { path in
                path.addEllipse(in: CGRect(x: 40, y: 46, width: 7, height: 7))
            }
            GlyphFill(color: secondary) { path in
                path.addEllipse(in: CGRect(x: 53, y: 46, width: 7, height: 7))
            }
            GlyphFill(color: secondary, draw: poly([(44, 62), (56, 62), (50, 74)]))
        }
    }

    // MARK: Creatures

    private var dragon: some View {
        ZStack {
            GlyphFill(color: primary, draw: poly([(16, 70), (40, 30), (56, 44), (48, 54), (72, 50), (56, 66), (76, 72), (40, 84)]))
            GlyphFill(color: primary, draw: poly([(52, 22), (64, 6), (66, 24)]))
            GlyphFill(color: secondary) { path in
                path.addEllipse(in: CGRect(x: 44, y: 48, width: 7, height: 7))
            }
            GlyphFill(color: secondary, draw: poly([(40, 30), (30, 14), (46, 24)]))
        }
    }

    private var griffin: some View {
        ZStack {
            GlyphFill(color: primary, draw: poly([(50, 88), (10, 44), (34, 48), (28, 26), (52, 40), (76, 26), (70, 48), (94, 44)]))
            GlyphFill(color: secondary, draw: poly([(42, 24), (58, 24), (50, 40)]))
            GlyphFill(color: primary) { path in
                path.addEllipse(in: CGRect(x: 44, y: 16, width: 12, height: 12))
            }
            GlyphFill(color: secondary) { path in
                path.addEllipse(in: CGRect(x: 47, y: 19, width: 5, height: 5))
            }
        }
    }

    private var kraken: some View {
        ZStack {
            GlyphFill(color: primary) { path in
                path.addEllipse(in: CGRect(x: 26, y: 12, width: 48, height: 44))
            }
            GlyphStroke(color: primary, width: 9) { path in
                path.move(to: CGPoint(x: 32, y: 50))
                path.addQuadCurve(to: CGPoint(x: 14, y: 86), control: CGPoint(x: 8, y: 64))
                path.move(to: CGPoint(x: 44, y: 54))
                path.addQuadCurve(to: CGPoint(x: 42, y: 90), control: CGPoint(x: 32, y: 72))
                path.move(to: CGPoint(x: 56, y: 54))
                path.addQuadCurve(to: CGPoint(x: 58, y: 90), control: CGPoint(x: 68, y: 72))
                path.move(to: CGPoint(x: 68, y: 50))
                path.addQuadCurve(to: CGPoint(x: 86, y: 86), control: CGPoint(x: 92, y: 64))
            }
            GlyphFill(color: secondary) { path in
                path.addEllipse(in: CGRect(x: 36, y: 28, width: 9, height: 9))
            }
            GlyphFill(color: secondary) { path in
                path.addEllipse(in: CGRect(x: 55, y: 28, width: 9, height: 9))
            }
        }
    }

    private var phoenix: some View {
        ZStack {
            GlyphStroke(color: primary, width: 9) { path in
                path.move(to: CGPoint(x: 50, y: 46))
                path.addQuadCurve(to: CGPoint(x: 14, y: 18), control: CGPoint(x: 28, y: 30))
                path.move(to: CGPoint(x: 50, y: 46))
                path.addQuadCurve(to: CGPoint(x: 86, y: 18), control: CGPoint(x: 72, y: 30))
            }
            GlyphFill(color: primary, draw: poly([(42, 40), (58, 40), (54, 62), (50, 56), (46, 62)]))
            GlyphFill(color: secondary) { path in
                path.addEllipse(in: CGRect(x: 24, y: 62, width: 12, height: 12))
            }
            GlyphFill(color: secondary) { path in
                path.addEllipse(in: CGRect(x: 44, y: 70, width: 12, height: 12))
            }
            GlyphFill(color: secondary) { path in
                path.addEllipse(in: CGRect(x: 64, y: 62, width: 12, height: 12))
            }
        }
    }

    private var wraith: some View {
        ZStack {
            GlyphFill(color: primary) { path in
                path.move(to: CGPoint(x: 24, y: 88))
                path.addLine(to: CGPoint(x: 24, y: 44))
                path.addArc(center: CGPoint(x: 50, y: 44), radius: 26, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
                path.addLine(to: CGPoint(x: 76, y: 88))
                path.addLine(to: CGPoint(x: 63, y: 76))
                path.addLine(to: CGPoint(x: 50, y: 88))
                path.addLine(to: CGPoint(x: 37, y: 76))
                path.closeSubpath()
            }
            GlyphFill(color: secondary) { path in
                path.addEllipse(in: CGRect(x: 38, y: 40, width: 8, height: 12))
            }
            GlyphFill(color: secondary) { path in
                path.addEllipse(in: CGRect(x: 54, y: 40, width: 8, height: 12))
            }
        }
    }

    // MARK: Technology

    private var robot: some View {
        ZStack {
            GlyphStroke(color: secondary, width: 5) { path in
                path.move(to: CGPoint(x: 50, y: 4))
                path.addLine(to: CGPoint(x: 50, y: 16))
            }
            GlyphFill(color: secondary) { path in
                path.addEllipse(in: CGRect(x: 45, y: 0, width: 10, height: 10))
            }
            GlyphFill(color: primary) { path in
                path.addRoundedRect(in: CGRect(x: 20, y: 16, width: 60, height: 56), cornerSize: CGSize(width: 12, height: 12))
            }
            GlyphFill(color: secondary) { path in
                path.addRoundedRect(in: CGRect(x: 30, y: 32, width: 14, height: 14), cornerSize: CGSize(width: 4, height: 4))
            }
            GlyphFill(color: secondary) { path in
                path.addRoundedRect(in: CGRect(x: 56, y: 32, width: 14, height: 14), cornerSize: CGSize(width: 4, height: 4))
            }
            GlyphFill(color: secondary) { path in
                path.addRoundedRect(in: CGRect(x: 32, y: 56, width: 36, height: 6), cornerSize: CGSize(width: 3, height: 3))
            }
        }
    }

    private var circuit: some View {
        ZStack {
            GlyphStroke(color: primary, width: 6) { path in
                path.move(to: CGPoint(x: 50, y: 50))
                path.addLine(to: CGPoint(x: 50, y: 20))
                path.addLine(to: CGPoint(x: 80, y: 20))
                path.move(to: CGPoint(x: 50, y: 50))
                path.addLine(to: CGPoint(x: 20, y: 50))
                path.addLine(to: CGPoint(x: 20, y: 80))
                path.move(to: CGPoint(x: 50, y: 50))
                path.addLine(to: CGPoint(x: 80, y: 50))
                path.addLine(to: CGPoint(x: 80, y: 80))
                path.move(to: CGPoint(x: 50, y: 50))
                path.addLine(to: CGPoint(x: 50, y: 80))
            }
            GlyphFill(color: secondary) { path in
                path.addRoundedRect(in: CGRect(x: 40, y: 40, width: 20, height: 20), cornerSize: CGSize(width: 4, height: 4))
            }
            GlyphFill(color: secondary) { path in
                path.addEllipse(in: CGRect(x: 74, y: 14, width: 12, height: 12))
            }
            GlyphFill(color: secondary) { path in
                path.addEllipse(in: CGRect(x: 14, y: 74, width: 12, height: 12))
            }
            GlyphFill(color: secondary) { path in
                path.addEllipse(in: CGRect(x: 74, y: 74, width: 12, height: 12))
            }
            GlyphFill(color: secondary) { path in
                path.addEllipse(in: CGRect(x: 14, y: 44, width: 12, height: 12))
            }
            GlyphFill(color: secondary) { path in
                path.addEllipse(in: CGRect(x: 44, y: 74, width: 12, height: 12))
            }
        }
    }

    private var gear: some View {
        ZStack {
            GlyphStroke(color: primary, width: 12) { path in
                let teeth = 8
                for index in 0..<teeth {
                    let angle = Double(index) / Double(teeth) * 2 * .pi
                    path.move(to: CGPoint(x: 50 + 26 * cos(angle), y: 50 + 26 * sin(angle)))
                    path.addLine(to: CGPoint(x: 50 + 42 * cos(angle), y: 50 + 42 * sin(angle)))
                }
            }
            GlyphFill(color: primary) { path in
                path.addEllipse(in: CGRect(x: 18, y: 18, width: 64, height: 64))
            }
            GlyphFill(color: secondary) { path in
                path.addEllipse(in: CGRect(x: 38, y: 38, width: 24, height: 24))
            }
        }
    }

    private var satellite: some View {
        ZStack {
            GlyphFill(color: secondary) { path in
                path.addRoundedRect(in: CGRect(x: 4, y: 38, width: 28, height: 24), cornerSize: CGSize(width: 3, height: 3))
            }
            GlyphFill(color: secondary) { path in
                path.addRoundedRect(in: CGRect(x: 68, y: 38, width: 28, height: 24), cornerSize: CGSize(width: 3, height: 3))
            }
            GlyphFill(color: primary) { path in
                path.addRoundedRect(in: CGRect(x: 38, y: 34, width: 24, height: 32), cornerSize: CGSize(width: 5, height: 5))
            }
            GlyphStroke(color: primary, width: 5) { path in
                path.move(to: CGPoint(x: 50, y: 34))
                path.addLine(to: CGPoint(x: 50, y: 12))
            }
            GlyphStroke(color: secondary, width: 5) { path in
                path.addArc(center: CGPoint(x: 50, y: 16), radius: 10, startAngle: .degrees(200), endAngle: .degrees(-20), clockwise: false)
            }
        }
    }

    private var drone: some View {
        ZStack {
            GlyphStroke(color: primary, width: 7) { path in
                path.move(to: CGPoint(x: 38, y: 62))
                path.addLine(to: CGPoint(x: 20, y: 34))
                path.move(to: CGPoint(x: 62, y: 62))
                path.addLine(to: CGPoint(x: 80, y: 34))
                path.move(to: CGPoint(x: 38, y: 62))
                path.addLine(to: CGPoint(x: 20, y: 80))
                path.move(to: CGPoint(x: 62, y: 62))
                path.addLine(to: CGPoint(x: 80, y: 80))
            }
            GlyphFill(color: primary) { path in
                path.addRoundedRect(in: CGRect(x: 36, y: 46, width: 28, height: 22), cornerSize: CGSize(width: 6, height: 6))
            }
            GlyphStroke(color: secondary, width: 5) { path in
                path.addEllipse(in: CGRect(x: 8, y: 22, width: 24, height: 24))
            }
            GlyphStroke(color: secondary, width: 5) { path in
                path.addEllipse(in: CGRect(x: 68, y: 22, width: 24, height: 24))
            }
            GlyphStroke(color: secondary, width: 5) { path in
                path.addEllipse(in: CGRect(x: 8, y: 68, width: 24, height: 24))
            }
            GlyphStroke(color: secondary, width: 5) { path in
                path.addEllipse(in: CGRect(x: 68, y: 68, width: 24, height: 24))
            }
            GlyphFill(color: secondary) { path in
                path.addEllipse(in: CGRect(x: 44, y: 53, width: 12, height: 12))
            }
        }
    }

    private var reactor: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                GlyphStroke(color: primary, width: 6) { path in
                    var orbit = Path()
                    orbit.addEllipse(in: CGRect(x: 16, y: 32, width: 68, height: 36))
                    let angle = Double(index) * .pi / 3
                    let aboutCenter = CGAffineTransform(translationX: 50, y: 50)
                        .rotated(by: angle)
                        .translatedBy(x: -50, y: -50)
                    path.addPath(orbit.applying(aboutCenter))
                }
            }
            GlyphFill(color: secondary) { path in
                path.addEllipse(in: CGRect(x: 41, y: 41, width: 18, height: 18))
            }
        }
    }

    private var piston: some View {
        ZStack {
            GlyphFill(color: secondary) { path in
                path.addRoundedRect(in: CGRect(x: 42, y: 6, width: 16, height: 34), cornerSize: CGSize(width: 4, height: 4))
            }
            GlyphFill(color: primary) { path in
                path.addRoundedRect(in: CGRect(x: 24, y: 36, width: 52, height: 44), cornerSize: CGSize(width: 8, height: 8))
            }
            GlyphFill(color: secondary) { path in
                path.addRoundedRect(in: CGRect(x: 32, y: 46, width: 36, height: 8), cornerSize: CGSize(width: 3, height: 3))
            }
            GlyphFill(color: secondary) { path in
                path.addRoundedRect(in: CGRect(x: 32, y: 60, width: 36, height: 8), cornerSize: CGSize(width: 3, height: 3))
            }
        }
    }

    private var rocket: some View {
        ZStack {
            GlyphFill(color: primary) { path in
                path.move(to: CGPoint(x: 50, y: 4))
                path.addQuadCurve(to: CGPoint(x: 66, y: 52), control: CGPoint(x: 64, y: 18))
                path.addLine(to: CGPoint(x: 34, y: 52))
                path.addQuadCurve(to: CGPoint(x: 50, y: 4), control: CGPoint(x: 36, y: 18))
                path.closeSubpath()
            }
            GlyphFill(color: primary) { path in
                path.addRoundedRect(in: CGRect(x: 36, y: 50, width: 28, height: 20), cornerSize: CGSize(width: 4, height: 4))
            }
            GlyphFill(color: primary, draw: poly([(36, 56), (20, 78), (38, 72)]))
            GlyphFill(color: primary, draw: poly([(64, 56), (80, 78), (62, 72)]))
            GlyphFill(color: secondary) { path in
                path.addEllipse(in: CGRect(x: 44, y: 30, width: 12, height: 12))
            }
            GlyphFill(color: secondary, draw: poly([(42, 74), (58, 74), (50, 96)]))
        }
    }

    // MARK: Weather

    private var lightning: some View {
        GlyphFill(color: primary, draw: poly([(56, 6), (28, 50), (46, 50), (36, 94), (74, 38), (52, 38)]))
            .overlay {
                GlyphShape(draw: poly([(56, 6), (28, 50), (46, 50), (36, 94), (74, 38), (52, 38)]))
                    .stroke(secondary, lineWidth: 3)
            }
    }

    private var tornado: some View {
        ZStack {
            GlyphStroke(color: primary, width: 8) { path in
                path.move(to: CGPoint(x: 12, y: 16))
                path.addQuadCurve(to: CGPoint(x: 88, y: 16), control: CGPoint(x: 50, y: 8))
                path.move(to: CGPoint(x: 20, y: 36))
                path.addQuadCurve(to: CGPoint(x: 74, y: 36), control: CGPoint(x: 46, y: 30))
                path.move(to: CGPoint(x: 30, y: 56))
                path.addQuadCurve(to: CGPoint(x: 62, y: 56), control: CGPoint(x: 46, y: 52))
                path.move(to: CGPoint(x: 40, y: 76))
                path.addQuadCurve(to: CGPoint(x: 54, y: 76), control: CGPoint(x: 47, y: 74))
            }
            GlyphFill(color: secondary) { path in
                path.addEllipse(in: CGRect(x: 44, y: 86, width: 10, height: 10))
            }
        }
    }

    private var snowflake: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                GlyphStroke(color: primary, width: 7) { path in
                    var spoke = Path()
                    spoke.move(to: CGPoint(x: 50, y: 8))
                    spoke.addLine(to: CGPoint(x: 50, y: 92))
                    let angle = Double(index) * .pi / 3
                    let aboutCenter = CGAffineTransform(translationX: 50, y: 50)
                        .rotated(by: angle)
                        .translatedBy(x: -50, y: -50)
                    path.addPath(spoke.applying(aboutCenter))
                }
            }
            GlyphFill(color: secondary) { path in
                path.addEllipse(in: CGRect(x: 42, y: 42, width: 16, height: 16))
            }
        }
    }

    private var hurricane: some View {
        ZStack {
            GlyphStroke(color: primary, width: 9) { path in
                path.addArc(center: CGPoint(x: 50, y: 50), radius: 34, startAngle: .degrees(40), endAngle: .degrees(220), clockwise: false)
                let arcStart = 40.0 * Double.pi / 180
                path.move(to: CGPoint(x: 50 + 34 * cos(arcStart), y: 50 - 34 * sin(arcStart)))
                path.addQuadCurve(to: CGPoint(x: 50, y: 50), control: CGPoint(x: 78, y: 78))
            }
            GlyphFill(color: secondary) { path in
                path.addEllipse(in: CGRect(x: 39, y: 39, width: 22, height: 22))
            }
        }
    }

    private var comet: some View {
        ZStack {
            GlyphStroke(color: secondary, width: 6) { path in
                path.move(to: CGPoint(x: 54, y: 46))
                path.addLine(to: CGPoint(x: 10, y: 90))
                path.move(to: CGPoint(x: 60, y: 56))
                path.addLine(to: CGPoint(x: 24, y: 92))
                path.move(to: CGPoint(x: 46, y: 38))
                path.addLine(to: CGPoint(x: 18, y: 66))
            }
            GlyphFill(color: primary) { path in
                path.addEllipse(in: CGRect(x: 48, y: 16, width: 38, height: 38))
            }
            GlyphFill(color: secondary) { path in
                path.addEllipse(in: CGRect(x: 58, y: 26, width: 10, height: 10))
            }
        }
    }

    private var meteor: some View {
        ZStack {
            GlyphStroke(color: secondary, width: 6) { path in
                path.move(to: CGPoint(x: 60, y: 40))
                path.addLine(to: CGPoint(x: 92, y: 8))
                path.move(to: CGPoint(x: 66, y: 50))
                path.addLine(to: CGPoint(x: 96, y: 24))
            }
            GlyphFill(color: primary, draw: poly([(54, 30), (76, 36), (84, 58), (66, 78), (42, 70), (36, 48)]))
            GlyphFill(color: secondary) { path in
                path.addEllipse(in: CGRect(x: 48, y: 44, width: 9, height: 9))
            }
            GlyphFill(color: secondary) { path in
                path.addEllipse(in: CGRect(x: 62, y: 56, width: 7, height: 7))
            }
        }
    }

    private var eclipse: some View {
        ZStack {
            GlyphFill(color: secondary) { path in
                path.addEllipse(in: CGRect(x: 22, y: 22, width: 56, height: 56))
            }
            GlyphFill(color: primary) { path in
                path.addEllipse(in: CGRect(x: 12, y: 22, width: 56, height: 56))
            }
        }
    }

    // MARK: Objects & abstract

    private var shield: some View {
        ZStack {
            GlyphFill(color: primary, draw: poly([(50, 6), (88, 20), (84, 54), (50, 94), (16, 54), (12, 20)]))
            GlyphFill(color: secondary, draw: poly([(50, 30), (68, 44), (50, 70), (32, 44)]))
            GlyphShape(draw: poly([(50, 6), (88, 20), (84, 54), (50, 94), (16, 54), (12, 20)]))
                .stroke(secondary, lineWidth: 4)
        }
    }

    private var helmet: some View {
        ZStack {
            GlyphFill(color: primary) { path in
                path.move(to: CGPoint(x: 24, y: 58))
                path.addArc(center: CGPoint(x: 50, y: 46), radius: 30, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
                path.addLine(to: CGPoint(x: 80, y: 58))
                path.addLine(to: CGPoint(x: 62, y: 66))
                path.addLine(to: CGPoint(x: 62, y: 78))
                path.addLine(to: CGPoint(x: 24, y: 78))
                path.closeSubpath()
            }
            GlyphStroke(color: secondary, width: 5) { path in
                path.move(to: CGPoint(x: 62, y: 62))
                path.addLine(to: CGPoint(x: 84, y: 62))
                path.move(to: CGPoint(x: 62, y: 72))
                path.addLine(to: CGPoint(x: 82, y: 72))
                path.move(to: CGPoint(x: 62, y: 62))
                path.addLine(to: CGPoint(x: 62, y: 78))
            }
            GlyphFill(color: secondary) { path in
                path.addEllipse(in: CGRect(x: 34, y: 52, width: 9, height: 9))
            }
            GlyphStroke(color: secondary, width: 4) { path in
                path.move(to: CGPoint(x: 50, y: 16))
                path.addLine(to: CGPoint(x: 50, y: 30))
            }
        }
    }

    private var anvil: some View {
        ZStack {
            GlyphFill(color: primary) { path in
                path.move(to: CGPoint(x: 14, y: 30))
                path.addLine(to: CGPoint(x: 86, y: 30))
                path.addQuadCurve(to: CGPoint(x: 62, y: 52), control: CGPoint(x: 84, y: 48))
                path.addLine(to: CGPoint(x: 38, y: 52))
                path.addLine(to: CGPoint(x: 34, y: 68))
                path.addLine(to: CGPoint(x: 66, y: 68))
                path.addLine(to: CGPoint(x: 70, y: 86))
                path.addLine(to: CGPoint(x: 30, y: 86))
                path.addLine(to: CGPoint(x: 34, y: 52))
                path.addQuadCurve(to: CGPoint(x: 14, y: 30), control: CGPoint(x: 10, y: 40))
                path.closeSubpath()
            }
            GlyphFill(color: secondary) { path in
                path.addRoundedRect(in: CGRect(x: 14, y: 24, width: 72, height: 8), cornerSize: CGSize(width: 3, height: 3))
            }
        }
    }

    private var cannon: some View {
        ZStack {
            GlyphStroke(color: primary, width: 16) { path in
                path.move(to: CGPoint(x: 36, y: 64))
                path.addLine(to: CGPoint(x: 84, y: 22))
            }
            GlyphFill(color: secondary) { path in
                path.addEllipse(in: CGRect(x: 74, y: 12, width: 18, height: 18))
            }
            GlyphFill(color: primary) { path in
                path.addEllipse(in: CGRect(x: 14, y: 52, width: 40, height: 40))
            }
            GlyphFill(color: secondary) { path in
                path.addEllipse(in: CGRect(x: 26, y: 64, width: 16, height: 16))
            }
        }
    }

    private var lighthouse: some View {
        ZStack {
            GlyphStroke(color: secondary, width: 5) { path in
                path.move(to: CGPoint(x: 8, y: 22))
                path.addLine(to: CGPoint(x: 32, y: 30))
                path.move(to: CGPoint(x: 92, y: 22))
                path.addLine(to: CGPoint(x: 68, y: 30))
            }
            GlyphFill(color: secondary) { path in
                path.addEllipse(in: CGRect(x: 42, y: 10, width: 16, height: 16))
            }
            GlyphFill(color: primary, draw: poly([(40, 28), (60, 28), (68, 86), (32, 86)]))
            GlyphFill(color: secondary) { path in
                path.addRoundedRect(in: CGRect(x: 44, y: 44, width: 12, height: 12), cornerSize: CGSize(width: 3, height: 3))
            }
        }
    }

    private var star: some View {
        GlyphFill(color: primary) { path in
            let points = 5
            for index in 0..<points {
                let outerAngle = Double(index) / Double(points) * 2 * .pi - .pi / 2
                let innerAngle = outerAngle + .pi / Double(points)
                path.move(to: CGPoint(x: 50 + 42 * cos(outerAngle), y: 50 + 42 * sin(outerAngle)))
                path.addLine(to: CGPoint(x: 50 + 18 * cos(innerAngle), y: 50 + 18 * sin(innerAngle)))
                path.addLine(to: CGPoint(x: 50 + 42 * cos(outerAngle + 2 * .pi / Double(points)), y: 50 + 42 * sin(outerAngle + 2 * .pi / Double(points))))
                path.closeSubpath()
            }
        }
        .overlay {
            GlyphShape(draw: poly([(50, 30), (54, 46), (70, 46), (57, 56), (62, 72), (50, 62), (38, 72), (43, 56), (30, 46), (46, 46)]))
                .fill(secondary)
        }
    }

    private var flame: some View {
        ZStack {
            GlyphFill(color: primary) { path in
                path.move(to: CGPoint(x: 50, y: 4))
                path.addCurve(to: CGPoint(x: 78, y: 58), control1: CGPoint(x: 76, y: 24), control2: CGPoint(x: 82, y: 42))
                path.addCurve(to: CGPoint(x: 50, y: 94), control1: CGPoint(x: 76, y: 76), control2: CGPoint(x: 60, y: 94))
                path.addCurve(to: CGPoint(x: 22, y: 58), control1: CGPoint(x: 40, y: 94), control2: CGPoint(x: 24, y: 76))
                path.addCurve(to: CGPoint(x: 50, y: 4), control1: CGPoint(x: 18, y: 42), control2: CGPoint(x: 24, y: 24))
                path.closeSubpath()
            }
            GlyphFill(color: secondary) { path in
                path.move(to: CGPoint(x: 50, y: 44))
                path.addCurve(to: CGPoint(x: 62, y: 72), control1: CGPoint(x: 62, y: 56), control2: CGPoint(x: 60, y: 66))
                path.addCurve(to: CGPoint(x: 50, y: 84), control1: CGPoint(x: 58, y: 78), control2: CGPoint(x: 54, y: 84))
                path.addCurve(to: CGPoint(x: 38, y: 72), control1: CGPoint(x: 46, y: 84), control2: CGPoint(x: 40, y: 78))
                path.addCurve(to: CGPoint(x: 50, y: 44), control1: CGPoint(x: 40, y: 66), control2: CGPoint(x: 38, y: 56))
                path.closeSubpath()
            }
        }
    }

    private var wave: some View {
        ZStack {
            GlyphStroke(color: primary, width: 9) { path in
                path.move(to: CGPoint(x: 8, y: 38))
                path.addCurve(to: CGPoint(x: 50, y: 38), control1: CGPoint(x: 24, y: 16), control2: CGPoint(x: 34, y: 16))
                path.addCurve(to: CGPoint(x: 92, y: 38), control1: CGPoint(x: 66, y: 16), control2: CGPoint(x: 76, y: 16))
            }
            GlyphStroke(color: primary, width: 9) { path in
                path.move(to: CGPoint(x: 8, y: 68))
                path.addCurve(to: CGPoint(x: 50, y: 68), control1: CGPoint(x: 24, y: 46), control2: CGPoint(x: 34, y: 46))
                path.addCurve(to: CGPoint(x: 92, y: 68), control1: CGPoint(x: 66, y: 46), control2: CGPoint(x: 76, y: 46))
            }
            GlyphFill(color: secondary) { path in
                path.addEllipse(in: CGRect(x: 42, y: 80, width: 16, height: 16))
            }
        }
    }

    private var mountain: some View {
        ZStack {
            GlyphFill(color: primary, draw: poly([(4, 88), (36, 24), (58, 62), (70, 40), (96, 88)]))
            GlyphFill(color: secondary, draw: poly([(28, 40), (36, 24), (44, 40), (38, 44)]))
            GlyphFill(color: secondary, draw: poly([(64, 50), (70, 40), (76, 50), (70, 53)]))
        }
    }

    private var compass: some View {
        ZStack {
            GlyphFill(color: primary, draw: poly([(50, 6), (58, 42), (50, 50), (42, 42)]))
            GlyphFill(color: primary, draw: poly([(50, 94), (58, 58), (50, 50), (42, 58)]))
            GlyphFill(color: primary, draw: poly([(6, 50), (42, 42), (50, 50), (42, 58)]))
            GlyphFill(color: primary, draw: poly([(94, 50), (58, 42), (50, 50), (58, 58)]))
            GlyphFill(color: secondary) { path in
                path.addEllipse(in: CGRect(x: 42, y: 42, width: 16, height: 16))
            }
            GlyphFill(color: primary) { path in
                path.addEllipse(in: CGRect(x: 46, y: 46, width: 8, height: 8))
            }
        }
    }
}

#Preview("Logo sampler") {
    let ids = ["wolf", "bull", "lightning", "gear", "kraken", "shield", "comet", "compass"]
    return VStack {
        ForEach(0..<2, id: \.self) { row in
            HStack(spacing: 12) {
                ForEach(0..<4, id: \.self) { column in
                    TeamLogoGlyph(
                        logoID: ids[row * 4 + column],
                        primary: Color(hex: 0x1A1A1A),
                        secondary: Color(hex: 0xD9B56E)
                    )
                    .frame(width: 64, height: 64)
                }
            }
        }
    }
    .padding()
    .background(Color(hex: 0x241E17))
}

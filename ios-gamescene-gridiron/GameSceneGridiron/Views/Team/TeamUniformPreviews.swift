import SwiftUI

// MARK: - Emblem

/// A team's badge: the vector logo inside a dark roundel with a secondary ring
/// and gold rim. Used on team cards, previews and the result screen.
struct TeamEmblemView: View {
    let team: GameTeam
    var size: CGFloat = 64

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(hex: 0x35291A), Color(hex: 0x14100A)],
                        center: UnitPoint(x: 0.4, y: 0.3),
                        startRadius: 1,
                        endRadius: size * 0.7
                    )
                )
            TeamLogoGlyph(
                logoID: team.logoID,
                primary: team.primaryColor,
                secondary: team.secondaryColor
            )
            .padding(size * 0.18)
            Circle()
                .strokeBorder(team.secondaryColor, lineWidth: size * 0.05)
                .padding(size * 0.02)
            Circle()
                .strokeBorder(Theme.gold.opacity(0.8), lineWidth: size * 0.03)
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.5), radius: size * 0.08, y: 2)
        .accessibilityHidden(true)
    }
}

// MARK: - Helmet

/// Side-profile sample helmet that recolors with the team: primary shell,
/// secondary crown stripe, facemask hardware, and the signature dark visor.
struct TeamHelmetView: View {
    let team: GameTeam
    var size: CGFloat = 96

    var body: some View {
        ZStack {
            GlyphShape(draw: Self.shellPath)
                .fill(
                    LinearGradient(
                        colors: [team.primaryColor.lightened(0.25), team.primaryColor, team.primaryColor.darkened(0.3)],
                        startPoint: UnitPoint(x: 0.3, y: 0),
                        endPoint: UnitPoint(x: 0.7, y: 1)
                    )
                )
            GlyphStroke(color: team.secondaryColor, width: 6) { path in
                path.move(to: CGPoint(x: 46, y: 12))
                path.addCurve(to: CGPoint(x: 80, y: 40), control1: CGPoint(x: 62, y: 12), control2: CGPoint(x: 78, y: 22))
            }
            // Dark visor — always opaque, never shows a face.
            GlyphShape(draw: { path in
                path.addRoundedRect(in: CGRect(x: 46, y: 42, width: 40, height: 16), cornerSize: CGSize(width: 8, height: 8))
            })
            .fill(Color(hex: 0x11151C))
            .overlay {
                GlyphShape(draw: { path in
                    path.addRoundedRect(in: CGRect(x: 48, y: 44, width: 34, height: 4), cornerSize: CGSize(width: 2, height: 2))
                })
                .fill(Color.white.opacity(0.14))
            }
            // Facemask hardware.
            GlyphStroke(color: Color(hex: 0x9AA3AD), width: 4.5) { path in
                path.move(to: CGPoint(x: 70, y: 40))
                path.addLine(to: CGPoint(x: 92, y: 44))
                path.move(to: CGPoint(x: 70, y: 52))
                path.addLine(to: CGPoint(x: 90, y: 56))
                path.move(to: CGPoint(x: 66, y: 44))
                path.addLine(to: CGPoint(x: 66, y: 60))
            }
            GlyphFill(color: Color.black.opacity(0.35), draw: { path in
                path.addEllipse(in: CGRect(x: 38, y: 52, width: 12, height: 12))
            })
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private static let shellPath: (inout Path) -> Void = { path in
        path.move(to: CGPoint(x: 16, y: 58))
        path.addCurve(to: CGPoint(x: 30, y: 16), control1: CGPoint(x: 14, y: 34), control2: CGPoint(x: 20, y: 18))
        path.addCurve(to: CGPoint(x: 70, y: 12), control1: CGPoint(x: 42, y: 8), control2: CGPoint(x: 60, y: 6))
        path.addCurve(to: CGPoint(x: 88, y: 48), control1: CGPoint(x: 84, y: 16), control2: CGPoint(x: 92, y: 32))
        path.addLine(to: CGPoint(x: 88, y: 60))
        path.addQuadCurve(to: CGPoint(x: 72, y: 64), control: CGPoint(x: 82, y: 66))
        path.addLine(to: CGPoint(x: 72, y: 74))
        path.addQuadCurve(to: CGPoint(x: 40, y: 72), control: CGPoint(x: 56, y: 82))
        path.addCurve(to: CGPoint(x: 16, y: 58), control1: CGPoint(x: 24, y: 70), control2: CGPoint(x: 16, y: 68))
        path.closeSubpath()
    }
}

// MARK: - Jersey

/// Front-view sample jersey that recolors with the team: primary body, secondary
/// shoulders/collar, sleeve stripes and a big number in the kit's contrast color.
struct TeamJerseyView: View {
    let team: GameTeam
    var size: CGFloat = 96

    private var numberColor: Color { TeamKitResolver.contrastColor(on: team.primaryColorHex) }

    var body: some View {
        ZStack {
            // Sleeves.
            GlyphFill(
                color: team.secondaryColor,
                draw: poly([(6, 26), (26, 18), (30, 52), (16, 58)])
            )
            GlyphFill(
                color: team.secondaryColor,
                draw: poly([(94, 26), (74, 18), (70, 52), (84, 58)])
            )
            GlyphStroke(color: team.primaryColor, width: 4) { path in
                path.move(to: CGPoint(x: 10, y: 40))
                path.addLine(to: CGPoint(x: 26, y: 42))
                path.move(to: CGPoint(x: 90, y: 40))
                path.addLine(to: CGPoint(x: 74, y: 42))
            }
            // Torso.
            GlyphShape(draw: { path in
                path.move(to: CGPoint(x: 26, y: 18))
                path.addLine(to: CGPoint(x: 74, y: 18))
                path.addCurve(to: CGPoint(x: 86, y: 92), control1: CGPoint(x: 84, y: 40), control2: CGPoint(x: 88, y: 70))
                path.addLine(to: CGPoint(x: 14, y: 92))
                path.addCurve(to: CGPoint(x: 26, y: 18), control1: CGPoint(x: 12, y: 70), control2: CGPoint(x: 16, y: 40))
                path.closeSubpath()
            })
            .fill(
                LinearGradient(
                    colors: [team.primaryColor.lightened(0.18), team.primaryColor, team.primaryColor.darkened(0.25)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            // Shoulder yokes.
            GlyphFill(color: team.secondaryColor, draw: poly([(26, 18), (74, 18), (76, 34), (24, 34)]))
            // Collar.
            GlyphFill(color: team.primaryColor.darkened(0.4), draw: poly([(40, 18), (60, 18), (56, 28), (44, 28)]))
            // Number.
            Text("00")
                .font(.system(size: 34, weight: .black).width(.condensed))
                .foregroundStyle(numberColor)
                .position(x: 50, y: 62)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

// MARK: - Color helpers

extension Color {
    /// A lighter mix of this color, used for uniform gradient highlights.
    func lightened(_ amount: Double) -> Color {
        mix(with: .white, amount: amount)
    }

    /// A darker mix of this color, used for uniform gradient shading.
    func darkened(_ amount: Double) -> Color {
        mix(with: .black, amount: amount)
    }

    private func mix(with other: Color, amount: Double) -> Color {
        #if canImport(UIKit)
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        var otherRed: CGFloat = 0
        var otherGreen: CGFloat = 0
        var otherBlue: CGFloat = 0
        var otherAlpha: CGFloat = 0
        UIColor(other).getRed(&otherRed, green: &otherGreen, blue: &otherBlue, alpha: &otherAlpha)
        return Color(
            red: Double(red) + (Double(otherRed) - Double(red)) * amount,
            green: Double(green) + (Double(otherGreen) - Double(green)) * amount,
            blue: Double(blue) + (Double(otherBlue) - Double(blue)) * amount
        )
        #else
        return self
        #endif
    }
}

/// A compact horizontal lockup: emblem + full franchise name. Used on cards.
struct TeamLockupView: View {
    let team: GameTeam
    var emblemSize: CGFloat = 40
    var nameSize: CGFloat = 15

    var body: some View {
        HStack(spacing: 10) {
            TeamEmblemView(team: team, size: emblemSize)
            VStack(alignment: .leading, spacing: 2) {
                Text(team.teamName.uppercased())
                    .font(.system(size: nameSize, weight: .heavy).width(.condensed))
                    .tracking(1)
                    .foregroundStyle(Theme.goldLight)
                    .lineLimit(1)
                Text(team.state.uppercased())
                    .font(Theme.typewriter(max(9, nameSize * 0.6), relativeTo: .caption2))
                    .tracking(1.5)
                    .foregroundStyle(Theme.paperInkSoft.opacity(0.9))
                    .lineLimit(1)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(team.state) \(team.teamName)")
    }
}

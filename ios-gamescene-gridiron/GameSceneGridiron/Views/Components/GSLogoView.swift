import SwiftUI

struct ShieldShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.13))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.5))
        path.addQuadCurve(
            to: CGPoint(x: rect.midX, y: rect.maxY),
            control: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.86)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.5),
            control: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.86)
        )
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.13))
        path.closeSubpath()
        return path
    }
}

/// Tiny football glyph drawn with shapes.
struct FootballGlyph: View {
    var color: Color = Theme.gold

    var body: some View {
        ZStack {
            Ellipse().fill(color)
            Rectangle()
                .fill(Theme.ink)
                .frame(width: 1.2)
                .padding(.vertical, 3)
                .rotationEffect(.degrees(90))
                .scaleEffect(x: 1, y: 0.45)
            HStack(spacing: 2) {
                ForEach(0..<3, id: \.self) { _ in
                    Rectangle().fill(Theme.ink).frame(width: 1, height: 4)
                }
            }
        }
        .accessibilityHidden(true)
    }
}

/// The GS shield mark.
struct GSShieldMark: View {
    var size: CGFloat = 76

    var body: some View {
        ZStack {
            ShieldShape()
                .fill(
                    LinearGradient(colors: [Color(hex: 0x2A231A), Color(hex: 0x0F0D0A)], startPoint: .top, endPoint: .bottom)
                )
            ShieldShape()
                .stroke(Theme.goldGradient, lineWidth: size * 0.05)
            ShieldShape()
                .inset(by: size * 0.09)
                .stroke(Theme.gold.opacity(0.45), lineWidth: 1)
            VStack(spacing: size * 0.02) {
                Text("GS")
                    .font(.system(size: size * 0.42, weight: .black, design: .serif))
                    .foregroundStyle(Theme.goldGradient)
                    .shadow(color: .black.opacity(0.8), radius: 1, y: 1)
                FootballGlyph()
                    .frame(width: size * 0.26, height: size * 0.13)
            }
            .offset(y: -size * 0.03)
        }
        .frame(width: size * 0.86, height: size)
        .shadow(color: Theme.bronze.opacity(0.35), radius: 14)
        .accessibilityHidden(true)
    }
}

extension ShieldShape: InsettableShape {
    func inset(by amount: CGFloat) -> some InsettableShape {
        InsetShield(inset: amount)
    }
}

struct InsetShield: InsettableShape {
    var inset: CGFloat

    func path(in rect: CGRect) -> Path {
        ShieldShape().path(in: rect.insetBy(dx: inset, dy: inset))
    }

    func inset(by amount: CGFloat) -> InsetShield {
        InsetShield(inset: inset + amount)
    }
}

/// Full logo lockup: shield + GAMESCENE / GRIDIRON wordmark.
struct GSLogoView: View {
    var scale: CGFloat = 1

    var body: some View {
        HStack(spacing: 14 * scale) {
            GSShieldMark(size: 78 * scale)
            VStack(alignment: .center, spacing: 4 * scale) {
                Text("GAMESCENE")
                    .font(.system(size: 31 * scale, weight: .black, design: .serif))
                    .foregroundStyle(Theme.goldGradient)
                    .shadow(color: .black.opacity(0.7), radius: 2, y: 2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                HStack(spacing: 8 * scale) {
                    Rectangle().fill(Theme.gold.opacity(0.7)).frame(width: 18 * scale, height: 1.5)
                    Text("GRIDIRON")
                        .font(.system(size: 15 * scale, weight: .semibold, design: .serif))
                        .tracking(6 * scale)
                        .foregroundStyle(Theme.silver)
                    Rectangle().fill(Theme.gold.opacity(0.7)).frame(width: 18 * scale, height: 1.5)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("GameScene: Gridiron")
        .accessibilityAddTraits(.isHeader)
    }
}

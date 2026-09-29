import SwiftUI

/// Temporary, unlabeled mystery location styled as the glowing "?" ghost from the
/// reference look. Only visible while dragging (or while flashing a rejection).
struct PlacementZoneView: View {
    let isHovered: Bool
    let isRejected: Bool
    var size: CGFloat = 38

    private static let ghostImage = UIImage(named: "ghost_football_player_question")

    @State private var pulse: Bool = false

    private var tint: Color {
        if isRejected { return Theme.danger }
        return isHovered ? Theme.success : Theme.gold
    }

    var body: some View {
        Group {
            if let ghost = Self.ghostImage {
                ghostZone(ghost)
            } else {
                vectorZone
            }
        }
        .frame(width: size, height: size * 1.3)
        .scaleEffect(isHovered ? 1.22 : 1)
        .animation(.spring(response: 0.25, dampingFraction: 0.6), value: isHovered)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { pulse = true }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Rendered spectral silhouette with the built-in "?" and a tinted halo.
    private func ghostZone(_ ghost: UIImage) -> some View {
        ZStack {
            Ellipse()
                .fill(tint.opacity(isHovered || isRejected ? 0.5 : 0.25))
                .blur(radius: 6)
                .scaleEffect(pulse ? 1.2 : 0.95)
            Image(uiImage: ghost)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .opacity(isHovered || isRejected ? 1 : 0.88)
        }
    }

    /// Vector fallback: pulsing ring, ghosted figure and a "?".
    private var vectorZone: some View {
        ZStack {
            Circle()
                .fill(tint.opacity(isHovered || isRejected ? 0.4 : 0.16))
                .blur(radius: 4)
                .scaleEffect(pulse ? 1.15 : 0.95)
            Circle()
                .strokeBorder(tint.opacity(0.9), style: StrokeStyle(lineWidth: 1.5, dash: isHovered ? [] : [4, 3]))
            Image(systemName: "person.fill")
                .font(.system(size: size * 0.46))
                .foregroundStyle(Color.white.opacity(0.18))
            Text("?")
                .font(.system(size: size * 0.42, weight: .heavy, design: .serif))
                .foregroundStyle(tint)
                .shadow(color: .black.opacity(0.7), radius: 1)
        }
        .frame(width: size, height: size)
    }
}

/// Horizontal shake driven by an incrementing counter.
struct ShakeEffect: GeometryEffect {
    var travel: CGFloat = 7
    var shakes: CGFloat = 4
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: travel * sin(animatableData * .pi * shakes), y: 0))
    }
}

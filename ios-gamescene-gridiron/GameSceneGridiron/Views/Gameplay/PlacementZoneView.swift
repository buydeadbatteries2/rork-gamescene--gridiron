import SwiftUI

/// Temporary, unlabeled mystery location. Only visible while dragging (or while
/// flashing a rejection). Compact by design: the visible circle is smaller than
/// its interactive hit area, and neighboring zones are de-overlapped by
/// `PlacementZoneLayout`, so targets feel precise rather than fuzzy.
struct PlacementZoneView: View {
    let isHovered: Bool
    let isRejected: Bool
    /// Faded while a different target is hovered, so the active one reads instantly.
    var isDimmed: Bool = false
    var size: CGFloat = 28

    @State private var pulse: Bool = false

    private var tint: Color {
        if isRejected { return Theme.danger }
        return isHovered ? Theme.success : Theme.gold
    }

    private var fillOpacity: Double {
        if isDimmed { return 0.06 }
        return isHovered || isRejected ? 0.42 : 0.16
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(tint.opacity(fillOpacity))
                .blur(radius: isHovered || isRejected ? 3 : 2)
                .scaleEffect(pulse ? 1.08 : 0.94)
            Circle()
                .strokeBorder(
                    tint.opacity(isDimmed ? 0.3 : 0.9),
                    style: StrokeStyle(lineWidth: isHovered ? 2 : 1.4, dash: isHovered ? [] : [4, 3])
                )
            Image(systemName: "person.fill")
                .font(.system(size: size * 0.42))
                .foregroundStyle(Color.white.opacity(isDimmed ? 0.08 : 0.16))
            Text("?")
                .font(.system(size: size * 0.48, weight: .heavy, design: .serif))
                .foregroundStyle(tint.opacity(isDimmed ? 0.4 : 1))
                .shadow(color: .black.opacity(0.7), radius: 1)
        }
        .frame(width: size, height: size)
        .scaleEffect(isHovered ? 1.28 : 1)
        .shadow(color: isHovered || isRejected ? tint.opacity(0.55) : .clear, radius: 7)
        .animation(.spring(response: 0.25, dampingFraction: 0.6), value: isHovered)
        .animation(.easeOut(duration: 0.18), value: isDimmed)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { pulse = true }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Subtle ring drawn at a hovered target's TRUE field point — the snap preview.
/// The displayed marker may sit a few points off for readability, but the
/// dragged player magnetizes toward and snaps onto this ring's center.
struct SnapPreviewRing: View {
    var tint: Color = Theme.success

    @State private var isPulsing: Bool = false

    var body: some View {
        Circle()
            .fill(tint.opacity(0.14))
            .background(Circle().strokeBorder(tint.opacity(0.85), lineWidth: 2))
            .scaleEffect(isPulsing ? 1.15 : 0.9)
            .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: isPulsing)
            .onAppear { isPulsing = true }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
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

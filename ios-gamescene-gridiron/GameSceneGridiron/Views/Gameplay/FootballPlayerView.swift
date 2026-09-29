import SwiftUI
import UIKit

/// Compact football-player piece. Uses the rendered mini-athlete busts (offense
/// black/gold, defense white/navy — plain logo-free kits, dark opaque visor, no face)
/// with a position-colored base badge; falls back to the vector marker if the art is
/// missing. Offense reads dark, defense reads white at a glance.
struct FootballPlayerView: View {
    let position: FootballPosition
    var size: CGFloat = 24
    var variant: PlayerVariant?
    var isHighlighted: Bool = false

    private var isOffense: Bool { position.side == .offense }
    private var tokenImageName: String { isOffense ? "football_player_figure" : "football_player_figure_2" }
    private var usesRenderedToken: Bool { UIImage(named: tokenImageName) != nil }
    private var arch: HelmetArch { HelmetArch(position: position) }
    private var helmetDiameter: CGFloat { size * 0.64 * arch.helmetScale }
    private var facemaskColor: Color { isOffense ? Color(hex: 0xC9A25A) : Color(hex: 0x8B97A3) }

    var body: some View {
        ZStack {
            if usesRenderedToken {
                renderedToken
            } else {
                vectorToken
            }
        }
        .frame(width: size * 1.1, height: size * 1.42)
        .overlay(alignment: .topTrailing) {
            if let variant {
                Image(systemName: variant.symbol)
                    .font(.system(size: size * 0.26, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: size * 0.44, height: size * 0.44)
                    .background(Theme.goldGradient, in: .circle)
                    .offset(x: size * 0.06, y: isOffense ? -size * 0.38 : size * 0.06)
            }
        }
        .background {
            if isHighlighted {
                Circle()
                    .fill(Theme.success.opacity(0.35))
                    .frame(width: size * 1.9, height: size * 1.9)
                    .blur(radius: 6)
                Circle()
                    .strokeBorder(Theme.gold, lineWidth: 1.5)
                    .frame(width: size * 1.5, height: size * 1.5)
            }
        }
        .shadow(color: .black.opacity(0.45), radius: 2.5, y: 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    /// Rendered mini-athlete with a position-colored base tag.
    private var renderedToken: some View {
        VStack(spacing: 1) {
            Color.clear
                .frame(width: size * 1.05, height: size * 1.05)
                .overlay {
                    Image(tokenImageName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .allowsHitTesting(false)
                }
            Text(position.rawValue)
                .font(.system(size: size * 0.28, weight: .heavy).width(.condensed))
                .foregroundStyle(Color.white.opacity(0.95))
                .padding(.horizontal, size * 0.12)
                .padding(.vertical, size * 0.02)
                .background(Theme.positionAccent(position).opacity(0.92), in: .capsule)
                .shadow(color: .black.opacity(0.55), radius: 1.5)
                .offset(y: -size * 0.02)
        }
        .frame(width: size * 1.1, alignment: .top)
    }

    /// Vector fallback (original marker) used when the rendered art is unavailable.
    private var vectorToken: some View {
        ZStack(alignment: .center) {
            Capsule()
                .fill(bodyColor)
                .frame(width: size * 1.04 * arch.shoulderScale, height: size * 0.44)
                .offset(y: facesUp ? size * 0.18 : -size * 0.18)
                .shadow(color: .black.opacity(0.55), radius: 2, x: 1, y: 1)
            Capsule()
                .fill(bodyColor)
                .frame(width: size * 0.7 * min(arch.shoulderScale, 1.1), height: size * 0.6)
                .offset(y: facesUp ? size * 0.32 : -size * 0.32)
            Circle()
                .fill(
                    RadialGradient(
                        colors: isOffense
                            ? [Color(hex: 0x4A3F30), Color(hex: 0x0E0C09)]
                            : [Color.white, Color(hex: 0xA9B0B7)],
                        center: UnitPoint(x: 0.35, y: 0.3),
                        startRadius: 1,
                        endRadius: size * 0.6
                    )
                )
                .frame(width: helmetDiameter, height: helmetDiameter)
                .overlay {
                    Capsule()
                        .fill(Color(hex: 0x11151C))
                        .frame(width: helmetDiameter * 0.56 * arch.visorScale, height: helmetDiameter * 0.26)
                        .offset(y: facesUp ? -helmetDiameter * 0.14 : helmetDiameter * 0.14)
                    Capsule()
                        .fill(facemaskColor)
                        .frame(width: helmetDiameter * 0.48, height: max(1.2, size * 0.08))
                        .offset(y: facesUp ? -helmetDiameter * 0.3 : helmetDiameter * 0.3)
                }
                .clipShape(.circle)
                .overlay {
                    Circle().strokeBorder(isOffense ? Theme.gold.opacity(0.85) : Color(hex: 0x3B4A5C), lineWidth: 1.2)
                }
                .offset(y: facesUp ? -size * 0.3 : size * 0.3)
            Text(position.rawValue)
                .font(.system(size: size * 0.3, weight: .heavy).width(.condensed))
                .foregroundStyle(isOffense ? Theme.goldLight : Color(hex: 0x1E2A38))
                .minimumScaleFactor(0.5)
                .offset(y: facesUp ? size * 0.32 : -size * 0.32)
        }
    }

    /// Direction the helmet points in the fallback: offense up, defense down.
    private var facesUp: Bool { isOffense }

    private var bodyColor: Color {
        isOffense ? Color(hex: 0x15120E) : Color(hex: 0xE9ECEF)
    }

    private var accessibilityText: String {
        let side = isOffense ? "Offense" : "Defense"
        if let variant { return "\(side) \(position.fullName), \(variant.title)" }
        return "\(side) \(position.fullName)"
    }
}

/// The avatar that follows the finger while dragging a missing player.
struct DraggedPlayerToken: View {
    let player: FootballPlayer
    let variant: PlayerVariant?
    let isOverSlot: Bool

    var body: some View {
        VStack(spacing: 3) {
            Color(hex: 0x1A1510)
                .frame(width: 52, height: 52)
                .overlay {
                    Image(player.cardAsset)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .allowsHitTesting(false)
                }
                .clipShape(.circle)
                .overlay {
                    Circle().strokeBorder(isOverSlot ? Theme.success : Theme.gold, lineWidth: 2.5)
                }
                .overlay(alignment: .topTrailing) {
                    if let variant {
                        Image(systemName: variant.symbol)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Theme.ink)
                            .frame(width: 20, height: 20)
                            .background(Theme.goldGradient, in: .circle)
                            .offset(x: 4, y: -2)
                    }
                }
                .shadow(color: (isOverSlot ? Theme.success : Theme.gold).opacity(0.7), radius: 12)
            Text(player.position.rawValue)
                .font(.system(size: 11, weight: .heavy).width(.condensed))
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 6)
                .padding(.vertical, 1)
                .background(Theme.goldGradient, in: .capsule)
        }
        .scaleEffect(isOverSlot ? 1.08 : 1)
        .animation(.spring(response: 0.25, dampingFraction: 0.6), value: isOverSlot)
        .shadow(color: .black.opacity(0.6), radius: 10, y: 12)
        .allowsHitTesting(false)
    }
}

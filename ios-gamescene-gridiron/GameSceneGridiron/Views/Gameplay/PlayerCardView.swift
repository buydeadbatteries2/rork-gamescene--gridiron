import SwiftUI

/// Premium roster card for a missing player: realistic visored portrait over a
/// position-colored spotlight, name plaque, position accent strip at the base.
/// Tap to reveal variants; press-and-hold and drag to place.
struct PlayerCardView: View {
    let player: FootballPlayer
    /// Team primary color multiplied over the controlled body asset so the
    /// fictional franchise recolors its players. Nil keeps the neutral base.
    var tint: Color?
    let isExpanded: Bool
    let selectedVariant: PlayerVariant?
    let isBeingDragged: Bool
    let onToggle: () -> Void
    let onSelectVariant: (PlayerVariant) -> Void

    private var accent: Color { Theme.positionAccent(player.position) }
    private var cardWidth: CGFloat { isExpanded ? 192 : 112 }
    private var portraitHeight: CGFloat { isExpanded ? 78 : 92 }

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onToggle) {
                VStack(spacing: 0) {
                    portrait
                    namePlaque
                }
                .contentShape(.rect)
            }
            .buttonStyle(PressableButtonStyle(scale: 0.97))
            .accessibilityLabel("\(player.position.fullName), \(player.shortName)")
            .accessibilityValue(selectedVariant.map { "\($0.title) selected" } ?? "No profile selected")
            .accessibilityHint(isExpanded ? "Collapse" : "Show Fast, Power and Veteran profiles")

            if isExpanded {
                variantChips
                    .padding(.top, 8)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))

                instruction
            }

            accentBar
        }
        .frame(width: cardWidth)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: 0x2E271E), Color(hex: 0x14110D)], startPoint: .top, endPoint: .bottom))
        }
        .clipShape(.rect(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    isExpanded ? AnyShapeStyle(accent) : AnyShapeStyle(Color.white.opacity(0.14)),
                    lineWidth: isExpanded ? 1.6 : 1
                )
        }
        .shadow(color: .black.opacity(0.45), radius: isExpanded ? 14 : 6, y: 4)
        .shadow(color: accent.opacity(isExpanded ? 0.4 : 0.18), radius: isExpanded ? 12 : 6, y: 2)
        .opacity(isBeingDragged ? 0.35 : 1)
        .scaleEffect(isBeingDragged ? 0.95 : 1)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isExpanded)
        .animation(.easeOut(duration: 0.2), value: isBeingDragged)
    }

    // MARK: Portrait

    private var portrait: some View {
        Color(hex: 0x14110D)
            .frame(height: portraitHeight)
            .overlay {
                // Position-colored spotlight behind the athlete, collectible style.
                RadialGradient(
                    colors: [accent.opacity(0.38), .clear],
                    center: UnitPoint(x: 0.5, y: 0.3),
                    startRadius: 2,
                    endRadius: cardWidth * 0.8
                )
                .allowsHitTesting(false)
            }
            .overlay {
                Image(player.cardAsset)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .colorMultiply(tint ?? .white)
                    .allowsHitTesting(false)
            }
            .overlay {
                LinearGradient(
                    colors: [.clear, .clear, Color(hex: 0x14110D)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .allowsHitTesting(false)
            }
            .clipped()
            .overlay(alignment: .topLeading) {
                // Premium glass sheen across the top of the portrait.
                LinearGradient(colors: [.white.opacity(0.12), .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: portraitHeight * 0.4)
                    .allowsHitTesting(false)
            }
            .overlay(alignment: .topTrailing) {
                if let selectedVariant {
                    Image(systemName: selectedVariant.symbol)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Theme.ink)
                        .frame(width: 22, height: 22)
                        .background(Theme.goldGradient, in: .circle)
                        .padding(6)
                }
            }
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(accent.opacity(0.6))
                    .frame(height: 1)
                    .allowsHitTesting(false)
            }
    }

    // MARK: Name plaque

    private var namePlaque: some View {
        HStack(spacing: 5) {
            Text(player.position.rawValue)
                .font(.system(size: 10.5, weight: .heavy).width(.condensed))
                .tracking(0.8)
                .foregroundStyle(Color.white.opacity(0.95))
                .padding(.horizontal, 5)
                .padding(.vertical, 1.5)
                .background(accent.opacity(0.9), in: .rect(cornerRadius: 3))
            Text(player.shortName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.95))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 6)
        .frame(height: 24)
        .frame(maxWidth: .infinity)
        .background(Color(hex: 0x0F0D0A))
    }

    // MARK: Variant selection

    private var variantChips: some View {
        HStack(spacing: 5) {
            ForEach(PlayerVariant.allCases) { variant in
                let isSelected = selectedVariant == variant
                let accent = Theme.variantColor(variant)
                Button { onSelectVariant(variant) } label: {
                    Text(variant.title.uppercased())
                        .font(.system(size: 10.5, weight: .bold).width(.condensed))
                        .tracking(0.6)
                        .foregroundStyle(
                            isSelected
                                ? (variant == .veteran ? Theme.ink : Color.white)
                                : Color.white.opacity(0.75)
                        )
                        .frame(maxWidth: .infinity)
                        .frame(height: 30)
                        .background {
                            Capsule().fill(isSelected ? AnyShapeStyle(accent) : AnyShapeStyle(Color.white.opacity(0.08)))
                        }
                        .overlay {
                            Capsule().strokeBorder(isSelected ? Color.clear : accent.opacity(0.55), lineWidth: 1)
                        }
                        .contentShape(.capsule)
                }
                .buttonStyle(PressableButtonStyle(scale: 0.92))
                .accessibilityLabel("\(variant.title): \(variant.summary)")
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 2)
    }

    private var instruction: some View {
        Text(selectedVariant == nil ? "Pick a profile, then hold to drag" : "Hold & drag up to the field")
            .font(Theme.typewriter(9.5, relativeTo: .caption2))
            .foregroundStyle(Theme.goldLight.opacity(0.7))
            .padding(.bottom, 7)
    }

    // MARK: Accent strip

    /// Colored base strip keyed to the position group — the card's signature accent.
    private var accentBar: some View {
        Rectangle()
            .fill(Theme.positionAccentGradient(player.position))
            .frame(height: 4.5)
    }
}

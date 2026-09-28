import SwiftUI

/// Compact roster card for a missing player. Tap to reveal variants; long-press and drag to place.
struct PlayerCardView: View {
    let player: FootballPlayer
    let isExpanded: Bool
    let selectedVariant: PlayerVariant?
    let isBeingDragged: Bool
    let onToggle: () -> Void
    let onSelectVariant: (PlayerVariant) -> Void

    private var cardWidth: CGFloat { isExpanded ? 192 : 112 }

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onToggle) {
                VStack(spacing: 2) {
                    // Realistic roster portrait: helmet + opaque dark visor, face never visible.
                    Color(hex: 0x14110D)
                        .frame(height: isExpanded ? 74 : 88)
                        .overlay {
                            Image(player.cardAsset)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
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
                        .overlay {
                            LinearGradient(
                                colors: [.clear, .black.opacity(0.3)],
                                startPoint: .center,
                                endPoint: .bottom
                            )
                            .allowsHitTesting(false)
                        }
                        .clipped()
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

                    Text(player.position.rawValue)
                        .font(.system(size: 12, weight: .heavy).width(.condensed))
                        .tracking(1)
                        .foregroundStyle(Theme.gold)
                    Text(player.shortName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.95))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .padding(.horizontal, 6)
                }
                .padding(.bottom, isExpanded ? 6 : 10)
                .contentShape(.rect)
            }
            .buttonStyle(PressableButtonStyle(scale: 0.97))
            .accessibilityLabel("\(player.position.fullName), \(player.shortName)")
            .accessibilityValue(selectedVariant.map { "\($0.title) selected" } ?? "No profile selected")
            .accessibilityHint(isExpanded ? "Collapse" : "Show Fast, Power and Veteran profiles")

            if isExpanded {
                HStack(spacing: 5) {
                    ForEach(PlayerVariant.allCases) { variant in
                        let isSelected = selectedVariant == variant
                        Button { onSelectVariant(variant) } label: {
                            Text(variant.title.uppercased())
                                .font(.system(size: 10.5, weight: .bold).width(.condensed))
                                .tracking(0.6)
                                .foregroundStyle(isSelected ? Theme.ink : Color.white.opacity(0.75))
                                .frame(maxWidth: .infinity)
                                .frame(height: 30)
                                .background {
                                    Capsule().fill(isSelected ? AnyShapeStyle(Theme.goldGradient) : AnyShapeStyle(Color.white.opacity(0.08)))
                                }
                                .overlay {
                                    Capsule().strokeBorder(isSelected ? Color.clear : Color.white.opacity(0.18), lineWidth: 1)
                                }
                                .contentShape(.capsule)
                        }
                        .buttonStyle(PressableButtonStyle(scale: 0.92))
                        .accessibilityLabel("\(variant.title): \(variant.summary)")
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
                .transition(.opacity.combined(with: .move(edge: .bottom)))

                Text(selectedVariant == nil ? "Pick a profile, then hold to drag" : "Hold & drag up to the field")
                    .font(Theme.typewriter(9.5, relativeTo: .caption2))
                    .foregroundStyle(Theme.goldLight.opacity(0.7))
                    .padding(.bottom, 7)
            }
        }
        .frame(width: cardWidth)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: 0x2A231A), Color(hex: 0x14110D)], startPoint: .top, endPoint: .bottom))
        }
        .clipShape(.rect(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    isExpanded ? AnyShapeStyle(Theme.goldGradient) : AnyShapeStyle(Color.white.opacity(0.12)),
                    lineWidth: isExpanded ? 1.6 : 1
                )
        }
        .shadow(color: isExpanded ? Theme.bronze.opacity(0.45) : .black.opacity(0.4), radius: isExpanded ? 12 : 5, y: 3)
        .opacity(isBeingDragged ? 0.35 : 1)
        .scaleEffect(isBeingDragged ? 0.95 : 1)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isExpanded)
        .animation(.easeOut(duration: 0.2), value: isBeingDragged)
    }
}

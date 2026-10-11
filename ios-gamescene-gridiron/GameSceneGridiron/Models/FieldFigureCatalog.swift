import Foundation

/// The on-field player figures: photoreal, fully geared athletes in a plain
/// white generic uniform (blank helmet, blank jersey, no numbers, no brands)
/// that recolor programmatically into each team's kit.
///
/// Facing contract — locked by tests:
/// - OFFENSE lines up at the bottom and faces up-field, so every offensive
///   figure is rendered from BEHIND (back of helmet and jersey).
/// - DEFENSE lines up at the top and faces the offense, so every defensive
///   figure is rendered from the FRONT (facemask + dark visor toward us).
nonisolated enum FieldFigureCatalog {
    nonisolated enum Facing: String, Sendable {
        /// Camera behind the player — the back of the helmet and jersey show.
        case back
        /// Camera in front of the player — facemask and visor show.
        case front
    }

    nonisolated struct Figure: Hashable, Sendable {
        /// Bundled asset name (`UIImage(named:)` / SwiftUI `Image`).
        let asset: String
        let facing: Facing
        let stance: String
    }

    /// Exactly one figure per position group. Safeties share the deep
    /// defensive-back body; no per-team or per-player art is ever generated.
    static func figure(for position: FootballPosition) -> Figure {
        switch position {
        case .qb: Figure(asset: "field_qb_back", facing: .back, stance: "Under center, ready for the snap")
        case .rb: Figure(asset: "field_rb_back", facing: .back, stance: "Two-point stance, hands on knees")
        case .wr: Figure(asset: "field_wr_back", facing: .back, stance: "Split-out sprinter's stance")
        case .te: Figure(asset: "field_te_back", facing: .back, stance: "Low crouched stance on the line")
        case .ol: Figure(asset: "field_ol_back", facing: .back, stance: "Three-point stance, hand down")
        case .dl: Figure(asset: "field_dl_front", facing: .front, stance: "Four-point stance, head up")
        case .lb: Figure(asset: "field_lb_front", facing: .front, stance: "Two-point ready stance")
        case .cb: Figure(asset: "field_cb_front", facing: .front, stance: "Press-coverage stance")
        case .ss, .fs: Figure(asset: "field_s_front", facing: .front, stance: "Upright deep-zone stance")
        }
    }

    /// The facing a position's figure must have: offense from behind, defense
    /// from the front.
    static func requiredFacing(for position: FootballPosition) -> Facing {
        position.side == .offense ? .back : .front
    }

    /// Every distinct bundled figure asset.
    static var allAssets: [String] {
        var seen: Set<String> = []
        return FootballPosition.allCases.compactMap { position in
            let asset = figure(for: position).asset
            return seen.insert(asset).inserted ? asset : nil
        }
    }
}

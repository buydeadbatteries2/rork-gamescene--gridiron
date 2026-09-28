import Foundation

/// A physical object left on the field. Clues reference these to pin down locations.
nonisolated struct EvidenceItem: Identifiable, Hashable, Sendable {
    nonisolated enum Kind: String, Hashable, Sendable {
        case orangeTowel
        case droppedGlove
        case waterBottle
        case muddyFootprints
        case looseFootball

        var title: String {
            switch self {
            case .orangeTowel: "Orange Towel"
            case .droppedGlove: "Dropped Glove"
            case .waterBottle: "Water Bottle"
            case .muddyFootprints: "Muddy Footprints"
            case .looseFootball: "Loose Football"
            }
        }
    }

    let id: String
    let kind: Kind
    let x: Double
    let y: Double
    /// Rotation in degrees so objects look dropped rather than placed.
    let rotation: Double
}

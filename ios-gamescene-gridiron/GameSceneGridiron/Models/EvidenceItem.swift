import Foundation

/// A physical object left on the field. Clues reference these to pin down locations.
/// The library is deliberately broad — equipment, sideline gear and field damage —
/// so every case file reads like a fresh scene, not the same five props.
nonisolated struct EvidenceItem: Identifiable, Hashable, Sendable {
    nonisolated enum Kind: String, Hashable, Sendable {
        // Legacy core objects
        case orangeTowel
        case droppedGlove
        case waterBottle
        case muddyFootprints
        case looseFootball

        // Equipment
        case mouthguard
        case wristPlaybook
        case chinStrap
        case brokenHelmetStrap
        case looseCleat
        case kickingTee
        case handWarmer
        case shoulderPadStrap
        case kneeBrace
        case visorCloth
        case tapeRoll
        case wristband
        case sportsDrinkCup
        case droppedPlayCard

        // Sideline / coaching
        case clipboard
        case laminatedPlaySheet
        case headset
        case challengeFlag
        case markerBoard
        case whistle
        case equipmentBag
        case orangeCone
        case pylon
        case yardMarker
        case chainMarker

        // Field damage / marks
        case skidMarks
        case tornTurf
        case grassStain
        case cleatMarks
        case divot
        case chalkMark
        case wetPatch
        case draggedFootTrail

        var title: String {
            switch self {
            case .orangeTowel: "Orange Towel"
            case .droppedGlove: "Dropped Glove"
            case .waterBottle: "Water Bottle"
            case .muddyFootprints: "Muddy Footprints"
            case .looseFootball: "Loose Football"
            case .mouthguard: "Mouthguard"
            case .wristPlaybook: "Wrist Playbook"
            case .chinStrap: "Chin Strap"
            case .brokenHelmetStrap: "Broken Helmet Strap"
            case .looseCleat: "Loose Cleat"
            case .kickingTee: "Kicking Tee"
            case .handWarmer: "Hand Warmer"
            case .shoulderPadStrap: "Shoulder-Pad Strap"
            case .kneeBrace: "Knee Brace"
            case .visorCloth: "Visor Cloth"
            case .tapeRoll: "Tape Roll"
            case .wristband: "Wristband"
            case .sportsDrinkCup: "Sports Drink Cup"
            case .droppedPlayCard: "Dropped Play Card"
            case .clipboard: "Clipboard"
            case .laminatedPlaySheet: "Laminated Play Sheet"
            case .headset: "Headset"
            case .challengeFlag: "Challenge Flag"
            case .markerBoard: "Marker Board"
            case .whistle: "Whistle"
            case .equipmentBag: "Equipment Bag"
            case .orangeCone: "Orange Cone"
            case .pylon: "Pylon"
            case .yardMarker: "Yard Marker"
            case .chainMarker: "Chain Marker"
            case .skidMarks: "Skid Marks"
            case .tornTurf: "Torn Turf"
            case .grassStain: "Grass Stain"
            case .cleatMarks: "Cleat Marks"
            case .divot: "Divot"
            case .chalkMark: "Chalk Mark"
            case .wetPatch: "Wet Patch"
            case .draggedFootTrail: "Dragged-Foot Trail"
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

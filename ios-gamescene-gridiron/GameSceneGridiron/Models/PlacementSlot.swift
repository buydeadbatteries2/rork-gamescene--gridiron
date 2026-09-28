import Foundation

/// A hidden location on the field. Only revealed (without labels) while dragging.
nonisolated struct PlacementSlot: Identifiable, Hashable, Sendable {
    let id: String
    let x: Double
    let y: Double
}

/// The single correct answer for one missing player.
nonisolated struct PlacementSolution: Hashable, Sendable {
    let slotID: String
    let variant: PlayerVariant
}

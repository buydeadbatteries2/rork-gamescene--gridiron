import Foundation

/// A complete, self-contained quarter mystery. Swap in new definitions to add puzzles.
nonisolated struct QuarterPuzzle: Identifiable, Hashable, Sendable {
    let id: String
    let quarterLabel: String
    let title: String
    let startingLives: Int
    let startingHints: Int
    let visiblePlayers: [FieldPlayer]
    let missingPlayers: [FootballPlayer]
    let evidence: [EvidenceItem]
    let slots: [PlacementSlot]
    let clues: [PuzzleClue]
    let hints: [PuzzleHint]
    /// Keyed by `FootballPlayer.id`.
    let solutions: [String: PlacementSolution]

    func slot(id: String) -> PlacementSlot? {
        slots.first { $0.id == id }
    }

    func player(id: String) -> FootballPlayer? {
        missingPlayers.first { $0.id == id }
    }

    /// Validates that each missing player maps to a unique slot. Useful when authoring puzzles.
    var isWellFormed: Bool {
        let slotIDs = solutions.values.map(\.slotID)
        return Set(slotIDs).count == slotIDs.count
            && solutions.count == missingPlayers.count
            && slotIDs.allSatisfy { slot(id: $0) != nil }
    }
}

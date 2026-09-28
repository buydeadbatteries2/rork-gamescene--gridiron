import Foundation

nonisolated enum ClueDifficulty: String, Hashable, Sendable {
    case easy
    case medium
    case hard

    var title: String { rawValue.uppercased() }
}

/// A written clue in the case file. `playerID` links it to the deduction it unlocks.
nonisolated struct PuzzleClue: Identifiable, Hashable, Sendable {
    let id: Int
    let text: String
    let difficulty: ClueDifficulty
    let playerID: String
}

/// An extra deduction the player can unlock with a hint. Never states the full answer.
nonisolated struct PuzzleHint: Identifiable, Hashable, Sendable {
    let id: String
    let playerID: String
    let text: String
}

/// A hint the player has already spent.
nonisolated struct UsedHint: Identifiable, Hashable, Sendable {
    let id: String
    let playerID: String
    let text: String
    let date: Date
}

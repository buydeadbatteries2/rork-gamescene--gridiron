import Foundation

/// A named, fictional player who is missing from the field and must be deduced.
nonisolated struct FootballPlayer: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let position: FootballPosition
    let portraitAsset: String

    var side: TeamSide { position.side }
}

/// A player already standing on the field when the quarter begins.
nonisolated struct FieldPlayer: Identifiable, Hashable, Sendable {
    let id: String
    let position: FootballPosition
    /// Normalized field coordinates (0...1). x runs toward the defense, y runs from far to near sideline.
    let x: Double
    let y: Double

    var side: TeamSide { position.side }
}

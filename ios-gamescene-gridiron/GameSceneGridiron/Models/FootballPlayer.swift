import Foundation

/// A named, fictional player who is missing from the field and must be deduced.
nonisolated struct FootballPlayer: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let position: FootballPosition
    /// Bundled imageset for the roster card portrait (helmet + dark visor, no visible face).
    let cardAsset: String

    var side: TeamSide { position.side }

    /// Roster-style display name: first initial + last name, e.g. "D. Ellis".
    var shortName: String {
        let parts = name.split(separator: " ")
        guard parts.count > 1, let first = parts.first, let last = parts.last else { return name }
        return "\(first.prefix(1)). \(last)"
    }
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

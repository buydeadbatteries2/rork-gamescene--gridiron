import Foundation

/// A missing player the detective has correctly placed on the field.
nonisolated struct PlacedPlayer: Identifiable, Hashable, Sendable {
    let player: FootballPlayer
    let profile: PlayerProfile
    let slot: PlacementSlot

    var id: String { player.id }
}

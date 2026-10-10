import SwiftUI
import Observation

/// Persists the player's franchise locally (UserDefaults JSON). A single source
/// of truth the Home screen, opponent select and match flow all read from.
@MainActor
@Observable
final class TeamStore {
    static let shared = TeamStore()

    static let storageKey = "gamescene.gridiron.userTeam"

    private let defaults: UserDefaults
    private(set) var userTeam: GameTeam?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        userTeam = Self.load(from: defaults)
    }

    var hasTeam: Bool { userTeam != nil }

    /// Saves (or replaces) the player's franchise and persists it immediately.
    func save(_ team: GameTeam) {
        var stored = team
        if let existing = userTeam, team.id == existing.id {
            stored = team
        } else {
            stored = GameTeam(
                id: team.id,
                state: team.state,
                teamName: team.teamName,
                logoID: team.logoID,
                primaryColorHex: team.primaryColorHex,
                secondaryColorHex: team.secondaryColorHex,
                isUserTeam: true
            )
        }
        userTeam = stored
        SaveStore.save(stored, key: Self.storageKey, defaults: defaults)
    }

    func clear() {
        userTeam = nil
        defaults.removeObject(forKey: Self.storageKey)
    }

    private static func load(from defaults: UserDefaults) -> GameTeam? {
        SaveStore.load(GameTeam.self, key: storageKey, defaults: defaults)
    }
}

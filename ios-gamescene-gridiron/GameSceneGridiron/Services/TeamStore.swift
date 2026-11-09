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
    private(set) var ownerID: UUID?
    var onLocalSave: (() -> Void)?
    private static let ownerKey = storageKey + ".owner"

    func setOwner(_ id: UUID?) {
        ownerID = id
        defaults.set(id?.uuidString, forKey: Self.ownerKey)
    }

    /// Remote hydration must never trigger an upload. Displaced identities are retained.
    func hydrate(_ team: GameTeam?, owner: UUID?) {
        if let old = userTeam, old.id != team?.id {
            SaveStore.save(old, key: Self.storageKey + ".backup." + old.id.uuidString, defaults: defaults)
        }
        userTeam = team
        setOwner(owner)
        if let team { SaveStore.save(team, key: Self.storageKey, defaults: defaults) }
        else { defaults.removeObject(forKey: Self.storageKey) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        userTeam = Self.load(from: defaults)
        ownerID = defaults.string(forKey: Self.ownerKey).flatMap(UUID.init(uuidString:))
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
        if let existing = userTeam, existing.id != stored.id {
            SaveStore.save(existing, key: Self.storageKey + ".backup." + existing.id.uuidString, defaults: defaults)
            setOwner(nil)
        }
        userTeam = stored
        SaveStore.save(stored, key: Self.storageKey, defaults: defaults)
        onLocalSave?()
    }

    func clear() {
        userTeam = nil
        setOwner(nil)
        defaults.removeObject(forKey: Self.storageKey)
    }

    private static func load(from defaults: UserDefaults) -> GameTeam? {
        SaveStore.load(GameTeam.self, key: storageKey, defaults: defaults)
    }
}

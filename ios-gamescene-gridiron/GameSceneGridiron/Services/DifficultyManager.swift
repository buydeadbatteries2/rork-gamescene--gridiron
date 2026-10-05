import Foundation
import Observation

/// Single source of truth for the user's selected difficulty. Persists
/// locally (UserDefaults) and survives restarts. Changing the selection
/// applies from the next unplayed game — completed games are never
/// regenerated and an active season's case schedule is never reshuffled.
@MainActor
@Observable
final class DifficultyManager {
    static let shared = DifficultyManager()

    static let storageKey = "gamescene.gridiron.difficulty"

    private let defaults: UserDefaults
    private(set) var selected: DifficultyLevel

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        selected = defaults.string(forKey: Self.storageKey)
            .flatMap(DifficultyLevel.init(rawValue:)) ?? .pro
    }

    /// Selects and immediately persists. PRO stays the default until the
    /// player explicitly chooses otherwise.
    func select(_ level: DifficultyLevel) {
        guard level != selected else { return }
        selected = level
        defaults.set(level.rawValue, forKey: Self.storageKey)
    }
}

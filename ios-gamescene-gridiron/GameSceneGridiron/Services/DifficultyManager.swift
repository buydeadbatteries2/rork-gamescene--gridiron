import Foundation
import Observation

/// Single source of truth for the user's selected difficulty. Persists
/// locally (UserDefaults) and survives restarts.
///
/// Phase 11.6: the selection is LOCKED while a season is in progress — every
/// regular-season game, playoff and championship of the running season plays
/// at the difficulty the season was started with. The lock lifts when the
/// season completes; the next season's choice is made before it starts and
/// locks again. Future competitive seasons (versus/faction) will supply a
/// host-controlled lock through the same `lockEvaluator` seam.
@MainActor
@Observable
final class DifficultyManager {
    static let shared = DifficultyManager()

    static let storageKey = "gamescene.gridiron.difficulty"

    private let defaults: UserDefaults
    private(set) var selected: DifficultyLevel

    /// Returns true while the difficulty selection is pinned. Default: an
    /// in-progress season. Tests inject their own evaluator; a future
    /// server-authoritative competitive season replaces the default.
    var lockEvaluator: () -> Bool = { SeasonManager.shared.hasSeasonInProgress }

    var isLocked: Bool { lockEvaluator() }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        selected = defaults.string(forKey: Self.storageKey)
            .flatMap(DifficultyLevel.init(rawValue:)) ?? .pro
    }

    /// Selects and immediately persists — unless an active season has the
    /// difficulty locked, in which case this is a no-op. PRO stays the
    /// default until the player explicitly chooses otherwise.
    func select(_ level: DifficultyLevel) {
        guard !isLocked else { return }
        selectUnlocked(level)
    }

    /// Persists a selection bypassing the season lock. Only season start
    /// (which resolves the new lock) and debug tooling may call this.
    func selectUnlocked(_ level: DifficultyLevel) {
        guard level != selected else { return }
        selected = level
        defaults.set(level.rawValue, forKey: Self.storageKey)
    }
}

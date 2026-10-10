import Foundation

/// Rejects re-entry while a short cooldown window runs. Applied to purchasing,
/// claiming and navigation buttons so a rapid double-tap can never fire the
/// action twice (two hint purchases, two season creations, …).
nonisolated struct TapThrottle: Sendable {
    private var lastFire: Date?
    private let interval: TimeInterval

    init(interval: TimeInterval = 0.6) {
        self.interval = interval
    }

    /// Returns true once per window; subsequent calls inside it return false.
    mutating func accept(now: Date = .now) -> Bool {
        if let lastFire, now.timeIntervalSince(lastFire) < interval {
            return false
        }
        lastFire = now
        return true
    }
}

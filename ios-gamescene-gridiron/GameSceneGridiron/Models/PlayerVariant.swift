import Foundation

/// Legacy internal spelling for the original three archetypes. Runtime code
/// uses `PlayerProfile` (which adds Rookie and Overrated); this type survives
/// only as the bridge for older case data and any persisted blobs. Never
/// extend this — add profiles to `PlayerProfile` instead.
nonisolated enum PlayerVariant: String, Hashable, Sendable, CaseIterable, Identifiable {
    case fast
    case power
    case veteran

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fast: "Fast"
        case .power: "Powerful"
        case .veteran: "Veteran"
        }
    }

    /// Bridge to the modern profile.
    var profile: PlayerProfile { PlayerProfile(legacy: self) }
}

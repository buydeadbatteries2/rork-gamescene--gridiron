import Foundation

/// The three archetypes every missing player can be deployed as.
nonisolated enum PlayerVariant: String, Hashable, Sendable, CaseIterable, Identifiable {
    case fast
    case power
    case veteran

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fast: "Fast"
        case .power: "Power"
        case .veteran: "Veteran"
        }
    }

    var symbol: String {
        switch self {
        case .fast: "bolt.fill"
        case .power: "dumbbell.fill"
        case .veteran: "star.fill"
        }
    }

    var summary: String {
        switch self {
        case .fast: "Speed and agility"
        case .power: "Strength and physicality"
        case .veteran: "Experience and awareness"
        }
    }
}

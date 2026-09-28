import UIKit

/// Thin wrapper around UIKit feedback generators so game logic stays UI-framework agnostic.
enum Haptics {
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    static func pickUp() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    static func tick() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    static func soft() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }
}

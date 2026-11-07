import UIKit

/// Thin wrapper around UIKit feedback generators so game logic stays UI-framework agnostic.
/// Every generator respects the Haptics accessibility setting in Settings.
enum Haptics {
    private static let notification = UINotificationFeedbackGenerator()
    private static let medium = UIImpactFeedbackGenerator(style: .medium)
    private static let selection = UISelectionFeedbackGenerator()
    private static let light = UIImpactFeedbackGenerator(style: .soft)

    private static var isEnabled: Bool { TutorialManager.shared.isHapticsEnabled }

    static func success() {
        guard isEnabled else { return }
        notification.notificationOccurred(.success)
    }

    static func error() {
        guard isEnabled else { return }
        notification.notificationOccurred(.error)
    }

    static func warning() {
        guard isEnabled else { return }
        notification.notificationOccurred(.warning)
    }

    static func pickUp() {
        guard isEnabled else { return }
        medium.impactOccurred()
        medium.prepare()
    }

    static func tick() {
        guard isEnabled else { return }
        selection.selectionChanged()
        selection.prepare()
    }

    static func soft() {
        guard isEnabled else { return }
        light.impactOccurred()
        light.prepare()
    }
}

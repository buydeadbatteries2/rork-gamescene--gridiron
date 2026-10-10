import SwiftUI

/// Reduce Motion support. Big page flips, card slides, count-ups and the home
/// glow simplify to fades or statics while essential feedback (snaps, stamps,
/// banners) stays intact. Views read these on the main actor.
@MainActor
enum Motion {
    static var isReduced: Bool { TutorialManager.shared.isReduceMotionEnabled }

    /// Full-width page transition (season hub destinations).
    static var pageTransition: AnyTransition {
        isReduced ? .opacity : .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .trailing).combined(with: .opacity)
        )
    }

    /// Directional card-slide transition (roster tray pages).
    static func cardSlide(forward: Bool) -> AnyTransition {
        isReduced ? .opacity : .asymmetric(
            insertion: .move(edge: forward ? .trailing : .leading).combined(with: .opacity),
            removal: .move(edge: forward ? .leading : .trailing).combined(with: .opacity)
        )
    }
}

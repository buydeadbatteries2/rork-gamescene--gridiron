import SwiftUI

/// Owns the decorative pulse locally, not in the full Home tree. A fixed blur
/// radius avoids continuously changing the blur kernel during the pulse.
struct HomeCTAGlow: ViewModifier {
    let isScrolling: Bool
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isVisible = false
    @State private var glow = false

    private var isActive: Bool {
        isVisible && !isScrolling && scenePhase == .active && !reduceMotion
    }

    func body(content: Content) -> some View {
        content
            .shadow(color: Theme.gold.opacity(reduceMotion ? 0.35 : (glow ? 0.35 : 0.1)), radius: 22)
            .onScrollVisibilityChange(threshold: 0.1) { isVisible = $0 }
            .onDisappear { isVisible = false }
            .task(id: isActive) {
                var transaction = Transaction(animation: nil)
                transaction.disablesAnimations = true
                withTransaction(transaction) { glow = false }
                guard isActive else { return }
                await Task.yield()
                guard !Task.isCancelled else { return }
                withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) { glow = true }
            }
    }
}

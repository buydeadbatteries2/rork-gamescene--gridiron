import SwiftUI

struct ContentView: View {
    /// First launch only: the guided onboarding (intro → team → difficulty →
    /// training case → Season 1). Returning users go straight home.
    @State private var showOnboarding = !TutorialManager.shared.hasCompletedOnboarding

    var body: some View {
        HomeView()
            .preferredColorScheme(.dark)
            .fullScreenCover(isPresented: $showOnboarding) {
                OnboardingFlowView()
            }
            // ACHIEVEMENT UNLOCKED notifications float above everything.
            // Unlocks only queue at safe breaks, so this never lands on a
            // live drag/drop — and a tap dismisses instantly.
            .overlay(alignment: .top) {
                AchievementPopupView()
                    .allowsHitTesting(true)
            }
    }
}

#Preview {
    ContentView()
}

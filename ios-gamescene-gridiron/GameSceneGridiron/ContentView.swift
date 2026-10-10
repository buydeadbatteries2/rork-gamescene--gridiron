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
    }
}

#Preview {
    ContentView()
}

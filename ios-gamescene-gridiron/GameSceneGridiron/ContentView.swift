import SwiftUI

struct ContentView: View {
    /// First launch only: the guided onboarding (intro → team → difficulty →
    /// training case → Season 1). Returning users go straight home.
    @State private var showOnboarding = !TutorialManager.shared.hasCompletedOnboarding
    @State private var auth = AuthService.shared

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
            // AUTH RESTORATION: the app stays on the loading board until the
            // Supabase session state resolves — login/onboarding never flashes
            // mid-restore. A missing/unreachable Supabase resolves to guest
            // and never blocks the game.
            .overlay {
                if auth.state == .restoring {
                    AuthLoadingBoard()
                        .transition(.opacity)
                }
            }
            // The password-reset deep link established a confirm-session —
            // present the new-password form above everything.
            .fullScreenCover(isPresented: $auth.isAwaitingNewPassword) {
                ResetPasswordView()
                    .preferredColorScheme(.dark)
            }
    }
}

/// Case-file styled restoration board shown while the Supabase session is
/// being restored at launch.
struct AuthLoadingBoard: View {
    var body: some View {
        ZStack {
            DeskBackground()
            VStack(spacing: 14) {
                Image(systemName: "folder.badge.gearshape")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(Theme.goldGradient)
                    .frame(width: 70, height: 70)
                    .background(Color.black.opacity(0.5), in: .circle)
                    .overlay { Circle().strokeBorder(Theme.gold.opacity(0.45), lineWidth: 1.2) }
                Text("CHECKING PLAYER FILE…")
                    .font(.system(size: 16, weight: .black).width(.compressed))
                    .tracking(2)
                    .foregroundStyle(Theme.paperInk)
                ProgressView()
                    .tint(Theme.gold)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Checking player file")
        }
    }
}

#Preview {
    ContentView()
}

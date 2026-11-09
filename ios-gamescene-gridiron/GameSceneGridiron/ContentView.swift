import SwiftUI

struct ContentView: View {
    /// First launch only: the guided onboarding (intro → team → difficulty →
    /// training case → Season 1). Returning users go straight home.
    @State private var teamSync = TeamSyncCoordinator.shared
    @State private var auth = AuthService.shared
    @State private var hasStartedLaunchMusic = false

    var body: some View {
        routedContent
            .preferredColorScheme(.dark)
            .task(id: auth.state) { await teamSync.resolve(auth.state) }
            .safeAreaInset(edge: .top) {
                if teamSync.phase == .ready && teamSync.hasPendingSave {
                    HStack {
                        Text(teamSync.isSaving ? "SAVING TEAM…" : "TEAM CHANGES NOT SYNCED")
                            .font(Theme.typewriter(11, relativeTo: .caption))
                        Spacer()
                        Button("RETRY") { Task { await teamSync.retryPendingSave() } }
                            .disabled(teamSync.isSaving)
                    }
                    .padding(12).foregroundStyle(Theme.goldLight).background(Theme.ink)
                } else if teamSync.phase == .local && TeamSyncCoordinator.userID(auth.state) != nil {
                    HStack {
                        Text("LOCAL PLAY — TEAM SYNC PAUSED")
                            .font(Theme.typewriter(11, relativeTo: .caption))
                        Spacer()
                        Button("RECONNECT") { Task { await teamSync.resolve(auth.state) } }
                    }
                    .padding(12).foregroundStyle(Theme.goldLight).background(Theme.ink)
                }
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
            .buttonStyle(PressableButtonStyle(scale: 1))
            .onAppear {
                guard !hasStartedLaunchMusic else { return }
                hasStartedLaunchMusic = true
                AudioManager.shared.playMusic(.menuTheme)
            }
    }

    @ViewBuilder private var routedContent: some View {
        if auth.state == .restoring || teamSync.resolvedState != auth.state || teamSync.phase == .loading {
            AuthLoadingBoard()
        } else if teamSync.phase == .failure || teamSync.phase == .migration {
            ZStack {
                DeskBackground()
                VStack(spacing: 22) {
                    Text(teamSync.phase == .migration ? "LINK YOUR LOCAL TEAM?" : "TEAM FILE UNAVAILABLE")
                        .font(Theme.display(24)).foregroundStyle(Theme.goldLight)
                    Text(teamSync.phase == .migration
                         ? "This account has no saved team. Link this device’s team only if it belongs to you. A team already saved to the account will always take priority."
                         : "We couldn’t check your saved team. Retry before creating a team, or continue with this device’s local solo data. Nothing has been deleted.")
                        .font(Theme.typewriter(14, relativeTo: .body)).foregroundStyle(Theme.paper)
                    if teamSync.phase == .migration {
                        Button("LINK LOCAL TEAM") { Task { await teamSync.migrateLocalTeam() } }
                            .buttonStyle(GoldCapsuleButtonStyle())
                        Button("CREATE A NEW TEAM") { teamSync.createNewInstead() }
                    } else {
                        Button("RETRY") { Task { await teamSync.resolve(auth.state) } }
                            .buttonStyle(GoldCapsuleButtonStyle())
                    }
                    Button("CONTINUE LOCAL / OFFLINE") { teamSync.useLocalOffline() }
                }
                .multilineTextAlignment(.center).foregroundStyle(Theme.goldLight).padding(28)
            }
        } else if teamSync.phase == .ready && !TeamStore.shared.hasTeam {
            TeamCreationView(onConfirm: { _ in
                TutorialManager.shared.skipSetupForRestoredTeam()
            }, onClose: { teamSync.useLocalOffline() })
        } else if teamSync.phase == .local && !TutorialManager.shared.hasCompletedOnboarding {
            OnboardingFlowView()
        } else {
            HomeView()
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

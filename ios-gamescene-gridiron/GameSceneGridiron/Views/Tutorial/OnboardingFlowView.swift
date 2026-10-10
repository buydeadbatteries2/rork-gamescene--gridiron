import SwiftUI

/// First-launch onboarding: intro → create team → select difficulty → guided
/// training case → enter Season 1. Runs exactly once (persisted by
/// `TutorialManager`); the only exit is completing the flow, so the user is
/// never left in a half-set-up state.
struct OnboardingFlowView: View {
    @Environment(\.dismiss) private var dismiss

    private enum Step: Equatable {
        case intro
        case createTeam
        case difficulty
        case training
    }

    @State private var step: Step = .intro

    var body: some View {
        ZStack {
            Theme.ink.ignoresSafeArea()

            switch step {
            case .intro:
                IntroView {
                    withAnimation(.easeInOut(duration: 0.35)) { step = .createTeam }
                }
                .transition(.opacity)

            case .createTeam:
                TeamCreationView(onConfirm: { _ in
                    withAnimation(.easeInOut(duration: 0.35)) { step = .difficulty }
                }, onClose: {
                    withAnimation(.easeInOut(duration: 0.35)) { step = .intro }
                })
                .transition(.opacity)

            case .difficulty:
                DifficultySelectView(confirmTitle: "CONTINUE TO TRAINING") { level in
                    Haptics.pickUp()
                    DifficultyManager.shared.select(level)
                    withAnimation(.easeInOut(duration: 0.35)) { step = .training }
                }
                .transition(.opacity)

            case .training:
                TrainingFlowView {
                    finish()
                } onQuit: {
                    // Leaving the training case early still lands the user in a
                    // complete, playable state — never a dead end.
                    finish()
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: step)
        .interactiveDismissDisabled()
    }

    /// Completes onboarding and enters Season 1 with the confirmed difficulty.
    private func finish() {
        TutorialManager.shared.completeOnboarding()
        if let team = TeamStore.shared.userTeam {
            SeasonManager.shared.startNewSeason(userTeam: team)
        }
        dismiss()
    }
}

#Preview {
    OnboardingFlowView()
        .preferredColorScheme(.dark)
}

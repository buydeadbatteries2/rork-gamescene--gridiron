import SwiftUI

/// The guided TRAINING CASE: the real gameplay engine running a dedicated
/// tutorial puzzle with the coach step machine laid over it. Impossible to
/// permanently fail (hearts are never at stake), uses a disposable wallet so
/// the player's Game Balls and hints are never touched, and never records any
/// season, roster or economy state.
struct TrainingFlowView: View {
    /// Completion button copy — onboarding starts Season 1, a replay just returns.
    var completeButtonTitle: String = "START MY SEASON"
    let onComplete: () -> Void
    var onQuit: (() -> Void)?

    @State private var viewModel: GameViewModel
    @State private var session: TrainingSession
    @State private var hasAppeared: Bool = false
    @State private var isExitConfirmed: Bool = false

    init(completeButtonTitle: String = "START MY SEASON", onComplete: @escaping () -> Void, onQuit: (() -> Void)? = nil) {
        self.completeButtonTitle = completeButtonTitle
        self.onComplete = onComplete
        self.onQuit = onQuit
        // A disposable wallet on its own defaults suite: hints spent here never
        // touch the persistent economy, and no Game Ball reward is ever granted.
        let trainingWallet = PlayerWallet(
            defaults: UserDefaults(suiteName: "gamescene.gridiron.training.\(UUID().uuidString)") ?? .standard
        )
        let gameViewModel = GameViewModel(puzzle: TrainingCase.puzzle(), wallet: trainingWallet)
        gameViewModel.isTraining = true
        _viewModel = State(initialValue: gameViewModel)
        _session = State(initialValue: TrainingSession(viewModel: gameViewModel))
    }

    var body: some View {
        ZStack {
            Theme.ink.ignoresSafeArea()

            GameplayView(
                viewModel: viewModel,
                onQuit: { onQuit?() ?? onComplete() },
                onQuarterComplete: { _ in },
                training: session,
                trainingExit: {
                    Haptics.tick()
                    isExitConfirmed = true
                }
            )
            // Once the case is solved the board freezes: no further tutorial
            // interactions, highlights or prompts — only the completion card.
            .allowsHitTesting(!session.isComplete)
            .accessibilityHidden(session.isComplete)

            if session.isComplete {
                completionCard
                    .transition(.opacity)
                    .zIndex(10)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: session.step)
        .onChange(of: viewModel.expandedPlayerID) { _, _ in
            session.handleExpansion()
        }
        .onChange(of: viewModel.placements.count) { _, _ in
            session.placementsChanged()
        }
        .onChange(of: session.step) { _, step in
            // Persisted the instant the final objective is solved — not on
            // button tap, not on relaunch.
            if step == .complete {
                TutorialManager.shared.markTutorialCompleted()
            }
        }
        // Safe exit from every mode: the confirm copy points at Settings
        // replay, and EXIT hands off to the mode's own exit path.
        .confirmationDialog(
            "EXIT TRAINING?",
            isPresented: $isExitConfirmed,
            titleVisibility: .visible
        ) {
            Button("CONTINUE TRAINING", role: .cancel) {}
            Button("EXIT", role: .destructive) {
                onQuit?() ?? onComplete()
            }
        } message: {
            Text("You can replay the tutorial later from Settings.")
        }
    }

    // MARK: Completion

    /// CASE SOLVED → TRAINING COMPLETE → "You're ready for Season 1."
    private var completionCard: some View {
        ZStack {
            Color.black.opacity(0.82).ignoresSafeArea()

            VStack(spacing: 18) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(Theme.success)

                Text("CASE SOLVED")
                    .font(.system(size: 30, weight: .black).width(.compressed))
                    .tracking(2)
                    .foregroundStyle(Theme.goldGradient)

                Text("TRAINING COMPLETE")
                    .font(Theme.typewriterBold(15, relativeTo: .headline))
                    .tracking(2)
                    .foregroundStyle(Theme.paperInk)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 5)
                    .paperCard(cornerRadius: 3)
                    .rotationEffect(.degrees(-1.5))

                Text("You're ready for Season 1.")
                    .font(Theme.typewriter(15, relativeTo: .callout))
                    .foregroundStyle(Theme.paperInkSoft)

                Button {
                    Haptics.success()
                    AudioManager.shared.play(.quarterWon)
                    onComplete()
                } label: {
                    HStack {
                        Spacer()
                        Text(completeButtonTitle)
                        Spacer()
                        Image(systemName: "sportscourt.fill")
                            .font(.system(size: 15, weight: .bold))
                    }
                    .padding(.horizontal, 26)
                }
                .buttonStyle(GoldCapsuleButtonStyle())
                .padding(.top, 6)
            }
            .padding(26)
            .frame(maxWidth: 320)
            .background {
                PaperSurface(cornerRadius: 8, darkness: 0.02)
                    .shadow(color: .black.opacity(0.8), radius: 24, y: 12)
            }
            .overlay(alignment: .top) {
                PushPin(size: 20).offset(y: -10)
            }
            .padding(.horizontal, 30)
            .accessibilityElement(children: .contain)
        }
    }
}

#Preview {
    TrainingFlowView(onComplete: {})
        .preferredColorScheme(.dark)
}

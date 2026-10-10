import SwiftUI

/// One live quarter: HUD, field, clue notebook, roster tray and reserved ad area,
/// stacked vertically. The quarter view model is injected by the match flow so the
/// match can carry the finished quarter's state into the result screen.
struct GameplayView: View {
    static let coordinateSpace = "gameplay"

    let viewModel: GameViewModel
    var matchViewModel: MatchViewModel?
    let onQuit: () -> Void
    let onQuarterComplete: (GameViewModel) -> Void
    /// Franchises coloring the field tokens: offense = user team, defense = opponent.
    let userTeam: GameTeam?
    let opponent: GameTeam?
    /// TRAINING CASE coach (nil during real games): drives highlights, the
    /// coach banner row and ad suppression for the duration of the tutorial.
    var training: TrainingSession?
    /// First regular-season game only: subtle contextual training wheels
    /// (notebook pulse + control reminders). Never changes difficulty.
    var showFirstGameAssist: Bool = false

    init(
        viewModel: GameViewModel,
        matchViewModel: MatchViewModel? = nil,
        onQuit: @escaping () -> Void = {},
        onQuarterComplete: @escaping (GameViewModel) -> Void = { _ in },
        userTeam: GameTeam? = nil,
        opponent: GameTeam? = nil,
        training: TrainingSession? = nil,
        showFirstGameAssist: Bool = false
    ) {
        self.viewModel = viewModel
        self.matchViewModel = matchViewModel
        self.onQuit = onQuit
        self.onQuarterComplete = onQuarterComplete
        self.userTeam = userTeam
        self.opponent = opponent
        self.training = training
        self.showFirstGameAssist = showFirstGameAssist
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        VStack(spacing: 14) {
            GameHUDView(
                viewModel: viewModel,
                matchViewModel: matchViewModel,
                highlightHint: training?.isHintHighlighted == true
            ) {
                Haptics.tick()
                withAnimation(.easeOut(duration: 0.2)) { viewModel.isPaused = true }
            }
            .padding(.horizontal, 16)
            .padding(.top, 6)

            GameFieldView(
                viewModel: viewModel,
                userTeam: userTeam,
                opponent: opponent,
                highlightedEvidenceID: training?.highlightedEvidenceID,
                guidedSlotID: training?.guidedSlotID
            )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .frame(minHeight: 220)
                .padding(.horizontal, 6)
                .layoutPriority(1)

            // Coach banner (training) or first-game reminder strip — always
            // its own layout row, never covering field, notebook or tray.
            if let coach = training?.coach {
                CoachBanner(message: coach) {
                    Haptics.tick()
                    AudioManager.shared.play(.buttonPress)
                    training?.advancePastCurrentStep()
                }
                .padding(.horizontal, 16)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else if showFirstGameAssist, !viewModel.isDragging {
                firstGameReminder
                    .padding(.horizontal, 16)
                    .transition(.opacity)
            }

            ClueNotebookView(
                viewModel: viewModel,
                onOpenCaseFile: {
                    Haptics.tick()
                    viewModel.isNotebookPresented = true
                },
                highlightCaseFile: training?.isCaseFileHighlighted == true,
                assistPulse: showFirstGameAssist
            )
            .padding(.horizontal, 16)

            RosterTrayView(
                viewModel: viewModel,
                tint: userTeam?.primaryColor,
                highlightedPlayerID: training?.highlightedPlayerID
            )
                .frame(height: 200, alignment: .bottom)

            // Absolute bottom banner slot, always its own row — never over
            // gameplay content. Ad-Free owners and the training case get the
            // space back entirely.
            if training == nil {
                GameBannerAdView()
                    .padding(.horizontal, 16)
                    .padding(.bottom, 6)
            }
        }
        .coordinateSpace(.named(Self.coordinateSpace))
        .overlay(alignment: .topLeading) {
            if let player = viewModel.draggingPlayer {
                DraggedPlayerToken(
                    player: player,
                    variant: viewModel.selectedVariant(for: player.id),
                    isOverSlot: viewModel.hoveredSlotID != nil,
                    tint: userTeam?.primaryColor
                )
                .position(draggedTokenPosition(for: viewModel))
                .transition(.scale(scale: 0.5).combined(with: .opacity))
            }
        }
        .overlay(alignment: .top) {
            if let feedback = viewModel.feedback {
                FeedbackBanner(message: feedback)
                    .padding(.horizontal, 20)
                    .padding(.top, 60)
                    .onTapGesture { viewModel.dismissFeedback() }
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .id(feedback.id)
            }
        }
        .background { gameplayBackground }
        .overlay {
            if viewModel.isPaused {
                PauseOverlay(
                    onResume: { withAnimation(.easeOut(duration: 0.2)) { viewModel.isPaused = false } },
                    onRestart: { viewModel.restart() },
                    onQuit: onQuit
                )
                .transition(.opacity)
            }
        }
        .overlay {
            // Rewarded-video offers. Nothing is granted unless the ad's reward
            // callback fires (`.granted`); an early close just returns here.
            if viewModel.isLastChancePending {
                LastChanceOverlay(
                    isWatching: isWatchingAd,
                    onWatch: { watchRewarded(.lastChanceLife) { viewModel.grantLastChanceLife() } },
                    onAccept: { viewModel.acceptLastChanceLoss() }
                )
                .transition(.opacity)
            } else if viewModel.isHintOfferPresented {
                HintOfferOverlay(
                    isWatching: isWatchingAd,
                    canAffordHint: PlayerWallet.shared.canAffordHint,
                    hintCost: EconomyConfig.standard.hintCost,
                    onWatch: { watchRewarded(.hint) { viewModel.grantRewardedHint() } },
                    onBuy: { buyHintFromOffer() },
                    onCancel: { withAnimation(.easeOut(duration: 0.2)) { viewModel.isHintOfferPresented = false } }
                )
                .transition(.opacity)
            }
        }
        .sheet(isPresented: $viewModel.isNotebookPresented) {
            CaseFileSheet(viewModel: viewModel)
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: viewModel.isDragging)
        .statusBarHidden(false)
        .task {
            AudioManager.shared.playMusic(.gameplayTheme)
        }
        .onChange(of: viewModel.isPaused) { _, isPaused in
            let audio = AudioManager.shared
            if isPaused {
                audio.pauseMusic()
            } else if viewModel.result == .inProgress {
                audio.resumeMusic()
            }
        }
        .onChange(of: viewModel.result) { _, result in
            // Fade the bed out under the result stinger; report the verdict up to the match.
            if result == .inProgress {
                AudioManager.shared.playMusic(.gameplayTheme)
            } else {
                AudioManager.shared.stopMusic(fadeOutDuration: 1.4)
                onQuarterComplete(viewModel)
            }
        }
        .onDisappear {
            AudioManager.shared.stopMusic(fadeOutDuration: 0.6)
        }
    }

    // MARK: Snap preview

    /// Magnetic bias, display-only: while a valid target is hovered the drawn
    /// token leans toward the target's true field point so the spot the player
    /// is about to drop into is unmistakable. Release still resolves the real
    /// drop location against the nearest candidate — nothing auto-completes.
    private func draggedTokenPosition(for viewModel: GameViewModel) -> CGPoint {
        let base = CGPoint(
            x: viewModel.dragLocation.x,
            y: viewModel.dragLocation.y - GameViewModel.dragLift
        )
        guard let target = viewModel.hoveredSlotPoint else { return base }
        let pull: CGFloat = 0.35
        return CGPoint(
            x: base.x + (target.x - base.x) * pull,
            y: base.y + (target.y - base.y) * pull
        )
    }

    // MARK: Rewarded offers

    @State private var isWatchingAd = false

    /// Runs one rewarded-ad presentation. Grants `onGranted` only when the
    /// reward callback fired — a dismissed ad grants nothing and the offer
    /// stays up for another choice.
    private func watchRewarded(_ placement: RewardedAdPlacement, onGranted: @escaping () -> Void) {
        guard !isWatchingAd else { return }
        isWatchingAd = true
        Task { @MainActor in
            let result = await AdManager.shared.showRewarded(placement)
            isWatchingAd = false
            if result == .granted {
                onGranted()
            }
        }
    }

    /// Game Ball shortcut inside the hint offer — the sheet itself is the
    /// "Use 50 Game Balls to add 1 Hint?" confirmation.
    private func buyHintFromOffer() {
        guard PlayerWallet.shared.buyHint() else {
            Haptics.warning()
            return
        }
        AudioManager.shared.play(.hintPurchaseConfirm)
        Haptics.success()
        viewModel.hintPurchased()
    }

    // MARK: First-game assist

    /// One slim reminder strip for the user's very first regular-season game —
    /// subtle, non-blocking, and gone after Game 1.
    private var firstGameReminder: some View {
        HStack(spacing: 8) {
            Image(systemName: "hand.point.up.left")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Theme.gold)
            Text("ARROWS BROWSE PLAYERS — PICK A PROFILE, THEN HOLD TO DRAG")
                .font(.system(size: 9, weight: .heavy).width(.condensed))
                .tracking(1)
                .foregroundStyle(Theme.paperInkSoft)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity)
        .paperCard(cornerRadius: 4)
        .accessibilityLabel("Reminder: arrows browse players. Pick a profile, then hold to drag.")
    }

    private var gameplayBackground: some View {
        ZStack {
            Theme.ink
            RadialGradient(
                colors: [Theme.bronze.opacity(0.16), .clear],
                center: UnitPoint(x: 0.5, y: 0.0),
                startRadius: 10,
                endRadius: 380
            )
            Image("detective_desk_bg")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .opacity(0.35)
                .allowsHitTesting(false)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

#Preview {
    GameplayView(viewModel: GameViewModel(puzzle: SampleQuarter.puzzle))
        .preferredColorScheme(.dark)
}

/// One-mechanic-at-a-time coach banner shown between the field and the
/// notebook during the TRAINING CASE. With a button it waits for GOT IT;
/// without one it waits for the user to perform the taught action.
struct CoachBanner: View {
    let message: TrainingSession.Message
    let onConfirm: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Image(systemName: "graduationcap")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.bronzeDeep)
                Text(message.title)
                    .font(.system(size: 13, weight: .heavy).width(.condensed))
                    .tracking(1.5)
                    .foregroundStyle(Theme.paperInk)
                Spacer(minLength: 0)
                if let buttonTitle = message.buttonTitle {
                    Button(action: onConfirm) {
                        Text(buttonTitle)
                            .font(.system(size: 11, weight: .heavy).width(.condensed))
                            .tracking(1.2)
                            .foregroundStyle(Theme.ink)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                    }
                    .buttonStyle(GoldCapsuleButtonStyle())
                    .accessibilityLabel("\(buttonTitle): \(message.title)")
                }
            }
            Text(message.detail)
                .font(Theme.typewriter(12.5, relativeTo: .footnote))
                .foregroundStyle(Theme.paperInkSoft)
                .lineSpacing(2.5)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .paperCard(cornerRadius: 6)
        .shadow(color: .black.opacity(0.55), radius: 10, y: 5)
        .accessibilityElement(children: .contain)
    }
}

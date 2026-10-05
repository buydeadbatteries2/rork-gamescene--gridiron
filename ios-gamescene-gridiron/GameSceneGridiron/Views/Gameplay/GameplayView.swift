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

    init(
        viewModel: GameViewModel,
        matchViewModel: MatchViewModel? = nil,
        onQuit: @escaping () -> Void = {},
        onQuarterComplete: @escaping (GameViewModel) -> Void = { _ in },
        userTeam: GameTeam? = nil,
        opponent: GameTeam? = nil
    ) {
        self.viewModel = viewModel
        self.matchViewModel = matchViewModel
        self.onQuit = onQuit
        self.onQuarterComplete = onQuarterComplete
        self.userTeam = userTeam
        self.opponent = opponent
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        VStack(spacing: 14) {
            GameHUDView(viewModel: viewModel, matchViewModel: matchViewModel) {
                Haptics.tick()
                withAnimation(.easeOut(duration: 0.2)) { viewModel.isPaused = true }
            }
            .padding(.horizontal, 16)
            .padding(.top, 6)

            GameFieldView(viewModel: viewModel, userTeam: userTeam, opponent: opponent)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .frame(minHeight: 220)
                .padding(.horizontal, 6)
                .layoutPriority(1)

            ClueNotebookView(viewModel: viewModel) {
                Haptics.tick()
                viewModel.isNotebookPresented = true
            }
            .padding(.horizontal, 16)

            RosterTrayView(viewModel: viewModel, tint: userTeam?.primaryColor)
                .frame(height: 200, alignment: .bottom)

            // Absolute bottom banner slot, always its own row — never over
            // gameplay content. Ad-Free owners get the space back entirely.
            GameBannerAdView()
                .padding(.horizontal, 16)
                .padding(.bottom, 6)
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

import SwiftUI

/// The sample quarter: HUD, field, clue notebook, roster tray and reserved ad area, stacked vertically.
struct GameplayView: View {
    static let coordinateSpace = "gameplay"

    let onExit: () -> Void

    @State private var viewModel: GameViewModel = GameViewModel()

    var body: some View {
        @Bindable var viewModel = viewModel

        VStack(spacing: 12) {
            GameHUDView(viewModel: viewModel) {
                Haptics.tick()
                withAnimation(.easeOut(duration: 0.2)) { viewModel.isPaused = true }
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)

            GameFieldView(viewModel: viewModel)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .frame(minHeight: 220)
                .padding(.horizontal, 6)
                .layoutPriority(1)

            ClueNotebookView(viewModel: viewModel) {
                Haptics.tick()
                viewModel.isNotebookPresented = true
            }
            .padding(.horizontal, 16)

            RosterTrayView(viewModel: viewModel)
                .frame(height: 196, alignment: .bottom)

            AdBannerPlaceholder()
                .padding(.horizontal, 16)
                .padding(.bottom, 4)
        }
        .coordinateSpace(.named(Self.coordinateSpace))
        .overlay(alignment: .topLeading) {
            if let player = viewModel.draggingPlayer {
                DraggedPlayerToken(
                    player: player,
                    variant: viewModel.selectedVariant(for: player.id),
                    isOverSlot: viewModel.hoveredSlotID != nil
                )
                .position(x: viewModel.dragLocation.x, y: viewModel.dragLocation.y - GameViewModel.dragLift)
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
                    onQuit: onExit
                )
                .transition(.opacity)
            }
        }
        .overlay {
            if viewModel.result != .inProgress {
                QuarterResultView(viewModel: viewModel, onContinue: onExit)
                    .transition(.opacity.combined(with: .scale(scale: 1.04)))
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
            // Fade the bed out under the result stinger; bring it back on restart.
            if result == .inProgress {
                AudioManager.shared.playMusic(.gameplayTheme)
            } else {
                AudioManager.shared.stopMusic(fadeOutDuration: 1.4)
            }
        }
        .onDisappear {
            AudioManager.shared.stopMusic(fadeOutDuration: 0.6)
        }
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
    GameplayView(onExit: {})
        .preferredColorScheme(.dark)
}

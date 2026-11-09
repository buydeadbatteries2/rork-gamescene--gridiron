import SwiftUI

/// Phase 15B — plays ONE Versus match on the existing gameplay: quarter
/// intro → live quarter → quarter result → … → optional overtime. The five
/// cases are exactly the server's assignment; hints and every rescue are
/// off; no rewards, no ad gates. Progress is saved after every quarter, and
/// the finished file is queued durably BEFORE the result screen shows.
struct VersusPlayView: View {
    @Environment(\.dismiss) private var dismiss

    let context: VersusPlayContext
    let store: VersusStore

    @State private var matchViewModel: MatchViewModel
    @State private var quarterViewModel: GameViewModel?
    @State private var isConfirmingLeave = false

    init(context: VersusPlayContext, resume: VersusProgress?, store: VersusStore) {
        self.context = context
        self.store = store
        _matchViewModel = State(initialValue: MatchViewModel(versus: context, resume: resume))
    }

    var body: some View {
        ZStack {
            switch matchViewModel.phase {
            case .quarterIntro:
                QuarterIntroView(
                    puzzle: matchViewModel.currentPuzzle,
                    isOvertime: matchViewModel.match.isOvertime,
                    onBegin: beginQuarter,
                    difficulty: context.difficulty
                )
                .overlay(alignment: .topLeading) { leaveButton }
                .overlay(alignment: .top) { VersusHintsDisabledChip().padding(.top, 14) }
                .transition(.opacity)

            case .playing:
                if let quarterViewModel {
                    GameplayView(
                        viewModel: quarterViewModel,
                        matchViewModel: matchViewModel,
                        // Pause → Leave Investigation: progress is saved; the
                        // match stays open in the Hub. Never a forfeit.
                        onQuit: { dismiss() },
                        onQuarterComplete: finishQuarter
                    )
                    .id(matchViewModel.match.currentQuarterIndex)
                    .transition(.opacity)
                }

            case .quarterResult, .gameResult:
                if let quarterViewModel {
                    QuarterResultView(
                        viewModel: quarterViewModel,
                        matchViewModel: matchViewModel,
                        onContinue: continueAfterQuarter
                    )
                    .transition(.opacity)
                } else {
                    DeskBackground()
                }
            }
        }
        .animation(.easeInOut(duration: 0.35), value: matchViewModel.phase)
        .confirmationDialog("Leave this case file?", isPresented: $isConfirmingLeave, titleVisibility: .visible) {
            Button("Leave — progress is saved") { dismiss() }
            Button("Stay", role: .cancel) {}
        } message: {
            Text("Your Versus match stays open in the Hub until the deadline.")
        }
    }

    private var leaveButton: some View {
        Button {
            Haptics.tick()
            isConfirmingLeave = true
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(.black.opacity(0.45), in: .circle)
        }
        .padding(.leading, 16)
        .accessibilityLabel("Leave case file")
        .accessibilityIdentifier("versus.play.leave")
    }

    private func beginQuarter() {
        let viewModel = GameViewModel(puzzle: matchViewModel.currentPuzzle, difficulty: context.difficulty)
        viewModel.hintsDisabled = true
        // Per-match snapshot key FIRST — setting lastChanceKey restores it.
        viewModel.snapshotKey = VersusPlayContext.snapshotKey(matchID: context.matchID)
        viewModel.lastChanceKey = matchViewModel.currentLastChanceKey
        quarterViewModel = viewModel
        matchViewModel.beginQuarter()
    }

    private func finishQuarter(_ viewModel: GameViewModel) {
        matchViewModel.finishQuarter(with: viewModel)
        if matchViewModel.match.isComplete {
            // Queue + submit now — a kill on the result screen can't lose it.
            let results = matchViewModel.versusCaseResults
            let matchID = context.matchID
            let startedAt = context.startedAt
            let store = store
            Task { await store.completeGame(matchID: matchID, startedAt: startedAt, caseResults: results) }
        } else if let progress = matchViewModel.versusProgress {
            store.saveProgress(progress)
        }
    }

    private func continueAfterQuarter() {
        if matchViewModel.match.isComplete {
            Haptics.success()
            dismiss()
        } else {
            matchViewModel.continueFlow()
        }
    }
}

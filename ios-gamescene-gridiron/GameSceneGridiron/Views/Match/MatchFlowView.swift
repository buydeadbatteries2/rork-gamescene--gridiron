import SwiftUI

/// Owns one full game: quarter intro → live quarter → quarter result → …
/// → optional overtime → final verdict. Presented full screen from the season
/// flow (regular season, semifinal or championship) or standalone.
struct MatchFlowView: View {
    @Environment(\.dismiss) private var dismiss

    /// The two franchises in this matchup; colors the tokens and the result screen.
    var userTeam: GameTeam?
    var opponent: GameTeam?
    /// Postseason pressure: same rules, slightly tighter resources.
    var isPlayoff: Bool = false
    /// The championship final — stacks the championship Game Ball bonus.
    var isChampionship: Bool = false
    /// Season context for the case scheduler (nil = standalone quick game).
    var seasonNumber: Int?
    var week: Int?
    /// Called exactly once when a season game finishes. When set, the replay
    /// option is hidden — completed season games are never replayed.
    var onSeasonResult: ((GameMatch) -> Void)?

    @State private var matchViewModel: MatchViewModel
    @State private var quarterViewModel: GameViewModel?
    @State private var reportedSeasonResult = false

    init(
        userTeam: GameTeam? = nil,
        opponent: GameTeam? = nil,
        isPlayoff: Bool = false,
        isChampionship: Bool = false,
        seasonNumber: Int? = nil,
        week: Int? = nil,
        onSeasonResult: ((GameMatch) -> Void)? = nil
    ) {
        self.userTeam = userTeam
        self.opponent = opponent
        self.isPlayoff = isPlayoff
        self.seasonNumber = seasonNumber
        self.week = week
        self.onSeasonResult = onSeasonResult
        _matchViewModel = State(initialValue: MatchViewModel(
            isPlayoff: isPlayoff,
            isChampionship: isChampionship,
            seasonNumber: seasonNumber ?? 0,
            week: week ?? 1
        ))
    }

    var body: some View {
        ZStack {
            switch matchViewModel.phase {
            case .quarterIntro:
                QuarterIntroView(
                    puzzle: matchViewModel.currentPuzzle,
                    isOvertime: matchViewModel.match.isOvertime,
                    onBegin: beginQuarter
                )
                .transition(.opacity)

            case .playing:
                if let quarterViewModel {
                    GameplayView(
                        viewModel: quarterViewModel,
                        matchViewModel: matchViewModel,
                        onQuit: { dismiss() },
                        onQuarterComplete: { matchViewModel.finishQuarter(with: $0) },
                        userTeam: userTeam,
                        opponent: opponent
                    )
                    .id(matchViewModel.match.currentQuarterIndex)
                    .transition(.opacity)
                }

            case .quarterResult:
                if let quarterViewModel {
                    QuarterResultView(
                        viewModel: quarterViewModel,
                        matchViewModel: matchViewModel,
                        onContinue: { matchViewModel.continueFlow() },
                        userTeam: userTeam,
                        opponent: opponent
                    )
                    .transition(.opacity)

                }

            case .gameResult:
                MatchResultView(
                    matchViewModel: matchViewModel,
                    userTeam: userTeam,
                    opponent: opponent,
                    allowsReplay: onSeasonResult == nil,
                    continueLabel: onSeasonResult == nil ? "HOME" : "CONTINUE",
                    onPlayAgain: playAgain,
                    onHome: {
                        dismiss()
                        // Leaving the finished game is a natural break — the
                        // frequency gate and rewarded-ad suppression decide
                        // whether an interstitial actually appears.
                        AdManager.shared.maybeShowInterstitial()
                    }
                )
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: matchViewModel.phase)
        .onChange(of: matchViewModel.phase) { _, phase in
            guard phase == .gameResult else { return }
            // Natural-break bookkeeping for the interstitial frequency gate.
            if matchViewModel.match.isComplete {
                AdManager.shared.recordCompletedGame()
            }
            guard let onSeasonResult, !reportedSeasonResult else { return }
            reportedSeasonResult = true
            onSeasonResult(matchViewModel.match)
        }
    }

    private func beginQuarter() {
        quarterViewModel = GameViewModel(puzzle: matchViewModel.currentPuzzle)
        // The Last Chance rewarded life is offered once per quarter, keyed to
        // this match + quarter and persisted in the wallet.
        quarterViewModel?.lastChanceKey = matchViewModel.currentLastChanceKey
        matchViewModel.beginQuarter()
    }

    private func playAgain() {
        quarterViewModel = nil
        matchViewModel.startGame()
    }
}

#Preview {
    MatchFlowView()
}

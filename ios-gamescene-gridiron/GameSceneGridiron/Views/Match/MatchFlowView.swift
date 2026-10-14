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
    /// A saved active-investigation record for this exact game: when present
    /// and context-matched, the game resumes at the saved quarter with the
    /// saved quarter state (placements, lives, hints, clock, timeouts).
    var resumeRecord: ActiveMatchRecord?

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
        onSeasonResult: ((GameMatch) -> Void)? = nil,
        resumeRecord: ActiveMatchRecord? = nil
    ) {
        self.userTeam = userTeam
        self.opponent = opponent
        self.isPlayoff = isPlayoff
        self.seasonNumber = seasonNumber
        self.week = week
        self.onSeasonResult = onSeasonResult
        self.resumeRecord = resumeRecord
        _matchViewModel = State(initialValue: MatchViewModel(
            isPlayoff: isPlayoff,
            isChampionship: isChampionship,
            seasonNumber: seasonNumber ?? 0,
            week: week ?? 1,
            resume: resumeRecord
        ))
        matchViewModel.matchSeasonNumber = seasonNumber
        matchViewModel.matchWeek = week
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
                        onQuit: {
                            markFirstGameAssistDone()
                            dismiss()
                        },
                        onQuarterComplete: { matchViewModel.finishQuarter(with: $0) },
                        userTeam: userTeam,
                        opponent: opponent,
                        showFirstGameAssist: showFirstGameAssist
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
                markFirstGameAssistDone()
            }
            guard let onSeasonResult, !reportedSeasonResult else { return }
            reportedSeasonResult = true
            onSeasonResult(matchViewModel.match)
        }
    }

    private func beginQuarter() {
        quarterViewModel = GameViewModel(
            puzzle: matchViewModel.currentPuzzle,
            difficulty: matchViewModel.activeDifficulty
        )
        // The Last Chance rewarded life is offered once per quarter, keyed to
        // this match + quarter and persisted in the wallet.
        quarterViewModel?.lastChanceKey = matchViewModel.currentLastChanceKey
        matchViewModel.beginQuarter()
    }

    // MARK: First-game assist

    /// Subtle training wheels for the user's very first regular-season game
    /// only (Season 1, Week 1). Never changes the selected difficulty.
    private var showFirstGameAssist: Bool {
        guard !isPlayoff, seasonNumber == 1, week == 1 else { return false }
        return TutorialManager.shared.isFirstGameAssistActive
    }

    /// The training wheels disappear after Game 1 — marked on completion or
    /// on leaving the game.
    private func markFirstGameAssistDone() {
        guard showFirstGameAssist else { return }
        TutorialManager.shared.markFirstGameAssistDone()
    }

    private func playAgain() {
        quarterViewModel = nil
        matchViewModel.startGame()
    }
}

#Preview {
    MatchFlowView()
}

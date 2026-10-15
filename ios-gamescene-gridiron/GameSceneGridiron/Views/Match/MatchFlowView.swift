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
    /// Pending forced-ad gate between quarters / into overtime: the skip
    /// cost while the gate is up, nil otherwise.
    @State private var adGateSkipCost: Int?
    @State private var isOvertimeGate = false
    @State private var isWatchingGateAd = false

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
                        onContinue: { continueAfterQuarterResult() },
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
                        // Leaving the finished game is a natural break — but
                        // the same per-game cap applies: once two forced ads
                        // played, everything is free.
                        if matchViewModel.canShowPostGameInterstitial {
                            matchViewModel.recordForcedAdShown()
                            AdManager.shared.maybeShowInterstitial()
                        }
                    }
                )
                .transition(.opacity)
            }

            // Forced full-screen gate (Remove Ads owners never see it):
            // WATCH AD — always free — or SKIP AD for Game Balls.
            if let skipCost = adGateSkipCost {
                AdGateOverlay(
                    skipCost: skipCost,
                    isOvertime: isOvertimeGate,
                    isWatching: isWatchingGateAd,
                    canAffordSkip: PlayerWallet.shared.gameBalls >= skipCost,
                    onWatch: { watchGateAd() },
                    onSkip: { skipGateAd(skipCost: skipCost) }
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
        // The rescue ledgers are keyed to this match + quarter and persisted
        // in the wallet.
        quarterViewModel?.lastChanceKey = matchViewModel.currentLastChanceKey
        matchViewModel.beginQuarter()
    }

    // MARK: Between-quarter ad gates (Phase 11.7)

    /// Continues from a quarter result through the forced-ad policy: a won
    /// quarter may gate (WATCH AD or SKIP AD — Game Balls); a lost quarter
    /// always advances free.
    private func continueAfterQuarterResult() {
        switch matchViewModel.adGateDecision() {
        case .none:
            matchViewModel.continueFlow()
        case .forced(let skipCost):
            Haptics.tick()
            isOvertimeGate = matchViewModel.match.needsOvertime
            withAnimation(.easeOut(duration: 0.22)) { adGateSkipCost = skipCost }
        }
    }

    /// WATCH AD: the free route. A shown ad is recorded against the per-game
    /// cap; if no ad is available the player continues free — nothing spent.
    private func watchGateAd() {
        guard !isWatchingGateAd else { return }
        isWatchingGateAd = true
        Task { @MainActor in
            let result = await AdManager.shared.showForcedAd()
            isWatchingGateAd = false
            guard adGateSkipCost != nil else { return }
            withAnimation(.easeOut(duration: 0.22)) { adGateSkipCost = nil }
            if result == .shown {
                matchViewModel.recordForcedAdShown()
            }
            matchViewModel.continueFlow()
        }
    }

    /// SKIP AD — Game Balls. Only reachable when the balance covers it; the
    /// free WATCH AD route is always available instead.
    private func skipGateAd(skipCost: Int) {
        guard matchViewModel.skipAd(cost: skipCost) else { return }
        Haptics.success()
        AudioManager.shared.play(.buttonPress)
        withAnimation(.easeOut(duration: 0.22)) { adGateSkipCost = nil }
        matchViewModel.continueFlow()
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

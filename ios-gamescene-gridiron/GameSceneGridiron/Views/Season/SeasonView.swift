import SwiftUI

/// The full-screen season surface behind the Home CTA. Without a franchise it
/// shows CREATE YOUR TEAM; otherwise it is the season hub: calendar, standings,
/// postseason bracket and season summary, plus match presentation.
struct SeasonView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var teamStore = TeamStore.shared

    var body: some View {
        if let team = teamStore.userTeam {
            SeasonHubView(userTeam: team, onClose: { dismiss() })
        } else {
            TeamCreationView { _ in
                // TeamStore now has a franchise; the hub appears automatically.
            } onClose: {
                dismiss()
            }
        }
    }
}

// MARK: - Hub

/// Owns season navigation and match presentation. Season data lives in
/// `SeasonManager`; this view only routes and records.
private struct SeasonHubView: View {
    let userTeam: GameTeam
    let onClose: () -> Void

    @State private var seasonManager = SeasonManager.shared
    @State private var destination: Destination = .calendar
    @State private var activeMatch: ActiveMatch?
    @State private var showChampionshipIntro: Bool = false
    @State private var showCelebration: Bool = false
    @State private var celebrationPending: Bool = false
    @State private var isEditingTeam: Bool = false
    @State private var isShowingDifficultySelect: Bool = false
    @State private var resumedRecord: ActiveMatchRecord?

    private enum Destination {
        case calendar
        case standings
        case bracket
        case summary
    }

    private enum ActiveMatch: Identifiable, Equatable {
        case week(ScheduledGame)
        case semifinal(PlayoffMatchup)
        case championship(PlayoffMatchup)

        var id: String {
            switch self {
            case .week(let game): "week-\(game.id)"
            case .semifinal(let matchup): "semi-\(matchup.teamA.uuidString)-\(matchup.teamB.uuidString)"
            case .championship(let matchup): "champ-\(matchup.teamA.uuidString)-\(matchup.teamB.uuidString)"
            }
        }

        var isPlayoff: Bool {
            switch self {
            case .week: false
            case .semifinal, .championship: true
            }
        }

        var isChampionship: Bool {
            if case .championship = self { return true }
            return false
        }

        /// Case-scheduler week: the regular-season week number, or 11/12 for
        /// the postseason so playoff games draw their own case rotation.
        var caseWeek: Int {
            switch self {
            case .week(let game): game.week
            case .semifinal: 11
            case .championship: 12
            }
        }
    }

    var body: some View {
        ZStack {
            switch destination {
            case .calendar:
                SeasonCalendarView(
                    userTeam: userTeam,
                    onStartSeason: {
                        isShowingDifficultySelect = true
                    },
                    onClose: onClose,
                    onEditTeam: { isEditingTeam = true },
                    onOpenStandings: { switchDestination(.standings) },
                    onOpenPostseason: { switchDestination(.bracket) },
                    onOpenSummary: { switchDestination(.summary) }
                ) { game in
                    Haptics.pickUp()
                    resumedRecord = nil
                    activeMatch = .week(game)
                }
                .transition(pageTransition)

            case .standings:
                StandingsView(userTeam: userTeam) {
                    switchDestination(.calendar)
                }
                .transition(pageTransition)

            case .bracket:
                PlayoffBracketView(
                    userTeam: userTeam,
                    onBack: { switchDestination(.calendar) },
                    onPlaySemifinal: { matchup in
                        Haptics.pickUp()
                        resumedRecord = nil
                        activeMatch = .semifinal(matchup)
                    },
                    onPlayChampionship: {
                        Haptics.pickUp()
                        resumedRecord = nil
                        showChampionshipIntro = true
                    },
                    onViewSummary: { switchDestination(.summary) }
                )
                .transition(pageTransition)

            case .summary:
                if let summary = seasonManager.seasonResult {
                    SeasonSummaryView(
                        userTeam: userTeam,
                        summary: summary,
                        championName: championName,
                        onStartNewSeason: startNewSeason,
                        onClose: onClose
                    )
                    .transition(pageTransition)
                } else {
                    SeasonCalendarView(
                        userTeam: userTeam,
                        onStartSeason: {
                            isShowingDifficultySelect = true
                        },
                        onClose: onClose,
                        onEditTeam: { isEditingTeam = true },
                        onOpenStandings: { switchDestination(.standings) },
                        onOpenPostseason: { switchDestination(.bracket) },
                        onOpenSummary: {}
                    ) { game in
                        Haptics.pickUp()
                        activeMatch = .week(game)
                    }
                    .transition(pageTransition)
                }
            }
        }
        .animation(.easeInOut(duration: 0.35), value: destination)
        .fullScreenCover(item: $activeMatch) { match in
            MatchFlowView(
                userTeam: userTeam,
                opponent: opponentTeam(for: match),
                isPlayoff: match.isPlayoff,
                isChampionship: match.isChampionship,
                seasonNumber: seasonManager.season?.seasonNumber,
                week: match.caseWeek,
                onSeasonResult: { gameMatch in
                    record(match, gameMatch)
                },
                resumeRecord: resumedRecord
            )
        }
        .onAppear { resumeActiveInvestigationIfNeeded() }
        .onChange(of: destination) { _, _ in resumeActiveInvestigationIfNeeded() }
        .fullScreenCover(isPresented: $showChampionshipIntro) {
            if let matchup = seasonManager.pendingPlayoffMatchup,
               let opponent = opponentTeam(id: opponentID(in: matchup)) {
                ChampionshipIntroView(
                    userTeam: userTeam,
                    opponent: opponent,
                    onPlay: {
                        showChampionshipIntro = false
                        resumedRecord = nil
                        activeMatch = .championship(matchup)
                    },
                    onClose: { showChampionshipIntro = false }
                )
            }
        }
        .fullScreenCover(isPresented: $showCelebration) {
            if let summary = seasonManager.seasonResult {
                ChampionsCelebrationView(
                    userTeam: userTeam,
                    summary: summary,
                    onViewSummary: {
                        showCelebration = false
                        switchDestination(.summary)
                    }
                )
            }
        }
        .fullScreenCover(isPresented: $isEditingTeam) {
            TeamCreationView(existingTeam: userTeam) { _ in
                isEditingTeam = false
            } onClose: {
                isEditingTeam = false
            }
        }
        .sheet(isPresented: $isShowingDifficultySelect) {
            DifficultySelectView { level in
                // Phase 11.6: the confirmed level starts AND locks the new
                // season — the running season can never change difficulty.
                seasonManager.startNewSeason(userTeam: userTeam, difficulty: level)
                isShowingDifficultySelect = false
                destination = .calendar
            }
        }
        .onChange(of: activeMatch) { oldValue, newValue in
            if oldValue != nil, newValue == nil { resumedRecord = nil }
            guard oldValue != nil, newValue == nil, celebrationPending else { return }
            celebrationPending = false
            showCelebration = true
        }
    }

    private var pageTransition: AnyTransition {
        // Reduce Motion: plain fades instead of full-width page flips.
        Motion.pageTransition
    }

    // MARK: Investigation resume (Phase 11.6)

    /// Reopens a game the player left mid-investigation: the saved record
    /// must match the CURRENT season and its current game exactly. The match
    /// then resumes at the saved quarter with the saved quarter state —
    /// solved placements, lives, hints, timeouts, clock — never a fresh deal.
    private func resumeActiveInvestigationIfNeeded() {
        guard destination == .calendar, activeMatch == nil, resumedRecord == nil,
              !showCelebration else { return }
        guard let record = ActiveInvestigationStore.load(),
              let season = seasonManager.season,
              season.phase != .complete,
              let game = season.currentGame else { return }
        let seasonNumber = season.seasonNumber
        if record.isPlayoff {
            let isChampionshipPending = season.bracket?.championship?.has(teamID: season.userTeamID) == true
                && season.bracket?.championship?.result == nil
            guard record.seasonNumber == seasonNumber,
                  let matchup = seasonManager.pendingPlayoffMatchup,
                  record.isChampionship == isChampionshipPending else {
                ActiveInvestigationStore.clear()
                return
            }
            resumedRecord = record
            activeMatch = isChampionshipPending ? .championship(matchup) : .semifinal(matchup)
        } else {
            guard ActiveInvestigationStore.matches(
                record, seasonNumber: seasonNumber, week: game.week,
                isPlayoff: false, isChampionship: false
            ) else {
                ActiveInvestigationStore.clear()
                return
            }
            resumedRecord = record
            activeMatch = .week(game)
        }
    }

    private var championName: String? {
        guard let championID = seasonManager.season?.bracket?.championID else { return nil }
        if championID == userTeam.id { return nil }
        return OpponentTeams.team(with: championID)?.displayName
    }

    private func switchDestination(_ newDestination: Destination) {
        AudioManager.shared.play(.cardSelect)
        destination = newDestination
    }

    private func opponentID(in matchup: PlayoffMatchup) -> UUID {
        matchup.teamA == userTeam.id ? matchup.teamB : matchup.teamA
    }

    private func opponentTeam(id: UUID) -> GameTeam? {
        OpponentTeams.team(with: id)
    }

    private func opponentTeam(for match: ActiveMatch) -> GameTeam? {
        switch match {
        case .week(let game):
            return OpponentTeams.team(with: game.opponentID)
        case .semifinal(let matchup), .championship(let matchup):
            return OpponentTeams.team(with: opponentID(in: matchup))
        }
    }

    private func record(_ match: ActiveMatch, _ gameMatch: GameMatch) {
        var wasRecorded = false
        let stage: FranchiseGameStage
        switch match {
        case .week(let game):
            guard let opponent = OpponentTeams.team(with: game.opponentID) else { return }
            wasRecorded = seasonManager.recordUserMatch(gameMatch, opponent: opponent)
            stage = .regularSeason
        case .semifinal(let matchup):
            guard let opponent = OpponentTeams.team(with: opponentID(in: matchup)) else { return }
            wasRecorded = seasonManager.recordUserPlayoffMatch(gameMatch, opponent: opponent)
            stage = .semifinal
        case .championship(let matchup):
            guard let opponent = OpponentTeams.team(with: opponentID(in: matchup)) else { return }
            wasRecorded = seasonManager.recordUserPlayoffMatch(gameMatch, opponent: opponent)
            stage = .championship
            if seasonManager.season?.bracket?.championID == userTeam.id {
                celebrationPending = true
            }
        }

        // Franchise ledger: solved-case stats, game logs, Player of the Game,
        // records and dynasty history — one entry point, once per game.
        if let opponent = opponentTeam(for: match) {
            RosterManager.shared.recordGame(
                stage: stage,
                seasonNumber: seasonManager.season?.seasonNumber ?? 1,
                week: match.caseWeek,
                opponentName: opponent.displayName,
                teamWon: gameMatch.result?.isWin ?? false,
                events: gameMatch.statEvents,
                appearedIDs: gameMatch.appearedFranchiseIDs
            )
        }

        // Recognition events fire only for a game that was actually recorded
        // (season + roster ledgers updated) — a safe break on the result screen.
        if wasRecorded {
            AchievementCoordinator.gameCompleted(
                match: gameMatch,
                stage: stage,
                difficulty: DifficultyManager.shared.selected
            )
        }
    }

    /// Both season-start paths route through SELECT DIFFICULTY first; the
    /// confirmed level is persisted and shapes the whole coming season.
    private func startNewSeason() {
        isShowingDifficultySelect = true
    }
}

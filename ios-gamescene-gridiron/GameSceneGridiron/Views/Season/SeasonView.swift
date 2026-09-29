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
    }

    var body: some View {
        ZStack {
            switch destination {
            case .calendar:
                SeasonCalendarView(
                    userTeam: userTeam,
                    onClose: onClose,
                    onEditTeam: { isEditingTeam = true },
                    onOpenStandings: { switchDestination(.standings) },
                    onOpenPostseason: { switchDestination(.bracket) },
                    onOpenSummary: { switchDestination(.summary) }
                ) { game in
                    Haptics.pickUp()
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
                        activeMatch = .semifinal(matchup)
                    },
                    onPlayChampionship: {
                        Haptics.pickUp()
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
                onSeasonResult: { gameMatch in
                    record(match, gameMatch)
                }
            )
        }
        .fullScreenCover(isPresented: $showChampionshipIntro) {
            if let matchup = seasonManager.pendingPlayoffMatchup,
               let opponent = opponentTeam(id: opponentID(in: matchup)) {
                ChampionshipIntroView(
                    userTeam: userTeam,
                    opponent: opponent,
                    onPlay: {
                        showChampionshipIntro = false
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
        .onChange(of: activeMatch) { oldValue, newValue in
            guard oldValue != nil, newValue == nil, celebrationPending else { return }
            celebrationPending = false
            showCelebration = true
        }
    }

    private var pageTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .trailing).combined(with: .opacity)
        )
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
        switch match {
        case .week(let game):
            guard let opponent = OpponentTeams.team(with: game.opponentID) else { return }
            seasonManager.recordUserMatch(gameMatch, opponent: opponent)
        case .semifinal(let matchup):
            guard let opponent = OpponentTeams.team(with: opponentID(in: matchup)) else { return }
            seasonManager.recordUserPlayoffMatch(gameMatch, opponent: opponent)
        case .championship(let matchup):
            guard let opponent = OpponentTeams.team(with: opponentID(in: matchup)) else { return }
            seasonManager.recordUserPlayoffMatch(gameMatch, opponent: opponent)
            if seasonManager.season?.bracket?.championID == userTeam.id {
                celebrationPending = true
            }
        }
    }

    private func startNewSeason() {
        seasonManager.startNewSeason(userTeam: userTeam)
        destination = .calendar
    }
}

import SwiftUI

/// POSTSEASON — a 4-team investigation board: two clipped semifinal cards
/// connected by chalk lines to THE GRIDIRON CASE championship card. The
/// player's games use the full match flow; CPU games resolve locally.
struct PlayoffBracketView: View {
    let userTeam: GameTeam
    let onBack: () -> Void
    let onPlaySemifinal: (PlayoffMatchup) -> Void
    let onPlayChampionship: () -> Void
    let onViewSummary: () -> Void

    @State private var seasonManager = SeasonManager.shared
    @State private var hasAppeared: Bool = false

    private var bracket: PlayoffBracket? { seasonManager.season?.bracket }

    var body: some View {
        ZStack {
            DeskBackground()

            ScrollView {
                VStack(spacing: 18) {
                    header

                    if let bracket {
                        board(bracket)
                        championBanner(bracket)
                        if seasonManager.season?.phase == .complete {
                            summaryButton
                        }
                    } else {
                        emptyState
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 14)
                .padding(.bottom, 30)
                .opacity(hasAppeared ? 1 : 0)
                .offset(y: hasAppeared ? 0 : 18)
            }
            .scrollIndicators(.hidden)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) { hasAppeared = true }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 12) {
            Button {
                Haptics.tick()
                onBack()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.goldLight)
                    .frame(width: 38, height: 38)
                    .background(Color.black.opacity(0.45), in: .circle)
                    .overlay { Circle().strokeBorder(Theme.gold.opacity(0.4), lineWidth: 1) }
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityLabel("Back to the schedule")

            VStack(spacing: 2) {
                Text("POSTSEASON")
                    .font(.system(size: 26, weight: .black).width(.compressed))
                    .tracking(2)
                    .foregroundStyle(Theme.goldGradient)
                Text("FOUR TEAMS. ONE CASE TO CRACK.")
                    .font(Theme.typewriter(10, relativeTo: .caption2))
                    .tracking(1.2)
                    .foregroundStyle(Theme.paperInkSoft.opacity(0.85))
            }
            .frame(maxWidth: .infinity)

            if let season = seasonManager.season {
                Text("S\(season.seasonNumber)")
                    .font(.system(size: 13, weight: .heavy).width(.condensed))
                    .tracking(1)
                    .foregroundStyle(Theme.paperInk)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Theme.gold.opacity(0.16), in: .capsule)
                    .overlay { Capsule().strokeBorder(Theme.gold.opacity(0.5), lineWidth: 1) }
            }
        }
    }

    private var emptyState: some View {
        Text("The bracket fills after Week 10.")
            .font(Theme.typewriter(13, relativeTo: .footnote))
            .foregroundStyle(Theme.paperInkSoft)
            .padding(20)
            .paperCard(cornerRadius: 6)
    }

    // MARK: Board

    private func board(_ bracket: PlayoffBracket) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                MatchupCard(
                    title: "SEMIFINAL 1",
                    subtitle: "#1 VS #4",
                    matchup: bracket.semifinal1,
                    userTeamID: userTeam.id,
                    accent: .gold
                ) {
                    onPlaySemifinal(bracket.semifinal1)
                }
                MatchupCard(
                    title: "SEMIFINAL 2",
                    subtitle: "#2 VS #3",
                    matchup: bracket.semifinal2,
                    userTeamID: userTeam.id,
                    accent: .gold
                ) {
                    onPlaySemifinal(bracket.semifinal2)
                }
            }

            BracketConnector()

            if let championship = bracket.championship {
                championshipCard(championship)
            } else {
                championshipPlaceholder
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(Color.black.opacity(0.45), in: .rect(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Theme.gold.opacity(0.25), lineWidth: 1)
        }
        .rotationEffect(.degrees(-0.5))
    }

    private func championshipCard(_ championship: PlayoffMatchup) -> some View {
        VStack(spacing: 10) {
            VStack(spacing: 4) {
                Text("THE GRIDIRON CASE")
                    .font(.system(size: 24, weight: .black).width(.compressed))
                    .tracking(1.5)
                    .foregroundStyle(Theme.goldGradient)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text("CHAMPIONSHIP")
                    .font(.system(size: 11, weight: .heavy).width(.condensed))
                    .tracking(5)
                    .foregroundStyle(Theme.goldLight)
            }
            .padding(.top, 14)

            championshipTeams(championship)

            footer(for: championship) {
                Haptics.pickUp()
                AudioManager.shared.play(.profileSelect)
                onPlayChampionship()
            }
        }
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.black.opacity(0.7), Theme.gold.opacity(0.1), Color.black.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Theme.goldGradient, lineWidth: 2)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Theme.gold.opacity(0.4), lineWidth: 1)
                .padding(4)
        }
    }

    @ViewBuilder
    private func championshipTeams(_ championship: PlayoffMatchup) -> some View {
        HStack(spacing: 12) {
            ChampionshipTeamSlot(
                team: team(championship.teamA),
                seed: championship.seedA
            )
            Text("VS")
                .font(.system(size: 16, weight: .black).width(.compressed))
                .foregroundStyle(Theme.gold)
            ChampionshipTeamSlot(
                team: team(championship.teamB),
                seed: championship.seedB
            )
        }
    }

    private var championshipPlaceholder: some View {
        VStack(spacing: 8) {
            Text("THE GRIDIRON CASE")
                .font(.system(size: 22, weight: .black).width(.compressed))
                .tracking(1.5)
                .foregroundStyle(Theme.gold.opacity(0.75))
            Text("CHAMPIONSHIP")
                .font(.system(size: 10, weight: .heavy).width(.condensed))
                .tracking(5)
                .foregroundStyle(Theme.paperInkSoft)
            Text("SEMIFINAL WINNERS ADVANCE")
                .font(Theme.typewriter(11, relativeTo: .caption))
                .foregroundStyle(Theme.paperInkSoft.opacity(0.7))
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 26)
        .background(Color.black.opacity(0.35), in: .rect(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Theme.gold.opacity(0.35), style: StrokeStyle(lineWidth: 1.4, dash: [7, 5]))
        }
    }

    private var summaryButton: some View {
        Button {
            Haptics.pickUp()
            onViewSummary()
        } label: {
            HStack {
                Spacer()
                Text("VIEW SEASON SUMMARY")
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 14, weight: .bold))
            }
            .padding(.horizontal, 24)
        }
        .buttonStyle(GoldCapsuleButtonStyle())
    }

    // MARK: Champion banner

    @ViewBuilder
    private func championBanner(_ bracket: PlayoffBracket) -> some View {
        if let championID = bracket.championID {
            let isUser = championID == userTeam.id
            let champion = isUser ? userTeam : OpponentTeams.team(with: championID)
            HStack(spacing: 12) {
                if let champion {
                    TeamEmblemView(team: champion, size: 52)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(isUser ? "GRIDIRON CHAMPIONS" : "SEASON CHAMPIONS")
                            .font(.system(size: 17, weight: .black).width(.compressed))
                            .tracking(1)
                            .foregroundStyle(Theme.goldGradient)
                        Text(champion.displayName.uppercased())
                            .font(.system(size: 14, weight: .heavy).width(.compressed))
                            .tracking(0.8)
                            .foregroundStyle(Theme.paperInk)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .paperCard(cornerRadius: 8)
            .rotationEffect(.degrees(0.5))
            .transition(.scale(scale: 0.9).combined(with: .opacity))
        }
    }

    // MARK: Helpers

    private func team(_ id: UUID) -> GameTeam? {
        id == userTeam.id ? userTeam : OpponentTeams.team(with: id)
    }

    @ViewBuilder
    private func footer(for matchup: PlayoffMatchup, onPlay: @escaping () -> Void) -> some View {
        if let result = matchup.result {
            let outcome = result.outcome(for: userTeam.id)
            HStack(spacing: 8) {
                Text(result.scoreLine)
                    .font(.system(size: 18, weight: .black).width(.compressed))
                    .monospacedDigit()
                    .foregroundStyle(matchup.winnerID == userTeam.id ? Theme.easy : (matchup.has(teamID: userTeam.id) ? Theme.danger : Theme.paperInk))
                Text(result.wentToOT ? "OVERTIME" : "FINAL")
                    .font(.system(size: 9, weight: .heavy).width(.condensed))
                    .tracking(1.6)
                    .foregroundStyle(Theme.paperInkSoft)
                if matchup.has(teamID: userTeam.id) {
                    Text(outcome.isWin ? "YOU WIN" : "RUN ENDS")
                        .font(.system(size: 9, weight: .heavy).width(.condensed))
                        .tracking(1.6)
                        .foregroundStyle(outcome.isWin ? Theme.easy : Theme.danger)
                }
            }
            .padding(.bottom, 14)
        } else if matchup.has(teamID: userTeam.id) {
            Button(action: onPlay) {
                HStack {
                    Spacer()
                    Text("PLAY THE CASE")
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 13, weight: .bold))
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 4)
            }
            .buttonStyle(GoldCapsuleButtonStyle())
            .padding(.bottom, 12)
        } else {
            Text("AWAITING RESULT")
                .font(.system(size: 9, weight: .heavy).width(.condensed))
                .tracking(1.6)
                .foregroundStyle(Theme.paperInkSoft)
                .padding(.bottom, 14)
        }
    }
}

// MARK: - Team slot

private struct ChampionshipTeamSlot: View {
    let team: GameTeam?
    let seed: Int

    var body: some View {
        VStack(spacing: 5) {
            if let team {
                TeamEmblemView(team: team, size: 46)
                    .shadow(color: team.primaryColor.opacity(0.6), radius: 12)
                Text(team.shortName)
                    .font(.system(size: 12, weight: .black).width(.compressed))
                    .tracking(0.6)
                    .foregroundStyle(Theme.paperInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            } else {
                Image(systemName: "questionmark")
                    .font(.system(size: 20, weight: .black))
                    .foregroundStyle(Theme.paperInkSoft.opacity(0.5))
                    .frame(width: 46, height: 46)
                Text("TBD")
                    .font(.system(size: 12, weight: .black).width(.compressed))
                    .foregroundStyle(Theme.paperInkSoft)
            }
            Text("#\(seed)")
                .font(.system(size: 9, weight: .heavy).width(.condensed))
                .tracking(1)
                .foregroundStyle(Theme.goldLight)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Matchup card

/// One clipped playoff card on the board.
private struct MatchupCard: View {
    let title: String
    let subtitle: String
    let matchup: PlayoffMatchup
    let userTeamID: UUID
    let accent: Palette
    let onPlay: () -> Void

    enum Palette { case gold }

    private func team(_ id: UUID) -> GameTeam? {
        id == userTeamID ? nil : OpponentTeams.team(with: id)
    }

    var body: some View {
        VStack(spacing: 9) {
            VStack(spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .black).width(.compressed))
                    .tracking(1.4)
                    .foregroundStyle(Theme.paperInk)
                Text(subtitle)
                    .font(.system(size: 9, weight: .heavy).width(.condensed))
                    .tracking(1.6)
                    .foregroundStyle(Theme.paperInkSoft)
            }

            teamRow(seed: matchup.seedA, teamID: matchup.teamA)
            teamRow(seed: matchup.seedB, teamID: matchup.teamB)

            footer
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background {
            PaperSurface(cornerRadius: 6, darkness: 0.02)
                .shadow(color: .black.opacity(0.5), radius: 8, y: 5)
        }
        .rotationEffect(.degrees(title.contains("1") ? -1 : 1))
        .accessibilityElement(children: .combine)
    }

    private func teamRow(seed: Int, teamID: UUID) -> some View {
        let isWinner = matchup.winnerID == teamID
        let isUser = teamID == userTeamID
        return HStack(spacing: 7) {
            Text("#\(seed)")
                .font(.system(size: 10, weight: .heavy).width(.condensed))
                .foregroundStyle(Theme.goldLight)
                .frame(width: 24, height: 20)
                .background(Color.black.opacity(0.5), in: .capsule)
            if isUser {
                Image(systemName: "person.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.goldLight)
                    .frame(width: 26, height: 26)
                    .background(Theme.gold.opacity(0.25), in: .circle)
            } else if let team = team(teamID) {
                TeamEmblemView(team: team, size: 26)
            }
            Text(teamName(teamID))
                .font(.system(size: 11, weight: .bold).width(.compressed))
                .tracking(0.4)
                .foregroundStyle(isWinner ? Theme.goldLight : Theme.paperInk.opacity(0.85))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 0)
            if isWinner {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.easy)
            }
        }
    }

    private func teamName(_ id: UUID) -> String {
        if id == userTeamID { return "YOUR TEAM" }
        return OpponentTeams.team(with: id)?.shortName ?? "TBD"
    }

    @ViewBuilder
    private var footer: some View {
        if let result = matchup.result {
            Text(result.scoreLine)
                .font(.system(size: 15, weight: .black).width(.compressed))
                .monospacedDigit()
                .foregroundStyle(matchup.has(teamID: userTeamID) ? (matchup.winnerID == userTeamID ? Theme.easy : Theme.danger) : Theme.paperInk)
        } else if matchup.has(teamID: userTeamID) {
            Button {
                Haptics.pickUp()
                AudioManager.shared.play(.profileSelect)
                onPlay()
            } label: {
                Text("PLAY")
                    .font(.system(size: 12, weight: .black).width(.compressed))
                    .tracking(1.4)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 7)
            }
            .buttonStyle(GoldCapsuleButtonStyle())
        } else {
            Text("PENDING")
                .font(.system(size: 9, weight: .heavy).width(.condensed))
                .tracking(1.6)
                .foregroundStyle(Theme.paperInkSoft.opacity(0.7))
        }
    }
}

// MARK: - Connector

/// Chalk lines funneling the two semifinal winners into the championship slot.
private struct BracketConnector: View {
    var body: some View {
        GeometryReader { geometry in
            let w = geometry.size.width
            let h = geometry.size.height
            Path { path in
                path.move(to: CGPoint(x: w * 0.25, y: 0))
                path.addLine(to: CGPoint(x: w * 0.25, y: h * 0.45))
                path.addLine(to: CGPoint(x: w * 0.75, y: h * 0.45))
                path.move(to: CGPoint(x: w * 0.75, y: 0))
                path.addLine(to: CGPoint(x: w * 0.75, y: h * 0.45))
                path.move(to: CGPoint(x: w * 0.5, y: h * 0.45))
                path.addLine(to: CGPoint(x: w * 0.5, y: h))
            }
            .stroke(
                Theme.gold.opacity(0.5),
                style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [1, 6])
            )
        }
        .frame(height: 34)
        .accessibilityHidden(true)
    }
}

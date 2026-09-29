import SwiftUI

/// LEAGUE STANDINGS — the 11-team fictional league table on a case-file
/// clipboard. Sorted by wins; the user's row is highlighted and the playoff
/// cut line is marked once games are underway.
struct StandingsView: View {
    let userTeam: GameTeam
    let onClose: () -> Void

    @State private var seasonManager = SeasonManager.shared
    @State private var hasAppeared: Bool = false

    private var ranked: [LeagueStanding] { seasonManager.rankedStandings() }

    var body: some View {
        ZStack {
            DeskBackground()

            ScrollView {
                clipboard
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

    private var clipboard: some View {
        VStack(spacing: 14) {
            header
            columnHeaders
            rows
            legend
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity)
        .background {
            PaperSurface(cornerRadius: 8, darkness: 0.04)
                .shadow(color: .black.opacity(0.6), radius: 16, y: 10)
        }
        .overlay(alignment: .top) {
            PushPin(size: 20).offset(y: -9)
        }
        .rotationEffect(.degrees(0.6))
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button {
                Haptics.tick()
                onClose()
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
                Text("LEAGUE STANDINGS")
                    .font(.system(size: 24, weight: .black).width(.compressed))
                    .tracking(1.5)
                    .foregroundStyle(Theme.goldGradient)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text("CONFIDENTIAL — 11 TEAMS UNDER SURVEILLANCE")
                    .font(Theme.typewriter(10, relativeTo: .caption2))
                    .tracking(1)
                    .foregroundStyle(Theme.paperInkSoft.opacity(0.85))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
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

    private var columnHeaders: some View {
        HStack(spacing: 0) {
            Text("#")
                .frame(width: 30, alignment: .leading)
            Text("TEAM")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("W")
                .frame(width: 34)
            Text("L")
                .frame(width: 34)
            Text("GP")
                .frame(width: 40)
        }
        .font(.system(size: 10, weight: .heavy).width(.condensed))
        .tracking(1.4)
        .foregroundStyle(Theme.paperInkSoft)
        .padding(.horizontal, 10)
    }

    private var rows: some View {
        VStack(spacing: 0) {
            ForEach(Array(ranked.enumerated()), id: \.element.id) { index, standing in
                row(index: index, standing: standing)
                if index == 3, index < ranked.count - 1 {
                    playoffCutLine
                }
            }
        }
        .background(Color.black.opacity(0.28), in: .rect(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Theme.paperInk.opacity(0.2), lineWidth: 1)
        }
    }

    private var playoffCutLine: some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(Theme.gold.opacity(0.55))
                .frame(height: 1)
            Text("POSTSEASON CUT")
                .font(.system(size: 8, weight: .heavy).width(.condensed))
                .tracking(1.6)
                .foregroundStyle(Theme.goldLight.opacity(0.9))
            Rectangle()
                .fill(Theme.gold.opacity(0.55))
                .frame(height: 1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
    }

    private func row(index: Int, standing: LeagueStanding) -> some View {
        let isUser = standing.teamID == userTeam.id
        let team = isUser ? userTeam : OpponentTeams.team(with: standing.teamID)

        return HStack(spacing: 0) {
            Text("\(index + 1)")
                .font(Theme.typewriter(14, relativeTo: .subheadline))
                .monospacedDigit()
                .foregroundStyle(isUser ? Theme.goldLight : Theme.paperInkSoft)
                .frame(width: 30, alignment: .leading)

            if let team {
                HStack(spacing: 8) {
                    TeamEmblemView(team: team, size: 30)
                    Text(team.shortName)
                        .font(.system(size: 13, weight: isUser ? .black : .bold).width(.compressed))
                        .tracking(0.5)
                        .foregroundStyle(isUser ? Theme.goldLight : Theme.paperInk)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    if isUser {
                        Text("YOU")
                            .font(.system(size: 8, weight: .heavy).width(.condensed))
                            .tracking(1)
                            .foregroundStyle(Color.black)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Theme.gold, in: .capsule)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Text("\(standing.totalWins)")
                .font(.system(size: 15, weight: .black).width(.compressed))
                .monospacedDigit()
                .foregroundStyle(Theme.easy)
                .frame(width: 34)
            Text("\(standing.totalLosses)")
                .font(.system(size: 15, weight: .black).width(.compressed))
                .monospacedDigit()
                .foregroundStyle(Theme.danger)
                .frame(width: 34)
            Text("\(standing.gamesPlayed)")
                .font(.system(size: 13, weight: .bold).width(.compressed))
                .monospacedDigit()
                .foregroundStyle(Theme.paperInkSoft)
                .frame(width: 40)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(isUser ? Theme.gold.opacity(0.12) : .clear)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Theme.paperInk.opacity(0.1))
                .frame(height: 1)
        }
        .overlay(alignment: .leading) {
            if isUser {
                Rectangle()
                    .fill(Theme.gold)
                    .frame(width: 3)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Position \(index + 1). \(team?.displayName ?? ""), \(standing.recordLine), \(standing.gamesPlayed) games played")
    }

    private var legend: some View {
        Text("SORTED BY WINS — INVESTIGATION QUARTERS, NOT POINTS")
            .font(Theme.typewriter(10, relativeTo: .caption2))
            .tracking(0.8)
            .foregroundStyle(Theme.paperInkSoft.opacity(0.7))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }
}

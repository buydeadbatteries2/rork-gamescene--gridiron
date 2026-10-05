import SwiftUI

/// Player Detail — one roster member's full file: visored portrait, identity,
/// current-season stats, career stats and a game-by-game log of their
/// statistical contributions from solved cases.
struct PlayerDetailView: View {
    @Environment(\.dismiss) private var dismiss

    let player: FranchisePlayer
    let team: GameTeam
    let onClose: () -> Void

    @State private var hasAppeared: Bool = false

    var body: some View {
        ZStack {
            DeskBackground()

            ScrollView {
                VStack(spacing: 16) {
                    header
                        .opacity(hasAppeared ? 1 : 0)
                        .offset(y: hasAppeared ? 0 : 14)

                    statsCard(
                        title: "SEASON \(SeasonManager.shared.season?.seasonNumber ?? 1) STATS",
                        line: player.seasonStats,
                        emptyText: "NO SEASON STATS YET — SOLVE CASES TO BUILD A RESUME"
                    )
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(y: hasAppeared ? 0 : 14)

                    statsCard(
                        title: "CAREER STATS",
                        line: player.careerStats,
                        emptyText: "FIRST SEASON IN THE FILE"
                    )
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(y: hasAppeared ? 0 : 14)

                    gameLogCard
                        .opacity(hasAppeared ? 1 : 0)
                        .offset(y: hasAppeared ? 0 : 14)

                    Spacer(minLength: 10)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.85).delay(0.05)) { hasAppeared = true }
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(spacing: 0) {
            Color(hex: 0x14110D)
                .frame(height: 210)
                .overlay {
                    RadialGradient(
                        colors: [Theme.positionAccent(player.position).opacity(0.42), .clear],
                        center: UnitPoint(x: 0.5, y: 0.28),
                        startRadius: 4,
                        endRadius: 240
                    )
                    .allowsHitTesting(false)
                }
                .overlay {
                    Image(player.bodyAssetID)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .colorMultiply(team.primaryColor)
                        .allowsHitTesting(false)
                }
                .overlay {
                    LinearGradient(
                        colors: [.clear, .clear, Color(hex: 0x14110D)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .allowsHitTesting(false)
                }
                .clipped()
                .overlay(alignment: .topLeading) {
                    LinearGradient(colors: [.white.opacity(0.14), .clear], startPoint: .top, endPoint: .bottom)
                        .frame(height: 80)
                        .allowsHitTesting(false)
                }
                .overlay(alignment: .topTrailing) {
                    Button {
                        Haptics.tick()
                        onClose()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Theme.goldLight)
                            .frame(width: 34, height: 34)
                            .background(Color.black.opacity(0.55), in: .circle)
                            .overlay { Circle().strokeBorder(Theme.gold.opacity(0.4), lineWidth: 1) }
                    }
                    .buttonStyle(PressableButtonStyle())
                    .padding(10)
                    .accessibilityLabel("Close player file")
                }
                .overlay(alignment: .topLeading) {
                    if player.seasonStats.value(for: .playerOfTheGame) > 0
                        || player.careerStats.value(for: .playerOfTheGame) > 0 {
                        awardBadge
                            .padding(10)
                    }
                }

            VStack(spacing: 6) {
                Text(player.displayName.uppercased())
                    .font(.system(size: 28, weight: .black).width(.compressed))
                    .tracking(1)
                    .foregroundStyle(Theme.paperInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                HStack(spacing: 8) {
                    Text(player.slot.label)
                        .font(.system(size: 12, weight: .heavy).width(.condensed))
                        .tracking(1)
                        .foregroundStyle(Color.white.opacity(0.95))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2.5)
                        .background(Theme.positionAccent(player.position).opacity(0.9), in: .rect(cornerRadius: 4))
                    Text(player.position.fullName.uppercased())
                        .font(.system(size: 12, weight: .heavy).width(.condensed))
                        .tracking(1.2)
                        .foregroundStyle(Theme.paperInkSoft)
                    Text("·")
                        .foregroundStyle(Theme.paperInkSoft)
                    Text(team.displayName.uppercased())
                        .font(.system(size: 12, weight: .heavy).width(.condensed))
                        .tracking(1)
                        .foregroundStyle(Theme.bronzeDeep)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }

                Text("SAME PLAYER, ANY PROFILE — THE CASE DECIDES FAST, POWER OR VETERAN")
                    .font(Theme.typewriter(10, relativeTo: .caption2))
                    .foregroundStyle(Theme.paperInkSoft)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
            }
            .padding(.vertical, 12)
        }
        .frame(maxWidth: .infinity)
        .paperCard(cornerRadius: 8)
        .clipShape(.rect(cornerRadius: 8))
        .overlay(alignment: .top) { PushPin(size: 20).offset(y: -10) }
        .padding(.top, 10)
        .accessibilityElement(children: .contain)
    }

    private var awardBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "star.fill")
                .font(.system(size: 10, weight: .bold))
            Text("POG")
                .font(.system(size: 10, weight: .black).width(.condensed))
                .tracking(0.8)
        }
        .foregroundStyle(Theme.ink)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Theme.goldGradient, in: .capsule)
        .accessibilityLabel("Has earned Player of the Game awards")
    }

    // MARK: Stats

    private func statsCard(title: String, line: PlayerStatLine, emptyText: String) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .heavy).width(.condensed))
                .tracking(2)
                .foregroundStyle(Theme.paperInkSoft)
                .frame(maxWidth: .infinity, alignment: .leading)

            let rows = PlayerStat.relevant(for: player.position).filter { line.value(for: $0) > 0 }
            if rows.isEmpty {
                Text(emptyText)
                    .font(Theme.typewriter(12, relativeTo: .caption))
                    .foregroundStyle(Theme.paperInkSoft)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else {
                ForEach(rows, id: \.rawValue) { stat in
                    HStack {
                        Text(stat.fullLabel)
                            .font(Theme.typewriter(13, relativeTo: .footnote))
                            .foregroundStyle(Theme.paperInk)
                        Spacer()
                        Text("\(line.value(for: stat))")
                            .font(.system(size: 17, weight: .heavy).width(.condensed))
                            .monospacedDigit()
                            .foregroundStyle(Theme.goldLight)
                    }
                    .padding(.vertical, 6)
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(Theme.paperInk.opacity(0.12)).frame(height: 1)
                    }
                }
            }
        }
        .padding(14)
        .paperCard(cornerRadius: 6)
        .rotationEffect(.degrees(-0.4))
    }

    // MARK: Game log

    private var recentLogs: [PlayerGameLog] {
        Array(player.gameLogs.reversed().prefix(8))
    }

    @ViewBuilder
    private var gameLogCard: some View {
        VStack(spacing: 4) {
            Text("GAME LOG")
                .font(.system(size: 11, weight: .heavy).width(.condensed))
                .tracking(2)
                .foregroundStyle(Theme.paperInkSoft)
                .frame(maxWidth: .infinity, alignment: .leading)

            if recentLogs.isEmpty {
                Text("NO GAMES ON FILE YET")
                    .font(Theme.typewriter(12, relativeTo: .caption))
                    .foregroundStyle(Theme.paperInkSoft)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else {
                ForEach(recentLogs) { log in
                    HStack(spacing: 10) {
                        Text(log.teamWon ? "W" : "L")
                            .font(.system(size: 12, weight: .black).width(.condensed))
                            .foregroundStyle(.white)
                            .frame(width: 22, height: 22)
                            .background(
                                (log.teamWon ? Theme.easy : Theme.danger).opacity(0.85),
                                in: .circle
                            )

                        VStack(alignment: .leading, spacing: 2) {
                            Text(log.opponentName)
                                .font(.system(size: 13, weight: .heavy).width(.condensed))
                                .foregroundStyle(Theme.paperInk)
                                .lineLimit(1)
                            Text("S\(log.seasonNumber) · \(log.weekLabel)\(log.isPlayoff ? " · PLAYOFFS" : "")")
                                .font(.system(size: 10, weight: .heavy).width(.condensed))
                                .tracking(0.8)
                                .foregroundStyle(Theme.paperInkSoft)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        if log.wasPlayerOfGame {
                            Image(systemName: "star.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Theme.gold)
                                .accessibilityLabel("Player of the Game")
                        }

                        Text(log.stats.topSummary(limit: 2) ?? "—")
                            .font(Theme.typewriter(10, relativeTo: .caption2))
                            .foregroundStyle(Theme.bronzeDeep)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .padding(.vertical, 6)
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(Theme.paperInk.opacity(0.12)).frame(height: 1)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .padding(14)
        .paperCard(cornerRadius: 6)
        .rotationEffect(.degrees(0.4))
        .overlay(alignment: .top) { PushPin(size: 16).offset(y: -8) }
        .padding(.top, 8)
    }
}

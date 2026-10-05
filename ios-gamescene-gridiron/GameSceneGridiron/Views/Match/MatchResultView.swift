import SwiftUI

/// Premium final verdict for the whole game: heading, quarter-by-quarter results,
/// score line and the lightweight match statistics. Offers Play Again / Home.
struct MatchResultView: View {
    let matchViewModel: MatchViewModel
    var userTeam: GameTeam?
    var opponent: GameTeam?
    /// False for season games — completed season games are never replayed.
    var allowsReplay: Bool = true
    var continueLabel: String = "HOME"
    let onPlayAgain: () -> Void
    let onHome: () -> Void

    @State private var stampIn: Bool = false
    @State private var detailsIn: Bool = false
    @State private var isDoubling: Bool = false

    private let wallet = PlayerWallet.shared

    private var match: GameMatch { matchViewModel.match }
    private var result: MatchResult { match.result ?? .defeat }

    var body: some View {
        ZStack {
            DeskBackground()
            if !result.isWin {
                Color.black.opacity(0.35).ignoresSafeArea()
            }

            ScrollView {
                VStack(spacing: 22) {
                    GSLogoView(scale: 0.8)
                        .padding(.top, 8)

                    heading
                        .scaleEffect(stampIn ? 1 : 1.9)
                        .opacity(stampIn ? 1 : 0)
                        .rotationEffect(.degrees(stampIn ? -2 : -9))

                    if let userTeam, let opponent {
                        matchupRow(userTeam: userTeam, opponent: opponent)
                            .opacity(detailsIn ? 1 : 0)
                    }

                    scoreLine
                        .opacity(detailsIn ? 1 : 0)

                    resultsCard
                        .opacity(detailsIn ? 1 : 0)
                        .offset(y: detailsIn ? 0 : 22)

                    statsCard
                        .opacity(detailsIn ? 1 : 0)
                        .offset(y: detailsIn ? 0 : 22)

                    if let playerOfTheGame = matchViewModel.playerOfTheGame {
                        playerOfTheGameCard(playerOfTheGame)
                            .opacity(detailsIn ? 1 : 0)
                            .offset(y: detailsIn ? 0 : 22)
                    }

                    if !match.statEvents.isEmpty {
                        leadersCard
                            .opacity(detailsIn ? 1 : 0)
                            .offset(y: detailsIn ? 0 : 22)
                    }

                    if let breakdown = matchViewModel.rewardBreakdown {
                        rewardCard(breakdown)
                            .opacity(detailsIn ? 1 : 0)
                            .offset(y: detailsIn ? 0 : 22)
                    }

                    buttons
                        .opacity(detailsIn ? 1 : 0)
                        .padding(.bottom, 30)
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .onAppear {
            Haptics.tick()
            AudioManager.shared.play(result.isWin ? .caseSolved : .quarterLost)
            withAnimation(.spring(response: 0.42, dampingFraction: 0.55).delay(0.15)) { stampIn = true }
            withAnimation(.spring(response: 0.7, dampingFraction: 0.85).delay(0.5)) { detailsIn = true }
        }
        .sensoryFeedback(result.isWin ? .success : .warning, trigger: stampIn)
    }

    // MARK: Heading

    private var heading: some View {
        VStack(spacing: 6) {
            Text(result.heading)
                .font(.system(size: 38, weight: .black).width(.compressed))
                .foregroundStyle(result.isWin ? AnyShapeStyle(Theme.goldGradient) : AnyShapeStyle(Theme.danger))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            HStack(spacing: 10) {
                Rectangle().fill(Theme.gold.opacity(0.7)).frame(width: 28, height: 2)
                Text(result.isWin ? "THE INVESTIGATION IS OVER" : "THE CASE GOES UNRESOLVED")
                    .font(.system(size: 15, weight: .heavy).width(.compressed))
                    .tracking(2)
                    .foregroundStyle(Theme.goldLight)
                Rectangle().fill(Theme.gold.opacity(0.7)).frame(width: 28, height: 2)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(Color.black.opacity(0.7), in: .rect(cornerRadius: 4))
        .overlay {
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(result.isWin ? AnyShapeStyle(Theme.goldGradient) : AnyShapeStyle(Theme.danger), lineWidth: 3)
                .padding(4)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    // MARK: Matchup

    /// Both franchises with their emblems above the score line.
    private func matchupRow(userTeam: GameTeam, opponent: GameTeam) -> some View {
        HStack(spacing: 14) {
            TeamLockupView(team: userTeam, emblemSize: 42, nameSize: 14)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("VS")
                .font(.system(size: 15, weight: .black).width(.compressed))
                .tracking(1)
                .foregroundStyle(Theme.gold)
            TeamLockupView(team: opponent, emblemSize: 42, nameSize: 14)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(Color.black.opacity(0.55), in: .rect(cornerRadius: 6))
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(Theme.gold.opacity(0.3), lineWidth: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(userTeam.displayName) versus \(opponent.displayName)")
    }

    // MARK: Score

    private var scoreLine: some View {
        VStack(spacing: 2) {
            Text("RESULT")
                .font(.system(size: 11, weight: .heavy).width(.condensed))
                .tracking(2)
                .foregroundStyle(Theme.paperInkSoft)
            Text(match.scoreLine ?? "")
                .font(.system(size: 52, weight: .black).width(.compressed))
                .foregroundStyle(Theme.paperInk)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Final result \(match.scoreLine ?? "")")
    }

    // MARK: Quarter results

    private var resultsCard: some View {
        VStack(spacing: 14) {
            Text("QUARTER RESULTS")
                .font(.system(size: 11, weight: .heavy).width(.condensed))
                .tracking(2)
                .foregroundStyle(Theme.paperInkSoft)

            HStack(spacing: 10) {
                ForEach(match.quarterRecords) { record in
                    resultChip(record)
                }
                if let overtime = match.overtimeRecord {
                    resultChip(overtime)
                }
            }

            QuarterProgressTrack(match: match)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .paperCard(cornerRadius: 6)
        .overlay(alignment: .top) { PushPin().offset(y: -9) }
        .padding(.top, 9)
    }

    private func resultChip(_ record: QuarterRecord) -> some View {
        VStack(spacing: 5) {
            Image(systemName: record.outcome == .solved ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(record.outcome == .solved ? Theme.easy : Theme.danger)
                .contentTransition(.symbolEffect(.replace))
            Text(record.label)
                .font(.system(size: 12, weight: .heavy).width(.condensed))
                .tracking(0.8)
                .foregroundStyle(Theme.paperInk)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 66)
        .background {
            RoundedRectangle(cornerRadius: 6)
                .fill((record.outcome == .solved ? Theme.easy : Theme.danger).opacity(0.12))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder((record.outcome == .solved ? Theme.easy : Theme.danger).opacity(0.4), lineWidth: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(record.label): \(record.outcome == .solved ? "solved" : "failed")")
    }

    // MARK: Statistics

    private var statsCard: some View {
        VStack(spacing: 4) {
            Text("CASE NOTES")
                .font(.system(size: 11, weight: .heavy).width(.condensed))
                .tracking(2)
                .foregroundStyle(Theme.paperInkSoft)
                .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(statRows, id: \.label) { row in
                HStack {
                    Text(row.label)
                        .font(Theme.typewriter(14, relativeTo: .subheadline))
                        .foregroundStyle(Theme.paperInk)
                    Spacer()
                    Text("\(row.value)")
                        .font(.system(size: 17, weight: .heavy).width(.condensed))
                        .monospacedDigit()
                        .foregroundStyle(row.tint ?? Theme.goldLight)
                }
                .padding(.vertical, 7)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(Theme.paperInk.opacity(0.12)).frame(height: 1)
                }
            }
        }
        .padding(16)
        .paperCard(cornerRadius: 6)
        .rotationEffect(.degrees(-0.5))
    }

    private struct StatRow {
        let label: String
        let value: Int
        let tint: Color?
    }

    private var statRows: [StatRow] {
        [
            StatRow(label: "Quarters solved", value: match.quartersSolved, tint: Theme.easy),
            StatRow(label: "Quarters failed", value: match.quartersFailed, tint: Theme.danger),
            StatRow(label: "Correct placements", value: match.totalCorrectPlacements, tint: nil),
            StatRow(label: "Incorrect placements", value: match.totalWrongPlacements, tint: nil),
            StatRow(label: "Lives lost", value: match.totalLivesLost, tint: nil),
            StatRow(label: "Hints used", value: match.totalHintsUsed, tint: nil)
        ]
    }

    // MARK: Player of the Game

    /// The game's top contributor from the solved cases — cinematic, gold,
    /// wearing the franchise colors.
    private func playerOfTheGameCard(_ leader: StatLeader) -> some View {
        Color(hex: 0x14110D)
            .frame(height: 190)
            .overlay {
                RadialGradient(
                    colors: [Theme.gold.opacity(0.32), .clear],
                    center: UnitPoint(x: 0.5, y: 0.3),
                    startRadius: 2,
                    endRadius: 220
                )
                .allowsHitTesting(false)
            }
            .overlay {
                if let asset = leader.bodyAssetID {
                    Image(asset)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .colorMultiply(userTeam?.primaryColor ?? .white)
                        .allowsHitTesting(false)
                }
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
            .overlay(alignment: .top) {
                Text("PLAYER OF THE GAME")
                    .font(.system(size: 12, weight: .heavy).width(.condensed))
                    .tracking(3)
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 5)
                    .background(Theme.goldGradient, in: .capsule)
                    .padding(.top, 10)
            }
            .overlay(alignment: .bottom) {
                VStack(spacing: 4) {
                    Text(leader.name.uppercased())
                        .font(.system(size: 26, weight: .black).width(.compressed))
                        .tracking(1)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text("\(leader.position.rawValue) — \(leader.line.topSummary(limit: 3) ?? "")")
                        .font(Theme.typewriter(11, relativeTo: .caption))
                        .foregroundStyle(Theme.goldLight)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 10)
            }
            .clipShape(.rect(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Theme.goldGradient, lineWidth: 2)
            }
            .shadow(color: Theme.gold.opacity(0.3), radius: 14, y: 6)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Player of the game: \(leader.name), \(leader.position.rawValue), \(leader.line.topSummary() ?? "")")
    }

    // MARK: Game leaders

    private var leadersCard: some View {
        VStack(spacing: 4) {
            Text("GAME LEADERS")
                .font(.system(size: 11, weight: .heavy).width(.condensed))
                .tracking(2)
                .foregroundStyle(Theme.paperInkSoft)
                .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(Array(matchViewModel.gameLeaders.prefix(3).enumerated()), id: \.element.id) { _, leader in
                HStack(spacing: 10) {
                    Group {
                        if let asset = leader.bodyAssetID {
                            Image(asset)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .colorMultiply(userTeam?.primaryColor ?? .white)
                        } else {
                            Color.clear
                        }
                    }
                    .frame(width: 34, height: 44)
                    .clipped()
                    .clipShape(.rect(cornerRadius: 4))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(leader.name)
                            .font(.system(size: 15, weight: .heavy).width(.condensed))
                            .foregroundStyle(Theme.paperInk)
                            .lineLimit(1)
                        Text(leader.position.rawValue)
                            .font(.system(size: 10, weight: .heavy).width(.condensed))
                            .tracking(1)
                            .foregroundStyle(.white.opacity(0.95))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1.5)
                            .background(Theme.positionAccent(leader.position).opacity(0.9), in: .rect(cornerRadius: 3))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Text(leader.line.topSummary(limit: 3) ?? "—")
                        .font(Theme.typewriter(10, relativeTo: .caption2))
                        .foregroundStyle(Theme.bronzeDeep)
                        .multilineTextAlignment(.trailing)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                }
                .padding(.vertical, 7)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(Theme.paperInk.opacity(0.12)).frame(height: 1)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(leader.name), \(leader.position.rawValue), \(leader.line.topSummary() ?? "")")
            }
        }
        .padding(16)
        .paperCard(cornerRadius: 6)
        .rotationEffect(.degrees(0.5))
    }

    // MARK: Actions

    private var buttons: some View {
        VStack(spacing: 12) {
            if allowsReplay {
                Button {
                    Haptics.pickUp()
                    onPlayAgain()
                    AdManager.shared.maybeShowInterstitial()
                } label: {
                    HStack {
                        Spacer()
                        Text("PLAY AGAIN")
                        Spacer()
                        Image(systemName: "arrow.counterclockwise").font(.system(size: 15, weight: .bold))
                    }
                    .padding(.horizontal, 26)
                }
                .buttonStyle(GoldCapsuleButtonStyle())
                .accessibilityHint("Resets all results and starts a new game at Quarter 1")
            }

            Button(action: leave) {
                Text(continueLabel)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.paperInk)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .overlay { Capsule().strokeBorder(Theme.paperInk.opacity(0.4), lineWidth: 1.2) }
                    .contentShape(.capsule)
            }
            .buttonStyle(PressableButtonStyle(playsPressSound: true))
        }
    }

    /// Leaving the finished game is a natural break — the forced interstitial
    /// runs its frequency gate here (never during play, and never immediately
    /// after a rewarded video).
    private func leave() {
        onHome()
        AdManager.shared.maybeShowInterstitial()
    }

    // MARK: Case Reward

    /// The game's Game Ball payout: solved quarters, victory bonuses and the
    /// optional once-per-game 2× offer. The wallet was credited exactly once
    /// when the match completed; the card animates the balance filling up.
    private func rewardCard(_ breakdown: MatchRewardBreakdown) -> some View {
        let isDoubled = wallet.hasDoubledMatchReward(transactionID: breakdown.transactionID)
        let total = isDoubled ? breakdown.total * 2 : breakdown.total
        let balance = wallet.gameBalls
        return VStack(spacing: 4) {
            Text("CASE REWARD")
                .font(.system(size: 11, weight: .heavy).width(.condensed))
                .tracking(2)
                .foregroundStyle(Theme.paperInkSoft)
                .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(breakdown.lines) { line in
                rewardRow(label: line.label, amount: line.amount)
            }
            if isDoubled {
                rewardRow(label: "Reward Doubled", amount: breakdown.total, tint: Theme.gold)
            }

            HStack {
                Text("TOTAL EARNED")
                    .font(.system(size: 12, weight: .heavy).width(.condensed))
                    .tracking(1.5)
                    .foregroundStyle(Theme.paperInk)
                Spacer()
                HStack(spacing: 6) {
                    CountUpNumber(from: 0, to: total, size: 26)
                    GameBallIcon(size: 14)
                }
            }
            .padding(.top, 4)

            HStack {
                Text("WALLET")
                    .font(Theme.typewriter(12, relativeTo: .caption))
                    .foregroundStyle(Theme.paperInkSoft)
                Spacer()
                HStack(spacing: 6) {
                    CountUpNumber(from: balance - total, to: balance, size: 18)
                    GameBallIcon(size: 11)
                }
            }
            .padding(.top, 2)

            if !isDoubled, breakdown.total > 0 {
                doubleRewardOffer(breakdown)
            }
        }
        .padding(16)
        .paperCard(cornerRadius: 6)
        .rotationEffect(.degrees(-0.5))
        .onAppear {
            AudioManager.shared.play(.gameballDeposit)
            Haptics.success()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Case reward: earned \(total) game balls. Wallet balance \(balance).")
    }

    private func rewardRow(label: String, amount: Int, tint: Color? = nil) -> some View {
        HStack {
            Text(label)
                .font(Theme.typewriter(14, relativeTo: .subheadline))
                .foregroundStyle(Theme.paperInk)
            Spacer()
            HStack(spacing: 5) {
                Text("+\(amount)")
                    .font(.system(size: 17, weight: .heavy).width(.condensed))
                    .monospacedDigit()
                    .foregroundStyle(tint ?? Theme.goldLight)
                GameBallIcon(size: 11)
            }
        }
        .padding(.vertical, 7)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.paperInk.opacity(0.12)).frame(height: 1)
        }
    }

    /// Completely optional, once per game: watching a video doubles only this
    /// game's earned reward — never the existing wallet balance. Closing the
    /// video early grants nothing and the offer stays available.
    private func doubleRewardOffer(_ breakdown: MatchRewardBreakdown) -> some View {
        Button {
            guard !isDoubling else { return }
            Haptics.pickUp()
            isDoubling = true
            Task { @MainActor in
                let result = await AdManager.shared.showRewarded(.doubleReward)
                isDoubling = false
                guard result == .granted else { return }
                if wallet.doubleMatchReward(breakdown) {
                    AudioManager.shared.play(.gameballDeposit)
                    Haptics.success()
                }
            }
        } label: {
            HStack(spacing: 10) {
                if isDoubling {
                    ProgressView()
                        .tint(Theme.goldLight)
                } else {
                    Image(systemName: "play.rectangle.fill")
                        .font(.system(size: 16, weight: .bold))
                }
                Text(isDoubling ? "WATCHING…" : "WATCH VIDEO — 2× REWARD (+\(breakdown.total) GAME BALLS)")
                    .font(.system(size: 13, weight: .heavy).width(.condensed))
                    .tracking(0.8)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(Theme.goldLight)
            .frame(maxWidth: .infinity, minHeight: 50)
            .overlay { Capsule().strokeBorder(Theme.goldGradient, lineWidth: 2) }
            .contentShape(.capsule)
        }
        .buttonStyle(PressableButtonStyle(playsPressSound: true))
        .padding(.top, 10)
        .accessibilityHint("Doubles this game's earned reward by watching a video")
    }
}

#Preview {
    MatchResultView(
        matchViewModel: MatchViewModel(),
        onPlayAgain: {},
        onHome: {}
    )
}

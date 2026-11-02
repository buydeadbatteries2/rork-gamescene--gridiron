import SwiftUI

/// Where the RANKED entry stands for the current player — resolved once,
/// shared by the Home tile and the Ranked screen so both surfaces agree.
nonisolated enum RankedEntryState: Equatable {
    /// Guest/recovery: ranked play needs an account — show the sign-in gate.
    case needsAccount
    /// Signed in, but no franchise yet.
    case needsFranchise
    /// A ranked season is runnable (12 games, server-assigned cases).
    case active(gameNumber: Int, difficulty: DifficultyLevel)
    /// Signed in with a team but no runnable ranked season — start one.
    case readyToStart

    static func resolve(state: AuthSessionState, hasTeam: Bool, nextGameNumber: Int?, difficulty: DifficultyLevel?) -> RankedEntryState {
        guard !AccountGatePolicy.requiresAccount(state) else { return .needsAccount }
        guard hasTeam else { return .needsFranchise }
        if let next = nextGameNumber, let difficulty {
            return .active(gameNumber: next, difficulty: difficulty)
        }
        return .readyToStart
    }

    /// "GAME x OF 12" — x is the NEXT playable game (first game without a
    /// result). Prefetched assignments are held cases, never played games, so
    /// they never advance this number.
    static func progressLabel(_ gameNumber: Int) -> String {
        switch gameNumber {
        case 11: "SEMIFINAL · GAME 11 OF 12"
        case 12: "CHAMPIONSHIP · GAME 12 OF 12"
        default: "GAME \(gameNumber) OF 12"
        }
    }

    /// Games actually completed — the next playable game minus one.
    static func completedGames(_ gameNumber: Int) -> Int {
        max(0, min(12, gameNumber - 1))
    }
}

/// RANKED desk screen: the server-owned competitive season (Phase 14B).
/// Purely an entry surface — starting a season reuses SELECT DIFFICULTY and
/// the normal season flow, where `start-ranked-match` issues the assignments
/// and LeaderboardView shows the standings. No second ranked system.
struct RankedView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var seasonManager = SeasonManager.shared
    @State private var teamStore = TeamStore.shared
    @State private var isShowingSeason: Bool = false
    @State private var isShowingDifficulty: Bool = false
    @State private var isShowingLeaderboard: Bool = false
    @State private var hasAppeared: Bool = false

    var body: some View {
        ZStack {
            DeskBackground()

            VStack(spacing: 20) {
                header

                entryCard
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(y: hasAppeared ? 0 : 16)

                Button {
                    Haptics.tick()
                    isShowingLeaderboard = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "list.number")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(Theme.goldLight)
                            .frame(width: 32, height: 32)
                            .background(Color.black.opacity(0.4), in: .circle)
                        Text("LEADERBOARDS")
                            .font(.system(size: 15, weight: .black).width(.compressed))
                            .tracking(1)
                            .foregroundStyle(Theme.paperInk)
                        Spacer(minLength: 8)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Theme.paperInk.opacity(0.4))
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .paperCard(cornerRadius: 6)
                }
                .buttonStyle(PressableButtonStyle(scale: 0.98))
                .accessibilityIdentifier("ranked.leaderboards")
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 26)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.85).delay(0.05)) { hasAppeared = true }
        }
        .fullScreenCover(isPresented: $isShowingSeason) {
            // The existing season flow — ranked cases are adopted automatically
            // from the server assignments the prefetcher already holds.
            SeasonView()
        }
        .fullScreenCover(isPresented: $isShowingDifficulty) {
            DifficultySelectView(onConfirm: { level in
                guard let team = teamStore.userTeam else { return }
                // The server season is created by start-ranked-match when the
                // first game's assignment is fetched inside SeasonView.
                SeasonManager.shared.startNewSeason(userTeam: team, difficulty: level)
                isShowingDifficulty = false
                isShowingSeason = true
            }, confirmTitle: "START RANKED SEASON", requireExplicitSelection: true)
        }
        .fullScreenCover(isPresented: $isShowingLeaderboard) {
            LeaderboardView()
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            // Visible way out of Ranked — back to the main Home desk.
            Button {
                Haptics.tick()
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.goldLight)
                    .frame(width: 38, height: 38)
                    .background(Color.black.opacity(0.45), in: .circle)
                    .overlay { Circle().strokeBorder(Theme.gold.opacity(0.4), lineWidth: 1) }
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityLabel("Back to Home")
            .accessibilityIdentifier("ranked.back")

            VStack(alignment: .leading, spacing: 6) {
                Text("RANKED")
                    .font(.system(size: 26, weight: .black).width(.compressed))
                    .tracking(2)
                    .foregroundStyle(Theme.goldGradient)
                Text("TWELVE SERVER-VERIFIED CASES. ONE SEASON.")
                    .font(Theme.typewriter(11, relativeTo: .caption))
                    .tracking(1.2)
                    .foregroundStyle(Theme.paperInkSoft)
            }
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var entryCard: some View {
        // Difficulty and progress come from the SERVER season state (the
        // assignment store's snapshot) when one is known on this device; the
        // local solo season is only a fallback before the first assignment.
        let ranked = RankedAssignmentService.shared.rankedDisplayState
        let state = RankedEntryState.resolve(
            state: AuthService.shared.state,
            hasTeam: teamStore.userTeam != nil,
            nextGameNumber: ranked?.nextGameNumber ?? seasonManager.nextRankedGameNumber,
            difficulty: ranked?.difficulty ?? seasonManager.activeSeasonDifficulty
        )
        VStack(spacing: 14) {
            switch state {
            case .needsFranchise:
                Image(systemName: "person.3")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(Theme.paperInkSoft)
                Text("CREATE YOUR FRANCHISE FIRST")
                    .font(.system(size: 15, weight: .heavy).width(.condensed))
                    .tracking(1.2)
                    .foregroundStyle(Theme.paperInk)
                Text("Ranked play begins with Season 1 — tap START INVESTIGATION on the desk.")
                    .font(Theme.typewriter(11, relativeTo: .caption))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.paperInkSoft)

            case .readyToStart:
                statusLine("NO ACTIVE RANKED SEASON", detail: "Start one and every game is played from server-issued cases.")
                Button {
                    Haptics.pickUp()
                    isShowingDifficulty = true
                } label: {
                    HStack {
                        Spacer()
                        Text("START RANKED SEASON")
                        Spacer()
                        Image(systemName: "flame.fill")
                            .font(.system(size: 15, weight: .bold))
                    }
                    .padding(.horizontal, 26)
                }
                .buttonStyle(GoldCapsuleButtonStyle())
                .accessibilityIdentifier("ranked.start")

            case .active(let gameNumber, let difficulty):
                statusLine(difficulty.title, detail: "Difficulty locked for this season")
                progressBar(gameNumber: gameNumber)
                Text(RankedEntryState.progressLabel(gameNumber))
                    .font(.system(size: 13, weight: .heavy).width(.condensed))
                    .tracking(1.2)
                    .foregroundStyle(Theme.paperInk)
                Button {
                    Haptics.pickUp()
                    isShowingSeason = true
                } label: {
                    HStack {
                        Spacer()
                        Text("CONTINUE RANKED SEASON")
                        Spacer()
                        Image(systemName: "play.fill")
                            .font(.system(size: 15, weight: .bold))
                    }
                    .padding(.horizontal, 26)
                }
                .buttonStyle(GoldCapsuleButtonStyle())
                .accessibilityIdentifier("ranked.continue")

            case .needsAccount:
                // The Home tile never reaches this state (it shows the gate
                // first), but the screen stays honest if the session changes.
                Image(systemName: "lock")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(Theme.paperInkSoft)
                Text("CLEARANCE NEEDED FOR RANKED")
                    .font(.system(size: 15, weight: .heavy).width(.condensed))
                    .tracking(1.2)
                    .foregroundStyle(Theme.paperInk)
            }
        }
        .padding(16)
        .paperCard(cornerRadius: 6)
        .accessibilityElement(children: .contain)
    }

    private func statusLine(_ title: String, detail: String) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 17, weight: .black).width(.compressed))
                .tracking(1)
                .foregroundStyle(Theme.paperInk)
            Text(detail)
                .font(Theme.typewriter(11, relativeTo: .caption))
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.paperInkSoft)
        }
    }

    private func progressBar(gameNumber: Int) -> some View {
        let completed = RankedEntryState.completedGames(gameNumber)
        return GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.paperInk.opacity(0.12))
                Capsule()
                    .fill(Theme.goldGradient)
                    .frame(width: proxy.size.width * CGFloat(completed) / 12)
            }
        }
        .frame(height: 6)
        .accessibilityElement()
        .accessibilityLabel("\(completed) of 12 games played")
    }
}

#Preview {
    RankedView()
}

import SwiftUI

/// Top-level surface: brand, cinematic stadium photo, the investigation CTA, the
/// persistent wallet strip and locked future modes.
struct HomeView: View {
    @State private var teamStore = TeamStore.shared
    @State private var seasonManager = SeasonManager.shared
    @State private var auth = AuthService.shared
    @State private var isPlaying: Bool = false
    @State private var isEditingTeam: Bool = false
    @State private var isShowingTeamRoster: Bool = false
    @State private var isShowingRecords: Bool = false
    @State private var isShowingShop: Bool = false
    @State private var isShowingSettings: Bool = false
    @State private var isShowingTrophyRoom: Bool = false
    @State private var isShowingAccountEntry: Bool = false
    @State private var isShowingProfile: Bool = false
    @State private var isShowingLeaderboard: Bool = false
    @State private var isShowingLeaderboardGate: Bool = false
    @State private var isShowingRanked: Bool = false
    @State private var isShowingRankedGate: Bool = false
    @State private var isShowingVersus: Bool = false
    @State private var isShowingVersusGate: Bool = false
    @State private var versus = VersusStore.shared
    @State private var lockedMessage: String?
    @State private var hasAppeared: Bool = false
    @State private var glow: Bool = false
    @State private var confirmRestart = false

    var body: some View {
        ZStack {
            DeskBackground()

            ScrollView {
                VStack(spacing: 22) {
                    GSLogoView()
                        .padding(.top, 8)
                        .opacity(hasAppeared ? 1 : 0)
                        .offset(y: hasAppeared ? 0 : -12)

                    heroPhoto
                        .opacity(hasAppeared ? 1 : 0)
                        .scaleEffect(hasAppeared ? 1 : 0.96)

                    if let team = teamStore.userTeam {
                        seasonCard(team)
                            .opacity(hasAppeared ? 1 : 0)
                            .offset(y: hasAppeared ? 0 : 18)
                    }

                    Button {
                        Haptics.pickUp()
                        isPlaying = true
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: teamStore.hasTeam ? "sportscourt" : "magnifyingglass")
                                .font(.system(size: 22, weight: .semibold))
                            Text(ctaTitle)
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 15, weight: .bold))
                        }
                        .padding(.horizontal, 26)
                    }
                    .buttonStyle(GoldCapsuleButtonStyle())
                    .shadow(color: Theme.gold.opacity(glow ? 0.35 : 0.1), radius: glow ? 22 : 10)
                    .accessibilityHint(teamStore.hasTeam ? "Opens your season" : "Opens the investigation")

                    if teamStore.hasTeam, seasonManager.season != nil {
                        VStack(spacing: 6) {
                            Button("RESTART SEASON — 25 GAME BALLS") { confirmRestart = true }
                                .font(Theme.condensed(14))
                                .foregroundStyle(Theme.goldLight)
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .background(Color.black.opacity(0.55), in: .capsule)
                                .overlay { Capsule().strokeBorder(Theme.gold.opacity(0.35), lineWidth: 1) }
                                .buttonStyle(PressableButtonStyle())
                                .disabled(PlayerWallet.shared.gameBalls < EconomyConfig.standard.seasonRestartCost)
                                .opacity(PlayerWallet.shared.gameBalls < EconomyConfig.standard.seasonRestartCost ? 0.45 : 1)
                            if PlayerWallet.shared.gameBalls < EconomyConfig.standard.seasonRestartCost {
                                Text("25 GAME BALLS REQUIRED TO RESTART")
                                    .font(Theme.typewriter(10))
                                    .foregroundStyle(Theme.goldLight)
                            }
                        }
                        .confirmationDialog("Restart your season?", isPresented: $confirmRestart, titleVisibility: .visible) {
                            Button("Pay 25 Game Balls & Restart", role: .destructive) {
                                guard let team = teamStore.userTeam else { return }
                                if seasonManager.restartSeason(userTeam: team, wallet: PlayerWallet.shared) {
                                    isPlaying = true
                                }
                            }
                            Button("Cancel", role: .cancel) {}
                        } message: {
                            Text("This costs 25 Game Balls and replaces your current schedule and unfinished match with a new season at the same difficulty. Your team, roster and earned career stats are kept. This cannot be undone.")
                        }
                    }

                    // Versus entry temporarily hidden for this release.
                    // Keep the tile, routes and saved match progress for a later update.

                    walletStrip
                        .opacity(hasAppeared ? 1 : 0)
                        .offset(y: hasAppeared ? 0 : 16)

                    accountStrip
                        .opacity(hasAppeared ? 1 : 0)
                        .offset(y: hasAppeared ? 0 : 16)

                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 18) {
                        if let team = teamStore.userTeam {
                            Button {
                                Haptics.tick()
                                isShowingTeamRoster = true
                            } label: {
                                MyTeamFolderTile(team: team)
                            }
                            .buttonStyle(PressableButtonStyle(scale: 0.97))

                            Button {
                                Haptics.tick()
                                isShowingRecords = true
                            } label: {
                                UnlockedFolderTile(title: "RECORDS", symbol: "chart.bar")
                            }
                            .buttonStyle(PressableButtonStyle(scale: 0.97))
                        } else {
                            Button {
                                Haptics.warning()
                                withAnimation(.snappy) { lockedMessage = "Create your franchise first — tap START INVESTIGATION." }
                            } label: {
                                LockedFolderTile(title: "TEAM", symbol: "person.3")
                            }
                            .buttonStyle(PressableButtonStyle(scale: 0.97))

                            Button {
                                Haptics.warning()
                                withAnimation(.snappy) { lockedMessage = "Records begin with Season 1 — create your franchise first." }
                            } label: {
                                LockedFolderTile(title: "RECORDS", symbol: "chart.bar")
                            }
                            .buttonStyle(PressableButtonStyle(scale: 0.97))
                        }

                        Button {
                            Haptics.tick()
                            isShowingShop = true
                        } label: {
                            UnlockedFolderTile(title: "SHOP", symbol: "bag")
                        }
                        .buttonStyle(PressableButtonStyle(scale: 0.97))

                        Button {
                            Haptics.tick()
                            isShowingSettings = true
                        } label: {
                            UnlockedFolderTile(title: "SETTINGS", symbol: "gearshape")
                        }
                        .buttonStyle(PressableButtonStyle(scale: 0.97))

                        Button {
                            Haptics.tick()
                            isShowingTrophyRoom = true
                        } label: {
                            UnlockedFolderTile(title: "TROPHY ROOM", symbol: "trophy.fill")
                        }
                        .buttonStyle(PressableButtonStyle(scale: 0.97))

                        Button {
                            Haptics.tick()
                            // Server-verified competition needs an account; guests
                            // see the same CLEARANCE gate as the leaderboard.
                            if AccountGatePolicy.requiresAccount(auth.state) {
                                isShowingRankedGate = true
                            } else {
                                isShowingRanked = true
                            }
                        } label: {
                            UnlockedFolderTile(title: "RANKED", symbol: "flame.fill")
                        }
                        .buttonStyle(PressableButtonStyle(scale: 0.97))
                        .accessibilityIdentifier("home.ranked")

                        Button {
                            Haptics.tick()
                            // Online competition needs an account; guests see ACCOUNT REQUIRED.
                            if AccountGatePolicy.requiresAccount(auth.state) {
                                isShowingLeaderboardGate = true
                            } else {
                                isShowingLeaderboard = true
                            }
                        } label: {
                            UnlockedFolderTile(title: "LEADERBOARD", symbol: "list.number")
                        }
                        .buttonStyle(PressableButtonStyle(scale: 0.97))
                        .accessibilityIdentifier("home.leaderboard")
                    }
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(y: hasAppeared ? 0 : 20)
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)

            if let lockedMessage {
                VStack {
                    Spacer()
                    Text(lockedMessage)
                        .font(Theme.typewriter(14))
                        .foregroundStyle(Theme.paperInk)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .paperCard(cornerRadius: 4)
                        .padding(.bottom, 24)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .task(id: lockedMessage) {
                    try? await Task.sleep(for: .seconds(1.8))
                    withAnimation(.easeOut) { self.lockedMessage = nil }
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.05)) { hasAppeared = true }
            // Reduce Motion: the CTA glow rests at a gentle constant shine.
            if !Motion.isReduced {
                withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) { glow = true }
            } else {
                glow = true
            }
        }
        .fullScreenCover(isPresented: $isPlaying) {
            SeasonView()
        }
        .fullScreenCover(isPresented: $isShowingTeamRoster) {
            if let team = teamStore.userTeam {
                TeamRosterView(userTeam: team)
            }
        }
        .fullScreenCover(isPresented: $isShowingRecords) {
            if let team = teamStore.userTeam {
                RecordsView(userTeam: team)
            }
        }
        .fullScreenCover(isPresented: $isShowingShop) {
            ShopView()
        }
        .fullScreenCover(isPresented: $isShowingTrophyRoom) {
            TrophyRoomView()
        }
        .fullScreenCover(isPresented: $isShowingLeaderboard) {
            LeaderboardView()
        }
        .sheet(isPresented: $isShowingLeaderboardGate) {
            NavigationStack { AccountGateView(featureName: "Leaderboards") }
                .preferredColorScheme(.dark)
        }
        .fullScreenCover(isPresented: $isShowingRanked) {
            RankedView()
        }
        .sheet(isPresented: $isShowingRankedGate) {
            NavigationStack { AccountGateView(featureName: "Ranked") }
                .preferredColorScheme(.dark)
        }
        .fullScreenCover(isPresented: $isShowingVersus) {
            VersusHubView()
        }
        .sheet(isPresented: $isShowingVersusGate) {
            NavigationStack { AccountGateView(featureName: "Versus") }
                .preferredColorScheme(.dark)
        }
        .task(id: AccountGatePolicy.requiresAccount(auth.state)) {
            // Home badge: a quiet, throttled recovery read for signed-in players.
            guard !AccountGatePolicy.requiresAccount(auth.state) else { return }
            await versus.refresh()
        }
        .sheet(isPresented: $isShowingSettings) {
            SettingsView()
        }
        .sheet(isPresented: $isShowingAccountEntry) {
            // Guest front door: CREATE ACCOUNT / SIGN IN / CONTINUE AS GUEST.
            NavigationStack { AccountEntryView() }
                .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $isShowingProfile) {
            // Signed-in (or recovery) player file: identity, actions, sign out.
            NavigationStack { ProfileView() }
                .preferredColorScheme(.dark)
        }
        .fullScreenCover(isPresented: $isEditingTeam) {
            if let team = teamStore.userTeam {
                TeamCreationView(existingTeam: team) { _ in
                    isEditingTeam = false
                } onClose: {
                    isEditingTeam = false
                }
            }
        }
    }

    /// CONTINUE SEASON with an active season, START SEASON without one,
    /// CREATE YOUR TEAM for a fresh detective.
    private var ctaTitle: String {
        guard teamStore.hasTeam else { return "CREATE YOUR TEAM" }
        return seasonManager.hasActiveSeason ? "CONTINUE SEASON" : "START SEASON"
    }

    /// Persistent wallet strip: Game Balls and hints both survive restarts,
    /// games and seasons.
    /// Phase 15B — prominent VERSUS entry. Guests get the account gate;
    /// signed-in players open the Versus Hub. No franchise required.
    private var versusTile: some View {
        let attention = AccountGatePolicy.requiresAccount(auth.state) ? 0 : versus.attentionCount
        return Button {
            Haptics.pickUp()
            if AccountGatePolicy.requiresAccount(auth.state) {
                isShowingVersusGate = true
            } else {
                isShowingVersus = true
            }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(Theme.danger)
                    Text("VS")
                        .font(.system(size: 17, weight: .black).width(.compressed))
                        .foregroundStyle(Theme.paper)
                }
                .frame(width: 42, height: 42)
                .overlay { Circle().strokeBorder(Theme.paper.opacity(0.5), lineWidth: 1.5) }

                VStack(alignment: .leading, spacing: 2) {
                    Text("VERSUS")
                        .font(.system(size: 24, weight: .black).width(.compressed))
                        .tracking(2)
                        .foregroundStyle(Theme.paperInk)
                    Text(versusTagline(attention: attention))
                        .font(Theme.typewriter(11, relativeTo: .caption))
                        .foregroundStyle(Theme.paperInkSoft)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                Spacer(minLength: 6)
                if attention > 0 {
                    Text("\(attention)")
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(.white)
                        .frame(minWidth: 24, minHeight: 24)
                        .background(Theme.danger, in: .circle)
                        .accessibilityLabel("\(attention) Versus files need you")
                } else if AccountGatePolicy.requiresAccount(auth.state) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.paperInkSoft)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.paperInk.opacity(0.45))
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .paperCard(cornerRadius: 6)
            .overlay(alignment: .bottom) {
                CautionTape(stripeWidth: 7)
                    .frame(height: 6)
                    .clipShape(.rect(bottomLeadingRadius: 6, bottomTrailingRadius: 6))
            }
        }
        .buttonStyle(PressableButtonStyle(scale: 0.98))
        .accessibilityIdentifier("home.versus")
        .accessibilityHint("Head-to-head case files against another detective")
    }

    private func versusTagline(attention: Int) -> String {
        if AccountGatePolicy.requiresAccount(auth.state) { return "Sign in to challenge another detective" }
        if !versus.isAvailable { return "Versus offline" }
        if attention > 0 { return attention == 1 ? "A case file needs you" : "\(attention) case files need you" }
        if !versus.openMatches.isEmpty { return "Waiting on your opponent" }
        return "Same five cases. One opponent. No hints."
    }

    private var walletStrip: some View {
        HStack(spacing: 12) {
            WalletPill(amount: PlayerWallet.shared.gameBalls, numberColor: Theme.goldLight)
            HintPill(count: PlayerWallet.shared.hints, numberColor: Theme.goldLight)
        }
    }

    /// ACCOUNT entry on the desk: GUEST while playing solo (opens the account
    /// front door), the player's jersey name/username when signed in (opens the
    /// player file). Recovery pending routes to the same profile screen, which
    /// carries the FINISH PLAYER FILE card.
    private var accountStrip: some View {
        Button {
            Haptics.tick()
            AudioManager.shared.play(.buttonPress)
            if homeAccountState.opensProfile {
                isShowingProfile = true
            } else {
                isShowingAccountEntry = true
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: homeAccountState.symbol)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.goldLight)
                    .frame(width: 36, height: 36)
                    .background(Color.black.opacity(0.4), in: .circle)
                VStack(alignment: .leading, spacing: 3) {
                    Text(homeAccountState.title)
                        .font(.system(size: 15, weight: .black).width(.compressed))
                        .tracking(1)
                        .foregroundStyle(Theme.paperInk)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(homeAccountState.detail)
                        .font(Theme.typewriter(11, relativeTo: .caption))
                        .foregroundStyle(Theme.paperInkSoft)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.paperInk.opacity(0.4))
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .paperCard(cornerRadius: 6)
        }
        .buttonStyle(PressableButtonStyle(scale: 0.99))
        .accessibilityLabel("Account — \(homeAccountState.title)")
        .accessibilityHint(homeAccountState.opensProfile ? "Opens your player file" : "Opens account options")
    }

    /// Guest/signed-in/recovery resolution for the home entry — mirrored by
    /// the Settings ACCOUNT card so both surfaces agree.
    private var homeAccountState: AccountHomeState {
        AccountHomeState(auth.state)
    }

    /// Pinned season dossier: franchise, record, current week and next case.
    private func seasonCard(_ team: GameTeam) -> some View {
        HStack(spacing: 12) {
            TeamLockupView(team: team, emblemSize: 46, nameSize: 16)
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 4) {
                Text(seasonManager.userRecordLine ?? "0–0")
                    .font(.system(size: 28, weight: .black).width(.compressed))
                    .monospacedDigit()
                    .foregroundStyle(Theme.paperInk)
                Text(statusLine)
                    .font(.system(size: 10, weight: .heavy).width(.condensed))
                    .tracking(1.2)
                    .foregroundStyle(Theme.goldLight)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .padding(12)
        .paperCard(cornerRadius: 6)
        .rotationEffect(.degrees(-0.8))
        .overlay(alignment: .top) { PushPin(size: 18).offset(y: -8) }
        .padding(.top, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    private var statusLine: String {
        guard seasonManager.hasActiveSeason else { return "NO ACTIVE SEASON" }
        guard let week = seasonManager.currentWeek else {
            return seasonManager.season?.phase == .complete ? "SEASON COMPLETE" : "POSTSEASON"
        }
        if let next = seasonManager.nextOpponent {
            return "WEEK \(week) · NEXT: \(next.teamName.uppercased())"
        }
        return "WEEK \(week)"
    }

    private var accessibilitySummary: String {
        guard seasonManager.hasActiveSeason else {
            return "\(teamStore.userTeam?.displayName ?? "Your team"), no active season. Start a season to play."
        }
        var parts = ["Season \(seasonManager.season?.seasonNumber ?? 1)"
        ]
        parts.append("record \(seasonManager.userRecordLine ?? "0–0")")
        parts.append(statusLine.lowercased())
        return parts.joined(separator: ", ")
    }

    private var heroPhoto: some View {
        Color.black
            .aspectRatio(1.45, contentMode: .fit)
            .overlay {
                Image("football_stadium_night")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .allowsHitTesting(false)
            }
            .overlay {
                LinearGradient(colors: [.clear, .black.opacity(0.35)], startPoint: .center, endPoint: .bottom)
            }
            .clipShape(.rect(cornerRadius: 2))
            .padding(9)
            .background(Theme.paper.opacity(0.92), in: .rect(cornerRadius: 3))
            .shadow(color: .black.opacity(0.7), radius: 14, y: 10)
            .rotationEffect(.degrees(-1.2))
            .overlay(alignment: .top) {
                PushPin().offset(y: -8)
            }
            .overlay(alignment: .bottomTrailing) {
                StickyNote(text: "TRUTH LIVES\nON THE FIELD", rotation: -3, width: 108)
                    .offset(x: 6, y: 14)
            }
            .overlay(alignment: .topLeading) {
                StickyNote(text: "SAME GAME.\nDIFFERENT\nANSWERS.", rotation: -6, width: 86)
                    .offset(x: -14, y: -30)
            }
            .overlay(alignment: .topTrailing) {
                StickyNote(text: "PLAYS\nHIDE\nTHE TRUTH", rotation: 5, width: 78)
                    .offset(x: 12, y: -40)
            }
            .padding(.top, 16)
            .accessibilityElement()
            .accessibilityLabel("Night stadium photograph pinned to the case board")
    }
}

/// Dark detective-desk backdrop with a warm stadium glow.
struct DeskBackground: View {
    var body: some View {
        Theme.ink
            .overlay {
                Image("detective_desk_bg")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .allowsHitTesting(false)
            }
            .overlay {
                RadialGradient(
                    colors: [Theme.bronze.opacity(0.18), .clear],
                    center: UnitPoint(x: 0.5, y: 0.25),
                    startRadius: 10,
                    endRadius: 420
                )
            }
            .overlay {
                LinearGradient(colors: [.black.opacity(0.35), .clear, .black.opacity(0.3)], startPoint: .top, endPoint: .bottom)
            }
            .ignoresSafeArea()
            .accessibilityHidden(true)
    }
}

#Preview {
    HomeView()
}

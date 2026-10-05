import SwiftUI

/// Top-level surface: brand, cinematic stadium photo, the investigation CTA, the
/// persistent wallet strip and locked future modes.
struct HomeView: View {
    @State private var teamStore = TeamStore.shared
    @State private var seasonManager = SeasonManager.shared
    @State private var isPlaying: Bool = false
    @State private var isEditingTeam: Bool = false
    @State private var isShowingTeamRoster: Bool = false
    @State private var isShowingRecords: Bool = false
    @State private var isShowingShop: Bool = false
    @State private var isShowingSettings: Bool = false
    @State private var lockedMessage: String?
    @State private var hasAppeared: Bool = false
    @State private var glow: Bool = false

    private let lockedModes: [(title: String, symbol: String)] = [
        ("DYNASTY", "trophy")
    ]

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

                    walletStrip
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

                        ForEach(lockedModes, id: \.title) { mode in
                            Button {
                                Haptics.warning()
                                withAnimation(.snappy) { lockedMessage = "\(mode.title.capitalized) opens in a future season." }
                            } label: {
                                LockedFolderTile(title: mode.title, symbol: mode.symbol)
                            }
                            .buttonStyle(PressableButtonStyle(scale: 0.97))
                        }
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
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) { glow = true }
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
        .sheet(isPresented: $isShowingSettings) {
            SettingsView()
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
    private var walletStrip: some View {
        HStack(spacing: 12) {
            WalletPill(amount: PlayerWallet.shared.gameBalls)
            HintPill(count: PlayerWallet.shared.hints)
        }
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

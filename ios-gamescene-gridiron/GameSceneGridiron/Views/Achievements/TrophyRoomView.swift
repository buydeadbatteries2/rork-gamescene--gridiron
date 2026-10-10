import SwiftUI

/// TROPHY ROOM — the franchise's locked glass case: championship trophies on
/// lit shelves, major milestones, the franchise legacy ledger and the season
/// archive. Sports trophy display × detective evidence archive: spotlight
/// gradients, engraved plates, typewriter captions, push-pinned case cards.
struct TrophyRoomView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var legacyStore = LegacyStore.shared
    @State private var teamStore = TeamStore.shared
    @State private var selectedTrophy: ChampionshipTrophy?
    @State private var hasAppeared = false

    var body: some View {
        ZStack {
            caseRoomBackground

            ScrollView {
                VStack(spacing: 18) {
                    header
                        .opacity(hasAppeared ? 1 : 0)
                        .offset(y: hasAppeared ? 0 : 16)

                    trophyShelf
                        .opacity(hasAppeared ? 1 : 0)
                        .offset(y: hasAppeared ? 0 : 18)

                    milestonesCard
                        .opacity(hasAppeared ? 1 : 0)
                        .offset(y: hasAppeared ? 0 : 18)

                    legacyCard
                        .opacity(hasAppeared ? 1 : 0)
                        .offset(y: hasAppeared ? 0 : 18)

                    archiveCard
                        .opacity(hasAppeared ? 1 : 0)
                        .offset(y: hasAppeared ? 0 : 18)

                    Spacer(minLength: 12)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
        }
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.85).delay(0.05)) { hasAppeared = true }
        }
        .sheet(item: $selectedTrophy) { trophy in
            TrophyDetailSheet(trophy: trophy, archiveEntry: legacyStore.archiveEntry(forSeason: trophy.seasonNumber))
        }
    }

    // MARK: Background

    /// Locked case-room atmosphere: deep dark wood, a single warm spotlight
    /// cone over the shelf, faint evidence-tag vignette at the edges.
    private var caseRoomBackground: some View {
        ZStack {
            Theme.ink
            Image("detective_desk_bg")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .opacity(0.22)
                .allowsHitTesting(false)
            RadialGradient(
                colors: [Theme.gold.opacity(0.14), .clear],
                center: UnitPoint(x: 0.5, y: 0.12),
                startRadius: 10,
                endRadius: 460
            )
            LinearGradient(colors: [.black.opacity(0.5), .clear, .black.opacity(0.45)], startPoint: .top, endPoint: .bottom)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 12) {
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
            .accessibilityLabel("Back to the desk")

            VStack(spacing: 3) {
                Text("TROPHY ROOM")
                    .font(.system(size: 24, weight: .black).width(.compressed))
                    .tracking(1.5)
                    .foregroundStyle(Theme.goldGradient)
                Text("\(legacyStore.championshipsWon) CHAMPIONSHIP\(legacyStore.championshipsWon == 1 ? "" : "S") · \(legacyStore.totalCasesSolved) CASES SOLVED")
                    .font(.system(size: 10, weight: .heavy).width(.condensed))
                    .tracking(1.5)
                    .foregroundStyle(Theme.paperInkSoft)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)

            if let team = teamStore.userTeam {
                TeamEmblemView(team: team, size: 38)
                    .frame(width: 38)
            }
        }
        .padding(.horizontal, 20)
        .accessibilityElement(children: .contain)
    }

    // MARK: Trophy shelf

    private var trophyShelf: some View {
        VStack(spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "light.beacon.max")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Theme.gold)
                Text("THE GRIDIRON CROWN — CHAMPIONSHIP TROPHIES")
                    .font(.system(size: 11, weight: .heavy).width(.condensed))
                    .tracking(1.6)
                    .foregroundStyle(Theme.paperInk)
                Spacer()
            }

            if legacyStore.trophies.isEmpty {
                VStack(spacing: 8) {
                    EmptyTrophyCase()
                    Text("THE CASE IS EMPTY.")
                        .font(.system(size: 13, weight: .heavy).width(.condensed))
                        .tracking(1.5)
                        .foregroundStyle(Theme.paperInkSoft)
                    Text("Win the championship and the Gridiron Crown is engraved here — season, team, colors and all. Forever.")
                        .font(Theme.typewriter(11, relativeTo: .caption))
                        .foregroundStyle(Theme.paperInkSoft)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 10)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
            } else {
                // Scrollable shelf: every title stays on permanent display.
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(legacyStore.trophies) { trophy in
                            Button {
                                Haptics.tick()
                                AudioManager.shared.play(.cardSelect)
                                selectedTrophy = trophy
                            } label: {
                                TrophyShelfCard(trophy: trophy)
                            }
                            .buttonStyle(PressableButtonStyle(scale: 0.96))
                            .accessibilityLabel("Season \(trophy.seasonNumber) championship trophy, \(trophy.displayName), record \(trophy.regularSeasonRecord). Tap for the season summary.")
                        }
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 4)
                }
                .contentMargins(.horizontal, 4)
            }
        }
        .padding(14)
        .paperCard(cornerRadius: 6)
        .overlay(alignment: .top) { PushPin(size: 18).offset(y: -9) }
        .padding(.top, 9)
        .accessibilityElement(children: .contain)
    }

    // MARK: Milestones

    private var milestonesCard: some View {
        let players = RosterManager.shared.franchise?.allPlayers ?? []
        let legacy = legacyStore.franchiseLegacy(history: RosterManager.shared.franchise?.history ?? FranchiseHistory(), players: players)
        let rows: [(symbol: String, label: String, value: String, isMajor: Bool)] = [
            ("flag.checkered", "UNDEFEATED SEASONS", legacyStore.isUndefeatedSeasonOnRecord ? "ON RECORD" : "NONE YET", legacyStore.isUndefeatedSeasonOnRecord),
            ("diamond.fill", "HALL OF FAMER TITLES", "\(legacyStore.hallOfFamerTrophies.count)", !legacyStore.hallOfFamerTrophies.isEmpty),
            ("rectangle.stack.fill", "BACK-TO-BACK TITLES", "\(backToBackCount)×", backToBackCount > 0),
            ("star.fill", "MOST PLAYER OF THE GAME", legacy.mostPlayerOfTheGame.map { "\($0.name) · \($0.count)" } ?? "—", legacy.mostPlayerOfTheGame != nil)
        ]

        return VStack(spacing: 2) {
            sectionLabel("MAJOR FRANCHISE MILESTONES")
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                milestoneRow(row)
            }
        }
        .padding(14)
        .paperCard(cornerRadius: 6)
        .rotationEffect(.degrees(-0.4))
        .accessibilityElement(children: .contain)
    }

    /// Titles won in immediate succession (S4 → S5 counts once; S4→S5→S6 twice).
    private var backToBackCount: Int {
        let seasons = legacyStore.trophies.map(\.seasonNumber).sorted()
        var count = 0
        for index in 1..<max(1, seasons.count) where seasons[index] - seasons[index - 1] == 1 {
            count += 1
        }
        return count
    }

    private func milestoneRow(_ row: (symbol: String, label: String, value: String, isMajor: Bool)) -> some View {
        HStack(spacing: 10) {
            Image(systemName: row.symbol)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(row.isMajor ? Theme.gold : Theme.paperInkSoft.opacity(0.5))
                .frame(width: 24)
            Text(row.label)
                .font(Theme.typewriter(12.5, relativeTo: .footnote))
                .foregroundStyle(Theme.paperInk)
            Spacer()
            Text(row.value)
                .font(.system(size: 13, weight: .heavy).width(.condensed))
                .tracking(0.8)
                .foregroundStyle(row.isMajor ? AnyShapeStyle(Theme.goldGradient) : AnyShapeStyle(Theme.paperInkSoft))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.vertical, 7)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.paperInk.opacity(0.12)).frame(height: 1)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Legacy ledger

    private var legacyCard: some View {
        let players = RosterManager.shared.franchise?.allPlayers ?? []
        let legacy = legacyStore.franchiseLegacy(history: RosterManager.shared.franchise?.history ?? FranchiseHistory(), players: players)

        return VStack(spacing: 12) {
            sectionLabel("FRANCHISE LEGACY")

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                LegacyStatTile(label: "SEASONS PLAYED", value: "\(legacy.seasonsPlayed)")
                LegacyStatTile(label: "TOTAL WINS", value: "\(legacy.totalWins)")
                LegacyStatTile(label: "TOTAL LOSSES", value: "\(legacy.totalLosses)")
                LegacyStatTile(label: "PLAYOFF APPEARANCES", value: "\(legacy.playoffAppearances)")
                LegacyStatTile(label: "CHAMPIONSHIP APPEARANCES", value: "\(legacy.championshipAppearances)")
                LegacyStatTile(label: "CHAMPIONSHIPS", value: "\(legacy.championshipsWon)", accent: true)
                LegacyStatTile(label: "BEST SEASON RECORD", value: legacy.bestRecordLine ?? "—")
                LegacyStatTile(label: "WIN STREAK", value: "\(legacy.currentWinStreak) NOW · \(legacy.longestWinStreak) BEST")
                LegacyStatTile(label: "CASES SOLVED", value: "\(legacy.totalCasesSolved)", accent: true)
            }
        }
        .padding(14)
        .paperCard(cornerRadius: 6)
        .accessibilityElement(children: .contain)
    }

    // MARK: Season archive

    private var archiveCard: some View {
        VStack(spacing: 2) {
            sectionLabel("SEASON ARCHIVE — EVERY SEASON, PERMANENTLY ON FILE")

            if legacyStore.archive.isEmpty {
                Text("NO COMPLETED SEASONS ON FILE YET.")
                    .font(Theme.typewriter(12, relativeTo: .caption))
                    .foregroundStyle(Theme.paperInkSoft)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 10)
            } else {
                ForEach(legacyStore.archive) { entry in
                    SeasonArchiveRow(entry: entry)
                }
            }
        }
        .padding(14)
        .paperCard(cornerRadius: 6)
        .rotationEffect(.degrees(0.4))
        .overlay(alignment: .top) { PushPin(size: 16).offset(y: -8) }
        .padding(.top, 8)
        .accessibilityElement(children: .contain)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .heavy).width(.condensed))
            .tracking(2)
            .foregroundStyle(Theme.paperInkSoft)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Legacy stat tile

/// One engraved stat plate in the legacy ledger.
struct LegacyStatTile: View {
    let label: String
    let value: String
    var accent = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 8.5, weight: .black).width(.condensed))
                .tracking(1.2)
                .foregroundStyle(Theme.paperInkSoft)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(value)
                .font(.system(size: 17, weight: .black).width(.compressed))
                .monospacedDigit()
                .foregroundStyle(accent ? AnyShapeStyle(Theme.goldGradient) : AnyShapeStyle(Theme.goldLight))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            LinearGradient(colors: [Theme.surfaceRaised.opacity(0.9), Theme.surface.opacity(0.9)], startPoint: .top, endPoint: .bottom),
            in: .rect(cornerRadius: 5)
        )
        .overlay { RoundedRectangle(cornerRadius: 5).strokeBorder(Theme.paperInk.opacity(0.15), lineWidth: 1) }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

// MARK: - Season archive row

/// One archived season: SEASON 4 · 9–1 · 1st Place · PRO · GRIDIRON CHAMPIONS.
struct SeasonArchiveRow: View {
    let entry: SeasonArchiveEntry

    private var resultColor: Color {
        if entry.isChampion { return Theme.gold }
        if entry.postseasonResult == SeasonArchiveEntry.missedPlayoffsResult { return Theme.paperInkSoft }
        return Theme.paperInk
    }

    var body: some View {
        HStack(spacing: 10) {
            Text("S\(entry.seasonNumber)")
                .font(.system(size: 15, weight: .black).width(.compressed))
                .foregroundStyle(Theme.goldLight)
                .frame(width: 40, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(entry.recordLine)
                        .font(.system(size: 13, weight: .heavy).width(.condensed))
                        .monospacedDigit()
                        .foregroundStyle(Theme.paperInk)
                    Text(entry.standingLine)
                        .font(.system(size: 10, weight: .heavy).width(.condensed))
                        .foregroundStyle(Theme.paperInkSoft)
                    Text(entry.difficulty)
                        .font(.system(size: 9, weight: .black).width(.condensed))
                        .tracking(0.8)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(Theme.bronzeDeep.opacity(0.5), in: .rect(cornerRadius: 3))
                        .foregroundStyle(Theme.goldLight)
                }
                Text(entry.postseasonResult)
                    .font(.system(size: 10, weight: .heavy).width(.condensed))
                    .tracking(1)
                    .foregroundStyle(resultColor)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if entry.isUndefeated {
                Image(systemName: "flag.checkered")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.gold)
                    .accessibilityLabel("Undefeated season")
            }
            if entry.isChampion {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.gold)
                    .accessibilityLabel("Champions")
            }
        }
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.paperInk.opacity(0.12)).frame(height: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Season \(entry.seasonNumber), record \(entry.recordLine), \(entry.standingLine), difficulty \(entry.difficulty), \(entry.postseasonResult)")
    }
}

// MARK: - Trophy art (original GameScene design)

/// The GRIDIRON CROWN — an original fictional championship trophy: a tall
/// engraved gold tablet on a dark pedestal, a football bursting through a
/// star at the crown, all inside a lit glass case. Deliberately not modeled
/// on any real sports trophy.
struct ChampionshipTrophyArt: View {
    var primaryColor: Color = Theme.gold
    var secondaryColor: Color = Theme.goldLight
    var size: CGFloat = 110

    var body: some View {
        VStack(spacing: 0) {
            // Crown star
            Image(systemName: "star.fill")
                .font(.system(size: size * 0.13, weight: .bold))
                .foregroundStyle(secondaryColor)
                .offset(y: size * 0.02)

            // The tablet: tall gold plate with engraved football
            ZStack {
                RoundedRectangle(cornerRadius: size * 0.1)
                    .fill(
                        LinearGradient(
                            colors: [secondaryColor, primaryColor, Color(hex: 0x9C6B2C)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: size * 0.42, height: size * 0.56)
                // Engraved football
                Capsule()
                    .fill(Color(hex: 0x1B160E).opacity(0.85))
                    .frame(width: size * 0.26, height: size * 0.15)
                    .rotationEffect(.degrees(-18))
                Capsule()
                    .stroke(secondaryColor.opacity(0.9), lineWidth: 1.2)
                    .frame(width: size * 0.26, height: size * 0.15)
                    .rotationEffect(.degrees(-18))
                // Laces
                Rectangle()
                    .fill(secondaryColor)
                    .frame(width: size * 0.08, height: 1.2)
                    .rotationEffect(.degrees(-18))
                    .offset(y: -size * 0.012)
                // Engraving lines
                VStack(spacing: size * 0.03) {
                    Rectangle().fill(Color(hex: 0x1B160E).opacity(0.5)).frame(width: size * 0.24, height: 1.5)
                    Rectangle().fill(Color(hex: 0x1B160E).opacity(0.35)).frame(width: size * 0.16, height: 1.5)
                }
                .offset(y: size * 0.19)
            }
            .padding(.bottom, size * 0.03)

            // Stem
            Rectangle()
                .fill(primaryColor)
                .frame(width: size * 0.07, height: size * 0.1)

            // Pedestal
            VStack(spacing: 0) {
                Rectangle()
                    .fill(
                        LinearGradient(colors: [primaryColor, Color(hex: 0x9C6B2C)], startPoint: .top, endPoint: .bottom)
                    )
                    .frame(width: size * 0.3, height: size * 0.045)
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(colors: [Color(hex: 0x4A3316), Color(hex: 0x241808)], startPoint: .top, endPoint: .bottom)
                    )
                    .frame(width: size * 0.6, height: size * 0.09)
            }
        }
        .frame(width: size, height: size)
        .shadow(color: Theme.gold.opacity(0.3), radius: 8, y: 4)
        .accessibilityHidden(true)
    }
}

/// An empty glass case — the shelf waiting for the first title.
struct EmptyTrophyCase: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.black.opacity(0.35))
                .frame(width: 120, height: 110)
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Theme.gold.opacity(0.3), lineWidth: 1.5)
                .frame(width: 120, height: 110)
            Image(systemName: "lock.fill")
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(Theme.paperInkSoft.opacity(0.5))
        }
        .accessibilityHidden(true)
    }
}

/// One trophy on the shelf: the crown art inside a lit glass case with an
/// engraved season plate beneath. Historical snapshot only — the colors and
/// name shown are those of the season it was won, never current branding.
struct TrophyShelfCard: View {
    let trophy: ChampionshipTrophy

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                // Spotlight cone
                LinearGradient(
                    colors: [Theme.gold.opacity(0.2), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(width: 96, height: 128)
                ChampionshipTrophyArt(
                    primaryColor: Color(hex: trophy.primaryColorHex),
                    secondaryColor: Color(hex: trophy.secondaryColorHex),
                    size: 104
                )
                // Glass case sheen
                LinearGradient(
                    colors: [.white.opacity(0.1), .clear],
                    startPoint: .topLeading,
                    endPoint: .center
                )
                .frame(width: 96, height: 128)
                .accessibilityHidden(true)
            }
            .frame(height: 130)

            VStack(spacing: 2) {
                Text("SEASON \(trophy.seasonNumber)")
                    .font(.system(size: 12, weight: .black).width(.condensed))
                    .tracking(1)
                    .foregroundStyle(Theme.goldGradient)
                Text(trophy.displayName.uppercased())
                    .font(.system(size: 9, weight: .heavy).width(.condensed))
                    .tracking(0.8)
                    .foregroundStyle(Theme.paperInkSoft)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("\(trophy.regularSeasonRecord) · \(trophy.resultLine)")
                    .font(.system(size: 9, weight: .heavy).width(.condensed))
                    .monospacedDigit()
                    .foregroundStyle(Theme.bronzeDeep)
            }
        }
        .padding(10)
        .frame(width: 150)
        .background(
            LinearGradient(colors: [Theme.surfaceRaised.opacity(0.95), Theme.surface.opacity(0.95)], startPoint: .top, endPoint: .bottom),
            in: .rect(cornerRadius: 8)
        )
        .overlay { RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.gold.opacity(0.35), lineWidth: 1) }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Trophy detail sheet

/// The full historical season summary behind one tapped trophy.
struct TrophyDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let trophy: ChampionshipTrophy
    let archiveEntry: SeasonArchiveEntry?

    var body: some View {
        ZStack {
            Theme.ink.ignoresSafeArea()

            VStack(spacing: 16) {
                HStack {
                    Spacer()
                    Button {
                        Haptics.tick()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Theme.goldLight)
                            .frame(width: 34, height: 34)
                            .background(Color.black.opacity(0.55), in: .circle)
                            .overlay { Circle().strokeBorder(Theme.gold.opacity(0.4), lineWidth: 1) }
                    }
                    .buttonStyle(PressableButtonStyle())
                    .accessibilityLabel("Close trophy summary")
                }
                .padding(.horizontal, 20)

                ChampionshipTrophyArt(
                    primaryColor: Color(hex: trophy.primaryColorHex),
                    secondaryColor: Color(hex: trophy.secondaryColorHex),
                    size: 130
                )

                VStack(spacing: 6) {
                    Text("GRIDIRON CHAMPIONS")
                        .font(.system(size: 11, weight: .black).width(.condensed))
                        .tracking(2.5)
                        .foregroundStyle(Theme.gold)
                    Text("SEASON \(trophy.seasonNumber)")
                        .font(.system(size: 30, weight: .black).width(.compressed))
                        .foregroundStyle(Theme.goldGradient)
                    Text("\(trophy.displayName.uppercased()) · \(trophy.teamState.uppercased())")
                        .font(.system(size: 12, weight: .heavy).width(.condensed))
                        .tracking(1)
                        .foregroundStyle(Theme.paperInk)
                }

                VStack(spacing: 2) {
                    detailRow("TEAM", trophy.displayName)
                    detailRow("REGULAR SEASON", trophy.regularSeasonRecord)
                    detailRow("DIFFICULTY", trophy.difficulty)
                    detailRow("CHAMPIONSHIP OPPONENT", trophy.opponentName)
                    detailRow("CHAMPIONSHIP RESULT", trophy.resultLine)
                    if let entry = archiveEntry {
                        detailRow("FINAL STANDING", entry.standingLine)
                        detailRow("POSTSEASON", entry.postseasonResult)
                    }
                    detailRow("WON", trophy.date.formatted(date: .abbreviated, time: .omitted))
                }
                .padding(14)
                .background(Theme.surface.opacity(0.9), in: .rect(cornerRadius: 8))
                .overlay { RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.gold.opacity(0.3), lineWidth: 1) }
                .padding(.horizontal, 20)

                Text("ENGRAVED THE SEASON IT WAS WON — RE-BRANDING THE FRANCHISE NEVER REWRITES HISTORY.")
                    .font(Theme.typewriter(9.5, relativeTo: .caption2))
                    .foregroundStyle(Theme.paperInkSoft)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)

                Spacer()
            }
            .padding(.top, 16)
        }
        .presentationDetents([.medium, .large])
        .presentationContentInteraction(.scrolls)
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 10, weight: .heavy).width(.condensed))
                .tracking(1.2)
                .foregroundStyle(Theme.paperInkSoft)
            Spacer()
            Text(value)
                .font(Theme.typewriter(13, relativeTo: .footnote))
                .foregroundStyle(Theme.paperInk)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.vertical, 5)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.paperInk.opacity(0.12)).frame(height: 1)
        }
        .accessibilityElement(children: .combine)
    }
}

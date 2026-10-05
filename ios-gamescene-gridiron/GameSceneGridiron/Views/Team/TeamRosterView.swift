import SwiftUI

/// TEAM — the franchise dossier: identity header, season leaders and the
/// persistent 12-player roster (6 offense, 6 defense). Tapping a player opens
/// their detail file. Not a management sim — just attachment and continuity.
struct TeamRosterView: View {
    @Environment(\.dismiss) private var dismiss

    let userTeam: GameTeam

    @State private var rosterManager = RosterManager.shared
    @State private var seasonManager = SeasonManager.shared
    @State private var selectedPlayer: FranchisePlayer?
    @State private var isEditingTeam: Bool = false
    @State private var hasAppeared: Bool = false

    var body: some View {
        ZStack {
            DeskBackground()

            ScrollView {
                VStack(spacing: 18) {
                    header
                        .opacity(hasAppeared ? 1 : 0)
                        .offset(y: hasAppeared ? 0 : 18)

                    if let franchise = rosterManager.franchise {
                        if !leaderRows.isEmpty {
                            leadersCard(franchise)
                                .opacity(hasAppeared ? 1 : 0)
                                .offset(y: hasAppeared ? 0 : 18)
                        }
                        rosterSection("OFFENSE", players: franchise.players(on: .offense))
                        rosterSection("DEFENSE", players: franchise.players(on: .defense))
                    }

                    Spacer(minLength: 12)
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
        .fullScreenCover(item: $selectedPlayer) { player in
            PlayerDetailView(player: player, team: userTeam, onClose: { selectedPlayer = nil })
        }
        .fullScreenCover(isPresented: $isEditingTeam) {
            TeamCreationView(existingTeam: userTeam) { _ in
                isEditingTeam = false
            } onClose: {
                isEditingTeam = false
            }
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
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

                Spacer(minLength: 8)

                Button {
                    Haptics.tick()
                    isEditingTeam = true
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.goldLight)
                        .frame(width: 38, height: 38)
                        .background(Color.black.opacity(0.45), in: .circle)
                        .overlay { Circle().strokeBorder(Theme.gold.opacity(0.4), lineWidth: 1) }
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityLabel("Redesign the franchise look")
            }

            HStack(spacing: 14) {
                TeamEmblemView(team: userTeam, size: 62)
                    .frame(width: 62)

                VStack(alignment: .leading, spacing: 6) {
                    Text(userTeam.displayName)
                        .font(.system(size: 22, weight: .black).width(.compressed))
                        .tracking(0.8)
                        .foregroundStyle(Theme.paperInk)
                        .lineLimit(2)
                        .minimumScaleFactor(0.6)
                    HStack(spacing: 5) {
                        Circle().fill(userTeam.primaryColor).frame(width: 11, height: 11)
                            .overlay { Circle().strokeBorder(Color.black.opacity(0.35), lineWidth: 1) }
                        Circle().fill(userTeam.secondaryColor).frame(width: 11, height: 11)
                            .overlay { Circle().strokeBorder(Color.black.opacity(0.35), lineWidth: 1) }
                        Text("THE FRANCHISE")
                            .font(.system(size: 10, weight: .heavy).width(.condensed))
                            .tracking(1.5)
                            .foregroundStyle(Theme.paperInkSoft)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .trailing, spacing: 3) {
                    Text(seasonManager.userRecordLine ?? "0–0")
                        .font(.system(size: 30, weight: .black).width(.compressed))
                        .monospacedDigit()
                        .foregroundStyle(Theme.paperInk)
                    Text(seasonManager.hasActiveSeason ? "SEASON \(seasonManager.season?.seasonNumber ?? 1)" : "NO SEASON")
                        .font(.system(size: 10, weight: .heavy).width(.condensed))
                        .tracking(1.2)
                        .foregroundStyle(Theme.goldLight)
                }
            }

            Text("12 RECURRING PLAYERS — SAME ROSTER EVERY CASE")
                .font(Theme.typewriter(11, relativeTo: .caption))
                .foregroundStyle(Theme.paperInkSoft)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .paperCard(cornerRadius: 8)
        .overlay(alignment: .topLeading) { PushPin(size: 18).offset(x: 16, y: -9) }
        .padding(.top, 10)
        .accessibilityElement(children: .contain)
    }

    // MARK: Season leaders

    private struct LeaderRow: Identifiable {
        let id: String
        let label: String
        let holder: String
        let position: String
        let value: Int
    }

    private var leaderRows: [LeaderRow] {
        guard let franchise = rosterManager.franchise else { return [] }
        return PlayerStat.leaderCategories.compactMap { stat in
            guard let leader = franchise.leader(for: stat) else { return nil }
            return LeaderRow(
                id: stat.rawValue,
                label: stat.fullLabel.uppercased(),
                holder: leader.displayName,
                position: leader.slot.label,
                value: leader.seasonStats.value(for: stat)
            )
        }
    }

    private func leadersCard(_ franchise: Franchise) -> some View {
        VStack(spacing: 4) {
            Text("SEASON LEADERS")
                .font(.system(size: 11, weight: .heavy).width(.condensed))
                .tracking(2)
                .foregroundStyle(Theme.paperInkSoft)
                .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(leaderRows) { row in
                HStack(spacing: 8) {
                    Text(row.label)
                        .font(Theme.typewriter(13, relativeTo: .footnote))
                        .foregroundStyle(Theme.paperInk)
                    Spacer()
                    Text("\(row.holder) — \(row.position) — \(row.value)")
                        .font(.system(size: 14, weight: .heavy).width(.condensed))
                        .monospacedDigit()
                        .foregroundStyle(Theme.bronzeDeep)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .padding(.vertical, 7)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(Theme.paperInk.opacity(0.12)).frame(height: 1)
                }
            }
        }
        .padding(14)
        .paperCard(cornerRadius: 6)
        .rotationEffect(.degrees(0.4))
        .overlay(alignment: .top) { PushPin(size: 16).offset(y: -8) }
        .padding(.top, 8)
    }

    // MARK: Roster sections

    private func rosterSection(_ title: String, players: [FranchisePlayer]) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Rectangle().fill(Theme.gold.opacity(0.6)).frame(width: 22, height: 2)
                Text("\(title) — \(players.count)")
                    .font(.system(size: 13, weight: .heavy).width(.condensed))
                    .tracking(2)
                    .foregroundStyle(Theme.goldGradient)
                Rectangle().fill(Theme.gold.opacity(0.6)).frame(maxWidth: .infinity)
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 12) {
                ForEach(players) { player in
                    RosterPlayerCard(
                        player: player,
                        tint: userTeam.primaryColor,
                        onSelect: {
                            Haptics.tick()
                            AudioManager.shared.play(.cardSelect)
                            selectedPlayer = player
                        }
                    )
                }
            }
        }
    }
}

// MARK: - Roster player card

/// Compact roster card: position chip, visored portrait in team colors,
/// short name and a small season stat summary.
private struct RosterPlayerCard: View {
    let player: FranchisePlayer
    let tint: Color
    let onSelect: () -> Void

    private var accent: Color { Theme.positionAccent(player.position) }

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 0) {
                portrait
                nameRow
                statLine
                accentBar
            }
        }
        .buttonStyle(PressableButtonStyle(scale: 0.95))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(player.slot.label), \(player.displayName), \(player.seasonStats.topSummary(limit: 2) ?? "no season stats yet")")
        .accessibilityHint("Opens the player detail file")
    }

    private var portrait: some View {
        Color(hex: 0x14110D)
            .frame(height: 78)
            .overlay {
                RadialGradient(
                    colors: [accent.opacity(0.35), .clear],
                    center: UnitPoint(x: 0.5, y: 0.3),
                    startRadius: 2,
                    endRadius: 90
                )
                .allowsHitTesting(false)
            }
            .overlay {
                Image(player.bodyAssetID)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .colorMultiply(tint)
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
                LinearGradient(colors: [.white.opacity(0.12), .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: 30)
                    .allowsHitTesting(false)
            }
            .overlay(alignment: .bottom) {
                Rectangle().fill(accent.opacity(0.6)).frame(height: 1)
            }
    }

    private var nameRow: some View {
        HStack(spacing: 5) {
            Text(player.slot.label)
                .font(.system(size: 10, weight: .heavy).width(.condensed))
                .tracking(0.8)
                .foregroundStyle(Color.white.opacity(0.95))
                .padding(.horizontal, 5)
                .padding(.vertical, 1.5)
                .background(accent.opacity(0.9), in: .rect(cornerRadius: 3))
            Text(player.displayName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.95))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .padding(.horizontal, 6)
        .frame(height: 23)
        .frame(maxWidth: .infinity)
        .background(Color(hex: 0x0F0D0A))
    }

    private var statLine: some View {
        Group {
            if let summary = player.seasonStats.topSummary(limit: 2) {
                Text(summary)
            } else {
                Text("NO STATS YET")
            }
        }
        .font(Theme.typewriter(9, relativeTo: .caption2))
        .foregroundStyle(Theme.goldLight.opacity(0.85))
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .padding(.horizontal, 6)
        .frame(height: 18)
        .frame(maxWidth: .infinity)
        .background(Color(hex: 0x14110D))
    }

    private var accentBar: some View {
        Rectangle()
            .fill(Theme.positionAccentGradient(player.position))
            .frame(height: 4)
    }
}

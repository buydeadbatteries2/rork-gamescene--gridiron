import SwiftUI

/// What opened a PLAYER FILE: a leaderboard row (with board stats) or a
/// search result (public profile already in hand).
struct PlayerFileSelection: Identifiable, Hashable {
    let userID: UUID
    let username: String
    let footballDisplayName: String
    let entry: LeaderboardEntry?
    let profile: PublicPlayerFile?

    var id: UUID { userID }

    init(entry: LeaderboardEntry) {
        userID = entry.userID
        username = entry.username
        footballDisplayName = entry.footballDisplayName
        self.entry = entry
        profile = nil
    }

    init(player: PublicPlayerFile) {
        userID = player.id
        username = player.username
        footballDisplayName = player.footballDisplayName
        entry = nil
        profile = player
    }
}

/// Public PLAYER FILE — username, football display name, server-verified
/// career numbers. Never real names or email.
struct PlayerFileView: View {
    let selection: PlayerFileSelection
    let board: LeaderboardBoard
    let loadProfile: (UUID) async -> PublicPlayerFile?

    @State private var profile: PublicPlayerFile?
    @State private var didFail = false

    var body: some View {
        ZStack {
            Theme.charcoal.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    dossier
                    if let entry = selection.entry {
                        boardStats(entry)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 28)
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
        }
        .preferredColorScheme(.dark)
        .task {
            if let preloaded = selection.profile {
                profile = preloaded
                return
            }
            profile = await loadProfile(selection.userID)
            didFail = profile == nil
        }
    }

    private var dossier: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 7) {
                Image(systemName: "person.text.rectangle")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.bronzeDeep)
                Text("PLAYER FILE")
                    .font(Theme.condensed(11))
                    .tracking(2)
                    .foregroundStyle(Theme.paperInkSoft)
                Spacer(minLength: 0)
                if let rank = selection.entry?.rank {
                    Text("#\(rank) \(board.title)")
                        .font(Theme.condensed(11))
                        .tracking(1.4)
                        .foregroundStyle(Theme.danger)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .overlay { RoundedRectangle(cornerRadius: 3).strokeBorder(Theme.danger.opacity(0.7), lineWidth: 1.2) }
                        .rotationEffect(.degrees(-4))
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("@\(selection.username)")
                    .font(Theme.condensed(28, weight: .black))
                    .foregroundStyle(Theme.paperInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(selection.footballDisplayName)
                    .font(Theme.typewriter(14))
                    .foregroundStyle(Theme.paperInkSoft)
            }

            Rectangle().fill(Theme.paperInk.opacity(0.25)).frame(height: 1)

            if let profile {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 14) {
                    stat("GLOBAL RATING", "\(profile.globalRating)")
                    stat("CHAMPIONSHIPS", "\(profile.championships)")
                    stat("CAREER GAMES", "\(profile.careerGamesPlayed)")
                    stat("CAREER WINS", "\(profile.careerWins)")
                    stat("WIN RATE", winRate(profile))
                }
            } else if didFail {
                Text("Career file unavailable offline.")
                    .font(Theme.typewriter(12))
                    .foregroundStyle(Theme.paperInkSoft)
            } else {
                HStack {
                    ProgressView().tint(Theme.paperInk)
                    Text("Pulling the file…")
                        .font(Theme.typewriter(12))
                        .foregroundStyle(Theme.paperInkSoft)
                }
            }
        }
        .padding(18)
        .background {
            PaperSurface(cornerRadius: 8, darkness: 0.04)
                .shadow(color: .black.opacity(0.6), radius: 16, y: 10)
        }
        .overlay(alignment: .top) { PushPin(size: 18).offset(y: -8) }
        .rotationEffect(.degrees(-0.5))
    }

    private func boardStats(_ entry: LeaderboardEntry) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("\(board.title) LEDGER")
                .font(Theme.condensed(11))
                .tracking(2)
                .foregroundStyle(Theme.gold)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 14) {
                darkStat(board == .weekly ? "POINTS" : "AVG", LeaderboardFormat.score(entry, board: board).replacingOccurrences(of: " — PROVISIONAL", with: ""))
                darkStat("COUNTED", "\(entry.gamesCounted)/\(entry.totalGames)")
                darkStat("TOP LEVEL", LeaderboardFormat.difficultyBadge(entry.topDifficulty))
                darkStat("WINS", "\(entry.wins)")
                darkStat("QUARTERS", "\(entry.quartersSolved)")
                darkStat("HINTS", "\(entry.hintsUsed)")
            }
            if entry.isProvisional {
                Text("PROVISIONAL — fewer than 5 verified games on record.")
                    .font(Theme.typewriter(11))
                    .foregroundStyle(Theme.danger)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: .rect(cornerRadius: 10))
        .overlay { RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.gold.opacity(0.3), lineWidth: 1) }
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(Theme.condensed(22, weight: .black))
                .monospacedDigit()
                .foregroundStyle(Theme.paperInk)
            Text(label)
                .font(Theme.condensed(9))
                .tracking(1.4)
                .foregroundStyle(Theme.paperInkSoft)
        }
    }

    private func darkStat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(Theme.condensed(18, weight: .black))
                .monospacedDigit()
                .foregroundStyle(Theme.paper)
            Text(label)
                .font(Theme.condensed(9))
                .tracking(1.3)
                .foregroundStyle(Theme.paperDark.opacity(0.7))
        }
    }

    private func winRate(_ profile: PublicPlayerFile) -> String {
        guard profile.careerGamesPlayed > 0 else { return "—" }
        let rate = Double(profile.careerWins) / Double(profile.careerGamesPlayed) * 100
        return "\(Int(rate.rounded()))%"
    }
}

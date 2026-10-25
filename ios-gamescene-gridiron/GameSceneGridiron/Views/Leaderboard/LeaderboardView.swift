import SwiftUI

/// LEADERBOARD — the league's ranking ledger. A dark records room with a
/// pinned paper ledger of verified standings: WEEKLY / ALL-TIME tabs,
/// difficulty pills, username search, gold/silver/bronze podium rows and a
/// pinned YOUR RANK slip. Every number shown was computed by the server.
struct LeaderboardView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var model: LeaderboardViewModel
    @State private var selectedPlayer: PlayerFileSelection?
    @State private var hasAppeared = false
    @FocusState private var isSearchFocused: Bool

    init(model: LeaderboardViewModel? = nil) {
        _model = State(initialValue: model ?? .live())
    }

    var body: some View {
        ZStack {
            background

            VStack(spacing: 14) {
                header
                boardTabs
                difficultyPills
                searchField
                content
            }
            .padding(.top, 10)
            .opacity(hasAppeared ? 1 : 0)
            .offset(y: hasAppeared ? 0 : 14)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let mine = model.pinnedStanding, !isSearchActive, model.state == .loaded {
                pinnedRank(mine)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .preferredColorScheme(.dark)
        .task { await model.load() }
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.85).delay(0.05)) { hasAppeared = true }
        }
        .sheet(item: $selectedPlayer) { selection in
            PlayerFileView(selection: selection, board: model.board) { id in
                await model.playerFile(for: id)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sensoryFeedback(.selection, trigger: model.board)
        .sensoryFeedback(.selection, trigger: model.difficulty)
    }

    private var isSearchActive: Bool { PlayerSearchQuery.normalized(model.searchText) != nil }

    // MARK: Background

    private var background: some View {
        ZStack {
            Theme.ink
            RadialGradient(
                colors: [Theme.gold.opacity(0.12), .clear],
                center: UnitPoint(x: 0.5, y: 0.05),
                startRadius: 10,
                endRadius: 480
            )
            LinearGradient(colors: [.black.opacity(0.45), .clear, .black.opacity(0.5)], startPoint: .top, endPoint: .bottom)
        }
        .overlay {
            Image("detective_desk_bg")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .opacity(0.18)
                .allowsHitTesting(false)
        }
        .clipped()
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
                Text("LEADERBOARD")
                    .font(.system(size: 24, weight: .black).width(.compressed))
                    .tracking(1.5)
                    .foregroundStyle(Theme.goldGradient)
                Text(model.board.caption.uppercased())
                    .font(Theme.typewriter(10, relativeTo: .caption2))
                    .tracking(0.8)
                    .foregroundStyle(Theme.paperDark.opacity(0.8))
                    .contentTransition(.opacity)
            }
            .frame(maxWidth: .infinity)

            Image(systemName: "list.number")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Theme.gold.opacity(0.7))
                .frame(width: 38, height: 38)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 20)
    }

    // MARK: Tabs & pills

    private var boardTabs: some View {
        HStack(spacing: 0) {
            ForEach(LeaderboardBoard.allCases) { board in
                let isSelected = model.board == board
                Button {
                    withAnimation(.snappy) { model.board = board }
                } label: {
                    Text(board.title)
                        .font(Theme.condensed(14))
                        .tracking(1.8)
                        .foregroundStyle(isSelected ? Theme.ink : Theme.paperDark)
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .background {
                            if isSelected {
                                Capsule().fill(Theme.goldGradient)
                                    .matchedGeometryEffect(id: "boardTab", in: tabNamespace)
                            }
                        }
                        .contentShape(.capsule)
                }
                .buttonStyle(PressableButtonStyle(scale: 0.98))
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(4)
        .background(Color.black.opacity(0.45), in: .capsule)
        .overlay { Capsule().strokeBorder(Theme.gold.opacity(0.3), lineWidth: 1) }
        .padding(.horizontal, 20)
    }

    @Namespace private var tabNamespace

    private var difficultyPills: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(LeaderboardDifficultyFilter.allCases) { filter in
                    let isSelected = model.difficulty == filter
                    Button {
                        withAnimation(.snappy) { model.difficulty = filter }
                    } label: {
                        Text(filter.title)
                            .font(Theme.condensed(11))
                            .tracking(1.4)
                            .foregroundStyle(isSelected ? Theme.paperInk : Theme.paperDark.opacity(0.85))
                            .padding(.horizontal, 14)
                            .frame(minHeight: 32)
                            .background {
                                if isSelected {
                                    PaperSurface(cornerRadius: 16)
                                } else {
                                    Capsule().fill(Color.black.opacity(0.35))
                                }
                            }
                            .overlay {
                                Capsule().strokeBorder(isSelected ? Theme.bronze : Theme.paperDark.opacity(0.25), lineWidth: 1)
                            }
                            .contentShape(.capsule)
                    }
                    .buttonStyle(PressableButtonStyle(scale: 0.95))
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            .padding(.horizontal, 20)
        }
        .scrollIndicators(.hidden)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.paperInkSoft)
            TextField("", text: $model.searchText, prompt: Text("Search players by username").foregroundStyle(Theme.paperInkSoft.opacity(0.8)))
                .font(Theme.typewriter(13))
                .foregroundStyle(Theme.paperInk)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .focused($isSearchFocused)
            if model.isSearching {
                ProgressView().controlSize(.small).tint(Theme.paperInk)
            } else if !model.searchText.isEmpty {
                Button {
                    model.searchText = ""
                    isSearchFocused = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Theme.paperInkSoft)
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 40)
        .background { PaperSurface(cornerRadius: 8, darkness: 0.04) }
        .padding(.horizontal, 20)
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        if isSearchActive {
            searchResults
        } else {
            switch model.state {
            case .idle, .loading:
                loadingLedger
            case .offline:
                statusCard(
                    symbol: "wifi.slash",
                    title: "LEADERBOARD UNAVAILABLE",
                    message: "Connect to the internet to view online rankings."
                )
            case .unavailable:
                statusCard(
                    symbol: "exclamationmark.triangle",
                    title: "LEADERBOARD UNAVAILABLE",
                    message: "The records office isn't answering right now. Try again in a moment."
                )
            case .empty:
                statusCard(
                    symbol: "doc.text.magnifyingglass",
                    title: "NO VERIFIED GAMES YET",
                    message: emptyMessage
                )
            case .loaded:
                ledger
            }
        }
    }

    private var emptyMessage: String {
        let scope = model.difficulty == .all ? "" : " at \(model.difficulty.title)"
        switch model.board {
        case .weekly: return "Nobody has a verified game\(scope) this week. Finish a season game to open the books."
        case .allTime: return "Nobody has a verified game\(scope) yet. Finish a season game to open the books."
        }
    }

    private var ledger: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ledgerHeading
                ForEach(model.entries) { entry in
                    Button {
                        Haptics.tick()
                        selectedPlayer = PlayerFileSelection(entry: entry)
                    } label: {
                        LeaderboardRow(entry: entry, board: model.board, isCurrentUser: model.isCurrentUser(entry))
                    }
                    .buttonStyle(PressableButtonStyle(scale: 0.985))
                    .task { await model.loadMoreIfNeeded(current: entry) }

                    if entry.id != model.entries.last?.id {
                        Rectangle().fill(Theme.paperInk.opacity(0.12)).frame(height: 1).padding(.horizontal, 14)
                    }
                }
                if model.isLoadingMore {
                    ProgressView().tint(Theme.paperInk).padding(.vertical, 14)
                }
            }
            .padding(.bottom, 8)
            .background {
                PaperSurface(cornerRadius: 8, darkness: 0.03)
                    .shadow(color: .black.opacity(0.6), radius: 14, y: 8)
            }
            .overlay(alignment: .top) { PushPin(size: 18).offset(y: -8) }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.immediately)
        .refreshable { await model.refresh() }
    }

    private var ledgerHeading: some View {
        HStack(spacing: 10) {
            Text("RANK")
                .frame(width: 44, alignment: .leading)
            Text("DETECTIVE")
            Spacer(minLength: 0)
            Text(model.board == .weekly ? "POINTS" : "AVG")
        }
        .font(Theme.condensed(10))
        .tracking(1.6)
        .foregroundStyle(Theme.paperInkSoft)
        .padding(.horizontal, 16)
        .padding(.top, 18)
        .padding(.bottom, 8)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.paperInk.opacity(0.35)).frame(height: 1.2).padding(.horizontal, 14)
        }
    }

    private var loadingLedger: some View {
        VStack(spacing: 0) {
            ForEach(0..<7, id: \.self) { _ in
                HStack(spacing: 12) {
                    Circle().fill(Theme.paperInk.opacity(0.12)).frame(width: 30, height: 30)
                    VStack(alignment: .leading, spacing: 6) {
                        Capsule().fill(Theme.paperInk.opacity(0.14)).frame(width: 120, height: 10)
                        Capsule().fill(Theme.paperInk.opacity(0.08)).frame(width: 80, height: 8)
                    }
                    Spacer()
                    Capsule().fill(Theme.paperInk.opacity(0.14)).frame(width: 44, height: 14)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 13)
            }
            Spacer(minLength: 0)
        }
        .padding(.top, 10)
        .background { PaperSurface(cornerRadius: 8, darkness: 0.03) }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 24)
        .redacted(reason: .placeholder)
        .phaseAnimator([0.55, 1.0]) { view, phase in
            view.opacity(phase)
        } animation: { _ in .easeInOut(duration: 0.9) }
        .accessibilityLabel("Loading rankings")
    }

    private func statusCard(symbol: String, title: String, message: String) -> some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(Theme.bronzeDeep)
                Text(title)
                    .font(Theme.condensed(17, weight: .black))
                    .tracking(1.6)
                    .foregroundStyle(Theme.paperInk)
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(Theme.typewriter(13, relativeTo: .callout))
                    .foregroundStyle(Theme.paperInkSoft)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                Button {
                    Haptics.tick()
                    Task { await model.refresh() }
                } label: {
                    Text("TRY AGAIN")
                        .font(Theme.condensed(13))
                        .tracking(1.8)
                        .foregroundStyle(Theme.paperInk)
                        .padding(.horizontal, 24)
                        .frame(minHeight: 40)
                        .overlay { Capsule().strokeBorder(Theme.paperInk.opacity(0.4), lineWidth: 1.2) }
                        .contentShape(.capsule)
                }
                .buttonStyle(PressableButtonStyle(playsPressSound: true))
                .padding(.top, 4)
            }
            .padding(.vertical, 26)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity)
            .background {
                PaperSurface(cornerRadius: 8, darkness: 0.04)
                    .shadow(color: .black.opacity(0.6), radius: 14, y: 8)
            }
            .overlay(alignment: .top) { PushPin(size: 18).offset(y: -8) }
            .rotationEffect(.degrees(-0.6))
            .padding(.horizontal, 24)
            .padding(.top, 24)
            Spacer(minLength: 0)
        }
    }

    // MARK: Search results

    @ViewBuilder
    private var searchResults: some View {
        if model.searchFailed {
            statusCard(
                symbol: "wifi.slash",
                title: "SEARCH UNAVAILABLE",
                message: "Connect to the internet to search players."
            )
        } else if model.searchResults.isEmpty && !model.isSearching {
            statusCard(
                symbol: "person.fill.questionmark",
                title: "NO MATCHING FILES",
                message: "No detective goes by that username."
            )
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(model.searchResults) { player in
                        Button {
                            Haptics.tick()
                            isSearchFocused = false
                            selectedPlayer = PlayerFileSelection(player: player)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "person.text.rectangle")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(Theme.bronzeDeep)
                                    .frame(width: 30)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("@\(player.username)")
                                        .font(Theme.condensed(15))
                                        .foregroundStyle(Theme.paperInk)
                                    Text(player.footballDisplayName)
                                        .font(Theme.typewriter(11, relativeTo: .caption))
                                        .foregroundStyle(Theme.paperInkSoft)
                                }
                                Spacer(minLength: 0)
                                Text("\(player.globalRating)")
                                    .font(Theme.condensed(16, weight: .black))
                                    .monospacedDigit()
                                    .foregroundStyle(Theme.paperInk)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Theme.paperInkSoft)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .contentShape(.rect)
                        }
                        .buttonStyle(PressableButtonStyle(scale: 0.985))
                        .accessibilityLabel("\(player.username), \(player.footballDisplayName), rating \(player.globalRating)")
                        if player.id != model.searchResults.last?.id {
                            Rectangle().fill(Theme.paperInk.opacity(0.12)).frame(height: 1).padding(.horizontal, 14)
                        }
                    }
                }
                .padding(.vertical, 6)
                .background { PaperSurface(cornerRadius: 8, darkness: 0.03) }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.immediately)
        }
    }

    // MARK: Pinned rank

    private func pinnedRank(_ entry: LeaderboardEntry) -> some View {
        Button {
            Haptics.tick()
            selectedPlayer = PlayerFileSelection(entry: entry)
        } label: {
            VStack(spacing: 0) {
                HStack {
                    Text("YOUR RANK")
                        .font(Theme.condensed(10))
                        .tracking(2)
                        .foregroundStyle(Theme.gold)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                LeaderboardRow(entry: entry, board: model.board, isCurrentUser: true, onDark: true)
            }
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Theme.surface.opacity(0.96))
                    .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.gold.opacity(0.55), lineWidth: 1.2) }
                    .shadow(color: .black.opacity(0.6), radius: 14, y: -2)
            }
        }
        .buttonStyle(PressableButtonStyle(scale: 0.985))
        .padding(.horizontal, 16)
        .padding(.bottom, 6)
        .accessibilityLabel("Your rank \(entry.rank)")
    }
}

// MARK: - Row

struct LeaderboardRow: View {
    let entry: LeaderboardEntry
    let board: LeaderboardBoard
    var isCurrentUser: Bool = false
    var onDark: Bool = false

    private var primaryInk: Color { onDark ? Theme.paper : Theme.paperInk }
    private var secondaryInk: Color { onDark ? Theme.paperDark.opacity(0.8) : Theme.paperInkSoft }

    var body: some View {
        HStack(spacing: 10) {
            rankBadge
                .frame(width: 44, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("@\(entry.username)")
                        .font(Theme.condensed(15))
                        .foregroundStyle(primaryInk)
                        .lineLimit(1)
                    if isCurrentUser && !onDark {
                        Text("YOU")
                            .font(Theme.condensed(9))
                            .tracking(1.2)
                            .foregroundStyle(Theme.ink)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Theme.gold, in: .rect(cornerRadius: 3))
                    }
                }
                Text(entry.footballDisplayName)
                    .font(Theme.typewriter(11, relativeTo: .caption))
                    .foregroundStyle(secondaryInk)
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            difficultyBadge

            scoreText
                .frame(minWidth: 52, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .background {
            if isCurrentUser && !onDark {
                Theme.gold.opacity(0.18)
            }
        }
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    @ViewBuilder
    private var rankBadge: some View {
        if let podium = entry.podium {
            ZStack {
                Circle()
                    .fill(medalGradient(podium))
                    .overlay { Circle().strokeBorder(.black.opacity(0.25), lineWidth: 1) }
                    .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                Text("\(entry.rank)")
                    .font(Theme.condensed(14, weight: .black))
                    .foregroundStyle(Theme.ink)
            }
            .frame(width: 30, height: 30)
        } else {
            Text("\(entry.rank)")
                .font(Theme.condensed(16, weight: .black))
                .monospacedDigit()
                .foregroundStyle(primaryInk.opacity(0.85))
                .frame(width: 30)
        }
    }

    private func medalGradient(_ podium: LeaderboardPodium) -> LinearGradient {
        let base: Color = switch podium {
        case .gold: Theme.gold
        case .silver: Theme.silver
        case .bronze: Theme.bronze
        }
        return LinearGradient(colors: [base.opacity(0.75), base, base.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private var difficultyBadge: some View {
        Text(LeaderboardFormat.difficultyBadge(entry.topDifficulty))
            .font(Theme.condensed(9))
            .tracking(1)
            .foregroundStyle(badgeColor)
            .padding(.horizontal, 5)
            .frame(minWidth: 30, minHeight: 18)
            .overlay { RoundedRectangle(cornerRadius: 3).strokeBorder(badgeColor.opacity(0.7), lineWidth: 1) }
            .rotationEffect(.degrees(-3))
    }

    private var badgeColor: Color {
        switch entry.topDifficulty {
        case "rookie": Theme.easy
        case "pro": Theme.medium
        case "all_pro": Theme.hard
        case "hall_of_famer": onDark ? Theme.gold : Theme.bronzeDeep
        default: secondaryInk
        }
    }

    @ViewBuilder
    private var scoreText: some View {
        switch board {
        case .weekly:
            Text(LeaderboardFormat.score(entry, board: board))
                .font(Theme.condensed(18, weight: .black))
                .monospacedDigit()
                .foregroundStyle(primaryInk)
        case .allTime:
            VStack(alignment: .trailing, spacing: 1) {
                Text(String(format: "%.1f", entry.score))
                    .font(Theme.condensed(18, weight: .black))
                    .monospacedDigit()
                    .foregroundStyle(primaryInk)
                if entry.isProvisional {
                    Text("PROVISIONAL")
                        .font(Theme.condensed(8))
                        .tracking(1)
                        .foregroundStyle(Theme.danger)
                }
            }
        }
    }

    private var accessibilitySummary: String {
        var parts = ["Rank \(entry.rank)", entry.username, entry.footballDisplayName, LeaderboardFormat.score(entry, board: board)]
        if isCurrentUser { parts.append("You") }
        return parts.joined(separator: ", ")
    }
}

#Preview {
    LeaderboardView()
}

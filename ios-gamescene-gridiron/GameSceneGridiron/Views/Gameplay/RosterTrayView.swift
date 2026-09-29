import SwiftUI

/// Paged tray of unsolved missing players. Shrinks as players are placed.
///
/// Navigation model (no swiping — arrows are the only way to browse):
/// - Shows as many collapsed cards as the available width fits (typically 3).
/// - The left/right metallic arrows slide between pages; they dim at the ends.
/// - A solved player is removed and pages re-flow with no gaps.
/// - Tap selects/expandes a card; tap on a variant chip picks the profile;
///   press-and-hold (~0.28s) sequences into the placement drag.
struct RosterTrayView: View {
    let viewModel: GameViewModel
    /// Team primary tint applied to the controlled body assets on every card.
    var tint: Color? = nil

    private enum SlideDirection { case forward, back }

    @GestureState private var isGestureActive: Bool = false
    @State private var pageIndex: Int = 0
    @State private var slideDirection: SlideDirection = .forward
    @State private var trayWidth: CGFloat = 360

    private let holdDuration: TimeInterval = 0.28
    private let cardSpacing: CGFloat = 10
    private let collapsedCardWidth: CGFloat = 112
    private let expandedCardWidth: CGFloat = 192

    var body: some View {
        let pages = self.pages(for: viewModel.remainingPlayers, availableWidth: trayWidth - 32)
        let index = min(pageIndex, max(pages.count - 1, 0))

        VStack(alignment: .leading, spacing: 8) {
            header(pages: pages, index: index)

            if viewModel.remainingPlayers.isEmpty {
                emptyState
            } else {
                pageCarousel(pages: pages, index: index)
            }
        }
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.width
        } action: { width in
            trayWidth = width
        }
        .onChange(of: isGestureActive) { _, isActive in
            if !isActive { viewModel.endDrag() }
        }
        .onChange(of: viewModel.remainingPlayers.count) { _, _ in
            // A player was placed: re-flow pages with no gaps and stay in range.
            let pages = self.pages(for: viewModel.remainingPlayers, availableWidth: trayWidth - 32)
            if pageIndex > max(pages.count - 1, 0) {
                pageIndex = max(pages.count - 1, 0)
            }
        }
        .onChange(of: viewModel.expandedPlayerID) { _, playerID in
            // Keep the card the user is configuring on screen.
            guard let playerID else { return }
            let pages = self.pages(for: viewModel.remainingPlayers, availableWidth: trayWidth - 32)
            if let target = pages.firstIndex(where: { $0.contains { $0.id == playerID } }), target != pageIndex {
                slideDirection = target > pageIndex ? .forward : .back
                withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                    pageIndex = target
                }
            }
        }
    }

    // MARK: Pieces

    private func header(pages: [[FootballPlayer]], index: Int) -> some View {
        HStack {
            Text("MISSING PLAYERS")
                .font(.system(size: 12, weight: .heavy).width(.condensed))
                .tracking(1.6)
                .foregroundStyle(Theme.silver.opacity(0.75))
            Spacer()
            if pages.count > 1 {
                Text("\(index + 1) / \(pages.count)")
                    .font(Theme.typewriter(10.5, relativeTo: .caption2))
                    .foregroundStyle(Theme.gold.opacity(0.85))
                    .contentTransition(.numericText())
                    .padding(.trailing, 8)
            }
            Text("\(viewModel.remainingPlayers.count) LEFT")
                .font(Theme.typewriter(11, relativeTo: .caption2))
                .foregroundStyle(Theme.gold.opacity(0.8))
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 16)
    }

    private var emptyState: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.seal.fill")
            Text("EVERY PLAYER ACCOUNTED FOR")
        }
        .font(.system(size: 14, weight: .heavy).width(.condensed))
        .foregroundStyle(Theme.goldLight)
        .frame(maxWidth: .infinity)
        .frame(height: 120)
        .transition(.opacity)
    }

    private func pageCarousel(pages: [[FootballPlayer]], index: Int) -> some View {
        ZStack {
            HStack(alignment: .bottom, spacing: cardSpacing) {
                ForEach(pages[index]) { player in
                    PlayerCardView(
                        player: player,
                        tint: tint,
                        isExpanded: viewModel.expandedPlayerID == player.id,
                        selectedVariant: viewModel.selectedVariant(for: player.id),
                        isBeingDragged: viewModel.draggingPlayerID == player.id,
                        onToggle: { viewModel.toggleExpanded(player.id) },
                        onSelectVariant: { viewModel.selectVariant($0, for: player.id) }
                    )
                    .simultaneousGesture(dragGesture(for: player))
                    .transition(.asymmetric(insertion: .opacity, removal: .scale(scale: 0.4).combined(with: .opacity)))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .id(index)
            .transition(slideTransition)
        }
        .overlay(alignment: .leading) {
            edgeFade(alignment: .leading)
        }
        .overlay(alignment: .trailing) {
            edgeFade(alignment: .trailing)
        }
        .overlay(alignment: .leading) {
            navArrow(
                icon: "chevron.left",
                label: "Previous players",
                isEnabled: index > 0
            ) { navigate(.back, to: index - 1) }
        }
        .overlay(alignment: .trailing) {
            navArrow(
                icon: "chevron.right",
                label: "More players",
                isEnabled: index < pages.count - 1
            ) { navigate(.forward, to: index + 1) }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: viewModel.remainingPlayers.map(\.id))
    }

    /// Soft ink gradient so the arrows read clearly against card edges.
    private func edgeFade(alignment: HorizontalAlignment) -> some View {
        let start = alignment == .leading ? Theme.ink.opacity(0.75) : Color.clear
        let end = alignment == .leading ? Color.clear : Theme.ink.opacity(0.75)
        return LinearGradient(colors: [start, end], startPoint: .leading, endPoint: .trailing)
            .frame(width: 34)
            .frame(maxHeight: .infinity, alignment: .center)
            .padding(.horizontal, alignment == .leading ? 12 : 0)
            .padding(.leading, alignment == .leading ? 0 : 12)
            .allowsHitTesting(false)
    }

    private func navArrow(
        icon: String,
        label: String,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .heavy))
                .foregroundStyle(isEnabled ? Theme.goldLight : Theme.silver.opacity(0.3))
                .frame(width: 32, height: 32)
                .background {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: 0x2E271E), Color(hex: 0x14110D)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: .black.opacity(0.6), radius: 4, y: 2)
                }
                .overlay {
                    Circle().strokeBorder(Theme.gold.opacity(isEnabled ? 0.75 : 0.2), lineWidth: 1.2)
                }
        }
        .buttonStyle(PressableButtonStyle(scale: 0.88))
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.4)
        .accessibilityLabel(label)
        .accessibilityHint("Moves through the missing-player roster one page at a time")
        .padding(.horizontal, 1)
    }

    // MARK: Pagination

    /// Greedy width-based pagination: collapsed cards pack 3-up on standard widths;
    /// an expanded card (192pt) reserves its real footprint so pages never overflow.
    private func pages(for players: [FootballPlayer], availableWidth: CGFloat) -> [[FootballPlayer]] {
        var result: [[FootballPlayer]] = []
        var current: [FootballPlayer] = []
        var currentWidth: CGFloat = 0

        for player in players {
            let width = cardWidth(for: player)
            let needed = current.isEmpty ? width : currentWidth + cardSpacing + width
            if !current.isEmpty, needed > availableWidth {
                result.append(current)
                current = [player]
                currentWidth = width
            } else {
                current.append(player)
                currentWidth = needed
            }
        }
        if !current.isEmpty { result.append(current) }
        return result
    }

    private func cardWidth(for player: FootballPlayer) -> CGFloat {
        viewModel.expandedPlayerID == player.id ? expandedCardWidth : collapsedCardWidth
    }

    private func navigate(_ direction: SlideDirection, to target: Int) {
        Haptics.tick()
        slideDirection = direction
        withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
            pageIndex = target
        }
    }

    private var slideTransition: AnyTransition {
        let enters: Edge = slideDirection == .forward ? .trailing : .leading
        let exits: Edge = slideDirection == .forward ? .leading : .trailing
        return .asymmetric(
            insertion: .move(edge: enters).combined(with: .opacity),
            removal: .move(edge: exits).combined(with: .opacity)
        )
    }

    // MARK: Drag

    private func dragGesture(for player: FootballPlayer) -> some Gesture {
        // Long press first: only a successful hold sequences into the drag, so taps
        // and any incidental touches never fight with selection.
        LongPressGesture(minimumDuration: holdDuration, maximumDistance: 15)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .named(GameplayView.coordinateSpace)))
            .updating($isGestureActive) { _, state, _ in
                state = true
            }
            .onChanged { value in
                guard case .second(true, let drag?) = value else { return }
                if viewModel.isDragging {
                    // Already carrying this player — follow the finger.
                    viewModel.updateDrag(to: drag.location)
                } else {
                    _ = viewModel.beginDrag(playerID: player.id, at: drag.location)
                }
            }
            .onEnded { _ in
                viewModel.endDrag()
            }
    }
}

import SwiftUI

/// Horizontally scrolling tray of unsolved missing players. Shrinks as players are placed.
///
/// Interaction split so scrolling is never blocked:
/// - A quick horizontal swipe moves the tray (the scroll view owns the touch; the long
///   press fails as soon as the finger travels).
/// - A tap selects/expandes a card (handled by the card's own button).
/// - A press-and-hold (~0.28s, minimal movement) sequences into a zero-distance drag
///   that carries the player onto the field.
struct RosterTrayView: View {
    let viewModel: GameViewModel

    @GestureState private var isGestureActive: Bool = false

    private let holdDuration: TimeInterval = 0.28

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("MISSING PLAYERS")
                    .font(.system(size: 12, weight: .heavy).width(.condensed))
                    .tracking(1.6)
                    .foregroundStyle(Theme.silver.opacity(0.75))
                Spacer()
                Text("\(viewModel.remainingPlayers.count) LEFT")
                    .font(Theme.typewriter(11, relativeTo: .caption2))
                    .foregroundStyle(Theme.gold.opacity(0.8))
                    .contentTransition(.numericText())
            }
            .padding(.horizontal, 16)

            if viewModel.remainingPlayers.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                    Text("EVERY PLAYER ACCOUNTED FOR")
                }
                .font(.system(size: 14, weight: .heavy).width(.condensed))
                .foregroundStyle(Theme.goldLight)
                .frame(maxWidth: .infinity)
                .frame(height: 120)
                .transition(.opacity)
            } else {
                ScrollView(.horizontal) {
                    HStack(alignment: .bottom, spacing: 10) {
                        ForEach(viewModel.remainingPlayers) { player in
                            PlayerCardView(
                                player: player,
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
                    .animation(.spring(response: 0.45, dampingFraction: 0.8), value: viewModel.remainingPlayers.map(\.id))
                }
                .contentMargins(.horizontal, 16)
                .scrollIndicators(.hidden)
                .scrollDisabled(viewModel.isDragging)
            }
        }
        .onChange(of: isGestureActive) { _, isActive in
            if !isActive { viewModel.endDrag() }
        }
    }

    private func dragGesture(for player: FootballPlayer) -> some Gesture {
        // Long press first: it FAILS the moment the finger travels, so a quick swipe is
        // free to scroll the tray. Only a successful hold sequences into the drag.
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

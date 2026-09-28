import SwiftUI

/// Horizontally scrolling tray of unsolved missing players. Shrinks as players are placed.
///
/// Drag model: a plain zero-distance drag gesture tracks the touch. Holding still on a
/// card for ~0.28s starts the placement drag (only when a variant is selected); moving
/// more than ~14pt before that cancels the hold so vertical scrolls still work.
struct RosterTrayView: View {
    let viewModel: GameViewModel

    @GestureState private var isGestureActive: Bool = false
    @State private var pressStartDate: Date?

    private let holdDuration: TimeInterval = 0.28
    private let holdMaxMovement: CGFloat = 14

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
        DragGesture(minimumDistance: 0, coordinateSpace: .named(GameplayView.coordinateSpace))
            .updating($isGestureActive) { _, state, _ in
                state = true
            }
            .onChanged { value in
                if viewModel.isDragging {
                    // Already carrying this player — follow the finger.
                    viewModel.updateDrag(to: value.location)
                    return
                }
                let movement = hypot(value.translation.width, value.translation.height)
                guard movement <= holdMaxMovement else {
                    // Moved too far, too fast: treat as a scroll, never start a drag.
                    pressStartDate = nil
                    return
                }
                let start = pressStartDate ?? value.time
                if pressStartDate == nil { pressStartDate = start }
                if value.time.timeIntervalSince(start) >= holdDuration {
                    pressStartDate = nil
                    if viewModel.beginDrag(playerID: player.id, at: value.location) {
                        viewModel.updateDrag(to: value.location)
                    }
                }
            }
            .onEnded { _ in
                pressStartDate = nil
                if viewModel.isDragging {
                    viewModel.endDrag()
                } else {
                    viewModel.cancelDrag()
                }
            }
    }
}

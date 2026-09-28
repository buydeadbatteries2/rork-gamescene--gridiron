import SwiftUI

/// The VERTICAL tactical field: offense at the bottom, defense up top, yard lines
/// running horizontally, sidelines on the left and right. Evidence, solved placements
/// and (while dragging) mystery zones are drawn on top.
struct GameFieldView: View {
    let viewModel: GameViewModel
    /// When false the field is a static snapshot (used on the result screen).
    var isInteractive: Bool = true

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let token = min(max(size.width * 0.066, 18), 26)

            ZStack(alignment: .topLeading) {
                FieldTurf()

                ForEach(viewModel.puzzle.evidence) { item in
                    evidence(item, token: token)
                        .position(x: size.width * item.x, y: size.height * item.y)
                }

                ForEach(viewModel.puzzle.visiblePlayers) { player in
                    FootballPlayerView(position: player.position, size: token)
                        .position(x: size.width * player.x, y: size.height * player.y)
                        .allowsHitTesting(false)
                }

                ForEach(viewModel.placements) { placed in
                    FootballPlayerView(
                        position: placed.player.position,
                        size: token,
                        variant: placed.variant,
                        isHighlighted: isInteractive && placed.id == viewModel.lastPlacedPlayerID
                    )
                    .position(x: size.width * placed.slot.x, y: size.height * placed.slot.y)
                    .transition(.scale(scale: 1.8).combined(with: .opacity))
                    .allowsHitTesting(false)
                }

                if isInteractive {
                    ForEach(viewModel.openSlots) { slot in
                        let isRejected = viewModel.rejectedSlotID == slot.id
                        if viewModel.isDragging || isRejected {
                            PlacementZoneView(
                                isHovered: viewModel.hoveredSlotID == slot.id,
                                isRejected: isRejected,
                                size: token * 1.7
                            )
                            .modifier(ShakeEffect(animatableData: isRejected ? CGFloat(viewModel.rejectionCount) : 0))
                            .animation(.linear(duration: 0.45), value: viewModel.rejectionCount)
                            .position(x: size.width * slot.x, y: size.height * slot.y)
                            .transition(.opacity.combined(with: .scale(scale: 0.6)))
                        }
                    }
                }
            }
            .animation(.easeInOut(duration: 0.2), value: viewModel.isDragging)
        }
        .clipShape(.rect(cornerRadius: 4))
        .overlay {
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(Color.black.opacity(0.6), lineWidth: 2)
        }
        .overlay(alignment: .bottom) {
            if isInteractive, viewModel.isDragging {
                Text("DROP WHERE THE EVIDENCE POINTS")
                    .font(Theme.typewriter(10, relativeTo: .caption2))
                    .tracking(1)
                    .foregroundStyle(Theme.goldLight)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.black.opacity(0.6), in: .capsule)
                    .padding(.bottom, 6)
                    .transition(.opacity)
            }
        }
        .onGeometryChange(for: CGRect.self) { proxy in
            proxy.frame(in: .named(GameplayView.coordinateSpace))
        } action: { frame in
            if isInteractive { viewModel.fieldFrame = frame }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Football field, offense at the bottom, defense up top")
    }

    @ViewBuilder
    private func evidence(_ item: EvidenceItem, token: CGFloat) -> some View {
        let isInspected = viewModel.inspectedEvidenceID == item.id
        Button {
            viewModel.inspect(item)
        } label: {
            EvidenceItemView(kind: item.kind, size: token * 0.95)
                .rotationEffect(.degrees(item.rotation))
                .frame(width: 44, height: 44)
                .contentShape(.rect)
        }
        .buttonStyle(PressableButtonStyle(scale: 0.9))
        .disabled(!isInteractive || viewModel.isDragging)
        .overlay(alignment: .top) {
            if isInspected {
                Text(item.kind.title.uppercased())
                    .font(Theme.typewriterBold(10, relativeTo: .caption2))
                    .foregroundStyle(Theme.paperInk)
                    .fixedSize()
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .paperCard(cornerRadius: 2)
                    .offset(y: -22)
                    .transition(.scale(scale: 0.7, anchor: .bottom).combined(with: .opacity))
            }
        }
        .zIndex(isInspected ? 5 : 0)
    }
}

/// Vertical field: depth runs from the bottom (offense backfield) to the top (deep
/// defense). Sidelines are the vertical chalk rails; yard lines stretch horizontally.
struct FieldTurf: View {
    /// Yard labels from top row (deepest) to bottom row, LOS ≈ 38-yard line at y 0.52.
    private let yardLabels = ["40", "45", "50", "45", "40", "35", "30", "25", "20"]

    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height

            // Mowing stripes — horizontal bands across the depth of the field
            let stripes = 12
            for i in 0..<stripes {
                let rect = CGRect(x: 0, y: h * CGFloat(i) / CGFloat(stripes), width: w, height: h / CGFloat(stripes) + 0.5)
                context.fill(Path(rect), with: .color(i.isMultiple(of: 2) ? Theme.turf : Color(hex: 0x28502A)))
            }

            // End-zone hatch hints beyond the top and bottom of the visible slice
            for band in [CGRect(x: 0, y: 0, width: w, height: 5), CGRect(x: 0, y: h - 5, width: w, height: 5)] {
                context.fill(Path(band), with: .color(Theme.chalk.opacity(0.16)))
            }

            // Sidelines — vertical chalk rails on the left and right
            for x in [w * 0.025, w * 0.975] {
                var rail = Path()
                rail.move(to: CGPoint(x: x, y: 0))
                rail.addLine(to: CGPoint(x: x, y: h))
                context.stroke(rail, with: .color(Theme.chalk.opacity(0.8)), lineWidth: 2)
            }

            // Yard lines every 10 "yards" — horizontal, spanning the whole width
            for i in 1...9 {
                let y = h * CGFloat(i) / 10
                var line = Path()
                line.move(to: CGPoint(x: 0, y: y))
                line.addLine(to: CGPoint(x: w, y: y))
                context.stroke(line, with: .color(Theme.chalk.opacity(0.7)), lineWidth: 1.4)

                // Hash marks: short vertical ticks either side of center
                for hx in [0.36, 0.64] {
                    var tick = Path()
                    tick.move(to: CGPoint(x: w * hx, y: y - 3.5))
                    tick.addLine(to: CGPoint(x: w * hx, y: y + 3.5))
                    context.stroke(tick, with: .color(Theme.chalk.opacity(0.45)), lineWidth: 0.9)
                }

                // 5-yard minor line
                let yMinor = h * (CGFloat(i) - 0.5) / 10
                var minor = Path()
                minor.move(to: CGPoint(x: 0, y: yMinor))
                minor.addLine(to: CGPoint(x: w, y: yMinor))
                context.stroke(minor, with: .color(Theme.chalk.opacity(0.25)), lineWidth: 0.8)
            }

            // Line of scrimmage — horizontal dashed gold line
            var los = Path()
            los.move(to: CGPoint(x: 0, y: h * 0.52))
            los.addLine(to: CGPoint(x: w, y: h * 0.52))
            context.stroke(los, with: .color(Theme.gold.opacity(0.4)), style: StrokeStyle(lineWidth: 1.2, dash: [6, 4]))

            // Yard numbers along both sidelines
            for (index, label) in yardLabels.enumerated() {
                let y = h * CGFloat(index + 1) / 10
                let text = Text(label)
                    .font(.system(size: max(9, w * 0.038), weight: .bold, design: .serif))
                    .foregroundColor(Theme.chalk.opacity(0.5))
                context.draw(context.resolve(text), at: CGPoint(x: w * 0.095, y: y))
                context.draw(context.resolve(text), at: CGPoint(x: w * 0.905, y: y))
            }

            // Depth cues: chalk arrows showing that deeper = toward the top
            var upArrow = Path()
            upArrow.move(to: CGPoint(x: w * 0.095, y: h * 0.115))
            upArrow.addLine(to: CGPoint(x: w * 0.095, y: h * 0.075))
            upArrow.move(to: CGPoint(x: w * 0.095, y: h * 0.075))
            upArrow.addLine(to: CGPoint(x: w * 0.075, y: h * 0.095))
            upArrow.move(to: CGPoint(x: w * 0.095, y: h * 0.075))
            upArrow.addLine(to: CGPoint(x: w * 0.115, y: h * 0.095))
            context.stroke(upArrow, with: .color(Theme.chalk.opacity(0.5)), lineWidth: 1.2)
            let deep = Text("DEEP")
                .font(.system(size: max(7, w * 0.028), weight: .bold, design: .monospaced))
                .foregroundColor(Theme.chalk.opacity(0.5))
            context.draw(context.resolve(deep), at: CGPoint(x: w * 0.095, y: h * 0.145))

            var downArrow = Path()
            downArrow.move(to: CGPoint(x: w * 0.095, y: h * 0.855))
            downArrow.addLine(to: CGPoint(x: w * 0.095, y: h * 0.895))
            downArrow.move(to: CGPoint(x: w * 0.095, y: h * 0.895))
            downArrow.addLine(to: CGPoint(x: w * 0.075, y: h * 0.875))
            downArrow.move(to: CGPoint(x: w * 0.095, y: h * 0.895))
            downArrow.addLine(to: CGPoint(x: w * 0.115, y: h * 0.875))
            context.stroke(downArrow, with: .color(Theme.chalk.opacity(0.5)), lineWidth: 1.2)
            let back = Text("BACKFIELD")
                .font(.system(size: max(6, w * 0.024), weight: .bold, design: .monospaced))
                .foregroundColor(Theme.chalk.opacity(0.5))
            context.draw(context.resolve(back), at: CGPoint(x: w * 0.11, y: h * 0.83))

            // Faint chalk play diagram (decorative) — a deep route running upward
            var route = Path()
            route.move(to: CGPoint(x: w * 0.3, y: h * 0.62))
            route.addQuadCurve(to: CGPoint(x: w * 0.42, y: h * 0.18), control: CGPoint(x: w * 0.28, y: h * 0.4))
            context.stroke(route, with: .color(Theme.chalk.opacity(0.1)), style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
        }
        .overlay {
            RadialGradient(colors: [.clear, .black.opacity(0.45)], center: .center, startRadius: 60, endRadius: 380)
        }
        .overlay {
            LinearGradient(colors: [Color.white.opacity(0.06), .clear], startPoint: .top, endPoint: .center)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

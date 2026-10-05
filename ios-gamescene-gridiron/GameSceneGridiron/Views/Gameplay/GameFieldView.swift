import SwiftUI
import UIKit

/// The VERTICAL tactical field: offense at the bottom, defense up top, yard lines
/// running horizontally, sidelines on the left and right. Evidence, solved placements
/// and (while dragging) mystery zones are drawn on top of a photoreal stadium turf.
struct GameFieldView: View {
    let viewModel: GameViewModel
    /// When false the field is a static snapshot (used on the result screen).
    var isInteractive: Bool = true
    /// Franchises wearing their colors: offense = user team, defense = opponent.
    var userTeam: GameTeam?
    var opponent: GameTeam?

    private var kits: (user: TeamKit, opponent: TeamKit)? {
        guard let userTeam, let opponent else { return nil }
        return TeamKitResolver.kits(user: userTeam, opponent: opponent)
    }

    private func kit(for position: FootballPosition) -> TeamKit? {
        guard let kits else { return nil }
        return position.side == .offense ? kits.user : kits.opponent
    }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let token = min(max(size.width * 0.075, 20), 30)

            ZStack(alignment: .topLeading) {
                FieldTurf()

                ForEach(viewModel.puzzle.evidence) { item in
                    evidence(item, token: token)
                        .position(x: size.width * item.x, y: size.height * item.y)
                }

                ForEach(viewModel.puzzle.visiblePlayers) { player in
                    FootballPlayerView(position: player.position, size: token, kit: kit(for: player.position))
                        .position(x: size.width * player.x, y: size.height * player.y)
                        .allowsHitTesting(false)
                }

                ForEach(viewModel.placements) { placed in
                    FootballPlayerView(
                        position: placed.player.position,
                        size: token,
                        variant: placed.variant,
                        isHighlighted: isInteractive && placed.id == viewModel.lastPlacedPlayerID,
                        kit: kit(for: placed.player.position)
                    )
                    .position(x: size.width * placed.slot.x, y: size.height * placed.slot.y)
                    .transition(.scale(scale: 1.8).combined(with: .opacity))
                    .allowsHitTesting(false)
                }

                if isInteractive {
                    // Only zones the dragged player could actually line up in —
                    // irrelevant landmarks for other positions stay hidden so
                    // the board never crowds with overlapping mystery targets.
                    let zoneDiameter = max(token * 1.2, 24)
                    let dragSlots = viewModel.candidateSlots
                    // Display-only de-overlap: markers may shift a few points
                    // so no two zones (or "?") ever stack. Snapping and solved
                    // placements always use the true field coordinates.
                    let markerPoints = PlacementZoneLayout.displayPositions(
                        slots: dragSlots,
                        fieldSize: size,
                        visibleDiameter: zoneDiameter
                    )
                    ForEach(dragSlots) { slot in
                        let isHovered = viewModel.hoveredSlotID == slot.id
                        let isRejected = viewModel.rejectedSlotID == slot.id
                        if viewModel.isDragging || isRejected {
                            PlacementZoneView(
                                isHovered: isHovered,
                                isRejected: isRejected,
                                isDimmed: viewModel.hoveredSlotID != nil && !isHovered,
                                size: zoneDiameter
                            )
                            .modifier(ShakeEffect(animatableData: isRejected ? CGFloat(viewModel.rejectionCount) : 0))
                            .animation(.linear(duration: 0.45), value: viewModel.rejectionCount)
                            .position(markerPoints[slot.id] ?? CGPoint(x: size.width * slot.x, y: size.height * slot.y))
                            .transition(.opacity.combined(with: .scale(scale: 0.6)))
                        }
                    }

                    // Snap preview ring at the TRUE target point — the display
                    // marker may be nudged for readability, but the player
                    // magnetizes toward and snaps onto this exact spot.
                    if viewModel.isDragging, let hovered = viewModel.hoveredSlotID,
                       let slot = viewModel.puzzle.slot(id: hovered) {
                        SnapPreviewRing(tint: Theme.success)
                            .frame(width: zoneDiameter * 1.15, height: zoneDiameter * 1.15)
                            .position(x: size.width * slot.x, y: size.height * slot.y)
                            .transition(.opacity.combined(with: .scale(scale: 0.7)))
                    }
                }
            }
            .animation(.easeInOut(duration: 0.2), value: viewModel.isDragging)
        }
        .clipShape(.rect(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [Theme.gold.opacity(0.55), Theme.bronzeDeep.opacity(0.45)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1.5
                )
        }
        .shadow(color: .black.opacity(0.55), radius: 14, y: 8)
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
            EvidenceItemView(kind: item.kind, size: token)
                .rotationEffect(.degrees(item.rotation))
                .frame(width: 48, height: 48)
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

/// The field surface. Uses the photoreal night-stadium render when bundled, and falls
/// back to the original painted turf so the puzzle board always works.
struct FieldTurf: View {
    private static let usesRenderedTurf = UIImage(named: "football_field_night") != nil

    var body: some View {
        if Self.usesRenderedTurf {
            renderedTurf
        } else {
            paintedTurf
        }
    }

    /// Photo-real stadium field + chalk markings + broadcast lighting.
    private var renderedTurf: some View {
        Theme.turfDark
            .overlay {
                Image("football_field_night")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .allowsHitTesting(false)
            }
            .overlay { FieldMarkings().allowsHitTesting(false) }
            .overlay {
                // Floodlight from the top fading into a darkened backfield foot.
                LinearGradient(
                    colors: [Color.white.opacity(0.08), .clear, .black.opacity(0.38)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .allowsHitTesting(false)
            }
            .overlay {
                // Darker perimeter edges keep the tactical board premium.
                RadialGradient(colors: [.clear, .black.opacity(0.38)], center: .center, startRadius: 70, endRadius: 420)
                    .allowsHitTesting(false)
            }
            .clipped()
            .accessibilityHidden(true)
    }

    /// Painted fallback: mowing stripes, chalk lines, same markings.
    private var paintedTurf: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height

            let stripes = 12
            for i in 0..<stripes {
                let rect = CGRect(x: 0, y: h * CGFloat(i) / CGFloat(stripes), width: w, height: h / CGFloat(stripes) + 0.5)
                context.fill(Path(rect), with: .color(i.isMultiple(of: 2) ? Theme.turf : Color(hex: 0x28502A)))
            }

            for band in [CGRect(x: 0, y: 0, width: w, height: 5), CGRect(x: 0, y: h - 5, width: w, height: 5)] {
                context.fill(Path(band), with: .color(Theme.chalk.opacity(0.16)))
            }

            for x in [w * 0.025, w * 0.975] {
                var rail = Path()
                rail.move(to: CGPoint(x: x, y: 0))
                rail.addLine(to: CGPoint(x: x, y: h))
                context.stroke(rail, with: .color(Theme.chalk.opacity(0.8)), lineWidth: 2)
            }

            for i in 1...9 {
                let y = h * CGFloat(i) / 10
                var line = Path()
                line.move(to: CGPoint(x: 0, y: y))
                line.addLine(to: CGPoint(x: w, y: y))
                context.stroke(line, with: .color(Theme.chalk.opacity(0.7)), lineWidth: 1.4)

                for hx in [0.36, 0.64] {
                    var tick = Path()
                    tick.move(to: CGPoint(x: w * hx, y: y - 3.5))
                    tick.addLine(to: CGPoint(x: w * hx, y: y + 3.5))
                    context.stroke(tick, with: .color(Theme.chalk.opacity(0.45)), lineWidth: 0.9)
                }

                let yMinor = h * (CGFloat(i) - 0.5) / 10
                var minor = Path()
                minor.move(to: CGPoint(x: 0, y: yMinor))
                minor.addLine(to: CGPoint(x: w, y: yMinor))
                context.stroke(minor, with: .color(Theme.chalk.opacity(0.25)), lineWidth: 0.8)
            }

            FieldMarkings.drawLineOfScrimmage(context: context, width: w, height: h)
            FieldMarkings.drawLabels(context: context, width: w, height: h)

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

/// Chalk markings shared by both turf paths: gold line-of-scrimmage, yard numbers
/// along both sidelines and DEEP / BACKFIELD depth arrows.
struct FieldMarkings: View {
    private let yardLabels = ["40", "45", "50", "45", "40", "35", "30", "25", "20"]

    var body: some View {
        Canvas { context, size in
            Self.drawLineOfScrimmage(context: context, width: size.width, height: size.height)
            Self.drawLabels(context: context, width: size.width, height: size.height)
        }
    }

    static func drawLineOfScrimmage(context: GraphicsContext, width: CGFloat, height: CGFloat) {
        var los = Path()
        los.move(to: CGPoint(x: 0, y: height * 0.52))
        los.addLine(to: CGPoint(x: width, y: height * 0.52))
        context.stroke(los, with: .color(Theme.gold.opacity(0.45)), style: StrokeStyle(lineWidth: 1.2, dash: [6, 4]))
    }

    static func drawLabels(context: GraphicsContext, width: CGFloat, height: CGFloat) {
        let yardLabels = ["40", "45", "50", "45", "40", "35", "30", "25", "20"]
        for (index, label) in yardLabels.enumerated() {
            let y = height * CGFloat(index + 1) / 10
            let text = Text(label)
                .font(.system(size: max(9, width * 0.038), weight: .bold, design: .serif))
                .foregroundColor(Theme.chalk.opacity(0.55))
            context.draw(context.resolve(text), at: CGPoint(x: width * 0.095, y: y))
            context.draw(context.resolve(text), at: CGPoint(x: width * 0.905, y: y))
        }

        // Depth cues: chalk arrows showing that deeper = toward the top
        var upArrow = Path()
        upArrow.move(to: CGPoint(x: width * 0.095, y: height * 0.115))
        upArrow.addLine(to: CGPoint(x: width * 0.095, y: height * 0.075))
        upArrow.move(to: CGPoint(x: width * 0.095, y: height * 0.075))
        upArrow.addLine(to: CGPoint(x: width * 0.075, y: height * 0.095))
        upArrow.move(to: CGPoint(x: width * 0.095, y: height * 0.075))
        upArrow.addLine(to: CGPoint(x: width * 0.115, y: height * 0.095))
        context.stroke(upArrow, with: .color(Theme.chalk.opacity(0.55)), lineWidth: 1.2)
        let deep = Text("DEEP")
            .font(.system(size: max(7, width * 0.028), weight: .bold, design: .monospaced))
            .foregroundColor(Theme.chalk.opacity(0.55))
        context.draw(context.resolve(deep), at: CGPoint(x: width * 0.095, y: height * 0.145))

        var downArrow = Path()
        downArrow.move(to: CGPoint(x: width * 0.095, y: height * 0.855))
        downArrow.addLine(to: CGPoint(x: width * 0.095, y: height * 0.895))
        downArrow.move(to: CGPoint(x: width * 0.095, y: height * 0.895))
        downArrow.addLine(to: CGPoint(x: width * 0.075, y: height * 0.875))
        downArrow.move(to: CGPoint(x: width * 0.095, y: height * 0.895))
        downArrow.addLine(to: CGPoint(x: width * 0.115, y: height * 0.875))
        context.stroke(downArrow, with: .color(Theme.chalk.opacity(0.55)), lineWidth: 1.2)
        let back = Text("BACKFIELD")
            .font(.system(size: max(6, width * 0.024), weight: .bold, design: .monospaced))
            .foregroundColor(Theme.chalk.opacity(0.55))
        context.draw(context.resolve(back), at: CGPoint(x: width * 0.11, y: height * 0.83))
    }
}

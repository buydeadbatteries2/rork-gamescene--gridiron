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
    /// Tutorial: the evidence object the coach is explaining glows softly.
    var highlightedEvidenceID: String? = nil
    /// Tutorial: while dragging, the correct training zone gets a subtle
    /// extra glow (guidance only — the drop still has to be made by hand).
    var guidedSlotID: String? = nil

    private var kits: (user: TeamKit, opponent: TeamKit)? {
        guard let userTeam, let opponent else { return nil }
        return TeamKitResolver.kits(user: userTeam, opponent: opponent)
    }

    /// Painter's order for figures: the user looks up-field from behind the
    /// offense, so offensive players always draw OVER the defense, and within a
    /// side the figure nearer the bottom of the field (closer to the viewer)
    /// draws over the one behind it. Stays well below the inspected-evidence
    /// and placement-zone layers.
    static func figureZIndex(position: FootballPosition, y: Double) -> Double {
        let sideBand: Double = position.side == .offense ? 2 : 1
        return sideBand + min(max(y, 0), 1) * 0.9
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
                        .overlay {
                            if item.id == highlightedEvidenceID {
                                PulsingHalo()
                                    .padding(-6)
                                    .allowsHitTesting(false)
                            }
                        }
                        .position(x: size.width * item.x, y: size.height * item.y)
                }

                ForEach(viewModel.puzzle.visiblePlayers) { player in
                    FootballPlayerView(position: player.position, size: token, kit: kit(for: player.position))
                        .position(x: size.width * player.x, y: size.height * player.y)
                        .zIndex(Self.figureZIndex(position: player.position, y: player.y))
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
                    .zIndex(Self.figureZIndex(position: placed.player.position, y: placed.slot.y))
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
                            .zIndex(4)
                            .transition(.opacity.combined(with: .scale(scale: 0.6)))
                        }
                    }

                    // Tutorial guidance: a soft chalk glow under the correct
                    // training target while the coach lesson is dragging.
                    if viewModel.isDragging, let guided = guidedSlotID,
                       guided != viewModel.hoveredSlotID,
                       let slot = viewModel.puzzle.slot(id: guided) {
                        Circle()
                            .strokeBorder(Theme.chalk.opacity(0.65), lineWidth: 2)
                            .background(Color.white.opacity(0.08), in: .circle)
                            .frame(width: zoneDiameter * 1.25, height: zoneDiameter * 1.25)
                            .position(x: size.width * slot.x, y: size.height * slot.y)
                            .zIndex(4)
                            .transition(.opacity)
                    }

                    // Snap preview ring at the TRUE target point — the display
                    // marker may be nudged for readability, but the player
                    // magnetizes toward and snaps onto this exact spot.
                    if viewModel.isDragging, let hovered = viewModel.hoveredSlotID,
                       let slot = viewModel.puzzle.slot(id: hovered) {
                        SnapPreviewRing(tint: Theme.success)
                            .frame(width: zoneDiameter * 1.15, height: zoneDiameter * 1.15)
                            .position(x: size.width * slot.x, y: size.height * slot.y)
                            .zIndex(4)
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

/// The field surface. Uses the perspective turf render supplied as the game
/// board (with a dark stands strip + sideline crew above the far boundary),
/// and falls back to the original painted turf so the puzzle board always
/// works. The render carries its own painted yard lines, hash marks and
/// numbers, so only the functional lines (first down, scrimmage, depth cues)
/// are drawn over it.
struct FieldTurf: View {
    static let turfAsset = "field_perspective"
    private static let usesRenderedTurf = UIImage(named: turfAsset) != nil

    var body: some View {
        if Self.usesRenderedTurf {
            renderedTurf
        } else {
            paintedTurf
        }
    }

    /// Perspective field filling the board, anchored so the near (bottom)
    /// sideline stays on screen; the far sideline tucks under a narrow
    /// stands-and-crew strip at the top edge.
    private var renderedTurf: some View {
        GeometryReader { proxy in
            let apron = min(max(proxy.size.height * 0.075, 16), 26)
            ZStack(alignment: .top) {
                Theme.turf

                Image(Self.turfAsset)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .offset(y: apron * 0.9)
                    .allowsHitTesting(false)

                SidelineCrewView()
                    .frame(height: apron)

                FieldMarkings(showsYardLines: false)
                    .allowsHitTesting(false)

                LinearGradient(
                    colors: [Color.white.opacity(0.04), .clear, .black.opacity(0.12)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .allowsHitTesting(false)
            }
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

            FieldMarkings.drawYardLines(context: context, width: w, height: h)
            FieldMarkings.drawLineOfScrimmage(context: context, width: w, height: h)
            FieldMarkings.drawLabels(context: context, width: w, height: h, showsNumbers: true)

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

/// Painted markings shared by both turf paths: white yard lines with per-yard
/// hash marks, big faded yard numbers along both sidelines, the yellow
/// first-down line, the blue line of scrimmage and the DEEP / BACKFIELD depth
/// arrows. The perspective turf render already paints its own yard lines,
/// hash marks and numbers, so the rendered path passes `showsYardLines: false`
/// and draws only the functional overlays.
struct FieldMarkings: View {
    /// Normalized field height of the line of scrimmage (offense lines up below it).
    static let scrimmageY: CGFloat = 0.52
    /// Normalized field height of the first-down marker, up-field of the ball.
    static let firstDownY: CGFloat = 0.42

    var showsYardLines = true

    var body: some View {
        Canvas { context, size in
            if showsYardLines {
                Self.drawYardLines(context: context, width: size.width, height: size.height)
            }
            Self.drawLineOfScrimmage(context: context, width: size.width, height: size.height)
            Self.drawLabels(context: context, width: size.width, height: size.height, showsNumbers: showsYardLines)
        }
    }

    /// Sidelines, a yard line every row, hash ticks every yard in the two
    /// inner columns and short ticks along both sidelines.
    static func drawYardLines(context: GraphicsContext, width: CGFloat, height: CGFloat) {
        let paint = Color.white.opacity(0.88)
        let faint = Color.white.opacity(0.62)

        for x in [width * 0.025, width * 0.975] {
            var rail = Path()
            rail.move(to: CGPoint(x: x, y: 0))
            rail.addLine(to: CGPoint(x: x, y: height))
            context.stroke(rail, with: .color(paint), lineWidth: 2.2)
        }

        for i in 1...9 {
            let y = height * CGFloat(i) / 10
            var line = Path()
            line.move(to: CGPoint(x: width * 0.025, y: y))
            line.addLine(to: CGPoint(x: width * 0.975, y: y))
            context.stroke(line, with: .color(paint), lineWidth: 1.8)
        }

        // One hash per yard: inner hash columns plus sideline ticks.
        let tick = max(3, width * 0.012)
        for yard in 1..<50 {
            let y = height * CGFloat(yard) / 50
            guard !yard.isMultiple(of: 5) else { continue }
            var marks = Path()
            for hx in [0.37, 0.63] {
                marks.move(to: CGPoint(x: width * hx - tick, y: y))
                marks.addLine(to: CGPoint(x: width * hx + tick, y: y))
            }
            marks.move(to: CGPoint(x: width * 0.025, y: y))
            marks.addLine(to: CGPoint(x: width * 0.025 + tick, y: y))
            marks.move(to: CGPoint(x: width * 0.975 - tick, y: y))
            marks.addLine(to: CGPoint(x: width * 0.975, y: y))
            context.stroke(marks, with: .color(faint), lineWidth: 1.1)
        }
    }

    /// Blue line of scrimmage with the yellow first-down line up-field of it.
    static func drawLineOfScrimmage(context: GraphicsContext, width: CGFloat, height: CGFloat) {
        var firstDown = Path()
        firstDown.move(to: CGPoint(x: width * 0.025, y: height * firstDownY))
        firstDown.addLine(to: CGPoint(x: width * 0.975, y: height * firstDownY))
        context.stroke(firstDown, with: .color(Color(hex: 0xF5D400).opacity(0.8)), lineWidth: 2.2)

        var los = Path()
        los.move(to: CGPoint(x: width * 0.025, y: height * scrimmageY))
        los.addLine(to: CGPoint(x: width * 0.975, y: height * scrimmageY))
        context.stroke(los, with: .color(Color(hex: 0x2F7BFF).opacity(0.8)), lineWidth: 2.2)
    }

    static func drawLabels(context: GraphicsContext, width: CGFloat, height: CGFloat, showsNumbers: Bool = true) {
        if showsNumbers {
            let yardLabels = ["40", "45", "50", "45", "40", "35", "30", "25", "20"]
            for (index, label) in yardLabels.enumerated() {
                let y = height * CGFloat(index + 1) / 10 + height * 0.05
                let text = Text(label)
                    .font(.system(size: max(14, width * 0.068), weight: .black).width(.condensed))
                    .foregroundColor(Color.white.opacity(0.38))
                context.draw(context.resolve(text), at: CGPoint(x: width * 0.095, y: y))
                context.draw(context.resolve(text), at: CGPoint(x: width * 0.905, y: y))
            }
        }

        // Depth cues: chalk arrows showing that deeper = toward the top
        var upArrow = Path()
        upArrow.move(to: CGPoint(x: width * 0.215, y: height * 0.115))
        upArrow.addLine(to: CGPoint(x: width * 0.215, y: height * 0.075))
        upArrow.move(to: CGPoint(x: width * 0.215, y: height * 0.075))
        upArrow.addLine(to: CGPoint(x: width * 0.195, y: height * 0.095))
        upArrow.move(to: CGPoint(x: width * 0.215, y: height * 0.075))
        upArrow.addLine(to: CGPoint(x: width * 0.235, y: height * 0.095))
        context.stroke(upArrow, with: .color(Color.white.opacity(0.7)), lineWidth: 1.2)
        let deep = Text("DEEP")
            .font(.system(size: max(7, width * 0.028), weight: .bold, design: .monospaced))
            .foregroundColor(Color.white.opacity(0.7))
        context.draw(context.resolve(deep), at: CGPoint(x: width * 0.215, y: height * 0.145))

        var downArrow = Path()
        downArrow.move(to: CGPoint(x: width * 0.215, y: height * 0.855))
        downArrow.addLine(to: CGPoint(x: width * 0.215, y: height * 0.895))
        downArrow.move(to: CGPoint(x: width * 0.215, y: height * 0.895))
        downArrow.addLine(to: CGPoint(x: width * 0.195, y: height * 0.875))
        downArrow.move(to: CGPoint(x: width * 0.215, y: height * 0.895))
        downArrow.addLine(to: CGPoint(x: width * 0.235, y: height * 0.875))
        context.stroke(downArrow, with: .color(Color.white.opacity(0.7)), lineWidth: 1.2)
        let back = Text("BACKFIELD")
            .font(.system(size: max(6, width * 0.024), weight: .bold, design: .monospaced))
            .foregroundColor(Color.white.opacity(0.7))
        context.draw(context.resolve(back), at: CGPoint(x: width * 0.225, y: height * 0.83))
    }
}

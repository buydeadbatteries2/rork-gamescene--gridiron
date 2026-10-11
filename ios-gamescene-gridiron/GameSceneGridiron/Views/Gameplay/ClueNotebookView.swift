import SwiftUI

/// The detective's spiral case notebook with three folder tabs:
/// CLUES (numbered, color-coded, marker-highlighted list — tap a clue to make
/// it the active one), FIELD EVIDENCE (polaroid photos of every object on the
/// field — tap to locate it on the turf) and NOTES (what's been placed, what's
/// still missing, hints spent). The trailing expand button opens the full
/// Case File sheet.
struct ClueNotebookView: View {
    enum Tab: String, CaseIterable, Identifiable {
        case clues = "CLUES"
        case evidence = "FIELD EVIDENCE"
        case notes = "NOTES"

        var id: String { rawValue }

        var symbol: String {
            switch self {
            case .clues: "list.clipboard"
            case .evidence: "magnifyingglass"
            case .notes: "note.text"
            }
        }
    }

    let viewModel: GameViewModel
    let onOpenCaseFile: () -> Void
    /// Tutorial / first-game assist: a soft pulsing gold halo over the CASE FILE button.
    var highlightCaseFile: Bool = false
    /// First-game assist: a subtle glow around the whole notebook.
    var assistPulse: Bool = false

    @State private var tab: Tab = .clues

    private var isLargerText: Bool { TutorialManager.shared.isLargerClueTextEnabled }
    private var isHighContrast: Bool { TutorialManager.shared.isHighContrastCluesEnabled }

    /// Colored clue-number badges, in notebook order (1…6).
    static let clueBadgeColors: [Color] = [
        Color(hex: 0xE2A82E), Color(hex: 0x2F6FBF), Color(hex: 0xC2412F),
        Color(hex: 0x3E8A4A), Color(hex: 0x7A4FB5), Color(hex: 0xE07A1F)
    ]

    static func badgeColor(for index: Int) -> Color {
        clueBadgeColors[((index % clueBadgeColors.count) + clueBadgeColors.count) % clueBadgeColors.count]
    }

    var body: some View {
        VStack(spacing: 0) {
            tabBar

            HStack(alignment: .top, spacing: 0) {
                SpiralBinding()
                    .frame(width: 18)
                    .padding(.vertical, 12)

                Group {
                    switch tab {
                    case .clues: cluesPage
                    case .evidence: evidencePage
                    case .notes: notesPage
                    }
                }
                .padding(.leading, 8)
                .padding(.trailing, 10)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .transition(.opacity)
            }
            .frame(height: isLargerText ? 290 : 240)
            .background {
                PaperSurface(cornerRadius: 0)
                    .overlay { RuledLines().allowsHitTesting(false) }
            }
        }
        .background {
            // Dark binder behind the tabs so the inactive tabs read as folder
            // tabs sitting behind the active page.
            UnevenRoundedRectangle(topLeadingRadius: 8, bottomLeadingRadius: 6, bottomTrailingRadius: 6, topTrailingRadius: 8)
                .fill(Color(hex: 0x1C1712))
                .shadow(color: .black.opacity(0.5), radius: 10, y: 5)
        }
        .overlay {
            if assistPulse {
                PulsingHalo()
                    .allowsHitTesting(false)
            }
        }
        .clipShape(.rect(cornerRadius: 6, style: .continuous))
        .animation(.easeInOut(duration: 0.22), value: tab)
        .animation(.easeInOut(duration: 0.3), value: isLargerText)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Case notebook, \(tab.rawValue.capitalized) tab")
    }

    // MARK: Tabs

    private var tabBar: some View {
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(Tab.allCases) { item in
                let isSelected = tab == item
                Button {
                    guard tab != item else { return }
                    Haptics.tick()
                    AudioManager.shared.play(.buttonPress)
                    tab = item
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: item.symbol)
                            .font(.system(size: 11, weight: .bold))
                        Text(item.rawValue)
                            .font(.system(size: 11, weight: .heavy).width(.condensed))
                            .tracking(1.1)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    .foregroundStyle(isSelected ? Theme.paperInk : Theme.paper.opacity(0.72))
                    .padding(.horizontal, 10)
                    .frame(height: isSelected ? 34 : 30)
                    .frame(maxWidth: .infinity)
                    .background {
                        UnevenRoundedRectangle(topLeadingRadius: 7, topTrailingRadius: 7)
                            .fill(isSelected ? AnyShapeStyle(Theme.paper) : AnyShapeStyle(Color(hex: 0x2B241C)))
                    }
                    .overlay(alignment: .bottom) {
                        if isSelected {
                            Rectangle()
                                .fill(Theme.bronze)
                                .frame(height: 2)
                                .padding(.horizontal, 10)
                                .offset(y: -3)
                        }
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(item.rawValue.capitalized) tab")
                .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            }

            Button(action: onOpenCaseFile) {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.goldLight)
                    .frame(width: 34, height: 30)
                    .background(Color(hex: 0x2B241C), in: UnevenRoundedRectangle(topLeadingRadius: 7, topTrailingRadius: 7))
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open full case file")
            .caseFileHighlight(isActive: highlightCaseFile)
        }
        .padding(.horizontal, 6)
        .padding(.top, 5)
    }

    // MARK: Clues

    private var cluesPage: some View {
        let clues = viewModel.puzzle.clues
        return ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: isLargerText ? 10 : 6) {
                    ForEach(Array(clues.enumerated()), id: \.element.id) { index, clue in
                        clueRow(clue, index: index, isCurrent: index == viewModel.currentClueIndex)
                            .id(clue.id)
                    }
                }
                .padding(.trailing, 2)
            }
            .scrollIndicators(.hidden)
            .onChange(of: viewModel.currentClueIndex) { _, index in
                guard clues.indices.contains(index) else { return }
                withAnimation(.easeOut(duration: 0.25)) {
                    proxy.scrollTo(clues[index].id, anchor: .center)
                }
            }
        }
    }

    private func clueRow(_ clue: PuzzleClue, index: Int, isCurrent: Bool) -> some View {
        let isSolved = viewModel.isClueSolved(clue)
        return Button {
            viewModel.showClue(at: index)
            Haptics.tick()
        } label: {
            HStack(alignment: .top, spacing: 9) {
                ZStack {
                    Circle()
                        .fill(Self.badgeColor(for: index))
                        .frame(width: 22, height: 22)
                        .shadow(color: .black.opacity(0.3), radius: 1, y: 1)
                    Text("\(index + 1)")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                }
                .opacity(isSolved ? 0.5 : 1)

                VStack(alignment: .leading, spacing: 4) {
                    Text(ClueHighlighter.highlighted(clue.text, highContrast: isHighContrast))
                        .font(Theme.typewriter(isLargerText ? 18 : 13.5, relativeTo: .callout))
                        .foregroundStyle(Theme.paperInk.opacity(isSolved ? 0.45 : 1))
                        .lineSpacing(isLargerText ? 4 : 2.5)
                        .strikethrough(isSolved, color: Theme.paperInk.opacity(0.35))
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if let hint = viewModel.usedHint(for: clue), !isSolved {
                        Label {
                            Text(ClueHighlighter.highlighted(hint.text, highContrast: isHighContrast))
                                .font(.system(size: isLargerText ? 14 : 11.5, weight: .medium))
                                .lineSpacing(2)
                                .fixedSize(horizontal: false, vertical: true)
                        } icon: {
                            Image(systemName: "lightbulb.fill")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundStyle(Theme.bronzeDeep)
                    }
                }

                if isSolved {
                    SolvedStamp()
                        .scaleEffect(0.62)
                        .frame(width: 44, height: 18)
                } else {
                    DifficultyPill(difficulty: clue.difficulty, compact: true)
                        .padding(.top, 3)
                }
            }
            .padding(.vertical, 5)
            .padding(.horizontal, 6)
            .background {
                if isCurrent {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Theme.bronze.opacity(0.13))
                        .overlay(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Theme.bronze)
                                .frame(width: 3)
                        }
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Clue \(index + 1): \(clue.text)")
        .accessibilityValue(isSolved ? "Solved" : (isCurrent ? "Active clue" : "Unsolved"))
    }

    // MARK: Field evidence

    private var evidencePage: some View {
        let evidence = viewModel.puzzle.evidence
        return VStack(alignment: .leading, spacing: 6) {
            Text("\(evidence.count) ITEMS LOGGED ON THE FIELD — TAP A PHOTO TO LOCATE IT")
                .font(.system(size: 9, weight: .heavy).width(.condensed))
                .tracking(1.1)
                .foregroundStyle(Theme.paperInkSoft)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(Array(evidence.enumerated()), id: \.element.id) { index, item in
                        let isInspected = viewModel.inspectedEvidenceID == item.id
                        Button {
                            Haptics.tick()
                            viewModel.inspect(item)
                        } label: {
                            EvidencePolaroid(kind: item.kind, isSelected: isInspected)
                                .rotationEffect(.degrees(index.isMultiple(of: 2) ? -2.2 : 1.8))
                        }
                        .buttonStyle(PressableButtonStyle(scale: 0.94))
                        .accessibilityLabel("\(item.kind.title) photo")
                        .accessibilityHint("Locates it on the field")
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 6)
            }
            .scrollIndicators(.hidden)
        }
    }

    // MARK: Notes

    private var notesPage: some View {
        let placed = viewModel.placements
        let missing = viewModel.remainingPlayers
        let hints = viewModel.usedHints
        return ScrollView {
            VStack(alignment: .leading, spacing: 9) {
                if placed.isEmpty && hints.isEmpty {
                    Text("No deductions logged yet. Read the clues, then place the missing players.")
                        .font(Theme.typewriter(12.5, relativeTo: .footnote))
                        .foregroundStyle(Theme.paperInkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if !placed.isEmpty {
                    notesHeader("PLACED", symbol: "checkmark.seal.fill", tint: Theme.easy)
                    ForEach(placed) { placement in
                        noteLine(
                            marker: "✓",
                            markerTint: Theme.easy,
                            text: "\(placement.player.shortName) — \(placement.player.position.rawValue) · \(placement.profile.title.uppercased())"
                        )
                    }
                }

                if !missing.isEmpty {
                    notesHeader("STILL MISSING", symbol: "questionmark.circle", tint: Theme.bronzeDeep)
                    ForEach(missing) { player in
                        noteLine(
                            marker: "□",
                            markerTint: Theme.paperInkSoft,
                            text: "\(player.shortName) — \(player.position.fullName)"
                        )
                    }
                }

                if !hints.isEmpty {
                    notesHeader("HINTS USED", symbol: "lightbulb.fill", tint: Theme.medium)
                    ForEach(hints) { hint in
                        noteLine(marker: "•", markerTint: Theme.bronzeDeep, text: hint.text)
                    }
                }

                HStack(spacing: 14) {
                    Label("\(viewModel.hintsRemaining) HINTS LEFT", systemImage: "lightbulb")
                    Label("\(viewModel.lives) LIVES", systemImage: "heart.fill")
                }
                .font(.system(size: 10, weight: .heavy).width(.condensed))
                .tracking(1)
                .foregroundStyle(Theme.paperInkSoft)
                .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
    }

    private func notesHeader(_ title: String, symbol: String, tint: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(tint)
            Text(title)
                .font(.system(size: 10.5, weight: .heavy).width(.condensed))
                .tracking(1.4)
                .foregroundStyle(Theme.paperInk)
        }
    }

    private func noteLine(marker: String, markerTint: Color, text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 7) {
            Text(marker)
                .font(Theme.typewriterBold(12, relativeTo: .caption))
                .foregroundStyle(markerTint)
                .frame(width: 12)
            Text(text)
                .font(Theme.typewriter(12.5, relativeTo: .footnote))
                .foregroundStyle(Theme.paperInk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: Evidence polaroid

/// Instant-photo card of one evidence object: white frame, turf backdrop,
/// typewritten caption. Used on the FIELD EVIDENCE notebook tab.
struct EvidencePolaroid: View {
    let kind: EvidenceItem.Kind
    var isSelected: Bool = false
    var width: CGFloat = 82

    var body: some View {
        VStack(spacing: 5) {
            ZStack {
                LinearGradient(
                    colors: [Color(hex: 0x3F7A34), Theme.turf, Theme.turfDark],
                    startPoint: .top,
                    endPoint: .bottom
                )
                // Faint yard line so the photo reads as "taken on the field".
                Rectangle()
                    .fill(Theme.chalk.opacity(0.55))
                    .frame(height: 1.5)
                    .offset(y: width * 0.22)
                EvidenceItemView(kind: kind, size: width * 0.42)
            }
            .frame(width: width - 10, height: width - 10)
            .clipShape(.rect(cornerRadius: 1.5))

            Text(kind.title.uppercased())
                .font(Theme.typewriterBold(7.5, relativeTo: .caption2))
                .tracking(0.4)
                .foregroundStyle(Theme.paperInk)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(width: width - 10)
        }
        .padding(.top, 5)
        .padding(.bottom, 6)
        .frame(width: width)
        .background(Color(hex: 0xF4EFE2), in: .rect(cornerRadius: 2))
        .overlay {
            RoundedRectangle(cornerRadius: 2)
                .strokeBorder(isSelected ? Theme.gold : Color.black.opacity(0.15), lineWidth: isSelected ? 2 : 1)
        }
        .shadow(color: .black.opacity(isSelected ? 0.5 : 0.35), radius: isSelected ? 6 : 3, y: 3)
        .accessibilityHidden(true)
    }
}

/// Faint horizontal rule lines, like a lined notebook page.
private struct RuledLines: View {
    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 22
            var y: CGFloat = 36
            while y < size.height {
                var line = Path()
                line.move(to: CGPoint(x: 26, y: y))
                line.addLine(to: CGPoint(x: size.width - 8, y: y))
                context.stroke(line, with: .color(Color(hex: 0x6E8BB0).opacity(0.16)), lineWidth: 0.8)
                y += spacing
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: Highlight helpers

/// Soft pulsing gold halo used by the tutorial and first-game assists.
struct PulsingHalo: View {
    @State private var isPulsing: Bool = false

    var body: some View {
        let motion = Motion.isReduced
        RoundedRectangle(cornerRadius: 8)
            .strokeBorder(Theme.gold.opacity(motion ? 0.75 : (isPulsing ? 0.85 : 0.25)), lineWidth: 2.5)
            .onAppear {
                guard !motion else { return }
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            }
    }
}

extension View {
    /// Pulsing gold ring around the CASE FILE button during the clue-reading lesson.
    @ViewBuilder
    func caseFileHighlight(isActive: Bool) -> some View {
        if isActive {
            self.overlay {
                PulsingHalo()
                    .padding(.horizontal, -5)
                    .padding(.vertical, -3)
                    .allowsHitTesting(false)
            }
        } else {
            self
        }
    }
}

struct DifficultyPill: View {
    let difficulty: ClueDifficulty
    var compact: Bool = false

    private var color: Color {
        switch difficulty {
        case .easy: Theme.easy
        case .medium: Theme.medium
        case .hard: Theme.hard
        }
    }

    var body: some View {
        Text(difficulty.title)
            .font(.system(size: compact ? 9 : 12, weight: .heavy).width(.condensed))
            .tracking(1)
            .foregroundStyle(Color.white.opacity(0.95))
            .padding(.horizontal, compact ? 6 : 10)
            .padding(.vertical, compact ? 2 : 5)
            .frame(minWidth: compact ? 0 : 82)
            .background(color, in: .rect(cornerRadius: 3))
            // High Contrast Clue Highlights: a crisp light rim around the
            // selected clue's difficulty tag.
            .overlay {
                if TutorialManager.shared.isHighContrastCluesEnabled {
                    RoundedRectangle(cornerRadius: 3)
                        .strokeBorder(Theme.chalk.opacity(0.9), lineWidth: 1.2)
                }
            }
            .accessibilityLabel("Difficulty \(difficulty.rawValue)")
    }
}

struct SolvedStamp: View {
    var body: some View {
        Text("SOLVED")
            .font(.system(size: 15, weight: .black).width(.condensed))
            .tracking(2)
            .foregroundStyle(Theme.easy)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .overlay { RoundedRectangle(cornerRadius: 3).strokeBorder(Theme.easy, lineWidth: 2) }
            .rotationEffect(.degrees(-10))
            .opacity(0.85)
            .accessibilityLabel("Solved")
    }
}

struct SpiralBinding: View {
    var body: some View {
        GeometryReader { proxy in
            let count = max(3, Int(proxy.size.height / 18))
            VStack(spacing: 0) {
                ForEach(0..<count, id: \.self) { _ in
                    Spacer(minLength: 0)
                    Circle()
                        .fill(Theme.ink)
                        .frame(width: 7, height: 7)
                        .overlay(alignment: .leading) {
                            Capsule()
                                .fill(LinearGradient(colors: [Theme.silver, Color(hex: 0x6B6F73)], startPoint: .top, endPoint: .bottom))
                                .frame(width: 12, height: 3)
                                .offset(x: -8)
                        }
                    Spacer(minLength: 0)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .accessibilityHidden(true)
    }
}

/// Faint X/O chalk play diagram.
struct ChalkDiagram: View {
    var body: some View {
        Canvas { context, size in
            let ink = GraphicsContext.Shading.color(Theme.paperInk)
            for (i, x) in [0.15, 0.4, 0.65].enumerated() {
                let c = CGPoint(x: size.width * x, y: size.height * (i == 1 ? 0.7 : 0.78))
                context.stroke(Path(ellipseIn: CGRect(x: c.x - 4, y: c.y - 4, width: 8, height: 8)), with: ink, lineWidth: 1.2)
            }
            for x in [0.3, 0.75] {
                let c = CGPoint(x: size.width * x, y: size.height * 0.25)
                var p = Path()
                p.move(to: CGPoint(x: c.x - 4, y: c.y - 4)); p.addLine(to: CGPoint(x: c.x + 4, y: c.y + 4))
                p.move(to: CGPoint(x: c.x + 4, y: c.y - 4)); p.addLine(to: CGPoint(x: c.x - 4, y: c.y + 4))
                context.stroke(p, with: ink, lineWidth: 1.2)
            }
            var arrow = Path()
            arrow.move(to: CGPoint(x: size.width * 0.4, y: size.height * 0.6))
            arrow.addQuadCurve(to: CGPoint(x: size.width * 0.92, y: size.height * 0.1), control: CGPoint(x: size.width * 0.9, y: size.height * 0.7))
            context.stroke(arrow, with: ink, style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
        }
        .accessibilityHidden(true)
    }
}

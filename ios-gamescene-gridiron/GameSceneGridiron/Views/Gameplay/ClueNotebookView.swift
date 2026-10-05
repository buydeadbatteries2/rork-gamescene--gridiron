import SwiftUI

/// Premium football investigation playbook: a spiral-bound manila card with
/// three tabs — CLUES (numbered, color-coded entries with marker-highlighted
/// copy), FIELD EVIDENCE (polaroid snapshot cards of the case objects) and
/// NOTES (case brief + spent hints). One clue at a time; swipe or tap arrows
/// to page. Tap CASE FILE for the full sheet.
struct ClueNotebookView: View {
    let viewModel: GameViewModel
    let onOpenCaseFile: () -> Void

    @State private var tab: PlaybookTab = .clues

    enum PlaybookTab: CaseIterable, Identifiable {
        case clues, evidence, notes

        var id: Self { self }

        var title: String {
            switch self {
            case .clues: "CLUES"
            case .evidence: "FIELD EVIDENCE"
            case .notes: "NOTES"
            }
        }

        var icon: String {
            switch self {
            case .clues: "list.number"
            case .evidence: "magnifyingglass"
            case .notes: "doc.text"
            }
        }

        var accessibilityLabel: String {
            switch self {
            case .clues: "Clues"
            case .evidence: "Field evidence"
            case .notes: "Case notes"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            tabBar
            Rectangle().fill(Theme.paperInk.opacity(0.3)).frame(height: 1)
            HStack(alignment: .top, spacing: 0) {
                SpiralBinding()
                    .frame(width: 15)
                    .padding(.vertical, 10)

                Group {
                    switch tab {
                    case .clues: cluesTab
                    case .evidence: evidenceTab
                    case .notes: notesTab
                    }
                }
                .padding(.leading, 8)
                .padding(.trailing, 12)
                .padding(.vertical, 9)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .frame(height: 178)
        .paperCard(cornerRadius: 6)
        .overlay(alignment: .bottomTrailing) {
            ChalkDiagram()
                .frame(width: 58, height: 40)
                .padding(10)
                .opacity(0.16)
                .allowsHitTesting(false)
        }
        .overlay {
            // Manila paper grain for a physical notebook feel.
            Image("manila_paper_texture")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .opacity(0.14)
                .blendMode(.multiply)
                .allowsHitTesting(false)
        }
        .clipShape(.rect(cornerRadius: 6, style: .continuous))
        .shadow(color: .black.opacity(0.5), radius: 10, y: 5)
        .animation(.easeOut(duration: 0.2), value: tab)
        .animation(.easeOut(duration: 0.22), value: viewModel.currentClueIndex)
        // Swipe pages clues; on other tabs the gesture steps aside so the
        // evidence filmstrip scrolls freely.
        .gesture(pageSwipe, including: tab == .clues ? .all : .subviews)
    }

    // MARK: Tab bar

    private var tabBar: some View {
        HStack(spacing: 6) {
            ForEach(PlaybookTab.allCases) { playbookTab($0) }

            Spacer(minLength: 6)

            Button(action: onOpenCaseFile) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 9, weight: .bold))
                    Text("CASE FILE")
                        .font(Theme.typewriterBold(11, relativeTo: .caption2))
                        .tracking(1)
                }
                .foregroundStyle(Theme.paperInk)
                .frame(height: 27)
                .padding(.horizontal, 9)
                .background(Theme.paperDark.opacity(0.55), in: .rect(cornerRadius: 6))
                .overlay {
                    RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.paperInk.opacity(0.25), lineWidth: 1)
                }
            }
            .buttonStyle(PressableButtonStyle(scale: 0.95))
            .accessibilityLabel("Open full case file")
        }
        .padding(.leading, 12)
        .padding(.trailing, 10)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }

    private func playbookTab(_ tab: PlaybookTab) -> some View {
        let isActive = self.tab == tab
        return Button {
            Haptics.tick()
            self.tab = tab
        } label: {
            HStack(spacing: 5) {
                Image(systemName: tab.icon)
                    .font(.system(size: 10.5, weight: .heavy))
                Text(tab.title)
                    .font(.system(size: 11.5, weight: .heavy).width(.condensed))
                    .tracking(0.8)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(isActive ? Theme.paperInk : Color.white.opacity(0.6))
            .frame(height: 27)
            .padding(.horizontal, 10)
            .background {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isActive ? AnyShapeStyle(Theme.paper) : AnyShapeStyle(Color(hex: 0x1A1510).opacity(0.85)))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(isActive ? Theme.paperInk.opacity(0.35) : Color.white.opacity(0.1), lineWidth: 1)
            }
            .shadow(color: .black.opacity(isActive ? 0.3 : 0.15), radius: 2, y: 1)
        }
        .buttonStyle(PressableButtonStyle(scale: 0.95))
        .accessibilityLabel(tab.accessibilityLabel)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    // MARK: Clues tab

    private var cluesTab: some View {
        Group {
            if let clue = viewModel.currentClue {
                HStack(alignment: .top, spacing: 9) {
                    ClueNumberChip(number: clue.id, size: 26)
                        .padding(.top, 1)

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 4) {
                            DifficultyPill(difficulty: clue.difficulty, compact: true)
                            Spacer(minLength: 4)
                            Button { viewModel.previousClue(); Haptics.tick() } label: {
                                Image(systemName: "chevron.left").frame(width: 26, height: 26).contentShape(.rect)
                            }
                            .accessibilityLabel("Previous clue")

                            Text("\(viewModel.currentClueIndex + 1)/\(viewModel.puzzle.clues.count)")
                                .font(Theme.typewriter(12, relativeTo: .caption))
                                .monospacedDigit()

                            Button { viewModel.nextClue(); Haptics.tick() } label: {
                                Image(systemName: "chevron.right").frame(width: 26, height: 26).contentShape(.rect)
                            }
                            .accessibilityLabel("Next clue")
                        }
                        .foregroundStyle(Theme.paperInk)

                        Text(ClueHighlighter.highlighted(clue.text))
                            .font(Theme.typewriter(14, relativeTo: .callout))
                            .foregroundStyle(Theme.paperInk.opacity(viewModel.isClueSolved(clue) ? 0.45 : 1))
                            .lineSpacing(3)
                            .minimumScaleFactor(0.62)
                            .frame(maxWidth: .infinity, alignment: .topLeading)

                        if let hint = viewModel.usedHint(for: clue), !viewModel.isClueSolved(clue) {
                            Label {
                                Text(ClueHighlighter.highlighted(hint.text))
                                    .font(.system(size: 11.5, weight: .medium))
                                    .lineSpacing(2)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.8)
                            } icon: {
                                Image(systemName: "lightbulb.fill")
                                    .font(.system(size: 10, weight: .bold))
                            }
                            .foregroundStyle(Theme.bronzeDeep)
                        }
                    }
                }
                .id(viewModel.currentClueIndex)
                .transition(.asymmetric(insertion: .opacity.combined(with: .offset(x: 16)), removal: .opacity))
                .overlay(alignment: .bottomTrailing) {
                    if viewModel.isClueSolved(clue) {
                        SolvedStamp().padding(.trailing, 2)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: Evidence tab

    private var evidenceTab: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 9) {
                ForEach(Array(viewModel.puzzle.evidence.enumerated()), id: \.element.id) { index, item in
                    Button {
                        Haptics.tick()
                        viewModel.inspect(item)
                    } label: {
                        EvidenceSnapshotCard(item: item, tilt: index.isMultiple(of: 2) ? -2.4 : 1.8)
                    }
                    .buttonStyle(PressableButtonStyle(scale: 0.94))
                    .accessibilityLabel("Evidence: \(item.kind.title)")
                }
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Notes tab

    private var notesTab: some View {
        let puzzle = viewModel.puzzle
        let solvedCount = puzzle.clues.filter { viewModel.isClueSolved($0) }.count
        return VStack(alignment: .leading, spacing: 5) {
            Text(puzzle.title)
                .font(Theme.typewriterBold(15, relativeTo: .headline))
                .foregroundStyle(Theme.paperInk)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(puzzle.introHeading.uppercased())
                .font(.system(size: 9.5, weight: .heavy).width(.condensed))
                .tracking(1.4)
                .foregroundStyle(Theme.bronze)

            Text(puzzle.introBody)
                .font(Theme.typewriter(11.5, relativeTo: .footnote))
                .foregroundStyle(Theme.paperInkSoft)
                .lineSpacing(2)
                .lineLimit(3)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 2)

            HStack(spacing: 10) {
                Label("\(solvedCount) OF \(puzzle.clues.count) CONFIRMED", systemImage: "checkmark.seal.fill")
                    .font(.system(size: 10, weight: .heavy).width(.condensed))
                    .tracking(0.8)
                    .foregroundStyle(Theme.easy)
                Spacer()
                Label("\(viewModel.hintsRemaining) HINTS LEFT", systemImage: "lightbulb.fill")
                    .font(.system(size: 10, weight: .heavy).width(.condensed))
                    .tracking(0.8)
                    .foregroundStyle(Theme.caution)
            }

            ForEach(viewModel.usedHints.prefix(2)) { hint in
                HStack(alignment: .top, spacing: 5) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(Theme.caution)
                    Text(hint.text)
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.paperInkSoft)
                        .lineLimit(1)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: Paging

    private var pageSwipe: some Gesture {
        DragGesture(minimumDistance: 24)
            .onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                Haptics.tick()
                if value.translation.width < 0 { viewModel.nextClue() } else { viewModel.previousClue() }
            }
    }
}

// MARK: - Clue number chip

/// Color-coded numbered clue chip cycling through the playbook palette.
struct ClueNumberChip: View {
    let number: Int
    var size: CGFloat = 26

    private var color: Color { Theme.clueChipColor(number) }

    var body: some View {
        Text("\(number)")
            .font(.system(size: size * 0.52, weight: .black).width(.condensed))
            .foregroundStyle(Color.white)
            .frame(width: size, height: size)
            .background {
                Circle().fill(
                    LinearGradient(
                        colors: [color.lightened(0.15), color.darkened(0.15)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
            .overlay { Circle().strokeBorder(Color.white.opacity(0.4), lineWidth: 1) }
            .shadow(color: color.opacity(0.5), radius: 3, y: 1)
            .accessibilityLabel("Clue \(number)")
    }
}

// MARK: - Evidence snapshot card

/// Polaroid-style evidence snapshot for the playbook's evidence tab.
struct EvidenceSnapshotCard: View {
    let item: EvidenceItem
    var tilt: CGFloat = 0

    var body: some View {
        VStack(spacing: 3) {
            Color(hex: 0xEFE8D5)
                .frame(width: 62, height: 44)
                .overlay {
                    EvidenceItemView(kind: item.kind, size: 22)
                        .allowsHitTesting(false)
                }
                .overlay(alignment: .bottom) {
                    LinearGradient(colors: [.clear, .black.opacity(0.1)], startPoint: .top, endPoint: .bottom)
                        .frame(height: 10)
                        .allowsHitTesting(false)
                }
                .overlay {
                    Rectangle().strokeBorder(Theme.paperInk.opacity(0.18), lineWidth: 0.7)
                }

            Text(item.kind.title.uppercased())
                .font(Theme.typewriterBold(7.5, relativeTo: .caption2))
                .tracking(0.4)
                .foregroundStyle(Theme.paperInk)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, 3)
                .padding(.bottom, 2)
        }
        .frame(width: 72)
        .background(Color(hex: 0xF6F1E3), in: .rect(cornerRadius: 3))
        .overlay {
            RoundedRectangle(cornerRadius: 3).strokeBorder(Theme.paperInk.opacity(0.22), lineWidth: 0.8)
        }
        .rotationEffect(.degrees(tilt))
        .shadow(color: .black.opacity(0.32), radius: 3, y: 2)
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

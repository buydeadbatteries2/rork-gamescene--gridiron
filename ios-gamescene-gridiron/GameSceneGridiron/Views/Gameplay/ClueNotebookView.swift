import SwiftUI

/// Spiral-bound case-file card showing one clue at a time, styled like the physical
/// football detective notebook: manila texture, generous margins, marker-highlighted
/// clue copy. Swipe or tap arrows to page.
struct ClueNotebookView: View {
    let viewModel: GameViewModel
    let onOpenCaseFile: () -> Void
    /// Tutorial / first-game assist: a soft pulsing gold halo over the CASE FILE button.
    var highlightCaseFile: Bool = false
    /// First-game assist: a subtle glow around the whole notebook.
    var assistPulse: Bool = false

    private var isLargerText: Bool { TutorialManager.shared.isLargerClueTextEnabled }
    private var isHighContrast: Bool { TutorialManager.shared.isHighContrastCluesEnabled }

    var body: some View {
        let clues = viewModel.puzzle.clues
        let clue = viewModel.currentClue

        HStack(alignment: .top, spacing: 0) {
            SpiralBinding()
                .frame(width: 18)
                .padding(.vertical, 12)

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Button(action: onOpenCaseFile) {
                        HStack(spacing: 5) {
                            Text("CASE FILE")
                                .font(Theme.typewriterBold(14, relativeTo: .caption))
                                .tracking(1.4)
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .foregroundStyle(Theme.paperInk)
                        .frame(minHeight: 30)
                        .contentShape(.rect)
                    }
                    .accessibilityLabel("Open full case file")
                    .caseFileHighlight(isActive: highlightCaseFile)

                    if let clue {
                        DifficultyPill(difficulty: clue.difficulty, compact: true)
                    }

                    Spacer(minLength: 4)

                    Button { viewModel.previousClue(); Haptics.tick() } label: {
                        Image(systemName: "chevron.left").frame(width: 30, height: 30).contentShape(.rect)
                    }
                    .accessibilityLabel("Previous clue")

                    Text("\(viewModel.currentClueIndex + 1)/\(clues.count)")
                        .font(Theme.typewriter(13, relativeTo: .caption))
                        .monospacedDigit()
                        .foregroundStyle(isHighContrast ? Theme.paperInk : Theme.paperInk.opacity(0.85))

                    Button { viewModel.nextClue(); Haptics.tick() } label: {
                        Image(systemName: "chevron.right").frame(width: 30, height: 30).contentShape(.rect)
                    }
                    .accessibilityLabel("Next clue")
                }
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.paperInk)

                // Case-file rule: short bronze accent over the full divider
                ZStack(alignment: .leading) {
                    Rectangle().fill(Theme.paperInk.opacity(0.3)).frame(height: 1)
                    Rectangle().fill(Theme.bronze).frame(width: 30, height: 2)
                }

                if let clue {
                    // Larger Clue Text: the clue area scrolls vertically if the
                    // copy needs more room — content is never clipped.
                    if isLargerText {
                        ScrollView {
                            clueBody(clue)
                                .id(clue.id)
                        }
                        .scrollIndicators(.hidden)
                    } else {
                        clueBody(clue)
                            .id(clue.id)
                            .transition(clueTransition)
                    }
                }
            }
            .padding(.leading, 10)
            .padding(.trailing, 14)
            .padding(.vertical, 10)
        }
        .frame(height: isLargerText ? 210 : 162)
        .paperCard(cornerRadius: 6)
        .overlay {
            if assistPulse {
                PulsingHalo()
                    .allowsHitTesting(false)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            ChalkDiagram()
                .frame(width: 58, height: 40)
                .padding(10)
                .opacity(0.22)
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
        .animation(.easeOut(duration: 0.22), value: viewModel.currentClueIndex)
        .animation(.easeInOut(duration: 0.3), value: isLargerText)
        .gesture(
            DragGesture(minimumDistance: 24)
                .onEnded { value in
                    guard abs(value.translation.width) > abs(value.translation.height) else { return }
                    Haptics.tick()
                    if value.translation.width < 0 { viewModel.nextClue() } else { viewModel.previousClue() }
                }
        )
    }

    private var clueTransition: AnyTransition {
        Motion.isReduced ? .opacity : .asymmetric(insertion: .opacity.combined(with: .offset(x: 16)), removal: .opacity)
    }

    @ViewBuilder
    private func clueBody(_ clue: PuzzleClue) -> some View {
        let isSolved = viewModel.isClueSolved(clue)
        VStack(alignment: .leading, spacing: 7) {
            Text(ClueHighlighter.highlighted(clue.text, highContrast: isHighContrast))
                .font(Theme.typewriter(isLargerText ? 21 : 15.5, relativeTo: .callout))
                .foregroundStyle(Theme.paperInk.opacity(isSolved ? 0.45 : 1))
                .lineSpacing(isLargerText ? 5 : 3.5)
                // Larger Clue Text never shrinks or clips — without it, the
                // graceful minimum-scale fallback still applies.
                .minimumScaleFactor(isLargerText ? 1 : 0.68)
                .fixedSize(horizontal: false, vertical: isLargerText)
                .frame(maxWidth: .infinity, alignment: .topLeading)

            if let hint = viewModel.usedHint(for: clue), !isSolved {
                Label {
                    Text(ClueHighlighter.highlighted(hint.text, highContrast: isHighContrast))
                        .font(.system(size: isLargerText ? 15 : 12, weight: .medium))
                        .lineSpacing(2)
                        .lineLimit(isLargerText ? nil : 3)
                        .minimumScaleFactor(0.8)
                } icon: {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundStyle(Theme.bronzeDeep)
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .overlay(alignment: .bottomTrailing) {
            if isSolved { SolvedStamp().padding(.trailing, 4) }
        }
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

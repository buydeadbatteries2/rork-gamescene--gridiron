import SwiftUI

/// Spiral-bound case-file card showing one clue at a time. Swipe or tap arrows to page.
struct ClueNotebookView: View {
    let viewModel: GameViewModel
    let onOpenCaseFile: () -> Void

    var body: some View {
        let clues = viewModel.puzzle.clues
        let clue = viewModel.currentClue

        HStack(alignment: .top, spacing: 0) {
            SpiralBinding()
                .frame(width: 16)
                .padding(.vertical, 10)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Button(action: onOpenCaseFile) {
                        HStack(spacing: 5) {
                            Text("CASE FILE")
                                .font(Theme.typewriterBold(13, relativeTo: .caption))
                                .tracking(1.2)
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .foregroundStyle(Theme.paperInk)
                        .frame(minHeight: 28)
                        .contentShape(.rect)
                    }
                    .accessibilityLabel("Open full case file")

                    if let clue {
                        DifficultyPill(difficulty: clue.difficulty, compact: true)
                    }

                    Spacer(minLength: 4)

                    Button { viewModel.previousClue(); Haptics.tick() } label: {
                        Image(systemName: "chevron.left").frame(width: 30, height: 28).contentShape(.rect)
                    }
                    .accessibilityLabel("Previous clue")

                    Text("\(viewModel.currentClueIndex + 1)/\(clues.count)")
                        .font(Theme.typewriter(13, relativeTo: .caption))
                        .monospacedDigit()

                    Button { viewModel.nextClue(); Haptics.tick() } label: {
                        Image(systemName: "chevron.right").frame(width: 30, height: 28).contentShape(.rect)
                    }
                    .accessibilityLabel("Next clue")
                }
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.paperInk)

                Rectangle().fill(Theme.paperInk.opacity(0.3)).frame(height: 1)

                if let clue {
                    let isSolved = viewModel.isClueSolved(clue)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(clue.text)
                            .font(Theme.typewriter(14.5, relativeTo: .callout))
                            .foregroundStyle(Theme.paperInk.opacity(isSolved ? 0.45 : 1))
                            .lineSpacing(2)
                            .minimumScaleFactor(0.72)
                            .frame(maxWidth: .infinity, alignment: .topLeading)

                        if let hint = viewModel.usedHint(for: clue), !isSolved {
                            Label(hint.text, systemImage: "lightbulb.fill")
                                .font(.system(size: 11.5, weight: .medium))
                                .foregroundStyle(Theme.bronzeDeep)
                                .lineLimit(2)
                                .minimumScaleFactor(0.8)
                        }
                    }
                    .frame(maxHeight: .infinity, alignment: .top)
                    .overlay(alignment: .bottomTrailing) {
                        if isSolved { SolvedStamp().padding(.trailing, 4) }
                    }
                    .id(clue.id)
                    .transition(.asymmetric(insertion: .opacity.combined(with: .offset(x: 16)), removal: .opacity))
                }
            }
            .padding(.leading, 8)
            .padding(.trailing, 12)
            .padding(.vertical, 8)
        }
        .frame(height: 138)
        .paperCard(cornerRadius: 4)
        .overlay(alignment: .bottomTrailing) {
            ChalkDiagram()
                .frame(width: 58, height: 40)
                .padding(10)
                .opacity(0.25)
                .allowsHitTesting(false)
        }
        .animation(.easeOut(duration: 0.22), value: viewModel.currentClueIndex)
        .gesture(
            DragGesture(minimumDistance: 24)
                .onEnded { value in
                    guard abs(value.translation.width) > abs(value.translation.height) else { return }
                    Haptics.tick()
                    if value.translation.width < 0 { viewModel.nextClue() } else { viewModel.previousClue() }
                }
        )
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

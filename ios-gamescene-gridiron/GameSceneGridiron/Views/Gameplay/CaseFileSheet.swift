import SwiftUI

/// Full case file: all six clues, solved state, used hints and remaining hint count.
struct CaseFileSheet: View {
    let viewModel: GameViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header

                Rectangle().fill(Theme.paperInk.opacity(0.35)).frame(height: 1)

                ForEach(Array(viewModel.puzzle.clues.enumerated()), id: \.element.id) { index, clue in
                    Button {
                        viewModel.showClue(at: index)
                        Haptics.tick()
                        dismiss()
                    } label: {
                        ClueRow(clue: clue, isSolved: viewModel.isClueSolved(clue))
                    }
                    .buttonStyle(PressableButtonStyle(scale: 0.98))
                }

                if !viewModel.usedHints.isEmpty {
                    Text("USED HINTS")
                        .font(.system(size: 13, weight: .heavy).width(.condensed))
                        .tracking(1.5)
                        .foregroundStyle(Theme.paperInkSoft)
                        .padding(.top, 6)
                    ForEach(viewModel.usedHints) { hint in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "lightbulb.fill").foregroundStyle(Theme.caution)
                            Text(hint.text)
                                .font(.system(size: 14))
                                .foregroundStyle(Color.white.opacity(0.9))
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(hint.date, format: .dateTime.hour().minute())
                                .font(.system(size: 11))
                                .foregroundStyle(Color.white.opacity(0.5))
                        }
                        .padding(12)
                        .background(Color(hex: 0x2A231A).opacity(0.92), in: .rect(cornerRadius: 8))
                    }
                }

                HStack {
                    Text("EVIDENCE")
                        .font(.system(size: 14, weight: .black).width(.condensed))
                        .tracking(2)
                        .foregroundStyle(Theme.danger)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .overlay { RoundedRectangle(cornerRadius: 3).strokeBorder(Theme.danger, lineWidth: 2) }
                        .rotationEffect(.degrees(-8))
                    Spacer()
                    Text("Hints remaining: \(viewModel.hintsRemaining)")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.paperInk)
                }
                .padding(.top, 10)
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 30)
        }
        .scrollIndicators(.hidden)
        .background {
            PaperSurface(cornerRadius: 0, darkness: 0.05)
                .ignoresSafeArea()
        }
        .overlay(alignment: .topLeading) {
            CautionTape(stripeWidth: 7)
                .frame(width: 110, height: 16)
                .rotationEffect(.degrees(-35))
                .offset(x: -30, y: 14)
                .allowsHitTesting(false)
        }
        .presentationDetents([.large, .medium])
        .presentationDragIndicator(.visible)
        .presentationContentInteraction(.scrolls)
        .presentationCornerRadius(22)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("CASE FILE — \(viewModel.puzzle.quarterLabel)")
                    .font(Theme.typewriterBold(28, relativeTo: .title))
                    .foregroundStyle(Theme.paperInk)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                Text("SIX CLUES. ONE TRUTH.")
                    .font(Theme.typewriter(13, relativeTo: .caption))
                    .tracking(1.5)
                    .foregroundStyle(Theme.paperInkSoft)
            }
            Spacer()
            StickyNote(text: "PLAYS\nHIDE\nTHE TRUTH", rotation: 6, width: 76)
        }
        .padding(.top, 8)
    }
}

private struct ClueRow: View {
    let clue: PuzzleClue
    let isSolved: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text("\(clue.id).")
                .font(Theme.typewriterBold(22, relativeTo: .title3))
                .foregroundStyle(Theme.paperInk)
                .frame(width: 30, alignment: .leading)
            VStack(alignment: .leading, spacing: 6) {
                DifficultyPill(difficulty: clue.difficulty, compact: true)
                Text(clue.text)
                    .font(.system(size: 14.5, weight: .medium))
                    .foregroundStyle(Theme.paperInk.opacity(isSolved ? 0.5 : 1))
                    .multilineTextAlignment(.leading)
                    .strikethrough(isSolved, color: Theme.paperInk.opacity(0.4))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if isSolved {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(Theme.easy)
            }
        }
        .padding(12)
        .background {
            PaperSurface(cornerRadius: 6, darkness: 0.06)
                .shadow(color: .black.opacity(0.28), radius: 4, y: 3)
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(isSolved ? "Solved" : "Unsolved")
    }
}

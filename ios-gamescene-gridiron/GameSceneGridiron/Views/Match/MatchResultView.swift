import SwiftUI

/// Premium final verdict for the whole game: heading, quarter-by-quarter results,
/// score line and the lightweight match statistics. Offers Play Again / Home.
struct MatchResultView: View {
    let matchViewModel: MatchViewModel
    let onPlayAgain: () -> Void
    let onHome: () -> Void

    @State private var stampIn: Bool = false
    @State private var detailsIn: Bool = false

    private var match: GameMatch { matchViewModel.match }
    private var result: MatchResult { match.result ?? .defeat }

    var body: some View {
        ZStack {
            DeskBackground()
            if !result.isWin {
                Color.black.opacity(0.35).ignoresSafeArea()
            }

            ScrollView {
                VStack(spacing: 22) {
                    GSLogoView(scale: 0.8)
                        .padding(.top, 8)

                    heading
                        .scaleEffect(stampIn ? 1 : 1.9)
                        .opacity(stampIn ? 1 : 0)
                        .rotationEffect(.degrees(stampIn ? -2 : -9))

                    scoreLine
                        .opacity(detailsIn ? 1 : 0)

                    resultsCard
                        .opacity(detailsIn ? 1 : 0)
                        .offset(y: detailsIn ? 0 : 22)

                    statsCard
                        .opacity(detailsIn ? 1 : 0)
                        .offset(y: detailsIn ? 0 : 22)

                    buttons
                        .opacity(detailsIn ? 1 : 0)
                        .padding(.bottom, 30)
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .onAppear {
            Haptics.tick()
            AudioManager.shared.play(result.isWin ? .caseSolved : .quarterLost)
            withAnimation(.spring(response: 0.42, dampingFraction: 0.55).delay(0.15)) { stampIn = true }
            withAnimation(.spring(response: 0.7, dampingFraction: 0.85).delay(0.5)) { detailsIn = true }
        }
        .sensoryFeedback(result.isWin ? .success : .warning, trigger: stampIn)
    }

    // MARK: Heading

    private var heading: some View {
        VStack(spacing: 6) {
            Text(result.heading)
                .font(.system(size: 38, weight: .black).width(.compressed))
                .foregroundStyle(result.isWin ? AnyShapeStyle(Theme.goldGradient) : AnyShapeStyle(Theme.danger))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            HStack(spacing: 10) {
                Rectangle().fill(Theme.gold.opacity(0.7)).frame(width: 28, height: 2)
                Text(result.isWin ? "THE INVESTIGATION IS OVER" : "THE CASE GOES UNRESOLVED")
                    .font(.system(size: 15, weight: .heavy).width(.compressed))
                    .tracking(2)
                    .foregroundStyle(Theme.goldLight)
                Rectangle().fill(Theme.gold.opacity(0.7)).frame(width: 28, height: 2)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(Color.black.opacity(0.7), in: .rect(cornerRadius: 4))
        .overlay {
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(result.isWin ? AnyShapeStyle(Theme.goldGradient) : AnyShapeStyle(Theme.danger), lineWidth: 3)
                .padding(4)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    // MARK: Score

    private var scoreLine: some View {
        VStack(spacing: 2) {
            Text("RESULT")
                .font(.system(size: 11, weight: .heavy).width(.condensed))
                .tracking(2)
                .foregroundStyle(Theme.paperInkSoft)
            Text(match.scoreLine ?? "")
                .font(.system(size: 52, weight: .black).width(.compressed))
                .foregroundStyle(Theme.paperInk)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Final result \(match.scoreLine ?? "")")
    }

    // MARK: Quarter results

    private var resultsCard: some View {
        VStack(spacing: 14) {
            Text("QUARTER RESULTS")
                .font(.system(size: 11, weight: .heavy).width(.condensed))
                .tracking(2)
                .foregroundStyle(Theme.paperInkSoft)

            HStack(spacing: 10) {
                ForEach(match.quarterRecords) { record in
                    resultChip(record)
                }
                if let overtime = match.overtimeRecord {
                    resultChip(overtime)
                }
            }

            QuarterProgressTrack(match: match)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .paperCard(cornerRadius: 6)
        .overlay(alignment: .top) { PushPin().offset(y: -9) }
        .padding(.top, 9)
    }

    private func resultChip(_ record: QuarterRecord) -> some View {
        VStack(spacing: 5) {
            Image(systemName: record.outcome == .solved ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(record.outcome == .solved ? Theme.easy : Theme.danger)
                .contentTransition(.symbolEffect(.replace))
            Text(record.label)
                .font(.system(size: 12, weight: .heavy).width(.condensed))
                .tracking(0.8)
                .foregroundStyle(Theme.paperInk)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 66)
        .background {
            RoundedRectangle(cornerRadius: 6)
                .fill((record.outcome == .solved ? Theme.easy : Theme.danger).opacity(0.12))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder((record.outcome == .solved ? Theme.easy : Theme.danger).opacity(0.4), lineWidth: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(record.label): \(record.outcome == .solved ? "solved" : "failed")")
    }

    // MARK: Statistics

    private var statsCard: some View {
        VStack(spacing: 4) {
            Text("CASE NOTES")
                .font(.system(size: 11, weight: .heavy).width(.condensed))
                .tracking(2)
                .foregroundStyle(Theme.paperInkSoft)
                .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(statRows, id: \.label) { row in
                HStack {
                    Text(row.label)
                        .font(Theme.typewriter(14, relativeTo: .subheadline))
                        .foregroundStyle(Theme.paperInk)
                    Spacer()
                    Text("\(row.value)")
                        .font(.system(size: 17, weight: .heavy).width(.condensed))
                        .monospacedDigit()
                        .foregroundStyle(row.tint ?? Theme.goldLight)
                }
                .padding(.vertical, 7)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(Theme.paperInk.opacity(0.12)).frame(height: 1)
                }
            }
        }
        .padding(16)
        .paperCard(cornerRadius: 6)
        .rotationEffect(.degrees(-0.5))
    }

    private struct StatRow {
        let label: String
        let value: Int
        let tint: Color?
    }

    private var statRows: [StatRow] {
        [
            StatRow(label: "Quarters solved", value: match.quartersSolved, tint: Theme.easy),
            StatRow(label: "Quarters failed", value: match.quartersFailed, tint: Theme.danger),
            StatRow(label: "Correct placements", value: match.totalCorrectPlacements, tint: nil),
            StatRow(label: "Incorrect placements", value: match.totalWrongPlacements, tint: nil),
            StatRow(label: "Lives lost", value: match.totalLivesLost, tint: nil),
            StatRow(label: "Hints used", value: match.totalHintsUsed, tint: nil)
        ]
    }

    // MARK: Actions

    private var buttons: some View {
        VStack(spacing: 12) {
            Button {
                Haptics.pickUp()
                onPlayAgain()
            } label: {
                HStack {
                    Spacer()
                    Text("PLAY AGAIN")
                    Spacer()
                    Image(systemName: "arrow.counterclockwise").font(.system(size: 15, weight: .bold))
                }
                .padding(.horizontal, 26)
            }
            .buttonStyle(GoldCapsuleButtonStyle())
            .accessibilityHint("Resets all results and starts a new game at Quarter 1")

            Button(action: onHome) {
                Text("HOME")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.paperInk)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .overlay { Capsule().strokeBorder(Theme.paperInk.opacity(0.4), lineWidth: 1.2) }
                    .contentShape(.capsule)
            }
            .buttonStyle(PressableButtonStyle(playsPressSound: true))
        }
    }
}

#Preview {
    MatchResultView(
        matchViewModel: MatchViewModel(),
        onPlayAgain: {},
        onHome: {}
    )
}

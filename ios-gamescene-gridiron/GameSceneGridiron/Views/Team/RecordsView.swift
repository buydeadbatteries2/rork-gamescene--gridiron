import SwiftUI

/// RECORDS — the franchise record book plus light dynasty history. Records are
/// the best single-season stat values ever posted by the 12-player roster and
/// persist across seasons; history counts seasons, wins, playoff runs and titles.
struct RecordsView: View {
    @Environment(\.dismiss) private var dismiss

    let userTeam: GameTeam

    @State private var rosterManager = RosterManager.shared
    @State private var hasAppeared: Bool = false

    var body: some View {
        ZStack {
            DeskBackground()

            ScrollView {
                VStack(spacing: 18) {
                    header
                        .opacity(hasAppeared ? 1 : 0)
                        .offset(y: hasAppeared ? 0 : 16)

                    recordsCard
                        .opacity(hasAppeared ? 1 : 0)
                        .offset(y: hasAppeared ? 0 : 16)

                    historyCard
                        .opacity(hasAppeared ? 1 : 0)
                        .offset(y: hasAppeared ? 0 : 16)

                    Spacer(minLength: 10)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.85).delay(0.05)) { hasAppeared = true }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 12) {
            Button {
                Haptics.tick()
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.goldLight)
                    .frame(width: 38, height: 38)
                    .background(Color.black.opacity(0.45), in: .circle)
                    .overlay { Circle().strokeBorder(Theme.gold.opacity(0.4), lineWidth: 1) }
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityLabel("Back to the desk")

            VStack(spacing: 3) {
                Text("FRANCHISE RECORDS")
                    .font(.system(size: 24, weight: .black).width(.compressed))
                    .tracking(1.5)
                    .foregroundStyle(Theme.goldGradient)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(userTeam.displayName.uppercased())
                    .font(.system(size: 10, weight: .heavy).width(.condensed))
                    .tracking(1.5)
                    .foregroundStyle(Theme.paperInkSoft)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)

            TeamEmblemView(team: userTeam, size: 38)
                .frame(width: 38)
        }
        .padding(.horizontal, 20)
        .accessibilityElement(children: .contain)
    }

    // MARK: Records

    @ViewBuilder
    private var recordsCard: some View {
        let rows = recordRows
        VStack(spacing: 4) {
            Text("THE RECORD BOOK — BEST SINGLE-SEASON MARKS")
                .font(.system(size: 11, weight: .heavy).width(.condensed))
                .tracking(2)
                .foregroundStyle(Theme.paperInkSoft)
                .frame(maxWidth: .infinity, alignment: .leading)

            if rows.isEmpty {
                Text("NO RECORDS YET — SEASON 1 IS STILL BEING WRITTEN.")
                    .font(Theme.typewriter(12, relativeTo: .caption))
                    .foregroundStyle(Theme.paperInkSoft)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else {
                ForEach(rows) { row in
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(row.label)
                                .font(Theme.typewriter(13, relativeTo: .footnote))
                                .foregroundStyle(Theme.paperInk)
                            Text("\(row.holder) — \(row.position) · SEASON \(row.seasonNumber)")
                                .font(.system(size: 10, weight: .heavy).width(.condensed))
                                .tracking(0.8)
                                .foregroundStyle(Theme.bronzeDeep)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Text("\(row.value)")
                            .font(.system(size: 22, weight: .black).width(.compressed))
                            .monospacedDigit()
                            .foregroundStyle(Theme.goldLight)
                    }
                    .padding(.vertical, 7)
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(Theme.paperInk.opacity(0.12)).frame(height: 1)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .padding(14)
        .paperCard(cornerRadius: 6)
        .overlay(alignment: .top) { PushPin(size: 18).offset(y: -9) }
        .padding(.top, 9)
        .rotationEffect(.degrees(-0.4))
    }

    private struct RecordRow: Identifiable {
        let id: String
        let label: String
        let value: Int
        let holder: String
        let position: String
        let seasonNumber: Int
    }

    private var recordRows: [RecordRow] {
        guard let franchise = rosterManager.franchise else { return [] }
        return PlayerStat.recordCategories.compactMap { stat in
            guard let record = franchise.records.record(for: stat) else { return nil }
            return RecordRow(
                id: stat.rawValue,
                label: stat.recordLabel.uppercased(),
                value: record.value,
                holder: record.holderName,
                position: record.holderPosition.rawValue,
                seasonNumber: record.seasonNumber
            )
        }
    }

    // MARK: Dynasty history

    private var historyCard: some View {
        let history = rosterManager.franchise?.history ?? FranchiseHistory()
        let rows: [(String, String, Bool)] = [
            ("Seasons", "\(history.seasonsPlayed)", false),
            ("All-Time Record", history.recordLine, false),
            ("Playoff Appearances", "\(history.playoffAppearances)", false),
            ("Championship Appearances", "\(history.championshipAppearances)", false),
            ("Championships Won", "\(history.championshipsWon)", true)
        ]

        return VStack(spacing: 4) {
            Text("DYNASTY HISTORY")
                .font(.system(size: 11, weight: .heavy).width(.condensed))
                .tracking(2)
                .foregroundStyle(Theme.paperInkSoft)
                .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack {
                    Text(row.0)
                        .font(Theme.typewriter(13, relativeTo: .footnote))
                        .foregroundStyle(Theme.paperInk)
                    Spacer()
                    Text(row.1)
                        .font(.system(size: 17, weight: .heavy).width(.condensed))
                        .monospacedDigit()
                        .foregroundStyle(row.2 ? AnyShapeStyle(Theme.goldGradient) : AnyShapeStyle(Theme.goldLight))
                }
                .padding(.vertical, 6)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(Theme.paperInk.opacity(0.12)).frame(height: 1)
                }
                .accessibilityElement(children: .combine)
            }

            Text("THE SAME 12 PLAYERS CARRY THIS FRANCHISE, SEASON AFTER SEASON.")
                .font(Theme.typewriter(10, relativeTo: .caption2))
                .foregroundStyle(Theme.paperInkSoft)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 6)
        }
        .padding(14)
        .paperCard(cornerRadius: 6)
        .rotationEffect(.degrees(0.4))
    }
}

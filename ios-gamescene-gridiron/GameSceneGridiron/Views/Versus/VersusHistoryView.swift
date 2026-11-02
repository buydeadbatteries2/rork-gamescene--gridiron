import SwiftUI

/// Phase 15B — MATCH HISTORY. Completed (scored or forfeited) matches,
/// newest first, straight from `my_versus_history`. Tapping a row opens the
/// read-only summary. No solutions, no hidden data.
struct VersusHistoryView: View {
    var store: VersusStore = .shared
    let onBack: () -> Void
    let onHome: () -> Void
    let onOpen: (UUID) -> Void

    @State private var isLoading = false

    var body: some View {
        ZStack {
            DeskBackground()

            ScrollView {
                VStack(spacing: 14) {
                    VersusHeader(
                        title: "MATCH HISTORY",
                        subtitle: "CLOSED VERSUS FILES · \(VersusPresentation.recordLine(store.myRecord))",
                        onBack: onBack,
                        onHome: onHome
                    )

                    if store.history.isEmpty {
                        emptyCard
                    } else {
                        LazyVStack(spacing: 10) {
                            ForEach(store.history) { entry in
                                Button {
                                    Haptics.tick()
                                    onOpen(entry.matchID)
                                } label: {
                                    VersusHistoryRow(entry: entry)
                                }
                                .buttonStyle(PressableButtonStyle(scale: 0.98))
                                .accessibilityIdentifier("versus.history.row")
                            }
                        }
                    }
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 26)
            }
            .scrollIndicators(.hidden)
            .refreshable { await store.loadHistory() }
        }
        .task {
            isLoading = true
            await store.loadHistory()
            isLoading = false
        }
    }

    private var emptyCard: some View {
        VStack(spacing: 8) {
            if isLoading {
                ProgressView().tint(Theme.paperInk)
            } else {
                Image(systemName: "archivebox")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(Theme.paperInkSoft)
            }
            Text(isLoading ? "Opening the archive…" : "No closed Versus files yet.")
                .font(Theme.typewriter(12, relativeTo: .caption))
                .foregroundStyle(Theme.paperInkSoft)
        }
        .frame(maxWidth: .infinity)
        .padding(22)
        .paperCard(cornerRadius: 6)
    }
}

/// opponent · W/L/T · both scores · difficulty · date.
struct VersusHistoryRow: View {
    let entry: VersusHistoryEntry

    var body: some View {
        HStack(spacing: 12) {
            Text(VersusPresentation.shortResult(entry.outcome))
                .font(.system(size: 26, weight: .black).width(.compressed))
                .foregroundStyle(Theme.paper)
                .frame(width: 44, height: 44)
                .background(entry.outcome.stampColor, in: .rect(cornerRadius: 6))
                .accessibilityLabel(VersusPresentation.resultTitle(entry.outcome, isForfeit: entry.isForfeit))

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.opponentUsername.map { "vs @\($0)" } ?? "vs UNKNOWN DETECTIVE")
                    .font(.system(size: 16, weight: .black).width(.condensed))
                    .foregroundStyle(Theme.paperInk)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(DifficultyLevel(serverValue: entry.difficulty)?.title ?? entry.difficulty.uppercased())
                    Text("·")
                    Text(VersusPresentation.shortDate(entry.completedAt))
                    if entry.isForfeit {
                        Text("· FORFEIT")
                    }
                }
                .font(Theme.typewriter(10, relativeTo: .caption2))
                .foregroundStyle(Theme.paperInkSoft)
            }
            Spacer(minLength: 6)
            Text("\(entry.myFinalScore.map(String.init) ?? "—")–\(entry.opponentFinalScore.map(String.init) ?? "—")")
                .font(.system(size: 20, weight: .black).width(.compressed))
                .foregroundStyle(Theme.paperInk)
                .monospacedDigit()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Theme.paperInk.opacity(0.4))
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .paperCard(cornerRadius: 6)
        .accessibilityElement(children: .combine)
    }
}

import SwiftUI

/// Phase 15B — VERSUS HUB. Presented full screen from Home (signed-in only).
/// Recovery happens here: every appearance / foreground re-reads the server,
/// so waiting, active, opponent-pending and unviewed results all reappear
/// after a force-close. Gentle polling only while something is pending.
struct VersusHubView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    var store: VersusStore = .shared

    @State private var path: [VersusRoute] = []
    @State private var hasAppeared = false

    var body: some View {
        NavigationStack(path: $path) {
            hub
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: VersusRoute.self) { route in
                    destination(route)
                        .toolbar(.hidden, for: .navigationBar)
                }
        }
        .task(id: store.hasPendingWork) {
            // Gentle polling: one read every ~45 s, only while a match is
            // waiting on someone or a file is queued. Cancelled automatically
            // when the Hub closes or nothing is pending.
            guard store.hasPendingWork else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(VersusRules.pollInterval))
                guard !Task.isCancelled, scenePhase == .active else { continue }
                await store.refresh()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await store.refresh() } }
        }
    }

    @ViewBuilder
    private func destination(_ route: VersusRoute) -> some View {
        switch route {
        case .find:
            VersusFindMatchView(store: store, onBack: pop, onHome: goHome, onMatched: { id in
                // Replace FIND with the match file — Back returns to the Hub.
                path = [.match(id)]
            })
        case .match(let id):
            VersusMatchView(matchID: id, isSummary: false, store: store, onBack: pop, onHome: goHome)
        case .history:
            VersusHistoryView(store: store, onBack: pop, onHome: goHome, onOpen: { id in
                path.append(.summary(id))
            })
        case .summary(let id):
            VersusMatchView(matchID: id, isSummary: true, store: store, onBack: pop, onHome: goHome)
        }
    }

    private func pop() {
        if !path.isEmpty { path.removeLast() }
    }

    private func goHome() {
        dismiss()
    }

    // MARK: Hub

    private var hub: some View {
        ZStack {
            DeskBackground()

            ScrollView {
                VStack(spacing: 18) {
                    VersusHeader(
                        title: "VERSUS",
                        subtitle: "ONE OPPONENT. SAME FIVE CASES. NO HINTS.",
                        backLabel: "Back to Home",
                        onBack: goHome,
                        trailing: AnyView(refreshButton)
                    )

                    if !store.isAvailable {
                        offlineCard
                    } else {
                        detectiveCard
                            .opacity(hasAppeared ? 1 : 0)
                            .offset(y: hasAppeared ? 0 : 14)

                        if store.lastRefreshFailed {
                            staleBanner
                        }

                        openFilesSection
                            .opacity(hasAppeared ? 1 : 0)

                        Button {
                            Haptics.pickUp()
                            path.append(.find)
                        } label: {
                            HStack {
                                Spacer()
                                Image(systemName: "magnifyingglass")
                                Text("FIND MATCH")
                                Spacer()
                            }
                        }
                        .buttonStyle(GoldCapsuleButtonStyle())
                        .accessibilityIdentifier("versus.hub.find")

                        VersusPaperButton(title: "MATCH HISTORY", systemImage: "archivebox.fill", id: "versus.hub.history") {
                            path.append(.history)
                        }
                    }

                    VersusPaperButton(title: "BACK TO HOME", systemImage: "house.fill", id: "versus.hub.home", action: goHome)
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 26)
            }
            .scrollIndicators(.hidden)
            .refreshable { await store.refresh(force: true) }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.85).delay(0.05)) { hasAppeared = true }
        }
        .task { await store.refresh(force: true) }
    }

    private var refreshButton: some View {
        Button {
            Haptics.tick()
            Task { await store.refresh(force: true) }
        } label: {
            Group {
                if store.isRefreshing {
                    ProgressView().tint(Theme.goldLight)
                } else {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.goldLight)
                }
            }
            .frame(width: 38, height: 38)
            .background(Color.black.opacity(0.45), in: .circle)
            .overlay { Circle().strokeBorder(Theme.gold.opacity(0.4), lineWidth: 1) }
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(store.isRefreshing || !store.isAvailable)
        .accessibilityLabel("Refresh")
        .accessibilityIdentifier("versus.hub.refresh")
    }

    private var detectiveCard: some View {
        let identity = VersusIdentity.current
        let record = store.myRecord
        let streak = VersusPresentation.streak(store.history)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    VersusFileLabel(text: "DETECTIVE ON FILE")
                    Text(identity?.username ?? "@detective")
                        .font(.system(size: 24, weight: .black).width(.compressed))
                        .foregroundStyle(Theme.paperInk)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    if let name = identity?.displayName, !name.isEmpty {
                        Text(name)
                            .font(Theme.typewriter(12, relativeTo: .caption))
                            .foregroundStyle(Theme.paperInkSoft)
                    }
                }
                Spacer(minLength: 8)
                if let streak {
                    Text("STREAK \(streak)")
                        .font(.system(size: 11, weight: .heavy).width(.condensed))
                        .tracking(1.4)
                        .foregroundStyle(Theme.paper)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Theme.bronzeDeep, in: .capsule)
                        .accessibilityLabel("Current streak \(streak)")
                }
            }

            Rectangle().fill(Theme.paperInk.opacity(0.18)).frame(height: 1)

            HStack(alignment: .lastTextBaseline, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    VersusFileLabel(text: "VERSUS RECORD · W-L-T")
                    Text(VersusPresentation.recordLine(record))
                        .font(.system(size: 44, weight: .black).width(.compressed))
                        .foregroundStyle(Theme.paperInk)
                        .contentTransition(.numericText())
                        .accessibilityIdentifier("versus.hub.record")
                }
                Spacer(minLength: 0)
                if let record, record.forfeitWins + record.forfeitLosses > 0 {
                    Text("FORFEITS \(record.forfeitWins)-\(record.forfeitLosses)")
                        .font(Theme.typewriter(11, relativeTo: .caption))
                        .foregroundStyle(Theme.paperInkSoft)
                }
            }
        }
        .padding(16)
        .paperCard(cornerRadius: 6)
        .overlay(alignment: .top) { PushPin(size: 18).offset(y: -8) }
    }

    @ViewBuilder
    private var openFilesSection: some View {
        let files = store.unviewedResults + store.openMatches
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("OPEN CASE FILES")
                    .font(.system(size: 13, weight: .heavy).width(.condensed))
                    .tracking(2)
                    .foregroundStyle(Theme.goldLight)
                if store.attentionCount > 0 {
                    Text("\(store.attentionCount)")
                        .font(.system(size: 11, weight: .black))
                        .foregroundStyle(.white)
                        .frame(minWidth: 20, minHeight: 20)
                        .background(Theme.danger, in: .circle)
                }
                Spacer()
            }

            if files.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: store.hasLoaded ? "tray" : "hourglass")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Theme.paperInkSoft)
                    Text(store.hasLoaded ? "No open files. Find an opponent to start one." : "Checking the wire…")
                        .font(Theme.typewriter(12, relativeTo: .caption))
                        .foregroundStyle(Theme.paperInkSoft)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(18)
                .paperCard(cornerRadius: 6, darkness: 0.06)
            } else {
                ForEach(files, id: \.matchID) { match in
                    Button {
                        Haptics.tick()
                        path.append(.match(match.matchID))
                    } label: {
                        VersusMatchRow(match: match, isQueued: store.pendingSubmission(for: match.matchID) != nil)
                    }
                    .buttonStyle(PressableButtonStyle(scale: 0.98))
                    .accessibilityIdentifier("versus.hub.row")
                }
            }
        }
    }

    private var staleBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.exclamationmark")
            Text("Couldn't reach the server — showing your saved files.")
                .font(Theme.typewriter(11, relativeTo: .caption))
            Spacer(minLength: 0)
        }
        .foregroundStyle(Theme.caution)
        .padding(10)
        .background(Color.black.opacity(0.5), in: .rect(cornerRadius: 6))
    }

    private var offlineCard: some View {
        VStack(spacing: 10) {
            Image(systemName: "antenna.radiowaves.left.and.right.slash")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(Theme.paperInkSoft)
            Text("VERSUS IS OFFLINE")
                .font(.system(size: 16, weight: .heavy).width(.condensed))
                .tracking(1.4)
                .foregroundStyle(Theme.paperInk)
            Text("Versus needs the GameScene server. Try again later.")
                .font(Theme.typewriter(12, relativeTo: .caption))
                .foregroundStyle(Theme.paperInkSoft)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .paperCard(cornerRadius: 6)
    }
}

/// One open / unviewed match in the Hub.
struct VersusMatchRow: View {
    let match: VersusMatch
    var isQueued: Bool = false

    var body: some View {
        let phase = VersusPhase.of(match)
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(isQueued ? "SUBMITTING CASE FILE…" : phase.rowStatus)
                    .font(.system(size: 11, weight: .heavy).width(.condensed))
                    .tracking(1.4)
                    .foregroundStyle(phase.rowColor)
                Text(match.opponentUsername.map { "vs @\($0)" } ?? "vs ? ? ?")
                    .font(.system(size: 17, weight: .black).width(.condensed))
                    .foregroundStyle(Theme.paperInk)
                    .lineLimit(1)
                Text(phase.isPending ? VersusPresentation.deadlineText(match) : "Tap to open the file")
                    .font(Theme.typewriter(11, relativeTo: .caption))
                    .foregroundStyle(Theme.paperInkSoft)
            }
            Spacer(minLength: 8)
            if let level = match.difficultyLevel {
                DifficultyBadge(level: level)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.paperInk.opacity(0.4))
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .paperCard(cornerRadius: 6)
        .overlay(alignment: .leading) {
            Rectangle().fill(phase.rowColor).frame(width: 4).clipShape(.rect(cornerRadius: 2))
        }
        .accessibilityElement(children: .combine)
    }
}

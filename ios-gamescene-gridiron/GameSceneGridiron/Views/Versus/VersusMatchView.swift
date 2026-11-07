import SwiftUI

/// Phase 15B — one Versus case file, rendered entirely from the SERVER row:
/// waiting (play now) → matchup → submitting → submitted / waiting for
/// opponent → VERSUS CASE CLOSED (or MATCH EXPIRED). The opponent's score
/// stays SEALED until the server completes the match. Never shows solutions,
/// real names, email or hidden server data.
struct VersusMatchView: View {
    let matchID: UUID
    /// Opened from MATCH HISTORY (read-only summary).
    var isSummary: Bool = false
    var store: VersusStore = .shared
    let onBack: () -> Void
    let onHome: () -> Void

    @State private var playContext: VersusPlayContext?
    @State private var playResume: VersusProgress?
    @State private var isLoading = false
    @State private var stampIn = false

    private var match: VersusMatch? { store.match(id: matchID) }

    var body: some View {
        ZStack {
            DeskBackground()

            ScrollView {
                VStack(spacing: 18) {
                    VersusHeader(
                        title: headerTitle,
                        subtitle: headerSubtitle,
                        onBack: onBack,
                        onHome: onHome
                    )

                    if let match {
                        content(for: match)
                    } else {
                        loadingCard
                    }

                    VersusPaperButton(title: "BACK TO HOME", systemImage: "house.fill", id: "versus.match.home", action: onHome)
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 26)
            }
            .scrollIndicators(.hidden)
            .refreshable { await reload(force: true) }
        }
        .task { await reload(force: false) }
        .onAppear { markViewedIfClosed() }
        .onChange(of: match.map { VersusPhase.of($0) }) { _, _ in
            markViewedIfClosed()
            stampIn = false
            withAnimation(.spring(response: 0.42, dampingFraction: 0.55).delay(0.1)) { stampIn = true }
        }
        .fullScreenCover(item: $playContext, onDismiss: {
            Task { await store.refresh(force: true) }
        }) { context in
            VersusPlayView(context: context, resume: playResume, store: store)
        }
    }

    // MARK: Header

    private var headerTitle: String {
        guard let match else { return "CASE FILE" }
        switch VersusPhase.of(match) {
        case .waitingCanPlay: return "WAITING ROOM"
        case .readyToPlay: return "MATCHUP"
        case .submittedWaiting: return "CASE FILE SUBMITTED"
        case .resolved: return "VERSUS CASE CLOSED"
        case .expiredNoResult: return "MATCH EXPIRED"
        case .cancelled: return "FILE CLOSED"
        }
    }

    private var headerSubtitle: String {
        guard let match, let level = match.difficultyLevel else { return "VERSUS" }
        return "VERSUS · \(level.title) · \(VersusRules.caseCount) CASES"
    }

    // MARK: Content

    @ViewBuilder
    private func content(for match: VersusMatch) -> some View {
        let phase = VersusPhase.of(match)
        let pending = store.pendingSubmission(for: matchID)
        let submitState = store.submitState(for: matchID)

        if phase.canPlay, pending != nil {
            submittingCard(match: match, state: submitState)
        } else if phase.canPlay, case .rejected(let message) = submitState {
            noticeCard(icon: "xmark.octagon.fill", title: "FILE NOT ACCEPTED", detail: message, color: Theme.danger)
        } else {
            switch phase {
            case .waitingCanPlay:
                waitingCard(match)
                playSection(match)
            case .readyToPlay:
                matchupCard(match)
                playSection(match)
            case .submittedWaiting(let joined):
                submittedCard(match, opponentJoined: joined)
            case .resolved(let outcome, let isForfeit):
                resultBoard(match, outcome: outcome, isForfeit: isForfeit)
            case .expiredNoResult:
                expiredCard(match)
            case .cancelled:
                noticeCard(
                    icon: "folder.badge.minus",
                    title: "FILE CLOSED",
                    detail: "The server closed this unplayed file (you searched another difficulty). No result.",
                    color: Theme.paperInkSoft
                )
            }
        }
        if submitState == .expired {
            noticeCard(
                icon: "clock.badge.xmark",
                title: "DEADLINE PASSED",
                detail: "Your case file arrived after the deadline. The server's result stands.",
                color: Theme.danger
            )
        }
    }

    // Waiting for an opponent — the cases are already assigned.
    private func waitingCard(_ match: VersusMatch) -> some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                ProgressView().tint(Theme.paperInk)
                Text("WAITING FOR AN OPPONENT")
                    .font(.system(size: 18, weight: .black).width(.compressed))
                    .tracking(1.2)
                    .foregroundStyle(Theme.paperInk)
            }
            factGrid(match)
            Text("Your five cases are already on file. Play now — your score stays sealed until an opponent takes the case. You don't need to stay on this screen.")
                .font(Theme.typewriter(11, relativeTo: .caption))
                .foregroundStyle(Theme.paperInkSoft)
                .multilineTextAlignment(.center)
        }
        .padding(18)
        .paperCard(cornerRadius: 6)
        .overlay(alignment: .top) { PushPin(size: 18).offset(y: -8) }
        .accessibilityIdentifier("versus.match.waiting")
    }

    // YOU vs OPPONENT.
    private func matchupCard(_ match: VersusMatch) -> some View {
        let me = VersusIdentity.current
        return VStack(spacing: 14) {
            HStack(alignment: .center, spacing: 6) {
                VersusDetectiveColumn(
                    tag: "YOU",
                    username: me?.username ?? "@you",
                    displayName: me?.displayName,
                    detail: VersusPresentation.recordLine(store.myRecord),
                    accent: Theme.turf
                )
                Text("VS")
                    .font(.system(size: 34, weight: .black).width(.compressed))
                    .foregroundStyle(Theme.danger)
                    .rotationEffect(.degrees(-6))
                VersusDetectiveColumn(
                    tag: "OPPONENT",
                    username: VersusPresentation.opponentName(match),
                    displayName: match.opponentDisplayName,
                    detail: VersusPresentation.recordLine(store.opponentRecord(for: match)),
                    accent: Theme.danger
                )
            }
            Rectangle().fill(Theme.paperInk.opacity(0.18)).frame(height: 1)
            factGrid(match)
        }
        .padding(18)
        .paperCard(cornerRadius: 6)
        .overlay(alignment: .top) { CautionTape().frame(height: 10).clipShape(.rect(cornerRadius: 2)).padding(.horizontal, 40).offset(y: -5) }
        .accessibilityIdentifier("versus.match.matchup")
    }

    private func factGrid(_ match: VersusMatch) -> some View {
        HStack(alignment: .top, spacing: 12) {
            fact("DIFFICULTY", match.difficultyLevel?.title ?? match.difficulty.uppercased())
            fact("CASES", "\(VersusRules.caseCount) · 4 + OT")
            fact("DEADLINE", VersusPresentation.deadlineText(match))
        }
    }

    private func fact(_ label: String, _ value: String) -> some View {
        VStack(spacing: 3) {
            VersusFileLabel(text: label)
            Text(value)
                .font(Theme.typewriterBold(12, relativeTo: .caption))
                .foregroundStyle(Theme.paperInk)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func playSection(_ match: VersusMatch) -> some View {
        if let problem = VersusPlayability.problem(for: match) {
            noticeCard(
                icon: "exclamationmark.triangle.fill",
                title: "CASE FILES UNAVAILABLE",
                detail: "This build doesn't carry the exact case files the server assigned (\(problem)). Update GameScene to play — cases are never substituted.",
                color: Theme.danger
            )
        } else {
            let resume = store.progress(for: match.matchID)
            VStack(spacing: 10) {
                Button { startPlay(match) } label: {
                    HStack {
                        Spacer()
                        Image(systemName: "magnifyingglass")
                        Text(resume != nil ? "RESUME INVESTIGATION" : (VersusPhase.of(match) == .waitingCanPlay ? "OPEN CASE" : "START INVESTIGATION"))
                        Spacer()
                    }
                }
                .buttonStyle(GoldCapsuleButtonStyle())
                .accessibilityIdentifier("versus.match.play")

                Label("HINTS DISABLED — COMPETITIVE CASE", systemImage: "lightbulb.slash")
                    .font(.system(size: 11, weight: .heavy).width(.condensed))
                    .tracking(1.2)
                    .foregroundStyle(Theme.goldLight.opacity(0.85))
                if let resume {
                    Text("Quarter \(min(resume.match.currentQuarterIndex + 1, VersusRules.caseCount)) is next — progress saved.")
                        .font(Theme.typewriter(11, relativeTo: .caption))
                        .foregroundStyle(Theme.paperInkSoft)
                }
            }
        }
    }

    private func startPlay(_ match: VersusMatch) {
        Haptics.pickUp()
        let resume = store.progress(for: match.matchID)
        if let resume, resume.match.isComplete {
            // Finished before the queue write landed — submit, don't replay.
            Task { await store.completeGame(matchID: match.matchID, startedAt: resume.startedAt, caseResults: resume.caseResults) }
            return
        }
        playResume = resume
        playContext = VersusPlayContext(match: match, startedAt: resume?.startedAt ?? Date())
    }

    private func submittingCard(match: VersusMatch, state: VersusStore.SubmitState?) -> some View {
        let retrying = state == .willRetry
        return VStack(spacing: 12) {
            if retrying {
                Image(systemName: "icloud.slash")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(Theme.paperInkSoft)
            } else {
                ProgressView().tint(Theme.paperInk)
            }
            Text(retrying ? "SAVED — WILL RETRY" : "SUBMITTING CASE FILE…")
                .font(.system(size: 18, weight: .black).width(.compressed))
                .tracking(1.2)
                .foregroundStyle(Theme.paperInk)
            Text(retrying
                 ? "Couldn't reach the server. Your file is saved on this device and will be sent automatically."
                 : "The server is verifying every placement.")
                .font(Theme.typewriter(11, relativeTo: .caption))
                .foregroundStyle(Theme.paperInkSoft)
                .multilineTextAlignment(.center)
            if retrying {
                Button {
                    Haptics.tick()
                    Task { await store.submit(matchID: match.matchID) }
                } label: {
                    HStack { Spacer(); Text("RETRY NOW"); Spacer() }
                }
                .buttonStyle(GoldCapsuleButtonStyle())
                .accessibilityIdentifier("versus.match.retry")
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .paperCard(cornerRadius: 6)
        .accessibilityIdentifier("versus.match.submitting")
    }

    // Finished first — own verified score only; opponent sealed.
    private func submittedCard(_ match: VersusMatch, opponentJoined: Bool) -> some View {
        VStack(spacing: 14) {
            VersusStamp(text: "CASE FILE SUBMITTED", color: Theme.turf, size: 28)
                .scaleEffect(stampIn ? 1 : 1.6)
                .opacity(stampIn ? 1 : 0)
            Text(opponentJoined ? "WAITING FOR OPPONENT · INVESTIGATING" : "WAITING FOR OPPONENT")
                .font(.system(size: 14, weight: .heavy).width(.condensed))
                .tracking(1.4)
                .foregroundStyle(Theme.paperInk)
            HStack(spacing: 6) {
                scoreColumn(tag: "YOU", name: VersusIdentity.current?.username ?? "@you", score: VersusPresentation.myScoreText(match), cases: match.myCasesSolved.map(String.init))
                Text("VS").font(.system(size: 22, weight: .black).width(.compressed)).foregroundStyle(Theme.paperInkSoft)
                scoreColumn(tag: "OPP", name: match.opponentUsername.map { "@\($0)" } ?? "TBD", score: VersusPresentation.opponentScoreText(match), cases: nil)
            }
            Text("\(VersusPresentation.deadlineText(match)). You can leave — the result lands in the Hub.")
                .font(Theme.typewriter(11, relativeTo: .caption))
                .foregroundStyle(Theme.paperInkSoft)
                .multilineTextAlignment(.center)
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .paperCard(cornerRadius: 6)
        .onAppear { stampIn = true }
        .accessibilityIdentifier("versus.match.submitted")
    }

    // VERSUS CASE CLOSED — evidence board.
    private func resultBoard(_ match: VersusMatch, outcome: VersusOutcome, isForfeit: Bool) -> some View {
        VStack(spacing: 16) {
            VersusStamp(text: VersusPresentation.resultTitle(outcome, isForfeit: isForfeit), color: outcome.stampColor, size: 54)
                .scaleEffect(stampIn ? 1 : 1.9)
                .opacity(stampIn ? 1 : 0)
                .rotationEffect(.degrees(stampIn ? 0 : -8))
                .accessibilityIdentifier("versus.match.result")

            HStack(alignment: .top, spacing: 6) {
                scoreColumn(
                    tag: "YOU",
                    name: VersusIdentity.current?.username ?? "@you",
                    score: VersusPresentation.myScoreText(match),
                    cases: match.myCasesSolved.map(String.init),
                    highlight: outcome == .win
                )
                Text("VS").font(.system(size: 22, weight: .black).width(.compressed)).foregroundStyle(Theme.paperInkSoft).padding(.top, 30)
                scoreColumn(
                    tag: "OPP",
                    name: VersusPresentation.opponentName(match),
                    score: VersusPresentation.opponentScoreText(match),
                    cases: VersusPresentation.opponentCasesText(match),
                    highlight: outcome == .loss
                )
            }

            Rectangle().fill(Theme.paperInk.opacity(0.18)).frame(height: 1)

            HStack(alignment: .top, spacing: 12) {
                fact("DIFFICULTY", match.difficultyLevel?.title ?? match.difficulty.uppercased())
                fact("CLOSED", VersusPresentation.shortDate(match.completedAt))
            }
            Text(VersusPresentation.resolutionDetail(match))
                .font(Theme.typewriter(11, relativeTo: .caption))
                .foregroundStyle(Theme.paperInkSoft)
                .multilineTextAlignment(.center)
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .paperCard(cornerRadius: 6)
        .overlay(alignment: .topLeading) { PushPin(size: 18).offset(x: 10, y: -8) }
        .overlay(alignment: .topTrailing) { PushPin(size: 18).offset(x: -10, y: -8) }
        .onAppear {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.55).delay(0.15)) { stampIn = true }
        }
        .sensoryFeedback(outcome == .loss ? .warning : .success, trigger: stampIn)
    }

    private func scoreColumn(tag: String, name: String, score: String, cases: String?, highlight: Bool = false) -> some View {
        VStack(spacing: 4) {
            Text(tag)
                .font(.system(size: 10, weight: .heavy).width(.condensed))
                .tracking(2)
                .foregroundStyle(Theme.paperInkSoft)
            Text(name)
                .font(.system(size: 15, weight: .black).width(.condensed))
                .foregroundStyle(Theme.paperInk)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(score)
                .font(.system(size: score == "SEALED" ? 22 : 38, weight: .black).width(.compressed))
                .foregroundStyle(highlight ? Theme.turf : Theme.paperInk)
                .contentTransition(.numericText())
            if let cases {
                Text("\(cases) CASES SOLVED")
                    .font(Theme.typewriter(10, relativeTo: .caption2))
                    .foregroundStyle(Theme.paperInkSoft)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func expiredCard(_ match: VersusMatch) -> some View {
        VStack(spacing: 14) {
            VersusStamp(text: "MATCH EXPIRED", color: Theme.paperInkSoft, size: 40)
                .scaleEffect(stampIn ? 1 : 1.6)
                .opacity(stampIn ? 1 : 0)
            Text(VersusPresentation.expiredDetail(match))
                .font(Theme.typewriter(12, relativeTo: .caption))
                .foregroundStyle(Theme.paperInk)
                .multilineTextAlignment(.center)
            Text("NO RESULT · NO W/L CHANGE")
                .font(.system(size: 12, weight: .heavy).width(.condensed))
                .tracking(1.6)
                .foregroundStyle(Theme.paperInkSoft)
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .paperCard(cornerRadius: 6, darkness: 0.08)
        .onAppear {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.6).delay(0.1)) { stampIn = true }
        }
        .accessibilityIdentifier("versus.match.expired")
    }

    private func noticeCard(icon: String, title: String, detail: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(color)
            Text(title)
                .font(.system(size: 16, weight: .heavy).width(.condensed))
                .tracking(1.4)
                .foregroundStyle(Theme.paperInk)
            Text(detail)
                .font(Theme.typewriter(11, relativeTo: .caption))
                .foregroundStyle(Theme.paperInkSoft)
                .multilineTextAlignment(.center)
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .paperCard(cornerRadius: 6)
    }

    private var loadingCard: some View {
        VStack(spacing: 10) {
            if isLoading {
                ProgressView().tint(Theme.paperInk)
                Text("Pulling the file…")
            } else {
                Image(systemName: "questionmark.folder")
                    .font(.system(size: 24, weight: .semibold))
                Text("This file isn't available right now. Pull to refresh.")
            }
        }
        .font(Theme.typewriter(12, relativeTo: .caption))
        .foregroundStyle(Theme.paperInkSoft)
        .multilineTextAlignment(.center)
        .padding(20)
        .frame(maxWidth: .infinity)
        .paperCard(cornerRadius: 6)
    }

    // MARK: Data

    private func reload(force: Bool) async {
        isLoading = true
        defer { isLoading = false }
        if isSummary {
            _ = await store.loadSummary(id: matchID)
        } else {
            await store.refresh(force: force)
            if store.match(id: matchID) == nil { _ = await store.loadSummary(id: matchID) }
        }
        markViewedIfClosed()
    }

    private func markViewedIfClosed() {
        guard let match, VersusPhase.of(match).isClosed else { return }
        store.markViewed(matchID)
    }
}

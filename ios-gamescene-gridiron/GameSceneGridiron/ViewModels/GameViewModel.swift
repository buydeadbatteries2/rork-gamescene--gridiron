import SwiftUI

/// Owns every gameplay rule for a single quarter: selection, dragging, validation, lives, hints and result.
/// Views only render state and forward user intents.
@Observable
final class GameViewModel {
    /// Distance (pt) from a slot center within which a drop snaps to that slot.
    static let snapRadius: CGFloat = 38
    /// The dragged token floats above the finger so it stays visible.
    static let dragLift: CGFloat = 44

    let puzzle: QuarterPuzzle

    /// The GAME difficulty this quarter is played at — decides the available
    /// player-profile pool and whether the Hall of Famer pressure clock runs.
    let difficulty: DifficultyLevel

    /// Position of this puzzle within the match (0-based; 4 = overtime).
    var puzzleIndex: Int { puzzle.index }

    private(set) var lives: Int
    /// Mirror of the persistent hint balance — hints live in the shared
    /// `PlayerWallet` and survive quarters, games and restarts.
    private(set) var hintsRemaining: Int
    /// The wallet this quarter draws hints from; tests inject isolated ones.
    private let wallet: PlayerWallet
    /// Offered when the player presses Hint with nothing left in the wallet.
    var isHintOfferPresented = false
    /// Uniquely identifies this quarter for the Last Chance ledger:
    /// "\(matchID)-q\(quarterIndex)" during a match, standalone otherwise.
    /// Setting it is the moment the quarter's timing snapshot (if any) is
    /// restored — a resumed quarter never gets consumed timeouts, lost lives
    /// or a reset clock back.
    var lastChanceKey: String = "standalone-quarter" {
        didSet { restoreClockSnapshotIfMatching() }
    }
    /// TRAINING CASE mode: wrong placements teach the mechanic instead of
    /// costing a heart, so the tutorial can never permanently fail.
    var isTraining: Bool = false
    /// TRAINING CASE mode: wrong placements teach the mechanic instead of
    /// costing a heart, so the tutorial can never permanently fail.
    /// True while the final heart is gone but the Last Chance offer is up —
    /// the quarter verdict waits for the player's choice.
    private(set) var isLastChancePending = false
    private(set) var usedHints: [UsedHint] = []
    private(set) var placements: [PlacedPlayer] = []
    private(set) var selectedProfiles: [String: PlayerProfile] = [:]
    private(set) var result: PuzzleResult = .inProgress
    private(set) var feedback: FeedbackMessage?

    // MARK: Hall of Famer pressure system

    /// Timeouts per quarter (Hall of Famer only).
    static let timeoutsPerQuarter = 2
    /// Timeout duration in seconds.
    static let timeoutDuration: TimeInterval = 25
    /// Persisted investigation-state key (all difficulties).
    static let clockSnapshotKey = "gamescene.gridiron.investigation"
    /// One-time explanation flag key.
    static let clockIntroKey = "gamescene.gridiron.hofClockExplained"

    /// True when the Hall of Famer pressure clock applies to this quarter.
    /// Training is never timed, whatever the difficulty.
    private(set) var isTimed: Bool
    /// The per-placement 40-second clock. Nil whenever the quarter is untimed.
    private(set) var playClock: PlayClockController?
    /// Timeouts left this quarter (never carries over between quarters).
    private(set) var timeoutsRemaining: Int
    /// Non-nil while the player is in a called timeout — a separate 25s clock.
    private(set) var timeoutClock: PlayClockController?
    /// First Hall of Famer game: the clock does not start until GOT IT.
    private(set) var isClockIntroPresented: Bool
    private let defaults: UserDefaults
    /// Clock factory (tests inject manual-tick controllers).
    private let makeClock: (TimeInterval) -> PlayClockController

    var expandedPlayerID: String?
    var currentClueIndex: Int = 0
    var isPaused: Bool = false
    var isNotebookPresented: Bool = false
    var inspectedEvidenceID: String?

    // MARK: Drag state
    private(set) var draggingPlayerID: String?
    private(set) var dragLocation: CGPoint = .zero
    private(set) var hoveredSlotID: String?
    private(set) var rejectedSlotID: String?
    private(set) var rejectionCount: Int = 0
    private(set) var lastPlacedPlayerID: String?

    /// Frame of the turf in the gameplay coordinate space; reported by the field view.
    var fieldFrame: CGRect = .zero

    /// Profiles the player may choose from at this game difficulty.
    var availableProfiles: [PlayerProfile] { PlayerProfile.pool(for: difficulty) }

    private var usedHintIDs: Set<String> = []
    /// Prevents repeated warnings while a blocked drag gesture keeps firing.
    private var blockedDragPlayerID: String?
    private var feedbackTask: Task<Void, Never>?

    init(
        puzzle: QuarterPuzzle = SampleQuarter.puzzle,
        wallet: PlayerWallet = .shared,
        difficulty: DifficultyLevel = .pro,
        defaults: UserDefaults = .standard,
        makeClock: ((TimeInterval) -> PlayClockController)? = nil
    ) {
        self.puzzle = puzzle
        self.wallet = wallet
        self.difficulty = difficulty
        self.defaults = defaults
        self.makeClock = makeClock ?? { PlayClockController(duration: $0) }
        self.lives = puzzle.startingLives
        self.hintsRemaining = wallet.hints
        let timed = difficulty == .hallOfFamer
        self.isTimed = timed
        self.timeoutsRemaining = timed ? Self.timeoutsPerQuarter : 0
        self.isClockIntroPresented = timed && !defaults.bool(forKey: Self.clockIntroKey)
        if timed {
            let clock = self.makeClock(40)
            playClock = clock
            // All stored properties are initialized — the callbacks can now
            // safely capture self.
            clock.onExpire = { [weak self] in self?.handlePlayClockExpiration() }
            clock.onWarning = { [weak self] in
                Haptics.warning()
                self?.show(FeedbackMessage(title: "10 SECONDS", detail: nil, tone: .lead), duration: 0.9)
            }
            clock.onCritical = { [weak self] in
                Haptics.warning()
                AudioManager.shared.play(.cardSelect)
                self?.show(FeedbackMessage(title: "5 SECONDS", detail: nil, tone: .failure), duration: 0.9)
            }
        } else {
            playClock = nil
        }
    }

    // MARK: Derived state

    var remainingPlayers: [FootballPlayer] {
        let solved = Set(placements.map(\.player.id))
        return puzzle.missingPlayers.filter { !solved.contains($0.id) }
    }

    var openSlots: [PlacementSlot] {
        let filled = Set(placements.map(\.slot.id))
        return puzzle.slots.filter { !filled.contains($0.id) }
    }

    /// Open slots that are valid candidates for the dragged player's position —
    /// while dragging, mystery zones for other positions' landmarks stay hidden
    /// so the field never crowds with spots the ball carrier can't occupy.
    /// (When nothing is dragged this is every open slot, which keeps rejection
    /// flashes working after a release.)
    var candidateSlots: [PlacementSlot] {
        candidateSlots(for: draggingPlayerID)
    }

    func candidateSlots(for playerID: String?) -> [PlacementSlot] {
        guard let playerID, let player = puzzle.player(id: playerID) else { return openSlots }
        let filled = Set(placements.map(\.slot.id))
        return puzzle.slots.filter {
            !filled.contains($0.id) && SlotRole.accepts(player.position, slotID: $0.id)
        }
    }

    var solvedPlayerIDs: Set<String> { Set(placements.map(\.player.id)) }

    var isDragging: Bool { draggingPlayerID != nil }

    var draggingPlayer: FootballPlayer? {
        draggingPlayerID.flatMap { puzzle.player(id: $0) }
    }

    var currentClue: PuzzleClue? {
        guard puzzle.clues.indices.contains(currentClueIndex) else { return nil }
        return puzzle.clues[currentClueIndex]
    }

    func isClueSolved(_ clue: PuzzleClue) -> Bool {
        solvedPlayerIDs.contains(clue.playerID)
    }

    func usedHint(for clue: PuzzleClue) -> UsedHint? {
        usedHints.last { $0.playerID == clue.playerID }
    }

    func selectedProfile(for playerID: String) -> PlayerProfile? {
        selectedProfiles[playerID]
    }

    /// Converts a normalized slot/evidence position into the gameplay coordinate space.
    func point(x: Double, y: Double) -> CGPoint {
        CGPoint(
            x: fieldFrame.minX + fieldFrame.width * x,
            y: fieldFrame.minY + fieldFrame.height * y
        )
    }

    // MARK: Selection

    func toggleExpanded(_ playerID: String) {
        guard result == .inProgress else { return }
        Haptics.tick()
        AudioManager.shared.play(.cardSelect)
        expandedPlayerID = expandedPlayerID == playerID ? nil : playerID
    }

    /// Selects a deployment profile. Only profiles valid for the active game
    /// difficulty are selectable — the UI never shows the others, and this
    /// guard keeps the model airtight.
    func selectProfile(_ profile: PlayerProfile, for playerID: String) {
        guard result == .inProgress, availableProfiles.contains(profile) else { return }
        Haptics.tick()
        AudioManager.shared.play(.profileSelect)
        expandedPlayerID = playerID
        if selectedProfiles[playerID] == profile {
            selectedProfiles[playerID] = nil
        } else {
            selectedProfiles[playerID] = profile
        }
    }

    func showClue(at index: Int) {
        guard puzzle.clues.indices.contains(index) else { return }
        currentClueIndex = index
    }

    func nextClue() {
        showClue(at: (currentClueIndex + 1) % puzzle.clues.count)
    }

    func previousClue() {
        showClue(at: (currentClueIndex - 1 + puzzle.clues.count) % puzzle.clues.count)
    }

    // MARK: Drag & drop

    /// Returns false when a drag isn't allowed yet (e.g. no profile chosen).
    @discardableResult
    func beginDrag(playerID: String, at location: CGPoint) -> Bool {
        guard result == .inProgress, !isPaused else { return false }
        guard blockedDragPlayerID != playerID else { return false }
        // A timeout is thinking/review time — no final placements while it runs.
        guard timeoutClock == nil else {
            show(FeedbackMessage(title: "TIMEOUT — REVIEW ONLY", detail: "Resume play to make your placement.", tone: .info))
            return false
        }
        guard selectedProfiles[playerID] != nil else {
            blockedDragPlayerID = playerID
            expandedPlayerID = playerID
            Haptics.warning()
            let options = availableProfiles.map { $0.title.uppercased() }.joined(separator: ", ")
            show(FeedbackMessage(title: "PICK A PROFILE FIRST", detail: "Choose \(options).", tone: .info))
            return false
        }
        expandedPlayerID = playerID
        draggingPlayerID = playerID
        inspectedEvidenceID = nil
        updateDrag(to: location)
        Haptics.pickUp()
        AudioManager.shared.play(.dragBegin)
        return true
    }

    func updateDrag(to location: CGPoint) {
        guard isDragging else { return }
        dragLocation = location
        let tokenPoint = CGPoint(x: location.x, y: location.y - Self.dragLift)
        let newHover = dropTarget(near: tokenPoint)?.id
        if newHover != hoveredSlotID {
            hoveredSlotID = newHover
            if newHover != nil { Haptics.soft() }
        }
    }

    /// Nearest valid candidate within the snap radius. Zones never resolve a
    /// release ambiguously: whatever the geometry, a drop resolves to this
    /// single nearest target — or to nothing when no candidate is in range.
    private func dropTarget(near tokenPoint: CGPoint) -> PlacementSlot? {
        candidateSlots
            .map { slot in (slot, distance(point(x: slot.x, y: slot.y), tokenPoint)) }
            .filter { $0.1 <= Self.snapRadius }
            .min { $0.1 < $1.1 }?.0
    }

    /// The hovered target's true field point in gameplay coordinates. The
    /// displayed marker may be nudged a few points for readability, but the
    /// snap preview, magnetism and the drop all resolve to this point.
    var hoveredSlotPoint: CGPoint? {
        hoveredSlotID.flatMap { puzzle.slot(id: $0) }.map { point(x: $0.x, y: $0.y) }
    }

    func endDrag() {
        blockedDragPlayerID = nil
        guard let playerID = draggingPlayerID else { return }
        // Re-resolve at release against the real drop point: the verdict is
        // always the nearest candidate within the snap radius, independent of
        // any hover bookkeeping.
        let slot = dropTarget(near: CGPoint(x: dragLocation.x, y: dragLocation.y - Self.dragLift))
        draggingPlayerID = nil
        hoveredSlotID = nil

        guard let slot,
              let player = puzzle.player(id: playerID),
              let profile = selectedProfiles[playerID] else {
            return
        }
        evaluate(player: player, profile: profile, slot: slot)
    }

    func cancelDrag() {
        blockedDragPlayerID = nil
        draggingPlayerID = nil
        hoveredSlotID = nil
    }

    private func evaluate(player: FootballPlayer, profile: PlayerProfile, slot: PlacementSlot) {
        let solution = puzzle.solutions[player.id]
        let isCorrect = solution?.slotID == slot.id && solution?.profile == profile

        if isCorrect {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) {
                placements.append(PlacedPlayer(player: player, profile: profile, slot: slot))
                expandedPlayerID = nil
                lastPlacedPlayerID = player.id
            }
            Haptics.success()
            AudioManager.shared.play(.placementCorrect)
            show(FeedbackMessage(title: "GOOD READ", detail: "\(player.position.rawValue) \(player.shortName) is in position.", tone: .success))
            advanceClueIfSolved()

            // Hall of Famer pressure: the placement's clock stops dead and the
            // next unsolved placement gets a fresh 40 seconds.
            playClock?.stop()
            persistClockSnapshot()
            if remainingPlayers.isEmpty {
                // Every player accounted for — the case itself is closed.
                AudioManager.shared.play(.caseSolved)
                finish(with: .won)
            } else {
                beginPlacementClock()
            }
        } else {
            lives = isTraining ? lives : max(0, lives - 1)
            rejectedSlotID = slot.id
            rejectionCount += 1
            persistClockSnapshot()
            BalanceTelemetry.shared.recordWrongPlacement(caseID: puzzle.id)
            Haptics.error()
            AudioManager.shared.play(.placementWrong)
            if isTraining {
                // Mistakes explain the mechanic and let the player continue —
                // the tutorial can never be permanently failed.
                show(
                    FeedbackMessage(
                        title: "NOT QUITE — RE-READ THE CLUE",
                        detail: "No heart is lost in training. In real games a wrong placement costs a heart. The clue describes what the play needs, and the evidence marks the spot.",
                        tone: .info
                    ),
                    duration: 3.4
                )
            } else {
                show(FeedbackMessage(title: "THAT DOESN'T FIT THE EVIDENCE", detail: nil, tone: .failure))
            }

            let rejected = slot.id
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(700))
                if self?.rejectedSlotID == rejected { self?.rejectedSlotID = nil }
            }

            if !isTraining, lives == 0 {
                offerLastChanceOrFinish()
            }
        }
    }

    private func advanceClueIfSolved() {
        guard let clue = currentClue, isClueSolved(clue) else { return }
        if let next = puzzle.clues.firstIndex(where: { !isClueSolved($0) }) {
            currentClueIndex = next
        }
    }

    private func finish(with outcome: PuzzleResult) {
        stopPressureClocks()
        clearClockSnapshot()
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(1100))
            guard let self, self.result == .inProgress else { return }
            withAnimation(.easeInOut(duration: 0.45)) {
                self.result = outcome
            }
            if outcome == .won {
                Haptics.success()
                AudioManager.shared.play(.quarterWon)
            } else {
                Haptics.warning()
                AudioManager.shared.play(.quarterLost)
                BalanceTelemetry.shared.recordQuarterFailure(
                    caseID: self.puzzle.id,
                    difficulty: DifficultyManager.shared.selected.title
                )
            }
        }
    }

    // MARK: Hall of Famer pressure clock

    /// Starts the fresh 40-second clock for the current placement — only when
    /// the quarter is timed, live, and the intro has been dismissed.
    func beginPlacementClock() {
        guard isTimed, result == .inProgress, !isTraining, !isPaused,
              !isLastChancePending, !isClockIntroPresented, timeoutClock == nil else { return }
        playClock?.startFresh()
    }

    /// First-time explanation dismissed: persist that, and only now let the
    /// first play clock run.
    func dismissClockIntro() {
        guard isClockIntroPresented else { return }
        isClockIntroPresented = false
        defaults.set(true, forKey: Self.clockIntroKey)
        Haptics.tick()
        AudioManager.shared.play(.buttonPress)
        beginPlacementClock()
    }

    /// External pause (backgrounding, ads, StoreKit, achievement popups,
    /// blocking dialogs, transitions). Freezes the exact remaining value —
    /// an external UI event never consumes play-clock time.
    func suspendPlayClock(for reason: PlayClockController.SuspendReason) {
        playClock?.suspend(reason: reason)
        timeoutClock?.suspend(reason: reason)
        persistClockSnapshot()
    }

    /// Lifts an external pause; the clock resumes from its preserved value.
    func resumePlayClock(for reason: PlayClockController.SuspendReason) {
        playClock?.resume(reason: reason)
        timeoutClock?.resume(reason: reason)
    }

    /// Calls one of the quarter's two timeouts: freezes the play clock at its
    /// exact remaining value and starts a separate 25-second timeout clock.
    func callTimeout() {
        guard isTimed, result == .inProgress, !isTraining, timeoutsRemaining > 0,
              timeoutClock == nil, let clock = playClock, clock.isActive, !isPaused,
              !isLastChancePending, !isClockIntroPresented else { return }
        timeoutsRemaining -= 1
        clock.suspend(reason: .timeout)
        let timeout = makeClock(Self.timeoutDuration)
        timeout.onExpire = { [weak self] in self?.endTimeout(resumeClock: true) }
        timeoutClock = timeout
        timeout.startFresh()
        Haptics.tick()
        AudioManager.shared.play(.buttonPress)
        persistClockSnapshot()
    }

    /// RESUME PLAY: ends the timeout early (or at its 25s expiry) and returns
    /// the play clock from its preserved value — never a reset to 40.
    func resumePlay() {
        endTimeout(resumeClock: true)
    }

    private func endTimeout(resumeClock: Bool) {
        guard timeoutClock != nil else { return }
        timeoutClock?.stop()
        timeoutClock = nil
        if resumeClock { playClock?.resume(reason: .timeout) }
        persistClockSnapshot()
    }

    /// The play clock hit zero: one failed attempt, exactly one life gone,
    /// no answer revealed, the drag returned to the tray and the zone UI
    /// cleared. A fresh 40 seconds starts while the quarter is still live.
    private func handlePlayClockExpiration() {
        guard result == .inProgress, !isTraining else { return }
        cancelDrag()
        rejectedSlotID = nil
        lives = max(0, lives - 1)
        rejectionCount += 1
        BalanceTelemetry.shared.recordWrongPlacement(caseID: puzzle.id)
        Haptics.error()
        AudioManager.shared.play(.placementWrong)
        show(FeedbackMessage(
            title: "PLAY CLOCK EXPIRED",
            detail: lives > 0 ? "The drive moved on. Pick a player and line them up again." : nil,
            tone: .failure
        ))
        if lives == 0 {
            persistClockSnapshot()
            offerLastChanceOrFinish()
        } else {
            beginPlacementClock()
            persistClockSnapshot()
        }
    }

    private func stopPressureClocks() {
        playClock?.stop()
        timeoutClock?.stop()
        timeoutClock = nil
    }

    // MARK: Investigation snapshot (anti-exploit persistence)

    /// Persists the whole live quarter state — solved placements, lives,
    /// consumed hint leads, timeouts and the frozen remaining play clock —
    /// for every difficulty, so leaving mid-investigation resumes exactly
    /// where things stood (a force-quit can never respawn consumed state).
    private func persistClockSnapshot() {
        let snapshot = InvestigationSnapshot(
            matchKey: lastChanceKey,
            caseID: puzzle.id,
            isTimed: isTimed,
            remaining: playClock?.remaining ?? 0,
            timeoutsRemaining: timeoutsRemaining,
            lives: lives,
            placedPlayerIDs: placements.map(\.player.id),
            usedHintIDs: Array(usedHintIDs)
        )
        SaveStore.save(snapshot, key: Self.clockSnapshotKey, defaults: defaults)
    }

    private func clearClockSnapshot() {
        defaults.removeObject(forKey: Self.clockSnapshotKey)
    }

    /// Restores lost lives, solved placements, consumed hint leads, consumed
    /// timeouts and the frozen remaining clock for the same match+quarter —
    /// a force-quit can never respawn them fresh.
    private func restoreClockSnapshotIfMatching() {
        guard let snapshot = SaveStore.load(
                  InvestigationSnapshot.self,
                  key: Self.clockSnapshotKey,
                  defaults: defaults
              ),
              snapshot.matchKey == lastChanceKey,
              snapshot.caseID == puzzle.id else { return }
        lives = min(puzzle.startingLives, snapshot.lives)
        timeoutsRemaining = snapshot.timeoutsRemaining
        placements = snapshot.placedPlayerIDs.compactMap { playerID in
            guard let player = puzzle.player(id: playerID),
                  let solution = puzzle.solutions[playerID],
                  let slot = puzzle.slot(id: solution.slotID) else { return nil }
            return PlacedPlayer(player: player, profile: solution.profile, slot: slot)
        }
        usedHintIDs.formUnion(snapshot.usedHintIDs)
        if snapshot.isTimed {
            playClock?.restore(remaining: snapshot.remaining)
        }
    }

    // MARK: Hints (persistent economy)

    var canUseHint: Bool {
        hintsRemaining > 0 && result == .inProgress && nextHint != nil
    }

    private var nextHint: PuzzleHint? {
        let solved = solvedPlayerIDs
        let order = puzzle.clues.map(\.playerID)
        return puzzle.hints
            .filter { !solved.contains($0.playerID) && !usedHintIDs.contains($0.id) }
            .min { (order.firstIndex(of: $0.playerID) ?? 0) < (order.firstIndex(of: $1.playerID) ?? 0) }
    }

    /// Consumes one persistent hint and reveals the next lead. With an empty
    /// wallet this opens the NEED A HINT? offer instead of a dead-end warning.
    func useHint() {
        guard hintsRemaining > 0 else {
            Haptics.warning()
            withAnimation(.easeOut(duration: 0.2)) { isHintOfferPresented = true }
            return
        }
        guard nextHint != nil, result == .inProgress else {
            show(FeedbackMessage(title: "NO NEW LEADS", detail: nil, tone: .info))
            return
        }
        guard wallet.consumeHint() else { return }
        hintsRemaining = wallet.hints
        revealNextHint()
    }

    private func revealNextHint() {
        guard let hint = nextHint, result == .inProgress else { return }
        BalanceTelemetry.shared.recordHintUsed(caseID: puzzle.id)
        usedHintIDs.insert(hint.id)
        persistClockSnapshot()
        usedHints.append(UsedHint(id: hint.id, playerID: hint.playerID, text: hint.text, date: .now))
        if let index = puzzle.clues.firstIndex(where: { $0.playerID == hint.playerID }) {
            currentClueIndex = index
        }
        Haptics.soft()
        AudioManager.shared.play(.hintUsed)
        show(FeedbackMessage(title: "NEW LEAD", detail: hint.text, tone: .lead), duration: 4.2)
    }

    /// Grants exactly one rewarded-ad hint and immediately reveals the lead —
    /// only ever called after the ad's reward callback fired.
    func grantRewardedHint() {
        guard wallet.addHints(1) else { return }
        hintsRemaining = wallet.hints
        revealNextHint()
    }

    /// Called after a Game Ball hint purchase in the offer sheet.
    func hintPurchased() {
        hintsRemaining = wallet.hints
        withAnimation(.easeOut(duration: 0.2)) { isHintOfferPresented = false }
        revealNextHint()
    }

    func dismissHintOffer() {
        withAnimation(.easeOut(duration: 0.2)) { isHintOfferPresented = false }
    }

    // MARK: Last Chance (rewarded life)

    /// The final heart is gone. Each quarter may offer exactly one rewarded
    /// extra life; otherwise the verdict lands immediately.
    private func offerLastChanceOrFinish() {
        if wallet.markLastChanceUsed(for: lastChanceKey) {
            withAnimation(.easeInOut(duration: 0.3)) { isLastChancePending = true }
        } else {
            finish(with: .lost)
        }
    }

    /// Only ever called after the rewarded ad's reward callback fired.
    func grantLastChanceLife() {
        guard isLastChancePending else { return }
        isLastChancePending = false
        lives = 1
        // The earned life restarts the current placement with a fresh 40
        // seconds. Consumed timeouts stay consumed.
        beginPlacementClock()
        Haptics.success()
        AudioManager.shared.play(.placementCorrect)
        show(FeedbackMessage(title: "SECOND CHANCE", detail: "One more attempt. Make it count.", tone: .lead), duration: 2.4)
    }

    func acceptLastChanceLoss() {
        isLastChancePending = false
        finish(with: .lost)
    }

    // MARK: Evidence

    func inspect(_ evidence: EvidenceItem) {
        Haptics.tick()
        let id = evidence.id
        withAnimation(.snappy) {
            inspectedEvidenceID = inspectedEvidenceID == id ? nil : id
        }
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(2))
            if self?.inspectedEvidenceID == id {
                withAnimation(.snappy) { self?.inspectedEvidenceID = nil }
            }
        }
    }

    // MARK: Flow

    /// Resets the quarter to its opening state. DEBUG/QA ONLY — production
    /// gameplay never exposes a restart (compiled out of Release builds).
    /// Restarting a live investigation would let a player dodge losses,
    /// reset wrong attempts and protect accuracy stats.
#if DEBUG
    func restart() {
        feedbackTask?.cancel()
        withAnimation(.easeInOut) {
            lives = puzzle.startingLives
            // Hints persist across restarts — the wallet is never refilled.
            hintsRemaining = wallet.hints
            isHintOfferPresented = false
            isLastChancePending = false
            usedHints = []
            usedHintIDs = []
            placements = []
            selectedProfiles = [:]
            result = .inProgress
            feedback = nil
            expandedPlayerID = nil
            currentClueIndex = 0
            isPaused = false
            draggingPlayerID = nil
            hoveredSlotID = nil
            rejectedSlotID = nil
            lastPlacedPlayerID = nil
            // Timeouts reset with the quarter; the clock starts fresh.
            timeoutsRemaining = isTimed ? Self.timeoutsPerQuarter : 0
            clearClockSnapshot()
        }
        beginPlacementClock()
    }
#endif

    // MARK: Feedback

    func show(_ message: FeedbackMessage, duration: Double = 1.6) {
        feedbackTask?.cancel()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            feedback = message
        }
        let id = message.id
        feedbackTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled, self?.feedback?.id == id else { return }
            withAnimation(.easeOut(duration: 0.25)) { self?.feedback = nil }
        }
    }

    func dismissFeedback() {
        withAnimation(.easeOut(duration: 0.2)) { feedback = nil }
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }
}

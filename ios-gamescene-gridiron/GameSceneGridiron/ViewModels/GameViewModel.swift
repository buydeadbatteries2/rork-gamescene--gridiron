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
    var lastChanceKey: String = "standalone-quarter"
    /// True while the final heart is gone but the Last Chance offer is up —
    /// the quarter verdict waits for the player's choice.
    private(set) var isLastChancePending = false
    private(set) var usedHints: [UsedHint] = []
    private(set) var placements: [PlacedPlayer] = []
    private(set) var selectedVariants: [String: PlayerVariant] = [:]
    private(set) var result: PuzzleResult = .inProgress
    private(set) var feedback: FeedbackMessage?

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

    private var usedHintIDs: Set<String> = []
    /// Prevents repeated warnings while a blocked drag gesture keeps firing.
    private var blockedDragPlayerID: String?
    private var feedbackTask: Task<Void, Never>?

    init(puzzle: QuarterPuzzle = SampleQuarter.puzzle, wallet: PlayerWallet = .shared) {
        self.puzzle = puzzle
        self.wallet = wallet
        self.lives = puzzle.startingLives
        self.hintsRemaining = wallet.hints
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

    func selectedVariant(for playerID: String) -> PlayerVariant? {
        selectedVariants[playerID]
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

    func selectVariant(_ variant: PlayerVariant, for playerID: String) {
        guard result == .inProgress else { return }
        Haptics.tick()
        AudioManager.shared.play(.profileSelect)
        expandedPlayerID = playerID
        if selectedVariants[playerID] == variant {
            selectedVariants[playerID] = nil
        } else {
            selectedVariants[playerID] = variant
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

    /// Returns false when a drag isn't allowed yet (e.g. no variant chosen).
    @discardableResult
    func beginDrag(playerID: String, at location: CGPoint) -> Bool {
        guard result == .inProgress, !isPaused else { return false }
        guard blockedDragPlayerID != playerID else { return false }
        guard selectedVariants[playerID] != nil else {
            blockedDragPlayerID = playerID
            expandedPlayerID = playerID
            Haptics.warning()
            show(FeedbackMessage(title: "PICK A PROFILE FIRST", detail: "Choose Fast, Power or Veteran.", tone: .info))
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
              let variant = selectedVariants[playerID] else {
            return
        }
        evaluate(player: player, variant: variant, slot: slot)
    }

    func cancelDrag() {
        blockedDragPlayerID = nil
        draggingPlayerID = nil
        hoveredSlotID = nil
    }

    private func evaluate(player: FootballPlayer, variant: PlayerVariant, slot: PlacementSlot) {
        let solution = puzzle.solutions[player.id]
        let isCorrect = solution?.slotID == slot.id && solution?.variant == variant

        if isCorrect {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) {
                placements.append(PlacedPlayer(player: player, variant: variant, slot: slot))
                expandedPlayerID = nil
                lastPlacedPlayerID = player.id
            }
            Haptics.success()
            AudioManager.shared.play(.placementCorrect)
            show(FeedbackMessage(title: "GOOD READ", detail: "\(player.position.rawValue) \(player.shortName) is in position.", tone: .success))
            advanceClueIfSolved()

            if remainingPlayers.isEmpty {
                // Every player accounted for — the case itself is closed.
                AudioManager.shared.play(.caseSolved)
                finish(with: .won)
            }
        } else {
            lives = max(0, lives - 1)
            rejectedSlotID = slot.id
            rejectionCount += 1
            Haptics.error()
            AudioManager.shared.play(.placementWrong)
            show(FeedbackMessage(title: "THAT DOESN'T FIT THE EVIDENCE", detail: nil, tone: .failure))

            let rejected = slot.id
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(700))
                if self?.rejectedSlotID == rejected { self?.rejectedSlotID = nil }
            }

            if lives == 0 {
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
            }
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
        usedHintIDs.insert(hint.id)
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
            selectedVariants = [:]
            result = .inProgress
            feedback = nil
            expandedPlayerID = nil
            currentClueIndex = 0
            isPaused = false
            draggingPlayerID = nil
            hoveredSlotID = nil
            rejectedSlotID = nil
            lastPlacedPlayerID = nil
        }
    }

    // MARK: Feedback

    private func show(_ message: FeedbackMessage, duration: Double = 1.6) {
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

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

    private(set) var lives: Int
    private(set) var hintsRemaining: Int
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

    init(puzzle: QuarterPuzzle = SampleQuarter.puzzle) {
        self.puzzle = puzzle
        self.lives = puzzle.startingLives
        self.hintsRemaining = puzzle.startingHints
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
        let nearest = openSlots
            .map { slot in (slot, distance(point(x: slot.x, y: slot.y), tokenPoint)) }
            .filter { $0.1 <= Self.snapRadius }
            .min { $0.1 < $1.1 }
        let newHover = nearest?.0.id
        if newHover != hoveredSlotID {
            hoveredSlotID = newHover
            if newHover != nil { Haptics.soft() }
        }
    }

    func endDrag() {
        blockedDragPlayerID = nil
        guard let playerID = draggingPlayerID else { return }
        let slotID = hoveredSlotID
        draggingPlayerID = nil
        hoveredSlotID = nil

        guard let slotID,
              let slot = puzzle.slot(id: slotID),
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
                finish(with: .lost)
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

    // MARK: Hints

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

    func useHint() {
        guard hintsRemaining > 0 else {
            Haptics.warning()
            show(FeedbackMessage(title: "NO HINTS LEFT", detail: "Trust the evidence.", tone: .info))
            return
        }
        guard let hint = nextHint, result == .inProgress else {
            show(FeedbackMessage(title: "NO NEW LEADS", detail: nil, tone: .info))
            return
        }
        hintsRemaining -= 1
        usedHintIDs.insert(hint.id)
        usedHints.append(UsedHint(id: hint.id, playerID: hint.playerID, text: hint.text, date: .now))
        if let index = puzzle.clues.firstIndex(where: { $0.playerID == hint.playerID }) {
            currentClueIndex = index
        }
        Haptics.soft()
        AudioManager.shared.play(.hintUsed)
        show(FeedbackMessage(title: "NEW LEAD", detail: hint.text, tone: .lead), duration: 4.2)
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
            hintsRemaining = puzzle.startingHints
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

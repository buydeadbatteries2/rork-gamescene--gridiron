import SwiftUI

/// The guided TRAINING CASE coach: a one-mechanic-at-a-time step machine laid
/// over the real gameplay engine. Every step is interactive — the user performs
/// the action while it is explained; nothing becomes a wall of text.
///
/// The session never fails permanently: `GameViewModel.isTraining` keeps hearts
/// out of play, and hints draw from a disposable wallet.
@Observable
final class TrainingSession {
    enum Step: Equatable {
        case inspectPlayer   // gate: tap a missing-player card
        case profiles        // explain FAST / POWER / VETERAN
        case readClue        // highlight the Case File, decode the example clue
        case dragPlayer      // hold + drag; zones appear; guided target glows
        case evidence        // after placement 1 — field evidence lesson
        case lives           // brief hearts explanation
        case freePlay        // no banner — place the corner
        case relational      // after placement 2 — chained-clue lesson
        case hints           // after placement 3 — highlight the hint button
        case complete        // completion screen
    }

    private(set) var step: Step = .inspectPlayer

    /// Explicit completion state: true only once the final objective is solved.
    /// The completion card reads this — never the presence of a coach overlay.
    var isComplete: Bool { step == .complete }

    let viewModel: GameViewModel

    init(viewModel: GameViewModel) {
        self.viewModel = viewModel
    }

    // MARK: Advancement

    /// The inspect gate: the first tap on a missing-player card advances.
    func handleExpansion() {
        guard step == .inspectPlayer, viewModel.expandedPlayerID != nil else { return }
        step = .profiles
    }

    func confirmProfiles() { if step == .profiles { step = .readClue } }
    func confirmClue() { if step == .readClue { step = .dragPlayer } }
    func confirmEvidence() { if step == .evidence { step = .lives } }
    func confirmLives() { if step == .lives { step = .freePlay } }
    func confirmRelational() { if step == .relational { step = .freePlay } }
    func confirmHints() { if step == .hints { step = .complete } }

    /// GOT IT tapped on the currently visible banner — advances whichever
    /// lesson is showing (no-op for action-waiting steps).
    func advancePastCurrentStep() {
        switch step {
        case .profiles: confirmProfiles()
        case .readClue: confirmClue()
        case .evidence: confirmEvidence()
        case .lives: confirmLives()
        case .relational: confirmRelational()
        case .hints: confirmHints()
        case .inspectPlayer, .dragPlayer, .freePlay, .complete: break
        }
    }

    /// Completing the case freezes the coaching: every highlight and prompt is
    /// derived from the step, so `.complete` is already a quiet board.

    /// Called on every placement-count change from the view.
    func placementsChanged() {
        switch viewModel.placements.count {
        case 1 where step == .dragPlayer:
            step = .evidence
        case 2 where step == .freePlay || step == .evidence || step == .lives:
            step = .relational
        case 3 where step == .freePlay || step == .relational:
            step = .hints
        default:
            break
        }
    }

    // MARK: Highlight state (read by the gameplay views)

    /// The missing-player card the coach wants tapped.
    var highlightedPlayerID: String? {
        (step == .inspectPlayer || step == .profiles || step == .dragPlayer)
            ? viewModel.remainingPlayers.first?.id
            : nil
    }

    var isCaseFileHighlighted: Bool { step == .readClue }

    var isHintHighlighted: Bool { step == .hints }

    /// While dragging during the drag lesson, the correct tutorial target
    /// gets a subtle extra glow — guidance, never an auto-solve.
    var guidedSlotID: String? {
        guard step == .dragPlayer, viewModel.isDragging, let player = viewModel.draggingPlayer else { return nil }
        return viewModel.puzzle.solutions[player.id]?.slotID
    }

    /// The pylon glows during the field-evidence lesson (second placement).
    var highlightedEvidenceID: String? {
        step == .evidence ? "\(TrainingCase.authored.id)-e-pylon" : nil
    }

    // MARK: Coach copy

    struct Message: Equatable {
        let title: String
        let detail: String
        /// nil = the banner waits for the user to perform the action.
        let buttonTitle: String?
    }

    var coach: Message? {
        switch step {
        case .inspectPlayer:
            Message(title: "MEET THE MISSING", detail: "Tap a player to inspect their profiles.", buttonTitle: nil)
        case .profiles:
            Message(
                title: "THREE PROFILES",
                detail: "FAST — best when speed and quick reaction matter. POWER — best when strength and physical play matter. VETERAN — best when awareness and experience matter. The same position may require a different profile in different cases.",
                buttonTitle: "GOT IT"
            )
        case .readClue:
            Message(
                title: "READ THE CLUE",
                detail: "The clue describes what the play needs — not always the exact answer. Quick suggests Fast. Back suggests RB. The orange cone helps identify the location.",
                buttonTitle: "GOT IT"
            )
        case .dragPlayer:
            viewModel.isDragging
                ? Message(title: "ZONES APPEAR", detail: "Placement spots only appear while dragging. Drop him on the glowing zone beside the orange cone.", buttonTitle: nil)
                : Message(title: "DRAG TO THE FIELD", detail: "Hold the player, then drag them onto the field.", buttonTitle: nil)
        case .evidence:
            Message(title: "FIELD EVIDENCE", detail: "Objects on the field are evidence. Their location matters. The pylon marks where the corner waits.", buttonTitle: "GOT IT")
        case .lives:
            Message(title: "HEARTS", detail: "Wrong placements cost a heart. Losing all hearts loses the quarter — not the whole game. In training, hearts are never at stake.", buttonTitle: "GOT IT")
        case .freePlay:
            nil
        case .relational:
            Message(title: "CHAINED CLUES", detail: "Some clues only make sense after another player is placed. Deeper than the corner needed the corner first. Place the safety by the laminated play sheet.", buttonTitle: "GOT IT")
        case .hints:
            Message(title: "HINTS", detail: "Hints give another piece of evidence without revealing the answer. You never have to spend one.", buttonTitle: "GOT IT")
        case .complete:
            nil
        }
    }
}

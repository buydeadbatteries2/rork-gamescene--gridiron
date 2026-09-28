import Foundation

/// Handcrafted Phase 1 sample quarter — VERTICAL field orientation.
///
/// Field coordinates are normalized to the turf rectangle:
/// - x: 0 = LEFT sideline, 1 = RIGHT sideline. Sidelines run vertically.
/// - y: 0 = deepest defensive territory (top of the screen), 1 = deepest offensive
///   backfield (bottom of the screen). Depth increases toward the TOP.
/// - Line of scrimmage ≈ y 0.52 (offense lines up below it, defense above it).
///
/// Solution walkthrough (unique):
/// 1. RB Fast    → deep backfield behind the QB (y≈0.78), next to the orange towel.
/// 2. FS Veteran → deepest slot dead center (y≈0.115), water bottle at his back.
/// 3. TE Power   → shoulder to shoulder with the right tackle (x≈0.775), the glove side.
/// 4. WR Veteran → split wide on the RIGHT sideline (visible WR is on the left).
/// 5. CB Power   → directly across that WR, loose football at his feet.
/// 6. LB Fast    → behind the defensive line on the right (strong) side, in front of
///    the safeties but behind the line, by the muddy footprints.
/// Decoy slots (left backfield, left backer, deep right) are never correct.
enum SampleQuarter {
    static let puzzle = QuarterPuzzle(
        id: "sample-q1",
        quarterLabel: "Q1",
        title: "The Towel on the 38",
        startingLives: 3,
        startingHints: 3,
        visiblePlayers: visiblePlayers,
        missingPlayers: missingPlayers,
        evidence: evidence,
        slots: slots,
        clues: clues,
        hints: hints,
        solutions: [
            "p-rb": PlacementSolution(slotID: "s-backfield", variant: .fast),
            "p-fs": PlacementSolution(slotID: "s-deep-middle", variant: .veteran),
            "p-te": PlacementSolution(slotID: "s-right-edge", variant: .power),
            "p-wr": PlacementSolution(slotID: "s-right-wide", variant: .veteran),
            "p-cb": PlacementSolution(slotID: "s-right-corner", variant: .power),
            "p-lb": PlacementSolution(slotID: "s-right-backer", variant: .fast)
        ]
    )

    // Offense occupies the bottom half (y > 0.52); defense the top half (y < 0.52).
    private static let visiblePlayers: [FieldPlayer] = [
        // Offense — offensive line just below the line of scrimmage
        FieldPlayer(id: "v-lt", position: .ol, x: 0.30, y: 0.565),
        FieldPlayer(id: "v-lg", position: .ol, x: 0.40, y: 0.565),
        FieldPlayer(id: "v-c", position: .ol, x: 0.50, y: 0.565),
        FieldPlayer(id: "v-rg", position: .ol, x: 0.60, y: 0.565),
        FieldPlayer(id: "v-rt", position: .ol, x: 0.70, y: 0.565),
        // Quarterback under center, in front of the backfield
        FieldPlayer(id: "v-qb", position: .qb, x: 0.50, y: 0.68),
        // Wide receiver split out by the LEFT sideline, on the line of scrimmage
        FieldPlayer(id: "v-wr", position: .wr, x: 0.075, y: 0.52),
        // Defense — front four just past the line of scrimmage
        FieldPlayer(id: "v-de1", position: .dl, x: 0.28, y: 0.475),
        FieldPlayer(id: "v-dt1", position: .dl, x: 0.42, y: 0.475),
        FieldPlayer(id: "v-dt2", position: .dl, x: 0.58, y: 0.475),
        FieldPlayer(id: "v-de2", position: .dl, x: 0.72, y: 0.475),
        // Middle linebacker, in front of the safeties
        FieldPlayer(id: "v-mlb", position: .lb, x: 0.50, y: 0.36),
        // Corner across the visible (left) receiver
        FieldPlayer(id: "v-cb", position: .cb, x: 0.075, y: 0.435),
        // Strong safety, deeper, leaning to the strong (right) side
        FieldPlayer(id: "v-ss", position: .ss, x: 0.62, y: 0.27)
    ]

    private static let missingPlayers: [FootballPlayer] = [
        FootballPlayer(id: "p-wr", name: "Damon Ellis", position: .wr, cardAsset: "football_receiver_portrait"),
        FootballPlayer(id: "p-rb", name: "Marcus Reed", position: .rb, cardAsset: "football_running_back"),
        FootballPlayer(id: "p-te", name: "Evan Cole", position: .te, cardAsset: "football_player_portrait_6"),
        FootballPlayer(id: "p-lb", name: "Tomas Vega", position: .lb, cardAsset: "linebacker_helmet_portrait"),
        FootballPlayer(id: "p-cb", name: "Jae Park", position: .cb, cardAsset: "cornerback_portrait"),
        FootballPlayer(id: "p-fs", name: "Andre Knox", position: .fs, cardAsset: "football_safety_portrait")
    ]

    private static let evidence: [EvidenceItem] = [
        EvidenceItem(id: "e-towel", kind: .orangeTowel, x: 0.55, y: 0.84, rotation: -18),
        EvidenceItem(id: "e-glove", kind: .droppedGlove, x: 0.86, y: 0.635, rotation: 28),
        EvidenceItem(id: "e-bottle", kind: .waterBottle, x: 0.53, y: 0.045, rotation: 72),
        EvidenceItem(id: "e-mud", kind: .muddyFootprints, x: 0.70, y: 0.29, rotation: 62),
        EvidenceItem(id: "e-ball", kind: .looseFootball, x: 0.955, y: 0.40, rotation: 14)
    ]

    private static let slots: [PlacementSlot] = [
        PlacementSlot(id: "s-backfield", x: 0.50, y: 0.78),        // RB (correct)
        PlacementSlot(id: "s-left-backfield", x: 0.34, y: 0.70),   // decoy
        PlacementSlot(id: "s-right-edge", x: 0.775, y: 0.565),     // TE (correct)
        PlacementSlot(id: "s-right-wide", x: 0.925, y: 0.535),     // WR (correct)
        PlacementSlot(id: "s-right-corner", x: 0.925, y: 0.435),   // CB (correct)
        PlacementSlot(id: "s-right-backer", x: 0.63, y: 0.365),    // LB (correct)
        PlacementSlot(id: "s-left-backer", x: 0.37, y: 0.365),     // decoy
        PlacementSlot(id: "s-deep-right", x: 0.84, y: 0.17),       // decoy
        PlacementSlot(id: "s-deep-middle", x: 0.50, y: 0.115)      // FS (correct)
    ]

    private static let clues: [PuzzleClue] = [
        PuzzleClue(
            id: 1,
            text: "A quick back is needed to exploit the opening. Line him up near the orange towel, deeper in the backfield than the quarterback.",
            difficulty: .easy,
            playerID: "p-rb"
        ),
        PuzzleClue(
            id: 2,
            text: "The last line of defense has seen every trick in the book. He sits deeper than anyone, dead center of the field, with the water bottle at his back.",
            difficulty: .easy,
            playerID: "p-fs"
        ),
        PuzzleClue(
            id: 3,
            text: "The quarterback wanted an extra blocker shoulder to shoulder with his last lineman on the right side of the line — the same sideline as the dropped glove. Whoever stands there has to be strong enough to seal a defensive end.",
            difficulty: .medium,
            playerID: "p-te"
        ),
        PuzzleClue(
            id: 4,
            text: "Our other target doesn't beat anyone with speed. He wins with twelve seasons of film study, split out wide on the opposite sideline from the receiver you can already see.",
            difficulty: .medium,
            playerID: "p-wr"
        ),
        PuzzleClue(
            id: 5,
            text: "Whoever covers that seasoned route runner can't give him a clean release. He lines up directly across from him, just past the line of scrimmage, and the loose football at his feet shows how physical it got.",
            difficulty: .hard,
            playerID: "p-cb"
        ),
        PuzzleClue(
            id: 6,
            text: "The muddy footprints belong to the defender who has to run down our quick back if he bounces outside. He lines up behind the defensive line on the right side — where the extra blocker waits — in front of the safeties, but still behind the line.",
            difficulty: .hard,
            playerID: "p-lb"
        )
    ]

    private static let hints: [PuzzleHint] = [
        PuzzleHint(id: "h-rb", playerID: "p-rb", text: "The towel lies near the bottom of the field, right behind the quarterback. Deeper in the backfield than that is the spot."),
        PuzzleHint(id: "h-fs", playerID: "p-fs", text: "Only one open spot is dead center and deeper than the strong safety. Look near the top of the field."),
        PuzzleHint(id: "h-te", playerID: "p-te", text: "Shoulder to shoulder means no gap at all between him and the last lineman on the right side of the line."),
        PuzzleHint(id: "h-wr", playerID: "p-wr", text: "The receiver you can see is split out by the LEFT sideline. This one goes on the RIGHT sideline, right on the line of scrimmage."),
        PuzzleHint(id: "h-cb", playerID: "p-cb", text: "A corner lines up directly across from the receiver he covers — same sideline, just across the line of scrimmage. Getting your hands on someone takes strength, not speed."),
        PuzzleHint(id: "h-lb", playerID: "p-lb", text: "The strong side is wherever the extra blocker stands. The footprints are behind the defensive line but in front of the safeties.")
    ]
}

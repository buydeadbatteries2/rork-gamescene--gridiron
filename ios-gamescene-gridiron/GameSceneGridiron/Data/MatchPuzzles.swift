import Foundation

/// The full Phase 2 game: four handcrafted regulation quarters plus one
/// handcrafted overtime puzzle. All data-driven through the existing
/// `QuarterPuzzle` engine — nothing about the quarters is hard-coded in views.
///
/// Difficulty ramps: Q1 introductory (2 easy / 3 medium / 1 hard),
/// Q2 relational adjustments (2 easy / 2 medium / 2 hard),
/// Q3 multi-player + evidence chains (4 medium / 2 hard),
/// Q4 clutch combinations (1 easy starter / 1 medium / 4 hard),
/// OT dramatic finale (2 medium / 3 hard).
///
/// Field coordinates (all puzzles): x 0 = left sideline, 1 = right sideline;
/// y 0 = deepest defense (top), 1 = deepest offense (bottom); LOS ≈ y 0.52.
nonisolated enum MatchPuzzles {
    static let regulation: [QuarterPuzzle] = [
        SampleQuarter.puzzle,
        quarter2,
        quarter3,
        quarter4
    ]

    static let overtime: QuarterPuzzle = overtimePuzzle

    // MARK: - Q2 — The Silent Count

    /// A completely separate investigation from Q1: protection crisis with a
    /// missing passer, a missing lineman, and a defense that rotates a safety
    /// into the box. Shares no clue logic, hint text, formation or evidence
    /// layout with any other quarter.
    static let quarter2 = QuarterPuzzle(
        id: "match-q2",
        index: 1,
        quarterLabel: "Q2",
        title: "The Silent Count",
        introHeading: "PROTECTION CRISIS",
        introBody: "The line is patched, the huddle is silent. Read it before the snap.",
        startingLives: 3,
        startingHints: 3,
        visiblePlayers: q2Visible,
        missingPlayers: q2Missing,
        evidence: q2Evidence,
        slots: q2Slots,
        clues: q2Clues,
        hints: q2Hints,
        solutions: [
            "q2-qb": PlacementSolution(slotID: "q2-s-gun", variant: .fast),
            "q2-ol": PlacementSolution(slotID: "q2-s-right-guard", variant: .power),
            "q2-wr": PlacementSolution(slotID: "q2-s-right-wide", variant: .veteran),
            "q2-cb": PlacementSolution(slotID: "q2-s-right-corner", variant: .fast),
            "q2-de": PlacementSolution(slotID: "q2-s-edge-rush", variant: .fast),
            "q2-ss": PlacementSolution(slotID: "q2-s-box-right", variant: .veteran)
        ]
    )

    private static let q2Visible: [FieldPlayer] = [
        FieldPlayer(id: "q2-v-lt", position: .ol, x: 0.30, y: 0.565),
        FieldPlayer(id: "q2-v-lg", position: .ol, x: 0.40, y: 0.565),
        FieldPlayer(id: "q2-v-c", position: .ol, x: 0.50, y: 0.565),
        FieldPlayer(id: "q2-v-rt", position: .ol, x: 0.70, y: 0.565),
        FieldPlayer(id: "q2-v-te", position: .te, x: 0.775, y: 0.565),
        FieldPlayer(id: "q2-v-rb", position: .rb, x: 0.42, y: 0.68),
        FieldPlayer(id: "q2-v-wr", position: .wr, x: 0.075, y: 0.53),
        FieldPlayer(id: "q2-v-dt1", position: .dl, x: 0.42, y: 0.475),
        FieldPlayer(id: "q2-v-dt2", position: .dl, x: 0.58, y: 0.475),
        FieldPlayer(id: "q2-v-de2", position: .dl, x: 0.72, y: 0.475),
        FieldPlayer(id: "q2-v-mlb", position: .lb, x: 0.50, y: 0.36),
        FieldPlayer(id: "q2-v-fs", position: .fs, x: 0.50, y: 0.135),
        FieldPlayer(id: "q2-v-cb", position: .cb, x: 0.075, y: 0.435)
    ]

    private static let q2Missing: [FootballPlayer] = [
        FootballPlayer(id: "q2-qb", name: "Dane Whitlock", position: .qb, cardAsset: "football_player_blank_helmet"),
        FootballPlayer(id: "q2-ol", name: "Bruno Kaminski", position: .ol, cardAsset: "football_player_lineman"),
        FootballPlayer(id: "q2-wr", name: "Silas Barnes", position: .wr, cardAsset: "football_player_render"),
        FootballPlayer(id: "q2-cb", name: "Kofi Mensah", position: .cb, cardAsset: "football_player_backpedal"),
        FootballPlayer(id: "q2-de", name: "Ilya Varga", position: .dl, cardAsset: "football_player_defensive_end"),
        FootballPlayer(id: "q2-ss", name: "Ray Underwood", position: .ss, cardAsset: "football_player_blank_gear_2")
    ]

    private static let q2Evidence: [EvidenceItem] = [
        EvidenceItem(id: "q2-e-towel", kind: .orangeTowel, x: 0.13, y: 0.83, rotation: -18),
        EvidenceItem(id: "q2-e-ball", kind: .looseFootball, x: 0.545, y: 0.615, rotation: 8),
        EvidenceItem(id: "q2-e-glove", kind: .droppedGlove, x: 0.955, y: 0.585, rotation: 26),
        EvidenceItem(id: "q2-e-mud", kind: .muddyFootprints, x: 0.10, y: 0.295, rotation: 55),
        EvidenceItem(id: "q2-e-bottle", kind: .waterBottle, x: 0.90, y: 0.055, rotation: 70)
    ]

    private static let q2Slots: [PlacementSlot] = [
        PlacementSlot(id: "q2-s-gun", x: 0.50, y: 0.655),        // QB (correct)
        PlacementSlot(id: "q2-s-right-guard", x: 0.60, y: 0.565), // OL (correct)
        PlacementSlot(id: "q2-s-right-wide", x: 0.925, y: 0.53),  // WR (correct)
        PlacementSlot(id: "q2-s-right-corner", x: 0.925, y: 0.435), // CB (correct)
        PlacementSlot(id: "q2-s-edge-rush", x: 0.165, y: 0.465),  // DE (correct)
        PlacementSlot(id: "q2-s-box-right", x: 0.66, y: 0.295),   // SS (correct)
        PlacementSlot(id: "q2-s-left-backfield", x: 0.36, y: 0.72), // decoy
        PlacementSlot(id: "q2-s-deep-right", x: 0.82, y: 0.155),  // decoy
        PlacementSlot(id: "q2-s-left-slot", x: 0.205, y: 0.525),  // decoy
        PlacementSlot(id: "q2-s-mike-left", x: 0.34, y: 0.365)    // decoy
    ]

    private static let q2Clues: [PuzzleClue] = [
        PuzzleClue(
            id: 1,
            text: "The center's hands are empty and the loose football lies four yards behind the line, dead center. The passer who takes it can leave the pocket at a sprint — this offense wants legs, not a statue.",
            difficulty: .easy,
            playerID: "q2-qb"
        ),
        PuzzleClue(
            id: 2,
            text: "There's a gap in the wall: one interior lineman is missing between the center and the right tackle, shoulder to shoulder with both. Whoever fills it anchors against a bull rush — strength, nothing else.",
            difficulty: .medium,
            playerID: "q2-ol"
        ),
        PuzzleClue(
            id: 3,
            text: "Our visible target owns the left sideline. The new one mirrors him across the field, right on the line of scrimmage beside the dropped glove — a timing technician who wins with route discipline, not wheels.",
            difficulty: .medium,
            playerID: "q2-wr"
        ),
        PuzzleClue(
            id: 4,
            text: "Straight across that new target — same sideline, just past the line of scrimmage. Nobody helps over the top on that island, so recovery speed is the only requirement.",
            difficulty: .medium,
            playerID: "q2-cb"
        ),
        PuzzleClue(
            id: 5,
            text: "The defense attacks the short wall: their widest rusher stands up beyond the tackles on the side away from the tight end, hunting the edge at full sprint. The muddy footprints on the left mark his lane.",
            difficulty: .hard,
            playerID: "q2-de"
        ),
        PuzzleClue(
            id: 6,
            text: "The deep men split the field's duties. One stays tall at the very top of the picture. The other crashes down into the box on the right, between the front and the second level — ten years of reads, packing against the run.",
            difficulty: .hard,
            playerID: "q2-ss"
        )
    ]

    private static let q2Hints: [PuzzleHint] = [
        PuzzleHint(id: "q2-h-qb", playerID: "q2-qb", text: "Dead center in the shotgun, about four yards behind the ball on the line — the loose football marks the spot."),
        PuzzleHint(id: "q2-h-ol", playerID: "q2-ol", text: "Between the center and the right tackle. No daylight on either shoulder."),
        PuzzleHint(id: "q2-h-wr", playerID: "q2-wr", text: "The visible receiver is on the LEFT. This one takes the RIGHT sideline, on the line of scrimmage, next to the glove."),
        PuzzleHint(id: "q2-h-cb", playerID: "q2-cb", text: "Across from the new target on the far sideline, just past the line of scrimmage — an island with no help over the top."),
        PuzzleHint(id: "q2-h-de", playerID: "q2-de", text: "Standing up wider than every down lineman, on the left — the side away from the tight end. The footprints point to his lane."),
        PuzzleHint(id: "q2-h-ss", playerID: "q2-ss", text: "Dropped into the box on the right, between the line and the linebackers. The free safety stays deep alone.")
    ]

    // MARK: - Q3 — The Silent Bunch

    static let quarter3 = QuarterPuzzle(
        id: "match-q3",
        index: 2,
        quarterLabel: "Q3",
        title: "The Silent Bunch",
        introHeading: "MOMENTUM SHIFT",
        introBody: "The field has changed. Something doesn't add up.",
        startingLives: 3,
        startingHints: 3,
        visiblePlayers: q3Visible,
        missingPlayers: q3Missing,
        evidence: q3Evidence,
        slots: q3Slots,
        clues: q3Clues,
        hints: q3Hints,
        solutions: [
            "q3-wr": PlacementSolution(slotID: "q3-s-bunch-outside", variant: .fast),
            "q3-te": PlacementSolution(slotID: "q3-s-right-te", variant: .power),
            "q3-rb": PlacementSolution(slotID: "q3-s-rb-left", variant: .fast),
            "q3-cb": PlacementSolution(slotID: "q3-s-left-corner", variant: .power),
            "q3-slb": PlacementSolution(slotID: "q3-s-right-backer", variant: .veteran),
            "q3-ss": PlacementSolution(slotID: "q3-s-deep-center", variant: .veteran)
        ]
    )

    private static let q3Visible: [FieldPlayer] = [
        FieldPlayer(id: "q3-v-lt", position: .ol, x: 0.32, y: 0.565),
        FieldPlayer(id: "q3-v-lg", position: .ol, x: 0.42, y: 0.565),
        FieldPlayer(id: "q3-v-c", position: .ol, x: 0.52, y: 0.565),
        FieldPlayer(id: "q3-v-rg", position: .ol, x: 0.62, y: 0.565),
        FieldPlayer(id: "q3-v-rt", position: .ol, x: 0.72, y: 0.565),
        FieldPlayer(id: "q3-v-qb", position: .qb, x: 0.50, y: 0.72),
        FieldPlayer(id: "q3-v-wr1", position: .wr, x: 0.22, y: 0.53),
        FieldPlayer(id: "q3-v-wr2", position: .wr, x: 0.925, y: 0.52),
        FieldPlayer(id: "q3-v-de1", position: .dl, x: 0.28, y: 0.475),
        FieldPlayer(id: "q3-v-dt1", position: .dl, x: 0.42, y: 0.475),
        FieldPlayer(id: "q3-v-dt2", position: .dl, x: 0.58, y: 0.475),
        FieldPlayer(id: "q3-v-de2", position: .dl, x: 0.72, y: 0.475),
        FieldPlayer(id: "q3-v-mlb", position: .lb, x: 0.50, y: 0.36),
        FieldPlayer(id: "q3-v-wlb", position: .lb, x: 0.34, y: 0.36),
        FieldPlayer(id: "q3-v-cb", position: .cb, x: 0.925, y: 0.435),
        FieldPlayer(id: "q3-v-ss", position: .ss, x: 0.35, y: 0.24)
    ]

    private static let q3Missing: [FootballPlayer] = [
        FootballPlayer(id: "q3-wr", name: "Tobias Finch", position: .wr, cardAsset: "football_player_render"),
        FootballPlayer(id: "q3-te", name: "Gus Halloran", position: .te, cardAsset: "football_player_blank_helmet_2"),
        FootballPlayer(id: "q3-rb", name: "Devon Carter", position: .rb, cardAsset: "football_player_running_back_2"),
        FootballPlayer(id: "q3-cb", name: "Miles Okafor", position: .cb, cardAsset: "football_player_cornerback"),
        FootballPlayer(id: "q3-slb", name: "Pete Lindqvist", position: .lb, cardAsset: "football_player_linebacker"),
        FootballPlayer(id: "q3-ss", name: "Amos Delgado", position: .ss, cardAsset: "football_player_blank_gear_2")
    ]

    private static let q3Evidence: [EvidenceItem] = [
        EvidenceItem(id: "q3-e-towel", kind: .orangeTowel, x: 0.38, y: 0.79, rotation: -20),
        EvidenceItem(id: "q3-e-ball", kind: .looseFootball, x: 0.775, y: 0.615, rotation: 10),
        EvidenceItem(id: "q3-e-mud", kind: .muddyFootprints, x: 0.665, y: 0.29, rotation: 60),
        EvidenceItem(id: "q3-e-bottle", kind: .waterBottle, x: 0.50, y: 0.045, rotation: 75),
        EvidenceItem(id: "q3-e-glove", kind: .droppedGlove, x: 0.085, y: 0.47, rotation: 30)
    ]

    private static let q3Slots: [PlacementSlot] = [
        PlacementSlot(id: "q3-s-bunch-outside", x: 0.14, y: 0.52),   // WR (correct)
        PlacementSlot(id: "q3-s-left-corner", x: 0.14, y: 0.425),    // CB (correct)
        PlacementSlot(id: "q3-s-right-te", x: 0.775, y: 0.565),      // TE (correct)
        PlacementSlot(id: "q3-s-rb-left", x: 0.38, y: 0.70),         // RB (correct)
        PlacementSlot(id: "q3-s-right-backer", x: 0.68, y: 0.36),    // SLB (correct)
        PlacementSlot(id: "q3-s-deep-center", x: 0.50, y: 0.115),    // FS (correct)
        PlacementSlot(id: "q3-s-right-backfield", x: 0.62, y: 0.70), // decoy
        PlacementSlot(id: "q3-s-deep-left", x: 0.30, y: 0.17),       // decoy
        PlacementSlot(id: "q3-s-right-slot", x: 0.80, y: 0.44)       // decoy
    ]

    private static let q3Clues: [PuzzleClue] = [
        PuzzleClue(
            id: 1,
            text: "The quarterback works from the gun, and the orange towel still smells like pregame. The quick back lines up beside that towel, on the passer's left.",
            difficulty: .medium,
            playerID: "q3-rb"
        ),
        PuzzleClue(
            id: 2,
            text: "Extra muscle on the right: shoulder to shoulder with the right tackle, where the loose football at his feet tells you exactly how physical the last rep got. Strength over speed.",
            difficulty: .medium,
            playerID: "q3-te"
        ),
        PuzzleClue(
            id: 3,
            text: "Two receivers crowd the left sideline like a late-night huddle. The inside man is already in place — the fastest of them joins him on the outside, right on the line of scrimmage.",
            difficulty: .medium,
            playerID: "q3-wr"
        ),
        PuzzleClue(
            id: 4,
            text: "Across that bunch waits the defender assigned to the fastest receiver. He wins with his hands at the line, not his wheels — power, not pace.",
            difficulty: .hard,
            playerID: "q3-cb"
        ),
        PuzzleClue(
            id: 5,
            text: "The muddy churn ends between the defensive front and the deep men, on the right. A seasoned backer stands there, reading the bunch before it ever moves.",
            difficulty: .medium,
            playerID: "q3-slb"
        ),
        PuzzleClue(
            id: 6,
            text: "The last man at the top of the picture keeps his eyes glued to the bunch. Dead center, deeper than every defender, the water bottle resting against his heel — nothing gets behind him.",
            difficulty: .hard,
            playerID: "q3-ss"
        )
    ]

    private static let q3Hints: [PuzzleHint] = [
        PuzzleHint(id: "q3-h-rb", playerID: "q3-rb", text: "Shotgun passer at center-bottom. The quick back stands beside the towel on his left."),
        PuzzleHint(id: "q3-h-te", playerID: "q3-te", text: "The football lies just short of the right tackle's outside shoulder. That's the extra blocker's spot."),
        PuzzleHint(id: "q3-h-wr", playerID: "q3-wr", text: "The bunch is on the LEFT sideline. The empty spot is the OUTSIDE of the pair, on the line of scrimmage."),
        PuzzleHint(id: "q3-h-cb", playerID: "q3-cb", text: "Directly across the line of scrimmage from the outside bunch receiver — same sideline."),
        PuzzleHint(id: "q3-h-slb", playerID: "q3-slb", text: "Between the line and the safeties, on the right side — where the footprints end."),
        PuzzleHint(id: "q3-h-ss", playerID: "q3-ss", text: "Top of the field, dead center, beside the bottle — facing the bunch.")
    ]

    // MARK: - Q4 — Fourth and Inches

    static let quarter4 = QuarterPuzzle(
        id: "match-q4",
        index: 3,
        quarterLabel: "Q4",
        title: "Fourth and Inches",
        introHeading: "CLUTCH SITUATION",
        introBody: "One final read could decide the game.",
        startingLives: 3,
        startingHints: 3,
        visiblePlayers: q4Visible,
        missingPlayers: q4Missing,
        evidence: q4Evidence,
        slots: q4Slots,
        clues: q4Clues,
        hints: q4Hints,
        solutions: [
            "q4-te": PlacementSolution(slotID: "q4-s-right-te", variant: .power),
            "q4-wr": PlacementSolution(slotID: "q4-s-right-wide", variant: .veteran),
            "q4-rb": PlacementSolution(slotID: "q4-s-backfield", variant: .fast),
            "q4-cb": PlacementSolution(slotID: "q4-s-right-corner", variant: .fast),
            "q4-dl": PlacementSolution(slotID: "q4-s-over-te", variant: .power),
            "q4-fs": PlacementSolution(slotID: "q4-s-deep-left", variant: .veteran)
        ]
    )

    private static let q4Visible: [FieldPlayer] = [
        FieldPlayer(id: "q4-v-lt", position: .ol, x: 0.34, y: 0.545),
        FieldPlayer(id: "q4-v-lg", position: .ol, x: 0.42, y: 0.545),
        FieldPlayer(id: "q4-v-c", position: .ol, x: 0.50, y: 0.545),
        FieldPlayer(id: "q4-v-rg", position: .ol, x: 0.58, y: 0.545),
        FieldPlayer(id: "q4-v-rt", position: .ol, x: 0.66, y: 0.545),
        FieldPlayer(id: "q4-v-qb", position: .qb, x: 0.50, y: 0.64),
        FieldPlayer(id: "q4-v-fb", position: .rb, x: 0.50, y: 0.72),
        FieldPlayer(id: "q4-v-de1", position: .dl, x: 0.32, y: 0.485),
        FieldPlayer(id: "q4-v-dt1", position: .dl, x: 0.42, y: 0.485),
        FieldPlayer(id: "q4-v-dt2", position: .dl, x: 0.58, y: 0.485),
        FieldPlayer(id: "q4-v-de2", position: .dl, x: 0.70, y: 0.485),
        FieldPlayer(id: "q4-v-mlb", position: .lb, x: 0.50, y: 0.34),
        FieldPlayer(id: "q4-v-cb", position: .cb, x: 0.075, y: 0.44),
        FieldPlayer(id: "q4-v-ss", position: .ss, x: 0.68, y: 0.22)
    ]

    private static let q4Missing: [FootballPlayer] = [
        FootballPlayer(id: "q4-te", name: "Hank Ostrowski", position: .te, cardAsset: "football_player_blank_helmet_2"),
        FootballPlayer(id: "q4-wr", name: "Caleb Turner", position: .wr, cardAsset: "football_player_receiver"),
        FootballPlayer(id: "q4-rb", name: "Ishmael Wren", position: .rb, cardAsset: "football_player_running_back_2"),
        FootballPlayer(id: "q4-cb", name: "Dante Ruiz", position: .cb, cardAsset: "football_player_backpedal"),
        FootballPlayer(id: "q4-dl", name: "Yusuf Kamara", position: .dl, cardAsset: "football_player_tackle_2"),
        FootballPlayer(id: "q4-fs", name: "Vic Sorensen", position: .fs, cardAsset: "football_player_blank_gear_2")
    ]

    private static let q4Evidence: [EvidenceItem] = [
        EvidenceItem(id: "q4-e-towel", kind: .orangeTowel, x: 0.50, y: 0.87, rotation: -15),
        EvidenceItem(id: "q4-e-ball", kind: .looseFootball, x: 0.50, y: 0.585, rotation: 8),
        EvidenceItem(id: "q4-e-glove", kind: .droppedGlove, x: 0.95, y: 0.475, rotation: 26),
        EvidenceItem(id: "q4-e-mud", kind: .muddyFootprints, x: 0.72, y: 0.30, rotation: 55),
        EvidenceItem(id: "q4-e-bottle", kind: .waterBottle, x: 0.09, y: 0.06, rotation: 68)
    ]

    private static let q4Slots: [PlacementSlot] = [
        PlacementSlot(id: "q4-s-right-te", x: 0.75, y: 0.545),      // TE (correct)
        PlacementSlot(id: "q4-s-over-te", x: 0.75, y: 0.45),        // DL (correct)
        PlacementSlot(id: "q4-s-right-wide", x: 0.925, y: 0.52),    // WR (correct)
        PlacementSlot(id: "q4-s-right-corner", x: 0.925, y: 0.42),  // CB (correct)
        PlacementSlot(id: "q4-s-backfield", x: 0.50, y: 0.80),      // RB (correct)
        PlacementSlot(id: "q4-s-deep-left", x: 0.40, y: 0.13),      // FS (correct)
        PlacementSlot(id: "q4-s-left-te", x: 0.26, y: 0.545),       // decoy
        PlacementSlot(id: "q4-s-left-wide", x: 0.075, y: 0.52),     // decoy
        PlacementSlot(id: "q4-s-left-backfield", x: 0.36, y: 0.70), // decoy
        PlacementSlot(id: "q4-s-left-backer", x: 0.30, y: 0.34),    // decoy
        PlacementSlot(id: "q4-s-deep-right", x: 0.80, y: 0.15)      // decoy
    ]

    private static let q4Clues: [PuzzleClue] = [
        PuzzleClue(
            id: 1,
            text: "Deepest man in the backfield: the change-of-pace back stands straight behind the fullback, just short of the orange towel. Quickest legs on the roster.",
            difficulty: .easy,
            playerID: "q4-rb"
        ),
        PuzzleClue(
            id: 2,
            text: "The right side of the line needs a sixth body, shoulder to shoulder with the right tackle. Whoever takes it anchors against a bull rush — pure strength.",
            difficulty: .hard,
            playerID: "q4-te"
        ),
        PuzzleClue(
            id: 3,
            text: "The defense answers by slanting their widest man directly over that new blocker — no runway, no angle, just raw power straight ahead.",
            difficulty: .hard,
            playerID: "q4-dl"
        ),
        PuzzleClue(
            id: 4,
            text: "Everyone else is packed inside, so one receiver keeps the sideline honest — split wide on the far side from the corner you can already see, right where the dropped glove landed. He's not there for speed: twelve seasons of knowing where the sticks are.",
            difficulty: .medium,
            playerID: "q4-wr"
        ),
        PuzzleClue(
            id: 5,
            text: "That seasoned receiver gets no help over the top. The man across from him is on an island — left there alone with nothing but recovery speed.",
            difficulty: .hard,
            playerID: "q4-cb"
        ),
        PuzzleClue(
            id: 6,
            text: "The muddy footprints pull everyone's eyes to the right — but the single-high safety tilts the other way, toward the left, deepest of anyone on the field. Nothing gets behind him after twelve years of seeing this exact moment.",
            difficulty: .hard,
            playerID: "q4-fs"
        )
    ]

    private static let q4Hints: [PuzzleHint] = [
        PuzzleHint(id: "q4-h-rb", playerID: "q4-rb", text: "Straight behind the fullback, deepest in the backfield, next to the towel."),
        PuzzleHint(id: "q4-h-te", playerID: "q4-te", text: "Shoulder to shoulder with the RIGHT tackle — the right side of the line."),
        PuzzleHint(id: "q4-h-dl", playerID: "q4-dl", text: "Directly over the new blocker, a half-yard deeper than the defensive front."),
        PuzzleHint(id: "q4-h-wr", playerID: "q4-wr", text: "The visible corner is on the LEFT sideline. The receiver takes the RIGHT, where the glove lies."),
        PuzzleHint(id: "q4-h-cb", playerID: "q4-cb", text: "Same sideline as the receiver he covers, just across the line of scrimmage. Wheels, not hands."),
        PuzzleHint(id: "q4-h-fs", playerID: "q4-fs", text: "Away from the footprints — left of center, deeper than everyone.")
    ]

    // MARK: - Overtime — The Goal Line

    static let overtimePuzzle = QuarterPuzzle(
        id: "match-ot",
        index: 4,
        quarterLabel: "OT",
        title: "The Goal Line",
        introHeading: "OVERTIME",
        introBody: "One situation. Winner takes the game.",
        startingLives: 3,
        startingHints: 3,
        visiblePlayers: otVisible,
        missingPlayers: otMissing,
        evidence: otEvidence,
        slots: otSlots,
        clues: otClues,
        hints: otHints,
        solutions: [
            "ot-te": PlacementSolution(slotID: "ot-s-left-te", variant: .power),
            "ot-rb": PlacementSolution(slotID: "ot-s-backfield", variant: .power),
            "ot-wr": PlacementSolution(slotID: "ot-s-right-wide", variant: .veteran),
            "ot-mlb": PlacementSolution(slotID: "ot-s-mike", variant: .veteran),
            "ot-ss": PlacementSolution(slotID: "ot-s-deep-center", variant: .fast)
        ]
    )

    private static let otVisible: [FieldPlayer] = [
        FieldPlayer(id: "ot-v-lt", position: .ol, x: 0.32, y: 0.545),
        FieldPlayer(id: "ot-v-lg", position: .ol, x: 0.42, y: 0.545),
        FieldPlayer(id: "ot-v-c", position: .ol, x: 0.52, y: 0.545),
        FieldPlayer(id: "ot-v-rg", position: .ol, x: 0.62, y: 0.545),
        FieldPlayer(id: "ot-v-rt", position: .ol, x: 0.72, y: 0.545),
        FieldPlayer(id: "ot-v-qb", position: .qb, x: 0.50, y: 0.63),
        FieldPlayer(id: "ot-v-fb", position: .rb, x: 0.50, y: 0.71),
        FieldPlayer(id: "ot-v-de1", position: .dl, x: 0.28, y: 0.485),
        FieldPlayer(id: "ot-v-dt1", position: .dl, x: 0.42, y: 0.485),
        FieldPlayer(id: "ot-v-dt2", position: .dl, x: 0.58, y: 0.485),
        FieldPlayer(id: "ot-v-de2", position: .dl, x: 0.72, y: 0.485),
        FieldPlayer(id: "ot-v-cb", position: .cb, x: 0.925, y: 0.435)
    ]

    private static let otMissing: [FootballPlayer] = [
        FootballPlayer(id: "ot-te", name: "Ezekiel Brandt", position: .te, cardAsset: "football_player_blank_helmet_2"),
        FootballPlayer(id: "ot-rb", name: "Lamar Ogunde", position: .rb, cardAsset: "football_player_running_back"),
        FootballPlayer(id: "ot-wr", name: "Nico Petrov", position: .wr, cardAsset: "football_player_receiver"),
        FootballPlayer(id: "ot-mlb", name: "Solomon Reyes", position: .lb, cardAsset: "football_player_linebacker"),
        FootballPlayer(id: "ot-ss", name: "Trey Bolden", position: .ss, cardAsset: "football_player_backpedal")
    ]

    private static let otEvidence: [EvidenceItem] = [
        EvidenceItem(id: "ot-e-ball", kind: .looseFootball, x: 0.50, y: 0.585, rotation: 6),
        EvidenceItem(id: "ot-e-towel", kind: .orangeTowel, x: 0.50, y: 0.88, rotation: -12),
        EvidenceItem(id: "ot-e-glove", kind: .droppedGlove, x: 0.20, y: 0.605, rotation: 24),
        EvidenceItem(id: "ot-e-mud", kind: .muddyFootprints, x: 0.50, y: 0.245, rotation: 60),
        EvidenceItem(id: "ot-e-bottle", kind: .waterBottle, x: 0.955, y: 0.615, rotation: 75)
    ]

    private static let otSlots: [PlacementSlot] = [
        PlacementSlot(id: "ot-s-left-te", x: 0.25, y: 0.545),        // TE (correct)
        PlacementSlot(id: "ot-s-backfield", x: 0.50, y: 0.79),       // RB (correct)
        PlacementSlot(id: "ot-s-right-wide", x: 0.925, y: 0.52),     // WR (correct)
        PlacementSlot(id: "ot-s-mike", x: 0.50, y: 0.34),            // MLB (correct)
        PlacementSlot(id: "ot-s-deep-center", x: 0.50, y: 0.135),    // SS (correct)
        PlacementSlot(id: "ot-s-right-te", x: 0.79, y: 0.545),       // decoy
        PlacementSlot(id: "ot-s-left-backfield", x: 0.35, y: 0.71),  // decoy
        PlacementSlot(id: "ot-s-left-backer", x: 0.28, y: 0.34)      // decoy
    ]

    private static let otClues: [PuzzleClue] = [
        PuzzleClue(
            id: 1,
            text: "Fourth and goal from inside the one. The dropped glove marks the outside shoulder of the left tackle — our extra blocker takes the spot beside it. No finesse tonight: strength.",
            difficulty: .medium,
            playerID: "ot-te"
        ),
        PuzzleClue(
            id: 2,
            text: "One receiver keeps to the right sideline beside the water bottle, holding the corner's eyes. The quarterback has trusted him with this throw for a decade.",
            difficulty: .medium,
            playerID: "ot-wr"
        ),
        PuzzleClue(
            id: 3,
            text: "The handoff goes between the tackles. The ball carrier sets up straight behind the fullback — the deepest man in the backfield — and from a yard out, muscle beats wiggle.",
            difficulty: .hard,
            playerID: "ot-rb"
        ),
        PuzzleClue(
            id: 4,
            text: "The mud is churned dead center, between the defensive front and the deep men. That's the captain's post — he's called every protection tonight, and he'll call this one too.",
            difficulty: .hard,
            playerID: "ot-mlb"
        ),
        PuzzleClue(
            id: 5,
            text: "Deepest man on the field, dead center, alone. If the quick back ever finds an edge, only recovery speed can erase the mistake.",
            difficulty: .medium,
            playerID: "ot-ss"
        )
    ]

    private static let otHints: [PuzzleHint] = [
        PuzzleHint(id: "ot-h-te", playerID: "ot-te", text: "The glove lies at the LEFT tackle's outside shoulder. The extra blocker stands beside it."),
        PuzzleHint(id: "ot-h-wr", playerID: "ot-wr", text: "Right sideline, next to the water bottle — the only receiver spot on the field."),
        PuzzleHint(id: "ot-h-rb", playerID: "ot-rb", text: "Straight behind the fullback — deepest man in the backfield. One yard; no wiggle needed."),
        PuzzleHint(id: "ot-h-mlb", playerID: "ot-mlb", text: "Dead center between the line and the deep men — where the mud is."),
        PuzzleHint(id: "ot-h-ss", playerID: "ot-ss", text: "Top of the field, dead center, alone.")
    ]
}

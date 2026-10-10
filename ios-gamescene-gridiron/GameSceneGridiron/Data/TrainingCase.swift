import Foundation

/// The dedicated TRAINING CASE — a guided tutorial puzzle that is NOT part of
/// the 10-game regular season. It is never scheduled, never adapted for
/// difficulty and never touches the season, the wallet or the roster ledger.
///
/// Design contract (Phase 8):
/// - Exactly 3 missing players (RB / CB / FS), one per taught profile
///   (Fast / Power / Veteran — the same position needs different profiles
///   in different cases, so the tutorial shows all three).
/// - Only a few evidence objects, each visually obvious and tied to one
///   placement: orange cone, pylon + mouthguard, laminated play sheet.
/// - Very clear clue relationships; NO deceptive decoy slots — the only
///   three mystery zones are the three answers.
/// - Proven by `CaseSolver` to have exactly one valid solution, like every
///   other case in the game. Nothing is ever artificially vague.
nonisolated enum TrainingCase {
    /// The authored case definition.
    static let authored: QuarterCase = CaseLibrary.makeCase(
        id: "case_training_drill",
        seed: 7,
        band: 1,
        title: "The Wednesday Walkthrough",
        heading: "TRAINING DRILL",
        body: "Three teammates are missing from the walkthrough field. The evidence tells you where each one lines up.",
        visible: Formation.build { builder in
            // Offense — small supporting cast below the line of scrimmage.
            builder.add(.ol, 0.30, 0.565)
            builder.add(.ol, 0.42, 0.565)
            builder.add(.ol, 0.58, 0.565)
            builder.add(.ol, 0.70, 0.565)
            builder.add(.qb, 0.50, 0.66)
            builder.add(.wr, 0.09, 0.52)
            // Defense — a light front so the three zones read clearly.
            builder.add(.dl, 0.36, 0.475)
            builder.add(.dl, 0.64, 0.475)
            builder.add(.lb, 0.50, 0.34)
        },
        missing: [
            (key: "rb", position: .rb),
            (key: "cb", position: .cb),
            (key: "fs", position: .fs)
        ],
        evidence: [
            (key: "cone", kind: .orangeCone, x: 0.50, y: 0.76, rotation: 14),
            (key: "pylon", kind: .pylon, x: 0.955, y: 0.42, rotation: -8),
            (key: "mouthguard", kind: .mouthguard, x: 0.90, y: 0.50, rotation: -26),
            (key: "playsheet", kind: .laminatedPlaySheet, x: 0.44, y: 0.11, rotation: 31)
        ],
        slots: [
            // No decoys: exactly one zone per answer.
            (key: "rb-right", x: 0.42, y: 0.74),
            (key: "cb-right", x: 0.88, y: 0.435),
            (key: "fs-center", x: 0.52, y: 0.14)
        ],
        clues: [
            (
                player: "rb",
                family: .evidenceRelationship,
                difficulty: .easy,
                text: "A quick back is needed beside the orange cone, in the backfield behind the quarterback.",
                constraints: [
                    .nearEvidence(player: "rb", evidence: "cone", radius: 0.09),
                    .variantIs(player: "rb", variant: .fast)
                ],
                evidence: ["cone"]
            ),
            (
                player: "cb",
                family: .profileDeduction,
                difficulty: .easy,
                text: "Jamming the receiver at the line takes strength, not speed. He lines up right beside the pylon, where the mouthguard dropped.",
                constraints: [
                    .nearEvidence(player: "cb", evidence: "pylon", radius: 0.09),
                    .variantIs(player: "cb", variant: .power)
                ],
                evidence: ["pylon", "mouthguard"]
            ),
            (
                player: "fs",
                family: .relativePosition,
                difficulty: .easy,
                text: "The experienced safety sets his station by the laminated play sheet, deeper than the corner you just placed.",
                constraints: [
                    .nearEvidence(player: "fs", evidence: "playsheet", radius: 0.09),
                    .yAbove(a: "fs", b: "cb", gap: 0.1),
                    .variantIs(player: "fs", variant: .veteran)
                ],
                evidence: ["playsheet"]
            )
        ],
        hints: [
            (player: "rb", text: "Quick means Fast. Back means Running Back — the open backfield spot right by the orange cone."),
            (player: "cb", text: "Strength over speed means Power. The pylon marks the front corner of the end zone — line up beside it."),
            (player: "fs", text: "Experience means Veteran. The deepest spot on the field sits beside the laminated play sheet.")
        ],
        solution: [
            (player: "rb", slot: "rb-right", variant: .fast),
            (player: "cb", slot: "cb-right", variant: .power),
            (player: "fs", slot: "fs-center", variant: .veteran)
        ]
    )

    /// The runtime puzzle for the guided training session. Reuses the standard
    /// case→puzzle conversion, then relabels the quarter tag so the HUD reads
    /// TRAINING instead of Q1.
    static func puzzle() -> QuarterPuzzle {
        let converted = CaseLibrary.puzzle(for: authored, quarterIndex: 0)
        return QuarterPuzzle(
            id: converted.id,
            index: converted.index,
            quarterLabel: "TRAINING",
            title: converted.title,
            introHeading: converted.introHeading,
            introBody: converted.introBody,
            startingLives: converted.startingLives,
            startingHints: converted.startingHints,
            visiblePlayers: converted.visiblePlayers,
            missingPlayers: converted.missingPlayers,
            evidence: converted.evidence,
            slots: converted.slots,
            clues: converted.clues,
            hints: converted.hints,
            solutions: converted.solutions
        )
    }
}

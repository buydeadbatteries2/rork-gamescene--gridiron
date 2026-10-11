import Foundation

// MARK: - Case Pack 6 — Phase 11.5
//
// Cases that use the expanded profile pool: OVERRATED (and Rookie-profile
// reasoning) as first-class authored answers. Overrated is never a dice roll —
// the mistake is written into the scenario (the repeat bites, the lost
// leverage, the receiver the offense keeps attacking), and every case still
// has exactly one solver-verified solution.

nonisolated enum CasePack6 {
    static let all: [QuarterCase] = [
        // 1 — The Island Everyone Feeds (seed 50)
        CaseLibrary.makeCase(
            id: "case_hype_island_31", seed: 50, band: 3,
            title: "The Island Everyone Feeds",
            heading: "FILM REVIEW",
            body: "A headline defender keeps getting picked on. Four jerseys are unaccounted for.",
            visible: Formation.build { b in
                b.line([0.30, 0.40, 0.50, 0.70])
                b.add(.qb, 0.50, 0.655)
                b.add(.wr, 0.075, 0.53)
                b.front([0.28, 0.42, 0.58, 0.72])
                b.add(.lb, 0.50, 0.36)
            },
            missing: [
                (key: "wr", position: .wr),
                (key: "cb", position: .cb),
                (key: "ol", position: .ol),
                (key: "fs", position: .fs)
            ],
            evidence: [
                (key: "visor", kind: .visorCloth, x: 0.905, y: 0.535, rotation: -18),
                (key: "stain", kind: .grassStain, x: 0.09, y: 0.415, rotation: 0),
                (key: "tape", kind: .tapeRoll, x: 0.59, y: 0.595, rotation: 40),
                (key: "bottle", kind: .waterBottle, x: 0.50, y: 0.115, rotation: 72)
            ],
            slots: [
                (key: "wr-split", x: 0.90, y: 0.53),
                (key: "cb-left", x: 0.10, y: 0.435),
                (key: "ol-gap", x: 0.60, y: 0.565),
                (key: "fs-center", x: 0.50, y: 0.13),
                (key: "rb-left", x: 0.38, y: 0.70),
                (key: "slot-left", x: 0.205, y: 0.525),
                (key: "box-right", x: 0.66, y: 0.295),
                (key: "deep-right", x: 0.80, y: 0.17)
            ],
            clues: [
                (player: "wr", family: .scenario, difficulty: .hard,
                 text: "The split end lines up alone on the right sideline, right where the visor cloth got thrown down. The offense has attacked his side three straight snaps — the name that sells the tickets is also the man they keep testing.",
                 constraints: [.nearEvidence(player: "wr", evidence: "visor", radius: 0.08), .profileIs(player: "wr", profile: .overrated)],
                 evidence: ["visor"]),
                (player: "cb", family: .evidenceRelationship, difficulty: .medium,
                 text: "Straight across from the visible receiver, a grass stain shows where someone back-pedaled all night. No safety help over there — only recovery speed survives alone on an island.",
                 constraints: [.nearEvidence(player: "cb", evidence: "stain", radius: 0.08), .profileIs(player: "cb", profile: .fast)],
                 evidence: ["stain"]),
                (player: "ol", family: .footballResponsibility, difficulty: .easy,
                 text: "There is a fight in the trench between the center and the right tackle. The tape roll abandoned there says the last rep was a war — whoever fills that gap will not be moved an inch.",
                 constraints: [.nearEvidence(player: "ol", evidence: "tape", radius: 0.08), .profileIs(player: "ol", profile: .powerful)],
                 evidence: ["tape"]),
                (player: "fs", family: .orderDepth, difficulty: .medium,
                 text: "The single-high post, dead center, higher than anyone else on the field, the water bottle at his heel. He has been alone back there all game — the steadiest head on the roster.",
                 constraints: [.nearEvidence(player: "fs", evidence: "bottle", radius: 0.08), .profileIs(player: "fs", profile: .veteran)],
                 evidence: ["bottle"])
            ],
            hints: [
                (player: "wr", text: "Right sideline, on the line of scrimmage — the visor cloth marks his split."),
                (player: "cb", text: "Left sideline, dead across from the lone visible receiver — the grass stain shows where his back-pedal ended."),
                (player: "ol", text: "Between the center and the right tackle, right by the tape roll."),
                (player: "fs", text: "Top center of the picture, deepest man on the field, beside the water bottle.")
            ],
            solution: [
                (player: "wr", slot: "wr-split", profile: .overrated),
                (player: "cb", slot: "cb-left", profile: .fast),
                (player: "ol", slot: "ol-gap", profile: .powerful),
                (player: "fs", slot: "fs-center", profile: .veteran)
            ]
        ),

        // 2 — The Highlight Trap (seed 51)
        CaseLibrary.makeCase(
            id: "case_highlight_trap_41", seed: 51, band: 4,
            title: "The Highlight Trap",
            heading: "PRESSURE CHECK",
            body: "Five jerseys missing — and one of them keeps chasing the highlight instead of the job.",
            visible: Formation.build { b in
                b.line([0.30, 0.40, 0.60, 0.70])
                b.add(.qb, 0.50, 0.66)
                b.add(.wr, 0.075, 0.52)
                b.add(.wr, 0.925, 0.52)
                b.front([0.28, 0.42, 0.58, 0.72])
                b.add(.cb, 0.09, 0.435)
                b.add(.fs, 0.72, 0.24)
            },
            missing: [
                (key: "rb", position: .rb),
                (key: "te", position: .te),
                (key: "qb2", position: .qb),
                (key: "lb", position: .lb),
                (key: "ss", position: .ss)
            ],
            evidence: [
                (key: "cone", kind: .orangeCone, x: 0.41, y: 0.755, rotation: 14),
                (key: "glove", kind: .droppedGlove, x: 0.79, y: 0.575, rotation: 28),
                (key: "chalk", kind: .chalkMark, x: 0.50, y: 0.60, rotation: 45),
                (key: "mud", kind: .muddyFootprints, x: 0.31, y: 0.30, rotation: 62),
                (key: "flag", kind: .challengeFlag, x: 0.60, y: 0.20, rotation: -14)
            ],
            slots: [
                (key: "rb-deep", x: 0.40, y: 0.75),
                (key: "te-right", x: 0.775, y: 0.565),
                (key: "qb-gun", x: 0.50, y: 0.61),
                (key: "lb-left", x: 0.30, y: 0.285),
                (key: "ss-right", x: 0.61, y: 0.19),
                (key: "rb-left", x: 0.24, y: 0.70),
                (key: "slot-right", x: 0.70, y: 0.525),
                (key: "deep-middle", x: 0.50, y: 0.115),
                (key: "box-right", x: 0.68, y: 0.30)
            ],
            clues: [
                (player: "rb", family: .evidenceRelationship, difficulty: .easy,
                 text: "The orange cone sits in the backfield's left lane — the back who owns that lane needs instant acceleration to hit the hole before it closes.",
                 constraints: [.nearEvidence(player: "rb", evidence: "cone", radius: 0.08), .profileIs(player: "rb", profile: .fast)],
                 evidence: ["cone"]),
                (player: "te", family: .footballResponsibility, difficulty: .medium,
                 text: "The right tackle needs a wingman on his shoulder. The dropped glove says the last rep was a fight — an extra blocker glues on tight, strength over everything.",
                 constraints: [.nearEvidence(player: "te", evidence: "glove", radius: 0.08), .profileIs(player: "te", profile: .powerful)],
                 evidence: ["glove"]),
                (player: "qb2", family: .formationKnowledge, difficulty: .medium,
                 text: "The chalk mark sits four yards behind the line, dead center — the gun. This passer has taken snaps there for the first time this week, and it shows: late off the mesh, eyes still learning the progressions.",
                 constraints: [.nearEvidence(player: "qb2", evidence: "chalk", radius: 0.08), .profileIs(player: "qb2", profile: .rookie)],
                 evidence: ["chalk"]),
                (player: "lb", family: .scenario, difficulty: .hard,
                 text: "The muddy footprints wander where a backer should be, but the picture says he chased the highlight instead: two steps toward the line, then gone — baited out of his lever for the third snap running, the linebacker the offense keeps putting on film.",
                 constraints: [.nearEvidence(player: "lb", evidence: "mud", radius: 0.08), .profileIs(player: "lb", profile: .overrated)],
                 evidence: ["mud"]),
                (player: "ss", family: .orderDepth, difficulty: .hard,
                 text: "The challenge flag lies on the right hash, between the front and the deep middle, higher than the boxed safety help. A decade of run reads parks him exactly there.",
                 constraints: [.nearEvidence(player: "ss", evidence: "flag", radius: 0.08), .yAbove(a: "ss", b: "lb", gap: 0.04), .profileIs(player: "ss", profile: .veteran)],
                 evidence: ["flag"])
            ],
            hints: [
                (player: "rb", text: "Left lane of the backfield, right by the orange cone."),
                (player: "te", text: "Right tackle's outside shoulder — the glove marks the fight."),
                (player: "qb2", text: "Dead center in the gun, four yards behind the ball — the chalk mark."),
                (player: "lb", text: "Left side, in front of the safeties but behind the line — the footprints wander there."),
                (player: "ss", text: "Right hash between the line and the deep middle — the challenge flag marks his post.")
            ],
            solution: [
                (player: "rb", slot: "rb-deep", profile: .fast),
                (player: "te", slot: "te-right", profile: .powerful),
                (player: "qb2", slot: "qb-gun", profile: .rookie),
                (player: "lb", slot: "lb-left", profile: .overrated),
                (player: "ss", slot: "ss-right", profile: .veteran)
            ]
        ),

        // 3 — The Reputation Deal (seed 52)
        CaseLibrary.makeCase(
            id: "case_reputation_blindside_51", seed: 52, band: 5,
            title: "The Reputation Deal",
            heading: "OVERTIME — SUDDEN DEATH",
            body: "One drive decides it. Five jerseys missing, and the biggest name on the field is the biggest question.",
            visible: Formation.build { b in
                b.line([0.28, 0.38, 0.60, 0.72])
                b.add(.qb, 0.50, 0.665)
                b.add(.wr, 0.075, 0.525)
                b.front([0.30, 0.44, 0.56, 0.70])
                b.add(.lb, 0.50, 0.345)
                b.add(.cb, 0.925, 0.43)
            },
            missing: [
                (key: "te", position: .te),
                (key: "wr", position: .wr),
                (key: "ol", position: .ol),
                (key: "dl", position: .dl),
                (key: "fs", position: .fs)
            ],
            evidence: [
                (key: "playbook", kind: .wristPlaybook, x: 0.66, y: 0.60, rotation: -22),
                (key: "card", kind: .droppedPlayCard, x: 0.905, y: 0.53, rotation: -8),
                (key: "strap", kind: .shoulderPadStrap, x: 0.475, y: 0.585, rotation: 18),
                (key: "divot", kind: .divot, x: 0.245, y: 0.40, rotation: 0),
                (key: "wet", kind: .wetPatch, x: 0.50, y: 0.125, rotation: 0)
            ],
            slots: [
                (key: "te-right", x: 0.675, y: 0.59),
                (key: "wr-right", x: 0.92, y: 0.525),
                (key: "ol-gap", x: 0.48, y: 0.575),
                (key: "dl-left", x: 0.255, y: 0.41),
                (key: "fs-center", x: 0.50, y: 0.12),
                (key: "rb-left", x: 0.36, y: 0.71),
                (key: "slot-left", x: 0.19, y: 0.53),
                (key: "box-right", x: 0.67, y: 0.28),
                (key: "deep-right", x: 0.82, y: 0.15)
            ],
            clues: [
                (player: "te", family: .footballResponsibility, difficulty: .medium,
                 text: "The right side of the line is leaking. The wrist playbook dropped exactly there — the extra blocker expected to pave that lane has already lost leverage twice tonight, and everybody keeps calling him the best one on the roster.",
                 constraints: [.nearEvidence(player: "te", evidence: "playbook", radius: 0.08), .profileIs(player: "te", profile: .overrated)],
                 evidence: ["playbook"]),
                (player: "wr", family: .evidenceRelationship, difficulty: .medium,
                 text: "Split wide on the right sideline where the dropped play card lies — twelve seasons of route discipline, no wasted motion, the quiet way he wins.",
                 constraints: [.nearEvidence(player: "wr", evidence: "card", radius: 0.08), .profileIs(player: "wr", profile: .veteran)],
                 evidence: ["card"]),
                (player: "ol", family: .formationKnowledge, difficulty: .easy,
                 text: "The shoulder-pad strap lies in the hole between center and left guard. Whoever fills that gap anchors against a bull rush and does not move an inch.",
                 constraints: [.nearEvidence(player: "ol", evidence: "strap", radius: 0.08), .profileIs(player: "ol", profile: .powerful)],
                 evidence: ["strap"]),
                (player: "dl", family: .orderDepth, difficulty: .medium,
                 text: "The divot torn up on the left edge sits just past the line of scrimmage, on the line's outside shoulder. First step explosion is the whole job — get by that tackle before he sets.",
                 constraints: [.nearEvidence(player: "dl", evidence: "divot", radius: 0.08), .profileIs(player: "dl", profile: .fast)],
                 evidence: ["divot"]),
                (player: "fs", family: .orderDepth, difficulty: .hard,
                 text: "The wet patch dead center is deeper than everyone else on the field. The last line has been alone back there all game — the steadiest head on the roster.",
                 constraints: [.nearEvidence(player: "fs", evidence: "wet", radius: 0.08), .profileIs(player: "fs", profile: .veteran)],
                 evidence: ["wet"])
            ],
            hints: [
                (player: "te", text: "Right side of the line, tight to the tackle — the wrist playbook marks the leak."),
                (player: "wr", text: "Right sideline, on the line of scrimmage — the dropped play card marks his split."),
                (player: "ol", text: "Between the center and the left guard — the shoulder pad strap lies in the hole."),
                (player: "dl", text: "Left edge, just past the line of scrimmage, on the tackle's outside shoulder — the divot."),
                (player: "fs", text: "Top center of the picture, deeper than the linebacker, beside the wet patch.")
            ],
            solution: [
                (player: "te", slot: "te-right", profile: .overrated),
                (player: "wr", slot: "wr-right", profile: .veteran),
                (player: "ol", slot: "ol-gap", profile: .powerful),
                (player: "dl", slot: "dl-left", profile: .fast),
                (player: "fs", slot: "fs-center", profile: .veteran)
            ]
        )
    ]
}

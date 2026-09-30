import Foundation

/// Band 4 — fourth-quarter cases: the hardest regulation looks, five or six
/// missing players, deductions that chain across evidence, players and formation.
nonisolated enum CasePack4 {
    static let all: [QuarterCase] = [

        // 31 — The Unders Safety (seed 30)
        CaseLibrary.makeCase(
            id: "case_unders_safety_01", seed: 30, band: 4,
            title: "The Unders Safety",
            heading: "POSTSEASON PRESSURE",
            body: "Both safeties vanished from the picture. The middle belongs to whoever reads it best.",
            visible: Formation.build { b in
                b.line([0.30, 0.40, 0.50, 0.60])
                b.add(.rb, 0.42, 0.68)
                b.add(.te, 0.225, 0.565)
                b.add(.wr, 0.075, 0.53)
                b.add(.wr, 0.925, 0.52)
                b.front([0.28, 0.42, 0.58, 0.72])
                b.add(.lb, 0.50, 0.36)
                b.add(.cb, 0.925, 0.435)
            },
            missing: [
                (key: "qb", position: .qb),
                (key: "ol", position: .ol),
                (key: "cb", position: .cb),
                (key: "ss", position: .ss),
                (key: "fs", position: .fs),
                (key: "lb", position: .lb)
            ],
            evidence: [
                (key: "chalk", kind: .chalkMark, x: 0.51, y: 0.715, rotation: 45),
                (key: "tee", kind: .kickingTee, x: 0.71, y: 0.605, rotation: 10),
                (key: "stain", kind: .grassStain, x: 0.09, y: 0.40, rotation: 0),
                (key: "whistle", kind: .whistle, x: 0.32, y: 0.33, rotation: -20),
                (key: "flag", kind: .challengeFlag, x: 0.675, y: 0.315, rotation: 16),
                (key: "bottle", kind: .waterBottle, x: 0.70, y: 0.11, rotation: 68)
            ],
            slots: [
                (key: "qb-gun", x: 0.50, y: 0.655),
                (key: "ol-rt", x: 0.70, y: 0.565),
                (key: "cb-left", x: 0.075, y: 0.435),
                (key: "ss-box", x: 0.34, y: 0.295),
                (key: "fs-deep-right", x: 0.68, y: 0.15),
                (key: "lb-right", x: 0.66, y: 0.36),
                (key: "under-center", x: 0.50, y: 0.63),
                (key: "back-left", x: 0.38, y: 0.70),
                (key: "slot-left", x: 0.205, y: 0.525),
                (key: "box-deep-right", x: 0.76, y: 0.25),
                (key: "edge-right", x: 0.835, y: 0.465),
                (key: "deep-left", x: 0.27, y: 0.14)
            ],
            clues: [
                (player: "qb", family: .scenario, difficulty: .easy,
                 text: "The chalk mark four yards behind the line, dead center, is the passer's office — and with the blitz pressure this late, whoever stands there has to be able to leave it in a heartbeat.",
                 constraints: [.nearEvidence(player: "qb", evidence: "chalk", radius: 0.08), .variantIs(player: "qb", variant: .fast)],
                 evidence: ["chalk"]),
                (player: "ol", family: .footballResponsibility, difficulty: .medium,
                 text: "The right tackle spot is vacant, and the kicking tee parked in front of it marks the replacement. Against this front he will eat double teams or the quarterback eats turf.",
                 constraints: [.nearEvidence(player: "ol", evidence: "tee", radius: 0.08), .variantIs(player: "ol", variant: .power)],
                 evidence: ["tee"]),
                (player: "cb", family: .evidenceRelationship, difficulty: .medium,
                 text: "The grass stain on the left island shows where the corner back-pedaled all game — across from the visible receiver, no help coming, only recovery speed as insurance.",
                 constraints: [.nearEvidence(player: "cb", evidence: "stain", radius: 0.08), .variantIs(player: "cb", variant: .fast)],
                 evidence: ["stain"]),
                (player: "ss", family: .orderDepth, difficulty: .medium,
                 text: "The whistle on the left second level marks the unders safety: below the deep men, above the backers, the first hat into every box count.",
                 constraints: [.nearEvidence(player: "ss", evidence: "whistle", radius: 0.08), .variantIs(player: "ss", variant: .veteran)],
                 evidence: ["whistle"]),
                (player: "fs", family: .profileDeduction, difficulty: .hard,
                 text: "The water bottle at the top right marks the post half. With the middle of the field wide open behind him, the job is pure erasure — range first, instincts second, neither optional.",
                 constraints: [.nearEvidence(player: "fs", evidence: "bottle", radius: 0.08), .variantIs(player: "fs", variant: .veteran)],
                 evidence: ["bottle"]),
                (player: "lb", family: .chainedDeduction, difficulty: .medium,
                 text: "The challenge flag at the right stack spot marks the run-and-hit backer: below the deep post, on the tight end's side of the field, where the hole closes fastest.",
                 constraints: [.nearEvidence(player: "lb", evidence: "flag", radius: 0.08), .yBelow(a: "lb", b: "fs", gap: 0.15), .variantIs(player: "lb", variant: .power)],
                 evidence: ["flag"])
            ],
            hints: [
                (player: "qb", text: "Dead center in the gun — at the chalk mark."),
                (player: "ol", text: "The open right tackle spot — where the kicking tee was left warming."),
                (player: "cb", text: "Left island across from the visible receiver — at the grass stain."),
                (player: "ss", text: "Left second level, below the deep men, above the backers — at the whistle."),
                (player: "fs", text: "Top right, single-high — beside the water bottle."),
                (player: "lb", text: "Right stack spot, below the deep post — at the challenge flag.")
            ],
            solution: [
                (player: "qb", slot: "qb-gun", variant: .fast),
                (player: "ol", slot: "ol-rt", variant: .power),
                (player: "cb", slot: "cb-left", variant: .fast),
                (player: "ss", slot: "ss-box", variant: .veteran),
                (player: "fs", slot: "fs-deep-right", variant: .veteran),
                (player: "lb", slot: "lb-right", variant: .power)
            ]
        ),

        // 32 — Three Levels Deep (seed 31)
        CaseLibrary.makeCase(
            id: "case_three_level_flood_02", seed: 31, band: 4,
            title: "Three Levels Deep",
            heading: "VERTICAL STRETCH",
            body: "Three receivers at three depths. The defense has one answer left.",
            visible: Formation.build { b in
                b.line([0.30, 0.40, 0.50, 0.60, 0.70])
                b.add(.wr, 0.075, 0.53)
                b.front([0.28, 0.42, 0.58, 0.72])
                b.add(.lb, 0.50, 0.36)
                b.add(.lb, 0.34, 0.36)
                b.add(.cb, 0.075, 0.435)
            },
            missing: [
                (key: "qb", position: .qb),
                (key: "wr1", position: .wr),
                (key: "wr2", position: .wr),
                (key: "cb", position: .cb),
                (key: "fs", position: .fs),
                (key: "ss", position: .ss)
            ],
            evidence: [
                (key: "ball", kind: .looseFootball, x: 0.545, y: 0.615, rotation: 8),
                (key: "cup", kind: .sportsDrinkCup, x: 0.945, y: 0.565, rotation: 18),
                (key: "band", kind: .wristband, x: 0.775, y: 0.585, rotation: 8),
                (key: "stain", kind: .grassStain, x: 0.905, y: 0.395, rotation: 0),
                (key: "marks", kind: .cleatMarks, x: 0.49, y: 0.095, rotation: 20),
                (key: "strap", kind: .shoulderPadStrap, x: 0.675, y: 0.335, rotation: -35)
            ],
            slots: [
                (key: "qb-gun", x: 0.50, y: 0.655),
                (key: "wr1-right", x: 0.925, y: 0.52),
                (key: "wr2-slot", x: 0.80, y: 0.535),
                (key: "cb-right", x: 0.925, y: 0.435),
                (key: "fs-center", x: 0.50, y: 0.13),
                (key: "ss-box", x: 0.66, y: 0.295),
                (key: "deep-gun", x: 0.50, y: 0.72),
                (key: "back-right", x: 0.62, y: 0.70),
                (key: "slot-left", x: 0.14, y: 0.52),
                (key: "box-left", x: 0.30, y: 0.28),
                (key: "deep-right", x: 0.70, y: 0.155),
                (key: "deep-left", x: 0.27, y: 0.14)
            ],
            clues: [
                (player: "qb", family: .scenario, difficulty: .easy,
                 text: "A three-level flood lives on the throw, and the loose football four yards behind the line marks the thrower — in the gun, with his eyes already downfield.",
                 constraints: [.nearEvidence(player: "qb", evidence: "ball", radius: 0.08), .variantIs(player: "qb", variant: .fast)],
                 evidence: ["ball"]),
                (player: "wr1", family: .relativePosition, difficulty: .medium,
                 text: "The sports drink cup at the far right numbers marks the deep third — the receiver who runs past the corner's cushion and keeps going until the safety flinches.",
                 constraints: [.nearEvidence(player: "wr1", evidence: "cup", radius: 0.08), .variantIs(player: "wr1", variant: .veteran)],
                 evidence: ["cup"]),
                (player: "wr2", family: .formationKnowledge, difficulty: .medium,
                 text: "The wristband inside of him marks the intermediate threat: off the tackle, at the depth where zones get soft, always the second read.",
                 constraints: [.nearEvidence(player: "wr2", evidence: "band", radius: 0.08), .variantIs(player: "wr2", variant: .fast)],
                 evidence: ["band"]),
                (player: "cb", family: .elimination, difficulty: .medium,
                 text: "The grass stain at the right corner's post marks the man on the deep third — and the staff's note says no veteran, no power build. That island is a footrace.",
                 constraints: [.nearEvidence(player: "cb", evidence: "stain", radius: 0.08), .variantIsNot(player: "cb", variant: .power), .variantIsNot(player: "cb", variant: .veteran)],
                 evidence: ["stain"]),
                (player: "fs", family: .evidenceRelationship, difficulty: .hard,
                 text: "The cleat marks at the very top of the picture, dead center, are the last line's post. Everything this concept does is designed to make him wrong exactly once.",
                 constraints: [.nearEvidence(player: "fs", evidence: "marks", radius: 0.08), .variantIs(player: "fs", variant: .veteran)],
                 evidence: ["marks"]),
                (player: "ss", family: .orderDepth, difficulty: .medium,
                 text: "The shoulder-pad strap on the right second level marks the box safety: below the deep post, above the backers, selling out against the run the flood is pretending to be.",
                 constraints: [.nearEvidence(player: "ss", evidence: "strap", radius: 0.08), .variantIs(player: "ss", variant: .power)],
                 evidence: ["strap"])
            ],
            hints: [
                (player: "qb", text: "Dead center of the gun — the loose football marks the spot."),
                (player: "wr1", text: "Far right numbers, deepest third — by the sports drink cup."),
                (player: "wr2", text: "Right slot, intermediate depth — where the wristband lies."),
                (player: "cb", text: "Right sideline at the corner's post — at the grass stain. A footrace."),
                (player: "fs", text: "Top center of the field, deepest man standing — at the cleat marks."),
                (player: "ss", text: "Right second level, below the deep post — at the shoulder-pad strap.")
            ],
            solution: [
                (player: "qb", slot: "qb-gun", variant: .fast),
                (player: "wr1", slot: "wr1-right", variant: .veteran),
                (player: "wr2", slot: "wr2-slot", variant: .fast),
                (player: "cb", slot: "cb-right", variant: .fast),
                (player: "fs", slot: "fs-center", variant: .veteran),
                (player: "ss", slot: "ss-box", variant: .power)
            ]
        ),

        // 33 — The Wedge (seed 32)
        CaseLibrary.makeCase(
            id: "case_short_yardage_wedge_03", seed: 32, band: 4,
            title: "The Wedge",
            heading: "FOURTH AND INCHES",
            body: "No space, no tricks. Just mass against mass for one foot of field.",
            visible: Formation.build { b in
                b.line([0.30, 0.40, 0.50, 0.60])
                b.add(.qb, 0.50, 0.63)
                b.add(.rb, 0.50, 0.71)
                b.add(.te, 0.225, 0.565)
                b.add(.wr, 0.925, 0.52)
                b.front([0.28, 0.42, 0.58])
                b.add(.lb, 0.50, 0.36)
                b.add(.cb, 0.925, 0.435)
                b.add(.fs, 0.50, 0.135)
            },
            missing: [
                (key: "rb", position: .rb),
                (key: "te", position: .te),
                (key: "ol", position: .ol),
                (key: "dl", position: .dl),
                (key: "lb", position: .lb)
            ],
            evidence: [
                (key: "brace", kind: .kneeBrace, x: 0.505, y: 0.835, rotation: -4),
                (key: "strap", kind: .chinStrap, x: 0.79, y: 0.615, rotation: -28),
                (key: "tee", kind: .kickingTee, x: 0.685, y: 0.605, rotation: 10),
                (key: "divot", kind: .divot, x: 0.725, y: 0.43, rotation: -14),
                (key: "flag", kind: .challengeFlag, x: 0.615, y: 0.30, rotation: 16)
            ],
            slots: [
                (key: "rb-deep", x: 0.50, y: 0.79),
                (key: "te-right", x: 0.775, y: 0.565),
                (key: "ol-rt", x: 0.70, y: 0.565),
                (key: "de-right", x: 0.72, y: 0.475),
                (key: "lb-right", x: 0.645, y: 0.35),
                (key: "back-left", x: 0.38, y: 0.70),
                (key: "te-left", x: 0.245, y: 0.565),
                (key: "edge-left", x: 0.165, y: 0.465),
                (key: "box-left", x: 0.30, y: 0.28),
                (key: "slot-right", x: 0.85, y: 0.46),
                (key: "deep-center", x: 0.50, y: 0.115)
            ],
            clues: [
                (player: "rb", family: .orderDepth, difficulty: .easy,
                 text: "The knee brace at the deepest backfield spot marks the wedge back: straight ahead, behind two tight bodies, moving the pile with his shoulders.",
                 constraints: [.nearEvidence(player: "rb", evidence: "brace", radius: 0.08), .variantIs(player: "rb", variant: .power)],
                 evidence: ["brace"]),
                (player: "te", family: .footballResponsibility, difficulty: .medium,
                 text: "The chin strap flung outside the right tackle marks the second giant — in a wedge, he does not block a man, he moves a wall.",
                 constraints: [.nearEvidence(player: "te", evidence: "strap", radius: 0.08), .variantIs(player: "te", variant: .power)],
                 evidence: ["strap"]),
                (player: "ol", family: .formationKnowledge, difficulty: .medium,
                 text: "The kicking tee in front of the vacant right tackle spot marks the sixth body across. He fires low, stays square, and is forbidden from standing up.",
                 constraints: [.nearEvidence(player: "ol", evidence: "tee", radius: 0.08), .variantIs(player: "ol", variant: .power)],
                 evidence: ["tee"]),
                (player: "dl", family: .scenario, difficulty: .medium,
                 text: "The defense slams a slanter over the new blocker — the divot at the right end marks his first step, straight down the line to wreck the wedge before it forms.",
                 constraints: [.nearEvidence(player: "dl", evidence: "divot", radius: 0.08), .variantIs(player: "dl", variant: .power)],
                 evidence: ["divot"]),
                (player: "lb", family: .evidenceRelationship, difficulty: .hard,
                 text: "The challenge flag at the right stack spot marks the plugger. In this pile, lateral speed is useless — the man who wins is the one who has done this a hundred times and never moved backward once.",
                 constraints: [.nearEvidence(player: "lb", evidence: "flag", radius: 0.08), .variantIs(player: "lb", variant: .veteran)],
                 evidence: ["flag"])
            ],
            hints: [
                (player: "rb", text: "Deepest in the backfield, straight behind the fullback — at the knee brace."),
                (player: "te", text: "Attached right, outside the fresh tackle — at the chin strap."),
                (player: "ol", text: "Right tackle spot, empty — look for the kicking tee in front of it."),
                (player: "dl", text: "Right end, slanting inside — over the divot."),
                (player: "lb", text: "Right stack spot — at the challenge flag.")
            ],
            solution: [
                (player: "rb", slot: "rb-deep", variant: .power),
                (player: "te", slot: "te-right", variant: .power),
                (player: "ol", slot: "ol-rt", variant: .power),
                (player: "dl", slot: "de-right", variant: .power),
                (player: "lb", slot: "lb-right", variant: .veteran)
            ]
        ),

        // 34 — The Scramble Drill (seed 33)
        CaseLibrary.makeCase(
            id: "case_scramble_drill_04", seed: 33, band: 4,
            title: "The Scramble Drill",
            heading: "PLAY EXTENSION",
            body: "The pocket is gone. The play is not. Find where everyone runs to.",
            visible: Formation.build { b in
                b.line([0.30, 0.40, 0.50, 0.60, 0.70])
                b.add(.rb, 0.42, 0.68)
                b.add(.wr, 0.075, 0.53)
                b.front([0.28, 0.42, 0.58])
                b.add(.lb, 0.50, 0.36)
                b.add(.lb, 0.34, 0.36)
                b.add(.cb, 0.075, 0.435)
                b.add(.cb, 0.925, 0.435)
                b.add(.fs, 0.50, 0.135)
            },
            missing: [
                (key: "qb", position: .qb),
                (key: "wr", position: .wr),
                (key: "te", position: .te),
                (key: "dl", position: .dl),
                (key: "ss", position: .ss)
            ],
            evidence: [
                (key: "cone", kind: .orangeCone, x: 0.645, y: 0.69, rotation: -10),
                (key: "cup", kind: .sportsDrinkCup, x: 0.945, y: 0.565, rotation: 18),
                (key: "strap", kind: .chinStrap, x: 0.79, y: 0.615, rotation: -28),
                (key: "skid", kind: .skidMarks, x: 0.725, y: 0.435, rotation: 12),
                (key: "strap2", kind: .shoulderPadStrap, x: 0.645, y: 0.335, rotation: -35)
            ],
            slots: [
                (key: "qb-scramble", x: 0.64, y: 0.64),
                (key: "wr-right", x: 0.925, y: 0.52),
                (key: "te-right", x: 0.775, y: 0.565),
                (key: "de-right", x: 0.72, y: 0.475),
                (key: "ss-box", x: 0.66, y: 0.295),
                (key: "gun-left", x: 0.38, y: 0.655),
                (key: "back-right", x: 0.55, y: 0.72),
                (key: "slot-left", x: 0.205, y: 0.525),
                (key: "deep-right", x: 0.70, y: 0.155),
                (key: "box-left", x: 0.30, y: 0.28),
                (key: "edge-left", x: 0.165, y: 0.465)
            ],
            clues: [
                (player: "qb", family: .scenario, difficulty: .easy,
                 text: "The pocket broke right, and the orange cone out past the tackle marks where the passer escaped to — running hard to the right sideline, buying time with his legs.",
                 constraints: [.nearEvidence(player: "qb", evidence: "cone", radius: 0.08), .variantIs(player: "qb", variant: .fast)],
                 evidence: ["cone"]),
                (player: "wr", family: .relativePosition, difficulty: .medium,
                 text: "The sports drink cup at the far right numbers marks the receiver who works back toward the scrambling passer — shallower than the corner chasing him, wider than the tight end below. He has run this drill a thousand times.",
                 constraints: [.nearEvidence(player: "wr", evidence: "cup", radius: 0.08), .variantIs(player: "wr", variant: .veteran)],
                 evidence: ["cup"]),
                (player: "te", family: .footballResponsibility, difficulty: .medium,
                 text: "The chin strap near the right tackle marks the blocker still working: on a scramble, the tight end's job is to keep moving his feet and wall off whoever dares the edge.",
                 constraints: [.nearEvidence(player: "te", evidence: "strap", radius: 0.08), .variantIs(player: "te", variant: .power)],
                 evidence: ["strap"]),
                (player: "dl", family: .evidenceRelationship, difficulty: .medium,
                 text: "The skid marks at the right end mark the pursuer — the rusher who lost the pocket and now chases the play from behind. His first three steps decide everything.",
                 constraints: [.nearEvidence(player: "dl", evidence: "skid", radius: 0.08), .variantIs(player: "dl", variant: .power)],
                 evidence: ["skid"]),
                (player: "ss", family: .profileDeduction, difficulty: .hard,
                 text: "The shoulder-pad strap in the right second level marks the auxiliary rusher — but against a running quarterback, the staff wants pursuit, not power. Quickest second-level man on the roster.",
                 constraints: [.nearEvidence(player: "ss", evidence: "strap2", radius: 0.08), .variantIs(player: "ss", variant: .fast)],
                 evidence: ["strap2"])
            ],
            hints: [
                (player: "qb", text: "Out past the right tackle, escaping right — at the orange cone."),
                (player: "wr", text: "Far right numbers, working back toward the passer — by the sports drink cup."),
                (player: "te", text: "Right side, at the chin strap, still blocking."),
                (player: "dl", text: "Right end — over the skid marks, chasing from behind."),
                (player: "ss", text: "Right second level — at the shoulder-pad strap. Pursuit speed is the requirement.")
            ],
            solution: [
                (player: "qb", slot: "qb-scramble", variant: .fast),
                (player: "wr", slot: "wr-right", variant: .veteran),
                (player: "te", slot: "te-right", variant: .power),
                (player: "dl", slot: "de-right", variant: .power),
                (player: "ss", slot: "ss-box", variant: .fast)
            ]
        ),

        // 35 — Right All Along (seed 34)
        CaseLibrary.makeCase(
            id: "case_screen_right_bias_05", seed: 34, band: 4,
            title: "Right All Along",
            heading: "BIASED CALL SHEET",
            body: "Every formation leans right. The call sheet says the fourth one is the real one.",
            visible: Formation.build { b in
                b.line([0.30, 0.40, 0.50, 0.60])
                b.add(.qb, 0.50, 0.655)
                b.add(.te, 0.775, 0.565)
                b.add(.wr, 0.075, 0.53)
                b.add(.wr, 0.925, 0.52)
                b.front([0.28, 0.42, 0.58, 0.72])
                b.add(.lb, 0.50, 0.36)
                b.add(.lb, 0.34, 0.36)
                b.add(.cb, 0.075, 0.435)
                b.add(.fs, 0.50, 0.135)
            },
            missing: [
                (key: "rb", position: .rb),
                (key: "wr", position: .wr),
                (key: "ol", position: .ol),
                (key: "lb", position: .lb),
                (key: "cb", position: .cb)
            ],
            evidence: [
                (key: "cone", kind: .orangeCone, x: 0.635, y: 0.745, rotation: -10),
                (key: "cup", kind: .sportsDrinkCup, x: 0.785, y: 0.58, rotation: 18),
                (key: "stain", kind: .grassStain, x: 0.805, y: 0.40, rotation: 0),
                (key: "flag", kind: .challengeFlag, x: 0.615, y: 0.30, rotation: 16),
                (key: "tee", kind: .kickingTee, x: 0.685, y: 0.605, rotation: 10)
            ],
            slots: [
                (key: "rb-right", x: 0.62, y: 0.70),
                (key: "wr-slot", x: 0.80, y: 0.535),
                (key: "ol-rt", x: 0.70, y: 0.565),
                (key: "lb-right", x: 0.645, y: 0.355),
                (key: "cb-slot", x: 0.795, y: 0.44),
                (key: "back-left", x: 0.38, y: 0.70),
                (key: "slot-left", x: 0.205, y: 0.525),
                (key: "edge-right", x: 0.89, y: 0.455),
                (key: "box-deep-right", x: 0.72, y: 0.27),
                (key: "deep-right", x: 0.70, y: 0.155),
                (key: "te-left", x: 0.245, y: 0.565)
            ],
            clues: [
                (player: "rb", family: .scenario, difficulty: .easy,
                 text: "The orange cone in the right backfield lane marks the screen back: he sells the block for a count, then leaks out behind the traffic with the whole right side in front of him.",
                 constraints: [.nearEvidence(player: "rb", evidence: "cone", radius: 0.08), .variantIs(player: "rb", variant: .veteran)],
                 evidence: ["cone"]),
                (player: "wr", family: .formationKnowledge, difficulty: .medium,
                 text: "The sports drink cup in the right slot marks the blocker-receiver: he wedges the nickel for one full count, then slips him — timing, not wheels.",
                 constraints: [.nearEvidence(player: "wr", evidence: "cup", radius: 0.08), .variantIs(player: "wr", variant: .fast)],
                 evidence: ["cup"]),
                (player: "ol", family: .footballResponsibility, difficulty: .medium,
                 text: "The kicking tee in front of the vacant right tackle spot is where the puller starts his path — three steps down the line, then turn uphill and lead through the hole.",
                 constraints: [.nearEvidence(player: "ol", evidence: "tee", radius: 0.08), .variantIs(player: "ol", variant: .power)],
                 evidence: ["tee"]),
                (player: "lb", family: .profileDeduction, difficulty: .hard,
                 text: "The challenge flag at the right stack spot marks the force player. Everyone in this concept is fast; the defense needs the one who can blow up the lead block instead of running around it.",
                 constraints: [.nearEvidence(player: "lb", evidence: "flag", radius: 0.08), .variantIs(player: "lb", variant: .power)],
                 evidence: ["flag"]),
                (player: "cb", family: .evidenceRelationship, difficulty: .medium,
                 text: "The grass stain at the slot's heel marks the nickel corner. He has to beat the receiver's wedge block at full speed — hands first, never dive.",
                 constraints: [.nearEvidence(player: "cb", evidence: "stain", radius: 0.08), .variantIs(player: "cb", variant: .fast)],
                 evidence: ["stain"])
            ],
            hints: [
                (player: "rb", text: "Right backfield — at the orange cone."),
                (player: "wr", text: "The right slot, just off the tackle — the sports drink cup marks him."),
                (player: "ol", text: "The right tackle spot — the kicking tee marks the puller's start."),
                (player: "lb", text: "Right stack spot — at the challenge flag. Blow up the lead block."),
                (player: "cb", text: "At the slot receiver's heel — the grass stain. Hands first.")
            ],
            solution: [
                (player: "rb", slot: "rb-right", variant: .veteran),
                (player: "wr", slot: "wr-slot", variant: .fast),
                (player: "ol", slot: "ol-rt", variant: .power),
                (player: "lb", slot: "lb-right", variant: .power),
                (player: "cb", slot: "cb-slot", variant: .fast)
            ]
        ),

        // 36 — Zero Help (seed 35)
        CaseLibrary.makeCase(
            id: "case_cover_zero_rush_06", seed: 35, band: 4,
            title: "Zero Help",
            heading: "ALL-OUT BLITZ",
            body: "No safeties deep, no backs spared. Every man is part of the storm.",
            visible: Formation.build { b in
                b.line([0.30, 0.40, 0.50, 0.60, 0.70])
                b.add(.rb, 0.42, 0.68)
                b.add(.te, 0.775, 0.565)
                b.add(.wr, 0.075, 0.53)
                b.front([0.28, 0.42, 0.58])
                b.add(.lb, 0.50, 0.36)
                b.add(.lb, 0.34, 0.36)
                b.add(.cb, 0.075, 0.435)
                b.add(.ss, 0.66, 0.24)
            },
            missing: [
                (key: "qb", position: .qb),
                (key: "wr", position: .wr),
                (key: "de", position: .dl),
                (key: "dl2", position: .dl),
                (key: "fs", position: .fs)
            ],
            evidence: [
                (key: "mud", kind: .muddyFootprints, x: 0.515, y: 0.715, rotation: 55),
                (key: "bottle", kind: .waterBottle, x: 0.955, y: 0.555, rotation: 65),
                (key: "divot", kind: .divot, x: 0.175, y: 0.43, rotation: -14),
                (key: "chain", kind: .chainMarker, x: 0.505, y: 0.52, rotation: 6),
                (key: "marks", kind: .cleatMarks, x: 0.49, y: 0.095, rotation: 20)
            ],
            slots: [
                (key: "qb-gun", x: 0.50, y: 0.655),
                (key: "wr-right", x: 0.925, y: 0.52),
                (key: "de-edge", x: 0.165, y: 0.465),
                (key: "dt-nose", x: 0.50, y: 0.475),
                (key: "fs-center", x: 0.50, y: 0.13),
                (key: "under-center", x: 0.50, y: 0.63),
                (key: "back-left", x: 0.38, y: 0.70),
                (key: "slot-left", x: 0.205, y: 0.525),
                (key: "edge-right", x: 0.835, y: 0.465),
                (key: "deep-right", x: 0.70, y: 0.155),
                (key: "box-left", x: 0.30, y: 0.28)
            ],
            clues: [
                (player: "qb", family: .scenario, difficulty: .easy,
                 text: "Zero coverage means everyone comes, and the muddy footprints four yards behind the line mark the passer who has exactly one beat to punish it. His legs are the answer key.",
                 constraints: [.nearEvidence(player: "qb", evidence: "mud", radius: 0.08), .variantIs(player: "qb", variant: .fast)],
                 evidence: ["mud"]),
                (player: "wr", family: .formationKnowledge, difficulty: .medium,
                 text: "The water bottle at the far right numbers marks the man one-on-one with no safety. Against zero, the isolated receiver is the whole plan — he beats his man clean or the play never happened.",
                 constraints: [.nearEvidence(player: "wr", evidence: "bottle", radius: 0.08), .variantIs(player: "wr", variant: .fast)],
                 evidence: ["bottle"]),
                (player: "de", family: .footballResponsibility, difficulty: .medium,
                 text: "The divot beyond the left tackle marks the edge sellout — standing up, wide, first man off the bus. The tight end cannot possibly reach him in time.",
                 constraints: [.nearEvidence(player: "de", evidence: "divot", radius: 0.08), .variantIs(player: "de", variant: .power)],
                 evidence: ["divot"]),
                (player: "dl2", family: .evidenceRelationship, difficulty: .medium,
                 text: "The chain marker dragged to dead center in the front marks the A-gap blitzer. He does not read anything — the count is his entire world.",
                 constraints: [.nearEvidence(player: "dl2", evidence: "chain", radius: 0.08), .variantIs(player: "dl2", variant: .power)],
                 evidence: ["chain"]),
                (player: "fs", family: .orderDepth, difficulty: .hard,
                 text: "The cleat marks at the very top of the picture are the lone deep defender's post — the one man the blitz left standing between a beaten coverage and six points.",
                 constraints: [.nearEvidence(player: "fs", evidence: "marks", radius: 0.08), .variantIs(player: "fs", variant: .veteran)],
                 evidence: ["marks"])
            ],
            hints: [
                (player: "qb", text: "Center of the gun, four yards deep — where the muddy footprints churn."),
                (player: "wr", text: "Far right numbers — by the water bottle, all alone."),
                (player: "de", text: "Left edge, wide and standing up — over the divot."),
                (player: "dl2", text: "Dead center in the front — at the dragged chain marker."),
                (player: "fs", text: "Top center, the only deep man — at the cleat marks.")
            ],
            solution: [
                (player: "qb", slot: "qb-gun", variant: .fast),
                (player: "wr", slot: "wr-right", variant: .fast),
                (player: "de", slot: "de-edge", variant: .power),
                (player: "dl2", slot: "dt-nose", variant: .power),
                (player: "fs", slot: "fs-center", variant: .veteran)
            ]
        ),

        // 37 — Broken Gap Integrity (seed 36)
        CaseLibrary.makeCase(
            id: "case_gap_integrity_07", seed: 36, band: 4,
            title: "Broken Gap Integrity",
            heading: "RUN FIT FAILURE",
            body: "One defender is out of his gap. The whole run fits falls apart without him.",
            visible: Formation.build { b in
                b.line([0.30, 0.40, 0.50, 0.60])
                b.add(.qb, 0.50, 0.63)
                b.add(.rb, 0.50, 0.71)
                b.add(.wr, 0.075, 0.53)
                b.add(.wr, 0.925, 0.52)
                b.front([0.28, 0.42, 0.58, 0.72])
                b.add(.lb, 0.50, 0.36)
                b.add(.lb, 0.34, 0.36)
                b.add(.cb, 0.925, 0.435)
                b.add(.fs, 0.50, 0.135)
            },
            missing: [
                (key: "rb", position: .rb),
                (key: "ol", position: .ol),
                (key: "dl", position: .dl),
                (key: "lb", position: .lb),
                (key: "ss", position: .ss)
            ],
            evidence: [
                (key: "brace", kind: .kneeBrace, x: 0.505, y: 0.835, rotation: -4),
                (key: "tee", kind: .kickingTee, x: 0.71, y: 0.605, rotation: 10),
                (key: "mud", kind: .muddyFootprints, x: 0.585, y: 0.43, rotation: 55),
                (key: "flag", kind: .challengeFlag, x: 0.615, y: 0.30, rotation: 16),
                (key: "strap", kind: .shoulderPadStrap, x: 0.725, y: 0.31, rotation: -35)
            ],
            slots: [
                (key: "rb-deep", x: 0.50, y: 0.79),
                (key: "ol-rt", x: 0.70, y: 0.565),
                (key: "dt-3tech", x: 0.58, y: 0.475),
                (key: "lb-right", x: 0.655, y: 0.35),
                (key: "ss-box", x: 0.70, y: 0.27),
                (key: "back-left", x: 0.38, y: 0.70),
                (key: "te-left", x: 0.245, y: 0.565),
                (key: "edge-left", x: 0.165, y: 0.465),
                (key: "box-left", x: 0.30, y: 0.28),
                (key: "slot-right", x: 0.85, y: 0.46),
                (key: "deep-center", x: 0.50, y: 0.115)
            ],
            clues: [
                (player: "rb", family: .orderDepth, difficulty: .easy,
                 text: "The knee brace at the deepest backfield spot marks the runner: one cut, downhill, and he tests the first gap that shows him daylight.",
                 constraints: [.nearEvidence(player: "rb", evidence: "brace", radius: 0.08), .variantIs(player: "rb", variant: .power)],
                 evidence: ["brace"]),
                (player: "ol", family: .formationKnowledge, difficulty: .medium,
                 text: "The kicking tee in front of the vacant right tackle spot marks the gap defender's nightmare — a sixth blocker across the line of scrimmage who exists only to keep the pocket square.",
                 constraints: [.nearEvidence(player: "ol", evidence: "tee", radius: 0.08), .variantIs(player: "ol", variant: .power)],
                 evidence: ["tee"]),
                (player: "dl", family: .evidenceRelationship, difficulty: .medium,
                 text: "The muddy footprints at the three-technique mark the slanter: he shoots the guard's outside shoulder so the back's first cut has nowhere to go.",
                 constraints: [.nearEvidence(player: "dl", evidence: "mud", radius: 0.08), .variantIs(player: "dl", variant: .fast)],
                 evidence: ["mud"]),
                (player: "lb", family: .chainedDeduction, difficulty: .hard,
                 text: "The challenge flag at the right stack spot marks the fill player — below the box safety, above nothing. When the slant spills the run outside, he is the last gap between the ball carrier and the second level.",
                 constraints: [.nearEvidence(player: "lb", evidence: "flag", radius: 0.08), .yBelow(a: "lb", b: "ss", gap: 0.05), .variantIs(player: "lb", variant: .veteran)],
                 evidence: ["flag"]),
                (player: "ss", family: .profileDeduction, difficulty: .medium,
                 text: "The shoulder-pad strap at the right box safety's alignment marks the extra hat. The staff does not need range from this spot — it needs a battering ram that ends the play in the hole.",
                 constraints: [.nearEvidence(player: "ss", evidence: "strap", radius: 0.08), .variantIs(player: "ss", variant: .power)],
                 evidence: ["strap"])
            ],
            hints: [
                (player: "rb", text: "Deepest in the backfield — at the knee brace."),
                (player: "ol", text: "The unfilled right tackle spot — the kicking tee points the way."),
                (player: "dl", text: "At the three-technique — over the muddy churn, slanting outside."),
                (player: "lb", text: "Right stack spot, below the box safety — at the challenge flag."),
                (player: "ss", text: "Right box alignment — at the shoulder-pad strap. A battering ram.")
            ],
            solution: [
                (player: "rb", slot: "rb-deep", variant: .power),
                (player: "ol", slot: "ol-rt", variant: .power),
                (player: "dl", slot: "dt-3tech", variant: .fast),
                (player: "lb", slot: "lb-right", variant: .veteran),
                (player: "ss", slot: "ss-box", variant: .power)
            ]
        ),

        // 38 — The Double Move (seed 37)
        CaseLibrary.makeCase(
            id: "case_dbl_move_sideline_08", seed: 37, band: 4,
            title: "The Double Move",
            heading: "TAKE THE BAIT",
            body: "The receiver sold the out route. Now everyone who bit it is chasing.",
            visible: Formation.build { b in
                b.line([0.30, 0.40, 0.50, 0.60, 0.70])
                b.add(.qb, 0.50, 0.655)
                b.add(.rb, 0.42, 0.68)
                b.add(.wr, 0.075, 0.53)
                b.front([0.28, 0.42, 0.58, 0.72])
                b.add(.lb, 0.50, 0.36)
                b.add(.lb, 0.34, 0.36)
                b.add(.cb, 0.075, 0.435)
                b.add(.ss, 0.35, 0.24)
            },
            missing: [
                (key: "wr", position: .wr),
                (key: "te", position: .te),
                (key: "cb", position: .cb),
                (key: "fs", position: .fs),
                (key: "lb", position: .lb)
            ],
            evidence: [
                (key: "card", kind: .droppedPlayCard, x: 0.945, y: 0.565, rotation: -8),
                (key: "cone", kind: .orangeCone, x: 0.905, y: 0.395, rotation: -12),
                (key: "playbook", kind: .wristPlaybook, x: 0.79, y: 0.615, rotation: 12),
                (key: "wet", kind: .wetPatch, x: 0.48, y: 0.165, rotation: 0),
                (key: "chain", kind: .chainMarker, x: 0.355, y: 0.315, rotation: 6)
            ],
            slots: [
                (key: "wr-right", x: 0.925, y: 0.52),
                (key: "te-right", x: 0.775, y: 0.565),
                (key: "cb-right", x: 0.925, y: 0.435),
                (key: "fs-center", x: 0.50, y: 0.13),
                (key: "lb-left", x: 0.34, y: 0.36),
                (key: "slot-left", x: 0.205, y: 0.525),
                (key: "edge-left", x: 0.165, y: 0.465),
                (key: "box-right", x: 0.66, y: 0.295),
                (key: "deep-right", x: 0.70, y: 0.155),
                (key: "left-backer", x: 0.26, y: 0.33),
                (key: "te-left", x: 0.245, y: 0.565)
            ],
            clues: [
                (player: "te", family: .footballResponsibility, difficulty: .easy,
                 text: "While the corner chases the bait, the right side still needs blocking: the wrist playbook outside the right tackle marks the tight end who turns the edge into a wall.",
                 constraints: [.nearEvidence(player: "te", evidence: "playbook", radius: 0.08), .variantIs(player: "te", variant: .veteran)],
                 evidence: ["playbook"]),
                (player: "wr", family: .scenario, difficulty: .medium,
                 text: "The dropped play card at the far right numbers marks the salesman himself — the receiver who snapped off the fake out and is now running free behind everyone who believed it.",
                 constraints: [.nearEvidence(player: "wr", evidence: "card", radius: 0.08), .variantIs(player: "wr", variant: .fast)],
                 evidence: ["card"]),
                (player: "cb", family: .elimination, difficulty: .medium,
                 text: "The orange cone inside the receiver's alignment marks the defender in the trail — and the call sheet says neither the power build nor the veteran. Only legs that can flip and run survive the double move.",
                 constraints: [.nearEvidence(player: "cb", evidence: "cone", radius: 0.08), .variantIsNot(player: "cb", variant: .power), .variantIsNot(player: "cb", variant: .veteran)],
                 evidence: ["cone"]),
                (player: "fs", family: .evidenceRelationship, difficulty: .hard,
                 text: "The wet patch at the very top of the picture, dead center, is the deep half's post. The double move is aimed directly at him — he has to read the receiver's hips, not his eyes.",
                 constraints: [.nearEvidence(player: "fs", evidence: "wet", radius: 0.08), .variantIs(player: "fs", variant: .veteran)],
                 evidence: ["wet"]),
                (player: "lb", family: .profileDeduction, difficulty: .medium,
                 text: "The chain marker dragged to the left inside backer spot marks the hook player. With everyone chasing the deep bait, his job is the exact opposite: sit, wait, and take away the comeback route underneath.",
                 constraints: [.nearEvidence(player: "lb", evidence: "chain", radius: 0.08), .variantIs(player: "lb", variant: .power)],
                 evidence: ["chain"])
            ],
            hints: [
                (player: "te", text: "Right side, just beyond the right tackle — where the wrist playbook was dropped."),
                (player: "wr", text: "Far right numbers — by the dropped play card. He sold the fake."),
                (player: "cb", text: "Inside the receiver's alignment — at the orange cone. Flip and run."),
                (player: "fs", text: "Top center, deepest man — beside the wet patch. Read the hips."),
                (player: "lb", text: "Left inside backer spot — where the chain marker sits. Sit on the comeback.")
            ],
            solution: [
                (player: "wr", slot: "wr-right", variant: .fast),
                (player: "te", slot: "te-right", variant: .veteran),
                (player: "cb", slot: "cb-right", variant: .fast),
                (player: "fs", slot: "fs-center", variant: .veteran),
                (player: "lb", slot: "lb-left", variant: .power)
            ]
        ),

        // 39 — Two Minutes, Five Wide (seed 38)
        CaseLibrary.makeCase(
            id: "case_two_minute_spread_09", seed: 38, band: 4,
            title: "Two Minutes, Five Wide",
            heading: "HURRY-UP OFFENSE",
            body: "No huddle, no backs, no time. The defense is substituting — and losing.",
            visible: Formation.build { b in
                b.line([0.30, 0.40, 0.50, 0.60])
                b.add(.wr, 0.075, 0.53)
                b.add(.wr, 0.22, 0.525)
                b.front([0.28, 0.42, 0.58, 0.72])
                b.add(.lb, 0.50, 0.36)
                b.add(.lb, 0.34, 0.36)
                b.add(.cb, 0.075, 0.435)
                b.add(.cb, 0.925, 0.435)
                b.add(.fs, 0.50, 0.135)
            },
            missing: [
                (key: "qb", position: .qb),
                (key: "wr1", position: .wr),
                (key: "wr2", position: .wr),
                (key: "ol", position: .ol),
                (key: "de", position: .dl)
            ],
            evidence: [
                (key: "mud", kind: .muddyFootprints, x: 0.515, y: 0.715, rotation: 55),
                (key: "band", kind: .wristband, x: 0.78, y: 0.60, rotation: 8),
                (key: "cup", kind: .sportsDrinkCup, x: 0.955, y: 0.565, rotation: 18),
                (key: "tee", kind: .kickingTee, x: 0.685, y: 0.605, rotation: 10),
                (key: "strap", kind: .brokenHelmetStrap, x: 0.845, y: 0.42, rotation: -22)
            ],
            slots: [
                (key: "qb-gun", x: 0.50, y: 0.655),
                (key: "wr1-right", x: 0.925, y: 0.52),
                (key: "wr2-slot", x: 0.765, y: 0.535),
                (key: "ol-rt", x: 0.70, y: 0.565),
                (key: "de-edge", x: 0.845, y: 0.465),
                (key: "gun-left", x: 0.38, y: 0.655),
                (key: "deep-gun", x: 0.38, y: 0.79),
                (key: "slot-left", x: 0.14, y: 0.52),
                (key: "box-deep-right", x: 0.72, y: 0.27),
                (key: "edge-left", x: 0.165, y: 0.465),
                (key: "back-right", x: 0.62, y: 0.70)
            ],
            clues: [
                (player: "qb", family: .scenario, difficulty: .easy,
                 text: "The muddy footprints four yards behind the line, dead center, mark the hurry-up passer — he is in the gun calling his own plays, and with this little time left, every second he holds the ball is a second he does not have.",
                 constraints: [.nearEvidence(player: "qb", evidence: "mud", radius: 0.08), .variantIs(player: "qb", variant: .fast)],
                 evidence: ["mud"]),
                (player: "wr1", family: .relativePosition, difficulty: .medium,
                 text: "The sports drink cup at the far right numbers marks the sideline worker — wider than the slot, shallower than the corner. In two-minute, his job is to get out of bounds, always.",
                 constraints: [.nearEvidence(player: "wr1", evidence: "cup", radius: 0.08), .variantIs(player: "wr1", variant: .veteran)],
                 evidence: ["cup"]),
                (player: "wr2", family: .formationKnowledge, difficulty: .medium,
                 text: "The wristband inside of him marks the chain mover: off the tackle, at the sticks, the quick throw that keeps the clock running while the defense scrambles to substitute.",
                 constraints: [.nearEvidence(player: "wr2", evidence: "band", radius: 0.08), .variantIs(player: "wr2", variant: .fast)],
                 evidence: ["band"]),
                (player: "ol", family: .footballResponsibility, difficulty: .medium,
                 text: "The kicking tee in front of the vacant right tackle spot marks the pass protector — in this package he backpedals forever and touches nobody, and the one time he lunges, the drive dies.",
                 constraints: [.nearEvidence(player: "ol", evidence: "tee", radius: 0.08), .variantIs(player: "ol", variant: .power)],
                 evidence: ["tee"]),
                (player: "de", family: .evidenceRelationship, difficulty: .hard,
                 text: "The broken helmet strap beyond the tackle marks the designated rusher — while his teammates drop into walls, he has one job: the fastest possible path to the quarterback's blind side.",
                 constraints: [.nearEvidence(player: "de", evidence: "strap", radius: 0.08), .variantIs(player: "de", variant: .fast)],
                 evidence: ["strap"])
            ],
            hints: [
                (player: "qb", text: "In the gun, dead center — right at the muddy footprints."),
                (player: "wr1", text: "Far right numbers — by the sports drink cup. Get out of bounds."),
                (player: "wr2", text: "Right slot — where the wristband lies. The chain mover."),
                (player: "ol", text: "The right tackle hole in the wall — the kicking tee marks the fix."),
                (player: "de", text: "Right edge — at the broken helmet strap. The designated rusher.")
            ],
            solution: [
                (player: "qb", slot: "qb-gun", variant: .fast),
                (player: "wr1", slot: "wr1-right", variant: .veteran),
                (player: "wr2", slot: "wr2-slot", variant: .fast),
                (player: "ol", slot: "ol-rt", variant: .power),
                (player: "de", slot: "de-edge", variant: .fast)
            ]
        ),

        // 40 — The Red-Zone Stamp (seed 39)
        CaseLibrary.makeCase(
            id: "case_red_zone_stamp_10", seed: 39, band: 4,
            title: "The Red-Zone Stamp",
            heading: "SCORING POSITION",
            body: "Eight yards from the end zone. One correct read stamps the quarter.",
            visible: Formation.build { b in
                b.line([0.30, 0.40, 0.50, 0.60, 0.70])
                b.add(.qb, 0.50, 0.63)
                b.add(.rb, 0.50, 0.71)
                b.add(.wr, 0.075, 0.53)
                b.add(.wr, 0.925, 0.52)
                b.front([0.28, 0.42, 0.58, 0.72])
                b.add(.lb, 0.50, 0.36)
                b.add(.lb, 0.34, 0.36)
                b.add(.cb, 0.075, 0.435)
                b.add(.fs, 0.50, 0.135)
            },
            missing: [
                (key: "te", position: .te),
                (key: "rb", position: .rb),
                (key: "dl", position: .dl),
                (key: "cb", position: .cb),
                (key: "ss", position: .ss)
            ],
            evidence: [
                (key: "sheet", kind: .laminatedPlaySheet, x: 0.795, y: 0.62, rotation: -6),
                (key: "brace", kind: .kneeBrace, x: 0.505, y: 0.835, rotation: -4),
                (key: "skid", kind: .skidMarks, x: 0.725, y: 0.435, rotation: 12),
                (key: "visor", kind: .visorCloth, x: 0.945, y: 0.475, rotation: 30),
                (key: "strap", kind: .shoulderPadStrap, x: 0.675, y: 0.335, rotation: -35)
            ],
            slots: [
                (key: "te-right", x: 0.775, y: 0.565),
                (key: "rb-deep", x: 0.50, y: 0.79),
                (key: "de-right", x: 0.72, y: 0.475),
                (key: "cb-right", x: 0.925, y: 0.435),
                (key: "ss-box", x: 0.66, y: 0.295),
                (key: "back-left", x: 0.38, y: 0.70),
                (key: "te-left", x: 0.245, y: 0.565),
                (key: "edge-left", x: 0.165, y: 0.465),
                (key: "box-left", x: 0.30, y: 0.28),
                (key: "deep-center", x: 0.50, y: 0.115),
                (key: "slot-right", x: 0.84, y: 0.44)
            ],
            clues: [
                (player: "te", family: .footballResponsibility, difficulty: .medium,
                 text: "The laminated play sheet dropped outside the right tackle is the goal-line package — an eligible giant attaches there, and the throw to his corner of the end zone is the whole plan B.",
                 constraints: [.nearEvidence(player: "te", evidence: "sheet", radius: 0.08), .variantIs(player: "te", variant: .veteran)],
                 evidence: ["sheet"]),
                (player: "rb", family: .orderDepth, difficulty: .easy,
                 text: "The knee brace at the deepest backfield spot marks the punch-back: behind the fullback, one cut, and the pile decides the rest.",
                 constraints: [.nearEvidence(player: "rb", evidence: "brace", radius: 0.08), .variantIs(player: "rb", variant: .power)],
                 evidence: ["brace"]),
                (player: "dl", family: .scenario, difficulty: .medium,
                 text: "The skid marks at the right end mark the crunch defender — he takes on the new blocker head-on so nobody reaches the second level.",
                 constraints: [.nearEvidence(player: "dl", evidence: "skid", radius: 0.08), .variantIs(player: "dl", variant: .power)],
                 evidence: ["skid"]),
                (player: "cb", family: .evidenceRelationship, difficulty: .medium,
                 text: "The visor cloth at the right corner's post marks the man on the lone wide receiver. In the red zone he plays with his hands at the line — the fade dies at the release.",
                 constraints: [.nearEvidence(player: "cb", evidence: "visor", radius: 0.08), .variantIs(player: "cb", variant: .fast)],
                 evidence: ["visor"]),
                (player: "ss", family: .profileDeduction, difficulty: .hard,
                 text: "The shoulder-pad strap at the right roamer's alignment marks the stamp itself: a body in the box that arrives angry. Range is irrelevant from eight yards — mass is everything.",
                 constraints: [.nearEvidence(player: "ss", evidence: "strap", radius: 0.08), .variantIs(player: "ss", variant: .power)],
                 evidence: ["strap"])
            ],
            hints: [
                (player: "te", text: "Right side, just beyond the right tackle — where the laminated play sheet dropped."),
                (player: "rb", text: "Deepest man in the backfield — right where the knee brace sits."),
                (player: "dl", text: "Right end — over the skid marks, crunching the new blocker."),
                (player: "cb", text: "Right sideline, mirroring the visible receiver — where the visor cloth sits."),
                (player: "ss", text: "Right box alignment — at the shoulder-pad strap. Mass over range.")
            ],
            solution: [
                (player: "te", slot: "te-right", variant: .veteran),
                (player: "rb", slot: "rb-deep", variant: .power),
                (player: "dl", slot: "de-right", variant: .power),
                (player: "cb", slot: "cb-right", variant: .fast),
                (player: "ss", slot: "ss-box", variant: .power)
            ]
        )
    ]
}

import Foundation

/// Band 2 — second-quarter cases: five missing players each, mixed
/// offense/defense balance, and clue logic that leans harder on relationships.
nonisolated enum CasePack2 {
    static let all: [QuarterCase] = [

        // 11 — Nobody in the Backfield (seed 10)
        CaseLibrary.makeCase(
            id: "case_empty_backfield_01", seed: 10, band: 2,
            title: "Nobody in the Backfield",
            heading: "EMPTY SET",
            body: "Five wide, no backs, no mercy. The picture is missing its author.",
            visible: Formation.build { b in
                b.line([0.30, 0.40, 0.50, 0.60, 0.70])
                b.add(.wr, 0.075, 0.53)
                b.add(.wr, 0.22, 0.525)
                b.front([0.28, 0.42, 0.58, 0.72])
                b.add(.lb, 0.50, 0.36)
                b.add(.cb, 0.075, 0.435)
                b.add(.fs, 0.50, 0.135)
            },
            missing: [
                (key: "qb", position: .qb),
                (key: "wr1", position: .wr),
                (key: "wr2", position: .wr),
                (key: "de", position: .dl),
                (key: "ss", position: .ss)
            ],
            evidence: [
                (key: "mud", kind: .muddyFootprints, x: 0.505, y: 0.71, rotation: 55),
                (key: "band", kind: .wristband, x: 0.775, y: 0.585, rotation: 8),
                (key: "strap", kind: .brokenHelmetStrap, x: 0.86, y: 0.50, rotation: -22),
                (key: "bottle", kind: .waterBottle, x: 0.97, y: 0.565, rotation: 70),
                (key: "strap2", kind: .shoulderPadStrap, x: 0.325, y: 0.335, rotation: -35)
            ],
            slots: [
                (key: "qb-gun", x: 0.50, y: 0.655),
                (key: "wr1-right", x: 0.955, y: 0.52),
                (key: "wr2-slot", x: 0.765, y: 0.535),
                (key: "de-edge", x: 0.875, y: 0.465),
                (key: "ss-box", x: 0.34, y: 0.295),
                (key: "left-gun", x: 0.38, y: 0.655),
                (key: "slot-left", x: 0.14, y: 0.52),
                (key: "box-right", x: 0.66, y: 0.295),
                (key: "deep-right", x: 0.70, y: 0.155),
                (key: "edge-left", x: 0.165, y: 0.465)
            ],
            clues: [
                (player: "qb", family: .scenario, difficulty: .easy,
                 text: "With no back to protect him, the passer stands alone in the gun — the muddy footprints four yards behind the line, dead center, are his. The play dies with him, so he'd better be able to move.",
                 constraints: [.nearEvidence(player: "qb", evidence: "mud", radius: 0.08), .variantIs(player: "qb", variant: .fast)],
                 evidence: ["mud"]),
                (player: "wr1", family: .formationKnowledge, difficulty: .medium,
                 text: "Empty sets live on the perimeter. The widest man splits to the far right numbers, where the water bottle was left — the veteran who always knows the exact sideline blade of grass to stand on.",
                 constraints: [.nearEvidence(player: "wr1", evidence: "bottle", radius: 0.08), .variantIs(player: "wr1", variant: .veteran)],
                 evidence: ["bottle"]),
                (player: "wr2", family: .footballResponsibility, difficulty: .medium,
                 text: "The slot man aligns off the right tackle, where the wristband was tossed. Inside of five yards everything happens at once out there — he wins with a first step, not a forty time.",
                 constraints: [.nearEvidence(player: "wr2", evidence: "band", radius: 0.08), .variantIs(player: "wr2", variant: .fast)],
                 evidence: ["band"]),
                (player: "de", family: .evidenceRelationship, difficulty: .medium,
                 text: "Against empty sets the defense sends their best rusher wide — the broken helmet strap just beyond the right tackle marks his path. Straight off the edge, full speed, no ceremonies.",
                 constraints: [.nearEvidence(player: "de", evidence: "strap", radius: 0.08), .variantIs(player: "de", variant: .fast)],
                 evidence: ["strap"]),
                (player: "ss", family: .chainedDeduction, difficulty: .hard,
                 text: "The shoulder-pad strap abandoned on the left second level marks the box player. He aligns well up the field of the wide rusher's lane, between the front and the deep middle — there to stop the run the empty set is faking.",
                 constraints: [.nearEvidence(player: "ss", evidence: "strap2", radius: 0.08), .yAbove(a: "ss", b: "de", gap: 0.15), .variantIs(player: "ss", variant: .power)],
                 evidence: ["strap2"])
            ],
            hints: [
                (player: "qb", text: "Dead center in the gun, four yards behind the line — at the muddy footprints."),
                (player: "wr1", text: "Far right numbers, on the line of scrimmage — by the water bottle."),
                (player: "wr2", text: "Inside right, off the tackle — where the wristband was tossed."),
                (player: "de", text: "Right edge, just beyond the tackle — the broken strap marks his rush lane."),
                (player: "ss", text: "Left second level, higher up the field than the edge rusher — at the shoulder-pad strap.")
            ],
            solution: [
                (player: "qb", slot: "qb-gun", variant: .fast),
                (player: "wr1", slot: "wr1-right", variant: .veteran),
                (player: "wr2", slot: "wr2-slot", variant: .fast),
                (player: "de", slot: "de-edge", variant: .fast),
                (player: "ss", slot: "ss-box", variant: .power)
            ]
        ),

        // 12 — The Fourth Corner (seed 11)
        CaseLibrary.makeCase(
            id: "case_nickel_slot_02", seed: 11, band: 2,
            title: "The Fourth Corner",
            heading: "NICKEL LOOK",
            body: "The defense brings an extra defensive back. The offense brings a mismatch hunter.",
            visible: Formation.build { b in
                b.line([0.30, 0.40, 0.50, 0.60, 0.70])
                b.add(.qb, 0.50, 0.655)
                b.add(.rb, 0.42, 0.68)
                b.add(.wr, 0.075, 0.53)
                b.add(.wr, 0.925, 0.52)
                b.front([0.28, 0.42, 0.58, 0.72])
                b.add(.lb, 0.50, 0.36)
                b.add(.ss, 0.66, 0.24)
                b.add(.fs, 0.50, 0.135)
            },
            missing: [
                (key: "wr", position: .wr),
                (key: "te", position: .te),
                (key: "cb1", position: .cb),
                (key: "cb2", position: .cb),
                (key: "lb", position: .lb)
            ],
            evidence: [
                (key: "cup", kind: .sportsDrinkCup, x: 0.79, y: 0.575, rotation: 16),
                (key: "cone", kind: .orangeCone, x: 0.805, y: 0.40, rotation: -12),
                (key: "tape", kind: .tapeRoll, x: 0.235, y: 0.525, rotation: 40),
                (key: "stain", kind: .grassStain, x: 0.09, y: 0.40, rotation: 0),
                (key: "flag", kind: .challengeFlag, x: 0.675, y: 0.315, rotation: 16)
            ],
            slots: [
                (key: "wr-slot", x: 0.80, y: 0.535),
                (key: "te-left", x: 0.245, y: 0.565),
                (key: "cb-slot", x: 0.795, y: 0.44),
                (key: "cb-left", x: 0.075, y: 0.435),
                (key: "lb-right", x: 0.66, y: 0.36),
                (key: "slot-left", x: 0.14, y: 0.52),
                (key: "edge-right", x: 0.89, y: 0.455),
                (key: "box-left", x: 0.30, y: 0.28),
                (key: "deep-left", x: 0.30, y: 0.155),
                (key: "deep-right", x: 0.70, y: 0.155)
            ],
            clues: [
                (player: "cb2", family: .relativePosition, difficulty: .easy,
                 text: "Straight across from the visible left receiver, just past the line of scrimmage, the grass stain shows a post worked hard all game. Outside leverage, no help — a straightforward assignment.",
                 constraints: [.nearEvidence(player: "cb2", evidence: "stain", radius: 0.08), .variantIs(player: "cb2", variant: .fast)],
                 evidence: ["stain"]),
                (player: "te", family: .footballResponsibility, difficulty: .medium,
                 text: "The left side needs an extra blocker outside the tackle, tight to the line, where the tape roll was left behind. He wins by landing first and staying attached.",
                 constraints: [.nearEvidence(player: "te", evidence: "tape", radius: 0.08), .variantIs(player: "te", variant: .power)],
                 evidence: ["tape"]),
                (player: "wr", family: .formationKnowledge, difficulty: .medium,
                 text: "The offense slides its best route runner into the right slot, just off the tackle where the sports drink cup sits. Slot play is about quickness out of a standstill — power is wasted there.",
                 constraints: [.nearEvidence(player: "wr", evidence: "cup", radius: 0.08), .variantIs(player: "wr", variant: .fast)],
                 evidence: ["cup"]),
                (player: "lb", family: .evidenceRelationship, difficulty: .medium,
                 text: "The challenge flag in the right second level marks where the defense keeps a run-first backer against the tight end's side. He splits the difference between the line and the deep men.",
                 constraints: [.nearEvidence(player: "lb", evidence: "flag", radius: 0.08), .variantIs(player: "lb", variant: .veteran)],
                 evidence: ["flag"]),
                (player: "cb1", family: .elimination, difficulty: .hard,
                 text: "The orange cone at the slot's heel is the nickel corner's press alignment. The staff's note is blunt: not the veteran, not the speedster — they want the one who plays with his hands and never gives ground.",
                 constraints: [.nearEvidence(player: "cb1", evidence: "cone", radius: 0.08), .variantIsNot(player: "cb1", variant: .veteran), .variantIsNot(player: "cb1", variant: .fast)],
                 evidence: ["cone"])
            ],
            hints: [
                (player: "cb2", text: "Left sideline across from the visible receiver — the grass stain gives it away."),
                (player: "te", text: "Left side, outside the left tackle — at the tape roll."),
                (player: "wr", text: "Right slot, off the tackle — by the sports drink cup."),
                (player: "lb", text: "Right second level — the challenge flag marks his spot."),
                (player: "cb1", text: "At the slot receiver's heel, on the line of scrimmage — the orange cone. Hands, not heels.")
            ],
            solution: [
                (player: "wr", slot: "wr-slot", variant: .fast),
                (player: "te", slot: "te-left", variant: .power),
                (player: "cb1", slot: "cb-slot", variant: .power),
                (player: "cb2", slot: "cb-left", variant: .fast),
                (player: "lb", slot: "lb-right", variant: .veteran)
            ]
        ),

        // 13 — The Wall at One (seed 12)
        CaseLibrary.makeCase(
            id: "case_goal_line_stand_03", seed: 12, band: 2,
            title: "The Wall at One",
            heading: "GOAL-TO-GO",
            body: "Half a yard decides everything. The picture is a fistfight waiting to happen.",
            visible: Formation.build { b in
                b.line([0.30, 0.40, 0.50, 0.60, 0.70])
                b.add(.qb, 0.50, 0.63)
                b.add(.rb, 0.50, 0.71)
                b.add(.wr, 0.925, 0.52)
                b.front([0.28, 0.42, 0.58])
                b.add(.lb, 0.34, 0.36)
                b.add(.cb, 0.925, 0.435)
            },
            missing: [
                (key: "te", position: .te),
                (key: "ol", position: .ol),
                (key: "dl", position: .dl),
                (key: "lb", position: .lb),
                (key: "ss", position: .ss)
            ],
            evidence: [
                (key: "strap", kind: .chinStrap, x: 0.785, y: 0.615, rotation: -28),
                (key: "brace", kind: .kneeBrace, x: 0.215, y: 0.525, rotation: -4),
                (key: "divot", kind: .divot, x: 0.495, y: 0.43, rotation: -14),
                (key: "chain", kind: .chainMarker, x: 0.64, y: 0.33, rotation: 6),
                (key: "board", kind: .markerBoard, x: 0.695, y: 0.215, rotation: -8)
            ],
            slots: [
                (key: "te-right", x: 0.775, y: 0.565),
                (key: "ol-lt", x: 0.225, y: 0.565),
                (key: "dl-nose", x: 0.50, y: 0.475),
                (key: "lb-right", x: 0.66, y: 0.36),
                (key: "ss-box", x: 0.68, y: 0.25),
                (key: "edge-left", x: 0.15, y: 0.45),
                (key: "box-left", x: 0.30, y: 0.28),
                (key: "deep-center", x: 0.50, y: 0.135),
                (key: "left-backer", x: 0.34, y: 0.365),
                (key: "slot-right", x: 0.85, y: 0.46)
            ],
            clues: [
                (player: "ol", family: .formationKnowledge, difficulty: .easy,
                 text: "Goal line means seven across. The empty left tackle spot, with the knee brace parked in front of it, gets the sixth body — he fires low and stays square, nothing fancy.",
                 constraints: [.nearEvidence(player: "ol", evidence: "brace", radius: 0.08), .variantIs(player: "ol", variant: .power)],
                 evidence: ["brace"]),
                (player: "te", family: .footballResponsibility, difficulty: .medium,
                 text: "A second giant attaches outside the right tackle, where the chin strap was flung after the last collision. He seals the edge so the back can lean forward for half a yard.",
                 constraints: [.nearEvidence(player: "te", evidence: "strap", radius: 0.08), .variantIs(player: "te", variant: .power)],
                 evidence: ["strap"]),
                (player: "dl", family: .scenario, difficulty: .medium,
                 text: "The defense loads the middle: the fresh divot dead center in the front marks the nose tackle's post. His only job is to not get moved backward one inch.",
                 constraints: [.nearEvidence(player: "dl", evidence: "divot", radius: 0.08), .variantIs(player: "dl", variant: .power)],
                 evidence: ["divot"]),
                (player: "lb", family: .evidenceRelationship, difficulty: .medium,
                 text: "The chain marker dragged to the right inside linebacker spot is the goal-line stack. From there he fills the gap the fullback aims for — arrives angry, finishes the play.",
                 constraints: [.nearEvidence(player: "lb", evidence: "chain", radius: 0.08), .variantIs(player: "lb", variant: .veteran)],
                 evidence: ["chain"]),
                (player: "ss", family: .orderDepth, difficulty: .hard,
                 text: "The marker board dropped at the right roamer's alignment tells the whole story: above the stack backer, below the deep men — the extra body in the box that turns half a yard into nothing.",
                 constraints: [.nearEvidence(player: "ss", evidence: "board", radius: 0.08), .yAbove(a: "ss", b: "lb", gap: 0.05), .variantIs(player: "ss", variant: .power)],
                 evidence: ["board"])
            ],
            hints: [
                (player: "ol", text: "The empty left tackle spot — the knee brace is parked right there."),
                (player: "te", text: "Right side, outside the right tackle — at the chin strap."),
                (player: "dl", text: "Dead center in the defensive front — over the fresh divot."),
                (player: "lb", text: "Right inside linebacker spot — where the chain marker was dragged."),
                (player: "ss", text: "Right box, above the stack backer, below the deep men — at the marker board.")
            ],
            solution: [
                (player: "te", slot: "te-right", variant: .power),
                (player: "ol", slot: "ol-lt", variant: .power),
                (player: "dl", slot: "dl-nose", variant: .power),
                (player: "lb", slot: "lb-right", variant: .veteran),
                (player: "ss", slot: "ss-box", variant: .power)
            ]
        ),

        // 14 — Pistol, Pocketed (seed 13)
        CaseLibrary.makeCase(
            id: "case_pistol_push_04", seed: 13, band: 2,
            title: "Pistol, Pocketed",
            heading: "PISTOL FORMATION",
            body: "The back sets up deep behind the passer. Both spots are empty.",
            visible: Formation.build { b in
                b.line([0.30, 0.40, 0.50, 0.60])
                b.add(.te, 0.775, 0.565)
                b.add(.wr, 0.075, 0.53)
                b.add(.wr, 0.925, 0.52)
                b.front([0.28, 0.42, 0.58, 0.72])
                b.add(.lb, 0.50, 0.36)
                b.add(.lb, 0.34, 0.36)
                b.add(.cb, 0.075, 0.435)
                b.add(.ss, 0.35, 0.24)
            },
            missing: [
                (key: "qb", position: .qb),
                (key: "rb", position: .rb),
                (key: "ol", position: .ol),
                (key: "de", position: .dl),
                (key: "fs", position: .fs)
            ],
            evidence: [
                (key: "chalk", kind: .chalkMark, x: 0.505, y: 0.67, rotation: 45),
                (key: "towel", kind: .orangeTowel, x: 0.49, y: 0.82, rotation: -15),
                (key: "tee", kind: .kickingTee, x: 0.71, y: 0.605, rotation: 10),
                (key: "divot", kind: .divot, x: 0.175, y: 0.43, rotation: -14),
                (key: "bottle", kind: .waterBottle, x: 0.70, y: 0.11, rotation: 68)
            ],
            slots: [
                (key: "qb-pistol", x: 0.50, y: 0.635),
                (key: "rb-deep", x: 0.50, y: 0.775),
                (key: "ol-rt", x: 0.70, y: 0.565),
                (key: "de-edge", x: 0.165, y: 0.465),
                (key: "fs-deep-right", x: 0.68, y: 0.15),
                (key: "left-gun", x: 0.38, y: 0.655),
                (key: "rb-left", x: 0.38, y: 0.72),
                (key: "left-slot", x: 0.14, y: 0.52),
                (key: "slot-right", x: 0.85, y: 0.46),
                (key: "box-right", x: 0.66, y: 0.295),
                (key: "deep-center", x: 0.50, y: 0.115)
            ],
            clues: [
                (player: "rb", family: .orderDepth, difficulty: .easy,
                 text: "The orange towel straight behind the quarterback's chalk line marks the deepest backfield spot — the pistol back. He takes the handoff moving forward, so downhill power is the whole résumé.",
                 constraints: [.nearEvidence(player: "rb", evidence: "towel", radius: 0.08), .variantIs(player: "rb", variant: .power)],
                 evidence: ["towel"]),
                (player: "qb", family: .formationKnowledge, difficulty: .medium,
                 text: "The chalk mark sits two yards closer than a normal gun — that's the pistol. From there the passer reads the guard's helmet and hands the ball off or keeps it; a steady head beats a fast one in this look.",
                 constraints: [.nearEvidence(player: "qb", evidence: "chalk", radius: 0.08), .variantIs(player: "qb", variant: .veteran)],
                 evidence: ["chalk"]),
                (player: "ol", family: .footballResponsibility, difficulty: .medium,
                 text: "The right tackle spot is vacant and the kicking tee in front of it shows where the staff walked through the fix. He anchors against the interior push and gives the deep back a lane.",
                 constraints: [.nearEvidence(player: "ol", evidence: "tee", radius: 0.08), .variantIs(player: "ol", variant: .power)],
                 evidence: ["tee"]),
                (player: "de", family: .evidenceRelationship, difficulty: .medium,
                 text: "The fresh divot beyond the left tackle marks the wide rusher's first step. He tries to turn the corner before the deep back ever gets to the line.",
                 constraints: [.nearEvidence(player: "de", evidence: "divot", radius: 0.08), .variantIs(player: "de", variant: .fast)],
                 evidence: ["divot"]),
                (player: "fs", family: .scenario, difficulty: .hard,
                 text: "The water bottle at the top right of the picture marks the post the defense left alone. The pistol dares the offense to throw deep — the man there has to erase that dare with range alone.",
                 constraints: [.nearEvidence(player: "fs", evidence: "bottle", radius: 0.08), .variantIs(player: "fs", variant: .fast)],
                 evidence: ["bottle"])
            ],
            hints: [
                (player: "rb", text: "Straight behind the quarterback's chalk line, deepest in the backfield — at the towel."),
                (player: "qb", text: "Center of the formation, closer than a gun — the chalk mark says exactly how deep."),
                (player: "ol", text: "The right tackle spot — in front of the kicking tee."),
                (player: "de", text: "Left edge, wider than every down lineman — over the fresh divot."),
                (player: "fs", text: "Top right, single-high and alone — beside the water bottle.")
            ],
            solution: [
                (player: "qb", slot: "qb-pistol", variant: .veteran),
                (player: "rb", slot: "rb-deep", variant: .power),
                (player: "ol", slot: "ol-rt", variant: .power),
                (player: "de", slot: "de-edge", variant: .fast),
                (player: "fs", slot: "fs-deep-right", variant: .fast)
            ]
        ),

        // 15 — The Flooded Zone (seed 14)
        CaseLibrary.makeCase(
            id: "case_four_wide_flood_05", seed: 14, band: 2,
            title: "The Flooded Zone",
            heading: "FOUR WIDE",
            body: "Four receivers spread the field. The coverage has to hold water.",
            visible: Formation.build { b in
                b.line([0.30, 0.40, 0.50, 0.60, 0.70])
                b.add(.wr, 0.075, 0.53)
                b.front([0.28, 0.42, 0.58, 0.72])
                b.add(.lb, 0.50, 0.36)
                b.add(.cb, 0.075, 0.435)
                b.add(.ss, 0.35, 0.24)
            },
            missing: [
                (key: "qb", position: .qb),
                (key: "wr1", position: .wr),
                (key: "wr2", position: .wr),
                (key: "cb", position: .cb),
                (key: "fs", position: .fs)
            ],
            evidence: [
                (key: "cup", kind: .sportsDrinkCup, x: 0.945, y: 0.565, rotation: 18),
                (key: "band", kind: .wristband, x: 0.765, y: 0.575, rotation: 8),
                (key: "cone", kind: .orangeCone, x: 0.795, y: 0.395, rotation: -12),
                (key: "ball", kind: .looseFootball, x: 0.545, y: 0.615, rotation: 8),
                (key: "marks", kind: .cleatMarks, x: 0.51, y: 0.095, rotation: 20)
            ],
            slots: [
                (key: "wr1-right", x: 0.925, y: 0.52),
                (key: "wr2-slot", x: 0.78, y: 0.53),
                (key: "cb-slot", x: 0.78, y: 0.435),
                (key: "qb-gun", x: 0.50, y: 0.655),
                (key: "fs-center", x: 0.50, y: 0.13),
                (key: "left-gun", x: 0.38, y: 0.655),
                (key: "deep-gun", x: 0.50, y: 0.72),
                (key: "slot-left", x: 0.205, y: 0.525),
                (key: "box-right", x: 0.66, y: 0.295),
                (key: "deep-right", x: 0.70, y: 0.155)
            ],
            clues: [
                (player: "qb", family: .scenario, difficulty: .easy,
                 text: "Four wide means no back, no huddle, no time. The loose football four yards behind the line, just right of center, is the passer's spot — and with a clean lane to scramble, his legs are part of the call.",
                 constraints: [.nearEvidence(player: "qb", evidence: "ball", radius: 0.08), .variantIs(player: "qb", variant: .fast)],
                 evidence: ["ball"]),
                (player: "wr1", family: .relativePosition, difficulty: .medium,
                 text: "The outside man on the right takes the numbers, where the sports drink cup was left. He's the route the whole concept leans on: patient, precise, the one who always ends up exactly where the ball is thrown.",
                 constraints: [.nearEvidence(player: "wr1", evidence: "cup", radius: 0.08), .variantIs(player: "wr1", variant: .veteran)],
                 evidence: ["cup"]),
                (player: "wr2", family: .formationKnowledge, difficulty: .medium,
                 text: "The slot man lines up inside of him off the tackle, where the wristband lies — the quick-hitter option who gets open before the defense can even settle.",
                 constraints: [.nearEvidence(player: "wr2", evidence: "band", radius: 0.08), .variantIs(player: "wr2", variant: .fast)],
                 evidence: ["band"]),
                (player: "cb", family: .elimination, difficulty: .medium,
                 text: "The orange cone at the slot's heel is the nickel's post. The staff ruled out the veteran and the power build — against a slot this quick, only recovery speed survives.",
                 constraints: [.nearEvidence(player: "cb", evidence: "cone", radius: 0.08), .variantIsNot(player: "cb", variant: .power), .variantIsNot(player: "cb", variant: .veteran)],
                 evidence: ["cone"]),
                (player: "fs", family: .evidenceRelationship, difficulty: .hard,
                 text: "With four vertical threats, one man owns the middle: the cleat marks at the very top of the picture, dead center. He reads the quarterback's front shoulder and takes away the deepest lane.",
                 constraints: [.nearEvidence(player: "fs", evidence: "marks", radius: 0.08), .variantIs(player: "fs", variant: .veteran)],
                 evidence: ["marks"])
            ],
            hints: [
                (player: "qb", text: "Center-right in the gun, four yards deep — at the loose football."),
                (player: "wr1", text: "Far right on the line of scrimmage — at the sports drink cup."),
                (player: "wr2", text: "Right slot, off the tackle — where the wristband lies."),
                (player: "cb", text: "At the slot receiver's heel, across the line — the orange cone. Wheels only."),
                (player: "fs", text: "Top center, deepest man on the field — at the cleat marks.")
            ],
            solution: [
                (player: "qb", slot: "qb-gun", variant: .fast),
                (player: "wr1", slot: "wr1-right", variant: .veteran),
                (player: "wr2", slot: "wr2-slot", variant: .fast),
                (player: "cb", slot: "cb-slot", variant: .fast),
                (player: "fs", slot: "fs-center", variant: .veteran)
            ]
        ),

        // 16 — The Strong-Side Leak (seed 15)
        CaseLibrary.makeCase(
            id: "case_strong_side_leak_06", seed: 15, band: 2,
            title: "The Strong-Side Leak",
            heading: "STRONG SIDE",
            body: "Everything leans right, and something over there is about to give.",
            visible: Formation.build { b in
                b.line([0.30, 0.40, 0.50, 0.60, 0.70])
                b.add(.qb, 0.50, 0.655)
                b.add(.wr, 0.075, 0.53)
                b.add(.wr, 0.925, 0.52)
                b.front([0.28, 0.42, 0.58])
                b.add(.lb, 0.50, 0.36)
                b.add(.lb, 0.34, 0.36)
                b.add(.cb, 0.075, 0.435)
                b.add(.ss, 0.66, 0.24)
                b.add(.fs, 0.50, 0.135)
            },
            missing: [
                (key: "te", position: .te),
                (key: "rb", position: .rb),
                (key: "dl", position: .dl),
                (key: "lb", position: .lb),
                (key: "cb", position: .cb)
            ],
            evidence: [
                (key: "strap", kind: .chinStrap, x: 0.79, y: 0.61, rotation: -28),
                (key: "cone", kind: .orangeCone, x: 0.635, y: 0.745, rotation: -10),
                (key: "mud", kind: .muddyFootprints, x: 0.725, y: 0.43, rotation: 55),
                (key: "flag", kind: .challengeFlag, x: 0.63, y: 0.31, rotation: 16),
                (key: "visor", kind: .visorCloth, x: 0.945, y: 0.475, rotation: 30)
            ],
            slots: [
                (key: "te-right", x: 0.775, y: 0.565),
                (key: "rb-right", x: 0.62, y: 0.70),
                (key: "de-right", x: 0.72, y: 0.475),
                (key: "lb-right", x: 0.645, y: 0.355),
                (key: "cb-right", x: 0.925, y: 0.435),
                (key: "box-left", x: 0.30, y: 0.28),
                (key: "slot-left", x: 0.14, y: 0.52),
                (key: "deep-center", x: 0.50, y: 0.115),
                (key: "left-backfield", x: 0.38, y: 0.70),
                (key: "edge-left", x: 0.165, y: 0.465)
            ],
            clues: [
                (player: "rb", family: .scenario, difficulty: .easy,
                 text: "The strong side is right, and the back aligns there — the orange cone in the right backfield lane marks him. When the leak springs, he's the one expected to plug it on the move.",
                 constraints: [.nearEvidence(player: "rb", evidence: "cone", radius: 0.08), .variantIs(player: "rb", variant: .veteran)],
                 evidence: ["cone"]),
                (player: "te", family: .footballResponsibility, difficulty: .medium,
                 text: "Outside the right tackle, where the chin strap was flung, the offense needs its heaviest hands. The tight end there is a battering ram that occasionally catches.",
                 constraints: [.nearEvidence(player: "te", evidence: "strap", radius: 0.08), .variantIs(player: "te", variant: .fast)],
                 evidence: ["strap"]),
                (player: "dl", family: .evidenceRelationship, difficulty: .medium,
                 text: "The muddy footprints just inside the right end mark the fifth rusher's launch point — standing up, wide of the tackles, hunting the edge before the tight end can slide.",
                 constraints: [.nearEvidence(player: "dl", evidence: "mud", radius: 0.08), .variantIs(player: "dl", variant: .power)],
                 evidence: ["mud"]),
                (player: "lb", family: .profileDeduction, difficulty: .hard,
                 text: "The challenge flag dropped at the right inside backer's stack tells you the call: stop the strong-side run. Strength over sideline speed — the man there has to take on the lead blocker head-on.",
                 constraints: [.nearEvidence(player: "lb", evidence: "flag", radius: 0.08), .variantIs(player: "lb", variant: .power)],
                 evidence: ["flag"]),
                (player: "cb", family: .relativePosition, difficulty: .medium,
                 text: "Across from the visible right receiver, just past the line of scrimmage, the visor cloth marks the corner. Tight coverage with a veteran's hands at the line — the receiver never gets a free release.",
                 constraints: [.nearEvidence(player: "cb", evidence: "visor", radius: 0.08), .variantIs(player: "cb", variant: .veteran)],
                 evidence: ["visor"])
            ],
            hints: [
                (player: "rb", text: "Right of the quarterback in the backfield — at the orange cone."),
                (player: "te", text: "Right side, just beyond the right tackle — where the chin strap was flung."),
                (player: "dl", text: "Right end, standing up beyond the tackles — over the muddy churn."),
                (player: "lb", text: "Right inside backer spot — where the challenge flag lies."),
                (player: "cb", text: "Right sideline across from the visible receiver — by the visor cloth.")
            ],
            solution: [
                (player: "te", slot: "te-right", variant: .fast),
                (player: "rb", slot: "rb-right", variant: .veteran),
                (player: "dl", slot: "de-right", variant: .power),
                (player: "lb", slot: "lb-right", variant: .power),
                (player: "cb", slot: "cb-right", variant: .veteran)
            ]
        ),

        // 17 — The Screen Nobody Bought (seed 16)
        CaseLibrary.makeCase(
            id: "case_screen_left_07", seed: 16, band: 2,
            title: "The Screen Nobody Bought",
            heading: "SCREEN CALL",
            body: "The fake sells everywhere except one spot — and that spot decides it.",
            visible: Formation.build { b in
                b.line([0.30, 0.40, 0.50, 0.60])
                b.add(.qb, 0.50, 0.655)
                b.add(.te, 0.775, 0.565)
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
                (key: "wr", position: .wr),
                (key: "ol", position: .ol),
                (key: "dl", position: .dl),
                (key: "ss", position: .ss)
            ],
            evidence: [
                (key: "trail", kind: .draggedFootTrail, x: 0.375, y: 0.745, rotation: 28),
                (key: "card", kind: .droppedPlayCard, x: 0.225, y: 0.485, rotation: -10),
                (key: "tee", kind: .kickingTee, x: 0.71, y: 0.605, rotation: 10),
                (key: "mud", kind: .muddyFootprints, x: 0.125, y: 0.42, rotation: 55),
                (key: "board", kind: .markerBoard, x: 0.305, y: 0.24, rotation: -8)
            ],
            slots: [
                (key: "rb-left", x: 0.38, y: 0.70),
                (key: "wr-slot-left", x: 0.205, y: 0.525),
                (key: "ol-rt", x: 0.70, y: 0.565),
                (key: "dl-edge", x: 0.135, y: 0.465),
                (key: "ss-box-left", x: 0.32, y: 0.28),
                (key: "rb-right", x: 0.62, y: 0.70),
                (key: "deep-left", x: 0.28, y: 0.13),
                (key: "box-right", x: 0.66, y: 0.295),
                (key: "slot-right", x: 0.80, y: 0.44),
                (key: "edge-right", x: 0.835, y: 0.465)
            ],
            clues: [
                (player: "rb", family: .scenario, difficulty: .easy,
                 text: "The screen starts with a fake retreat: the dragged-foot trail in the left backfield is exactly that — a back selling the block before flaring out. Quicker than anyone chasing him.",
                 constraints: [.nearEvidence(player: "rb", evidence: "trail", radius: 0.08), .variantIs(player: "rb", variant: .fast)],
                 evidence: ["trail"]),
                (player: "wr", family: .evidenceRelationship, difficulty: .medium,
                 text: "The screen's target lines up in the left slot, at the dropped play card — the route only works if he blocks his man for a count and then slips him.",
                 constraints: [.nearEvidence(player: "wr", evidence: "card", radius: 0.08), .variantIs(player: "wr", variant: .fast)],
                 evidence: ["card"]),
                (player: "ol", family: .footballResponsibility, difficulty: .medium,
                 text: "The right tackle spot is empty, and the kicking tee in front of it is where the replacement rehearsed. On a screen, his job is the easiest-looking hardest thing: sell the pass block, then release.",
                 constraints: [.nearEvidence(player: "ol", evidence: "tee", radius: 0.08), .variantIs(player: "ol", variant: .power)],
                 evidence: ["tee"]),
                (player: "dl", family: .chainedDeduction, difficulty: .hard,
                 text: "The muddy footprints beyond the left tackle mark the crasher the screen is baiting. He aligns below the roamer's post and above nothing — wide, standing up, first one to bite on the fake.",
                 constraints: [.nearEvidence(player: "dl", evidence: "mud", radius: 0.08), .yBelow(a: "dl", b: "ss", gap: 0.1), .variantIs(player: "dl", variant: .veteran)],
                 evidence: ["mud"]),
                (player: "ss", family: .elimination, difficulty: .medium,
                 text: "The marker board at the left roamer's alignment shows the defense's one honest player: he reads the screen all the way. The staff says he is neither the power build nor the veteran — just pure closing burst.",
                 constraints: [.nearEvidence(player: "ss", evidence: "board", radius: 0.08), .variantIsNot(player: "ss", variant: .power), .variantIsNot(player: "ss", variant: .veteran)],
                 evidence: ["board"])
            ],
            hints: [
                (player: "rb", text: "Left backfield, beside the dragged-foot trail."),
                (player: "wr", text: "Left slot, off the tackle — at the dropped play card."),
                (player: "ol", text: "The empty right tackle spot — the kicking tee parked just in front."),
                (player: "dl", text: "Left edge, wide and standing up — over the muddy churn, below the roamer."),
                (player: "ss", text: "Left second level — at the marker board. Closing burst is the only requirement.")
            ],
            solution: [
                (player: "rb", slot: "rb-left", variant: .fast),
                (player: "wr", slot: "wr-slot-left", variant: .fast),
                (player: "ol", slot: "ol-rt", variant: .power),
                (player: "dl", slot: "dl-edge", variant: .veteran),
                (player: "ss", slot: "ss-box-left", variant: .fast)
            ]
        ),

        // 18 — The Post and the Pillar (seed 17)
        CaseLibrary.makeCase(
            id: "case_post_safe_08", seed: 17, band: 2,
            title: "The Post and the Pillar",
            heading: "MIDDLE OF THE FIELD",
            body: "One route goes over the top. One defender stands under it.",
            visible: Formation.build { b in
                b.line([0.30, 0.40, 0.50, 0.60, 0.70])
                b.add(.qb, 0.50, 0.655)
                b.add(.rb, 0.42, 0.68)
                b.add(.wr, 0.075, 0.53)
                b.front([0.28, 0.42, 0.58, 0.72])
                b.add(.lb, 0.50, 0.36)
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
                (key: "cup", kind: .sportsDrinkCup, x: 0.945, y: 0.565, rotation: 18),
                (key: "stain", kind: .grassStain, x: 0.905, y: 0.395, rotation: 0),
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
                (key: "left-backer", x: 0.26, y: 0.33)
            ],
            clues: [
                (player: "te", family: .footballResponsibility, difficulty: .easy,
                 text: "The right tackle needs help, and the wrist playbook dropped at the blocker's spot marks where the staff wants it — a giant on the shoulder who turns the edge into a wall.",
                 constraints: [.nearEvidence(player: "te", evidence: "playbook", radius: 0.08), .variantIs(player: "te", variant: .power)],
                 evidence: ["playbook"]),
                (player: "wr", family: .relativePosition, difficulty: .medium,
                 text: "The post route belongs to the receiver split wide on the right, where the sports drink cup sits. Shallower than the corner's cushion, wider than the tight end — he runs between both.",
                 constraints: [.nearEvidence(player: "wr", evidence: "cup", radius: 0.08), .variantIs(player: "wr", variant: .fast)],
                 evidence: ["cup"]),
                (player: "cb", family: .elimination, difficulty: .medium,
                 text: "The grass stain across from that receiver marks his defender. The call sheet crosses out two names: no veteran, no power build — the post demands legs that can flip and run.",
                 constraints: [.nearEvidence(player: "cb", evidence: "stain", radius: 0.08), .variantIsNot(player: "cb", variant: .power), .variantIsNot(player: "cb", variant: .veteran)],
                 evidence: ["stain"]),
                (player: "fs", family: .evidenceRelationship, difficulty: .hard,
                 text: "The wet patch at the very top of the picture, dead center, marks the lone deep defender. If the post clears the corner, he is the only thing left — and he's been reading quarterbacks longer than some of them have been alive.",
                 constraints: [.nearEvidence(player: "fs", evidence: "wet", radius: 0.08), .variantIs(player: "fs", variant: .veteran)],
                 evidence: ["wet"]),
                (player: "lb", family: .profileDeduction, difficulty: .medium,
                 text: "The chain marker dragged to the left inside backer spot is the pillar call: hold the middle against the run. Sideline speed is worthless there — mass and read discipline are everything.",
                 constraints: [.nearEvidence(player: "lb", evidence: "chain", radius: 0.08), .variantIs(player: "lb", variant: .power)],
                 evidence: ["chain"])
            ],
            hints: [
                (player: "te", text: "Right side, outside the right tackle — at the wrist playbook."),
                (player: "wr", text: "Right sideline, on the line of scrimmage — by the sports drink cup."),
                (player: "cb", text: "Right sideline across from that receiver — at the grass stain."),
                (player: "fs", text: "Top of the picture, dead center, deepest man on the field — at the wet patch."),
                (player: "lb", text: "Left inside backer spot — where the chain marker was dragged.")
            ],
            solution: [
                (player: "wr", slot: "wr-right", variant: .fast),
                (player: "te", slot: "te-right", variant: .power),
                (player: "cb", slot: "cb-right", variant: .fast),
                (player: "fs", slot: "fs-center", variant: .veteran),
                (player: "lb", slot: "lb-left", variant: .power)
            ]
        ),

        // 19 — Two Tights, One Hole (seed 18)
        CaseLibrary.makeCase(
            id: "case_two_tight_power_09", seed: 18, band: 2,
            title: "Two Tights, One Hole",
            heading: "HEAVY PERSONNEL",
            body: "Jumbo package, three tight-end looks, and one missing piece everywhere.",
            visible: Formation.build { b in
                b.line([0.30, 0.40, 0.50, 0.60])
                b.add(.te, 0.225, 0.565)
                b.add(.rb, 0.50, 0.71)
                b.add(.wr, 0.925, 0.52)
                b.front([0.28, 0.42, 0.58])
                b.add(.lb, 0.50, 0.36)
                b.add(.lb, 0.34, 0.36)
                b.add(.cb, 0.925, 0.435)
                b.add(.fs, 0.50, 0.135)
            },
            missing: [
                (key: "qb", position: .qb),
                (key: "te", position: .te),
                (key: "ol", position: .ol),
                (key: "dl", position: .dl),
                (key: "lb", position: .lb)
            ],
            evidence: [
                (key: "ball", kind: .looseFootball, x: 0.50, y: 0.585, rotation: 6),
                (key: "tee", kind: .kickingTee, x: 0.685, y: 0.605, rotation: 10),
                (key: "strap", kind: .chinStrap, x: 0.80, y: 0.61, rotation: -28),
                (key: "divot", kind: .divot, x: 0.725, y: 0.43, rotation: -14),
                (key: "flag", kind: .challengeFlag, x: 0.615, y: 0.30, rotation: 16)
            ],
            slots: [
                (key: "qb-under", x: 0.50, y: 0.63),
                (key: "te-right", x: 0.775, y: 0.565),
                (key: "ol-rt", x: 0.70, y: 0.565),
                (key: "de-right", x: 0.72, y: 0.475),
                (key: "lb-right", x: 0.645, y: 0.35),
                (key: "gun-left", x: 0.38, y: 0.655),
                (key: "deep-under", x: 0.50, y: 0.70),
                (key: "box-left", x: 0.30, y: 0.28),
                (key: "edge-left", x: 0.165, y: 0.465),
                (key: "slot-right", x: 0.85, y: 0.46)
            ],
            clues: [
                (player: "qb", family: .formationKnowledge, difficulty: .easy,
                 text: "Jumbo personnel means the quarterback is under the center, hands ready — the loose football dead center at the line says exactly where. No shotgun in this package.",
                 constraints: [.nearEvidence(player: "qb", evidence: "ball", radius: 0.08), .variantIs(player: "qb", variant: .veteran)],
                 evidence: ["ball"]),
                (player: "ol", family: .evidenceRelationship, difficulty: .medium,
                 text: "The right tackle spot sits empty, and the kicking tee parked in front of it marks the fix. He drives straight ahead — in this package there is no backpedaling in his job description.",
                 constraints: [.nearEvidence(player: "ol", evidence: "tee", radius: 0.08), .variantIs(player: "ol", variant: .power)],
                 evidence: ["tee"]),
                (player: "te", family: .footballResponsibility, difficulty: .medium,
                 text: "The second tight end sets outside the new tackle, where the chin strap was flung. He's the crunch in the crunch formation — a mass that moves the line of scrimmage forward on its own.",
                 constraints: [.nearEvidence(player: "te", evidence: "strap", radius: 0.08), .variantIs(player: "te", variant: .power)],
                 evidence: ["strap"]),
                (player: "dl", family: .scenario, difficulty: .medium,
                 text: "The defense matches mass with mass: the divot just inside the right end is the slanter's first step, crashing down to make the hole shrink before it opens.",
                 constraints: [.nearEvidence(player: "dl", evidence: "divot", radius: 0.08), .variantIs(player: "dl", variant: .power)],
                 evidence: ["divot"]),
                (player: "lb", family: .orderDepth, difficulty: .hard,
                 text: "The challenge flag at the right stack spot marks the run-through backer: the first defender past the front toward the offense, above nothing, below no one — the hole closer.",
                 constraints: [.nearEvidence(player: "lb", evidence: "flag", radius: 0.08), .variantIs(player: "lb", variant: .veteran)],
                 evidence: ["flag"])
            ],
            hints: [
                (player: "qb", text: "Dead center, under the quarterback — at the loose football."),
                (player: "ol", text: "The right tackle spot — the kicking tee marks it."),
                (player: "te", text: "Right side, outside the new right tackle — at the chin strap."),
                (player: "dl", text: "Right end, inside of the edge — over the divot, slanting down."),
                (player: "lb", text: "Right stack spot between the front and the deep men — at the challenge flag.")
            ],
            solution: [
                (player: "qb", slot: "qb-under", variant: .veteran),
                (player: "te", slot: "te-right", variant: .power),
                (player: "ol", slot: "ol-rt", variant: .power),
                (player: "dl", slot: "de-right", variant: .power),
                (player: "lb", slot: "lb-right", variant: .veteran)
            ]
        ),

        // 20 — The A-Gap Whisper (seed 19)
        CaseLibrary.makeCase(
            id: "case_blitz_a_gap_10", seed: 19, band: 2,
            title: "The A-Gap Whisper",
            heading: "BLIND SIDE",
            body: "A blitz is coming through the middle. Nobody has said it out loud.",
            visible: Formation.build { b in
                b.line([0.30, 0.40, 0.50, 0.60, 0.70])
                b.add(.te, 0.775, 0.565)
                b.add(.wr, 0.075, 0.53)
                b.add(.wr, 0.925, 0.52)
                b.front([0.28, 0.42, 0.58])
                b.add(.lb, 0.50, 0.36)
                b.add(.lb, 0.34, 0.36)
                b.add(.cb, 0.925, 0.435)
                b.add(.ss, 0.66, 0.24)
            },
            missing: [
                (key: "qb", position: .qb),
                (key: "rb", position: .rb),
                (key: "cb", position: .cb),
                (key: "de", position: .dl),
                (key: "fs", position: .fs)
            ],
            evidence: [
                (key: "mud", kind: .muddyFootprints, x: 0.515, y: 0.715, rotation: 55),
                (key: "glove", kind: .droppedGlove, x: 0.365, y: 0.75, rotation: 24),
                (key: "stain", kind: .grassStain, x: 0.075, y: 0.395, rotation: 0),
                (key: "divot", kind: .divot, x: 0.155, y: 0.50, rotation: -14),
                (key: "marks", kind: .cleatMarks, x: 0.49, y: 0.095, rotation: 20)
            ],
            slots: [
                (key: "qb-gun", x: 0.50, y: 0.655),
                (key: "rb-left", x: 0.38, y: 0.70),
                (key: "cb-left", x: 0.075, y: 0.435),
                (key: "de-edge", x: 0.165, y: 0.465),
                (key: "fs-center", x: 0.50, y: 0.13),
                (key: "gun-left", x: 0.38, y: 0.655),
                (key: "under-center", x: 0.50, y: 0.63),
                (key: "box-right", x: 0.66, y: 0.295),
                (key: "deep-right", x: 0.70, y: 0.155),
                (key: "slot-right", x: 0.80, y: 0.44)
            ],
            clues: [
                (player: "qb", family: .scenario, difficulty: .easy,
                 text: "With a blitz whispering through the A-gaps, the passer stands in the gun — the muddy footprints four yards behind the line confirm it. He has one beat to feel the pressure and escape upfield.",
                 constraints: [.nearEvidence(player: "qb", evidence: "mud", radius: 0.08), .variantIs(player: "qb", variant: .fast)],
                 evidence: ["mud"]),
                (player: "rb", family: .evidenceRelationship, difficulty: .medium,
                 text: "The dropped glove in the left backfield marks the checkdown back: he releases only after confirming the edge, and everything he does afterward is instinct, not power.",
                 constraints: [.nearEvidence(player: "rb", evidence: "glove", radius: 0.08), .variantIs(player: "rb", variant: .power)],
                 evidence: ["glove"]),
                (player: "cb", family: .relativePosition, difficulty: .medium,
                 text: "Across from the visible left receiver, just past the line of scrimmage, the grass stain marks the corner on an island. With the blitz coming, nobody is helping him — pure recovery speed required.",
                 constraints: [.nearEvidence(player: "cb", evidence: "stain", radius: 0.08), .variantIs(player: "cb", variant: .fast)],
                 evidence: ["stain"]),
                (player: "de", family: .footballResponsibility, difficulty: .medium,
                 text: "The divot beyond the left tackle marks the wide rusher the line fears most. He gets one-on-one with no tight end to help — his job is the quarterback's blind side.",
                 constraints: [.nearEvidence(player: "de", evidence: "divot", radius: 0.08), .variantIs(player: "de", variant: .fast)],
                 evidence: ["divot"]),
                (player: "fs", family: .orderDepth, difficulty: .hard,
                 text: "The cleat marks at the very top of the picture are the last man's post: dead center, behind everyone, the only defender between a missed blitz and the end zone.",
                 constraints: [.nearEvidence(player: "fs", evidence: "marks", radius: 0.08), .variantIs(player: "fs", variant: .veteran)],
                 evidence: ["marks"])
            ],
            hints: [
                (player: "qb", text: "Dead center in the gun — at the muddy footprints."),
                (player: "rb", text: "Left of the quarterback in the backfield — by the dropped glove."),
                (player: "cb", text: "Left sideline across from the visible receiver — at the grass stain."),
                (player: "de", text: "Left edge, wider than the front — over the fresh divot."),
                (player: "fs", text: "Top center, behind everyone — at the cleat marks.")
            ],
            solution: [
                (player: "qb", slot: "qb-gun", variant: .fast),
                (player: "rb", slot: "rb-left", variant: .power),
                (player: "cb", slot: "cb-left", variant: .fast),
                (player: "de", slot: "de-edge", variant: .fast),
                (player: "fs", slot: "fs-center", variant: .veteran)
            ]
        )
    ]
}

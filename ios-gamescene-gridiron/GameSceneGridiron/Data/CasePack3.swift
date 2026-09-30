import Foundation

/// Band 3 — third-quarter cases: 5–6 missing players, deeper deduction chains,
/// and evidence that must be read in combination.
nonisolated enum CasePack3 {
    static let all: [QuarterCase] = [

        // 21 — The Overs Front (seed 20)
        CaseLibrary.makeCase(
            id: "case_overs_front_01", seed: 20, band: 3,
            title: "The Overs Front",
            heading: "SHIFTED FRONT",
            body: "The defense slid its whole look. The offense never adjusted.",
            visible: Formation.build { b in
                b.line([0.30, 0.40, 0.50, 0.60, 0.70])
                b.add(.rb, 0.42, 0.68)
                b.add(.wr, 0.075, 0.53)
                b.front([0.28, 0.42, 0.58])
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
                (key: "lb", position: .lb),
                (key: "ss", position: .ss)
            ],
            evidence: [
                (key: "ball", kind: .looseFootball, x: 0.545, y: 0.615, rotation: 8),
                (key: "card", kind: .droppedPlayCard, x: 0.945, y: 0.565, rotation: -8),
                (key: "strap", kind: .chinStrap, x: 0.79, y: 0.615, rotation: -28),
                (key: "mud", kind: .muddyFootprints, x: 0.155, y: 0.42, rotation: 55),
                (key: "flag", kind: .challengeFlag, x: 0.675, y: 0.315, rotation: 16),
                (key: "board", kind: .markerBoard, x: 0.305, y: 0.24, rotation: -8)
            ],
            slots: [
                (key: "qb-gun", x: 0.50, y: 0.655),
                (key: "wr-right", x: 0.925, y: 0.52),
                (key: "te-right", x: 0.775, y: 0.565),
                (key: "dl-edge", x: 0.165, y: 0.465),
                (key: "lb-right", x: 0.66, y: 0.36),
                (key: "ss-box-left", x: 0.34, y: 0.295),
                (key: "back-right", x: 0.62, y: 0.70),
                (key: "slot-left", x: 0.205, y: 0.525),
                (key: "deep-center", x: 0.50, y: 0.115),
                (key: "deep-right", x: 0.70, y: 0.155),
                (key: "edge-right", x: 0.835, y: 0.465),
                (key: "left-gun", x: 0.38, y: 0.655)
            ],
            clues: [
                (player: "qb", family: .scenario, difficulty: .easy,
                 text: "The shifted front means quick throws, and the loose football four yards behind the line marks the passer — in the gun, ready to get rid of it in a heartbeat or take off himself.",
                 constraints: [.nearEvidence(player: "qb", evidence: "ball", radius: 0.08), .variantIs(player: "qb", variant: .fast)],
                 evidence: ["ball"]),
                (player: "wr", family: .formationKnowledge, difficulty: .medium,
                 text: "The dropped play card at the far right numbers marks the receiver — isolated on that sideline against the visible corner, with the whole field to work. A route artist, not a track sprinter.",
                 constraints: [.nearEvidence(player: "wr", evidence: "card", radius: 0.08), .variantIs(player: "wr", variant: .veteran)],
                 evidence: ["card"]),
                (player: "te", family: .footballResponsibility, difficulty: .medium,
                 text: "The right tackle is exposed, and the chin strap flung outside his shoulder explains why. The help has to be a hammer: attach, seal, and end the rep.",
                 constraints: [.nearEvidence(player: "te", evidence: "strap", radius: 0.08), .variantIs(player: "te", variant: .power)],
                 evidence: ["strap"]),
                (player: "dl", family: .evidenceRelationship, difficulty: .medium,
                 text: "The muddy footprints churned beyond the left tackle mark the fifth rusher — the overs front's wide aligner, standing up beyond the tackles. He takes the longest road to the quarterback at full sprint.",
                 constraints: [.nearEvidence(player: "dl", evidence: "mud", radius: 0.08), .variantIs(player: "dl", variant: .fast)],
                 evidence: ["mud"]),
                (player: "lb", family: .orderDepth, difficulty: .medium,
                 text: "The challenge flag in the right second level marks the stack: the first defender behind the front on the tight end's side, reading run before anything else.",
                 constraints: [.nearEvidence(player: "lb", evidence: "flag", radius: 0.08), .variantIs(player: "lb", variant: .veteran)],
                 evidence: ["flag"]),
                (player: "ss", family: .profileDeduction, difficulty: .hard,
                 text: "The marker board at the left roamer's alignment confirms the call: he walks down into the box against the run-heavy look. The staff wants a body that arrives angry — power over polish.",
                 constraints: [.nearEvidence(player: "ss", evidence: "board", radius: 0.08), .variantIs(player: "ss", variant: .power)],
                 evidence: ["board"])
            ],
            hints: [
                (player: "qb", text: "Dead center in the gun, four yards deep — at the loose football."),
                (player: "wr", text: "Far right numbers, on the line of scrimmage — at the dropped play card."),
                (player: "te", text: "Right edge of the line, outside the tackle — beside the chin strap."),
                (player: "dl", text: "Left edge, standing up wide — over the muddy churn."),
                (player: "lb", text: "Right second level — the challenge flag marks his stack."),
                (player: "ss", text: "Left box, walked down toward the line — at the marker board.")
            ],
            solution: [
                (player: "qb", slot: "qb-gun", variant: .fast),
                (player: "wr", slot: "wr-right", variant: .veteran),
                (player: "te", slot: "te-right", variant: .power),
                (player: "dl", slot: "dl-edge", variant: .fast),
                (player: "lb", slot: "lb-right", variant: .veteran),
                (player: "ss", slot: "ss-box-left", variant: .power)
            ]
        ),

        // 22 — Crossers Everywhere (seed 21)
        CaseLibrary.makeCase(
            id: "case_crossing_routes_02", seed: 21, band: 3,
            title: "Crossers Everywhere",
            heading: "MOTION CHAOS",
            body: "Routes are crossing at three levels. Nobody is where they were a second ago.",
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
                (key: "rb", position: .rb),
                (key: "wr", position: .wr),
                (key: "te", position: .te),
                (key: "cb", position: .cb),
                (key: "fs", position: .fs)
            ],
            evidence: [
                (key: "ball", kind: .looseFootball, x: 0.545, y: 0.615, rotation: 8),
                (key: "cone", kind: .orangeCone, x: 0.635, y: 0.745, rotation: -10),
                (key: "tape", kind: .tapeRoll, x: 0.235, y: 0.525, rotation: 40),
                (key: "cup", kind: .sportsDrinkCup, x: 0.945, y: 0.565, rotation: 18),
                (key: "stain", kind: .grassStain, x: 0.905, y: 0.395, rotation: 0),
                (key: "marks", kind: .cleatMarks, x: 0.49, y: 0.095, rotation: 20)
            ],
            slots: [
                (key: "qb-gun", x: 0.50, y: 0.655),
                (key: "rb-right", x: 0.62, y: 0.70),
                (key: "wr-right", x: 0.925, y: 0.52),
                (key: "te-left", x: 0.245, y: 0.565),
                (key: "cb-right", x: 0.925, y: 0.435),
                (key: "fs-center", x: 0.50, y: 0.13),
                (key: "deep-gun", x: 0.50, y: 0.72),
                (key: "slot-left", x: 0.14, y: 0.52),
                (key: "box-right", x: 0.66, y: 0.295),
                (key: "deep-right", x: 0.70, y: 0.155),
                (key: "back-left", x: 0.38, y: 0.70),
                (key: "edge-left", x: 0.165, y: 0.465)
            ],
            clues: [
                (player: "qb", family: .scenario, difficulty: .easy,
                 text: "With crossers flooding every level, the passer works from the gun — the loose football four yards behind the line marks him. He has to see the whole board at once and get the ball out on rhythm.",
                 constraints: [.nearEvidence(player: "qb", evidence: "ball", radius: 0.08), .variantIs(player: "qb", variant: .fast)],
                 evidence: ["ball"]),
                (player: "te", family: .evidenceRelationship, difficulty: .medium,
                 text: "The crossing game starts underneath, and the tape roll in the left slot marks where the tight end releases from. He slips his block and settles in the first hole he finds.",
                 constraints: [.nearEvidence(player: "te", evidence: "tape", radius: 0.08), .variantIs(player: "te", variant: .power)],
                 evidence: ["tape"]),
                (player: "wr", family: .formationKnowledge, difficulty: .medium,
                 text: "The deepest crosser comes from the right, where the sports drink cup sits at the numbers. He runs behind everything at full tilt — the throw finds him moving.",
                 constraints: [.nearEvidence(player: "wr", evidence: "cup", radius: 0.08), .variantIs(player: "wr", variant: .fast)],
                 evidence: ["cup"]),
                (player: "rb", family: .footballResponsibility, difficulty: .medium,
                 text: "The orange cone in the right backfield marks the checkdown back. With the blitz looming over the crossing routes, his value is patience: see it, sit in the soft spot, take the guaranteed yards.",
                 constraints: [.nearEvidence(player: "rb", evidence: "cone", radius: 0.08), .variantIs(player: "rb", variant: .veteran)],
                 evidence: ["cone"]),
                (player: "cb", family: .relativePosition, difficulty: .medium,
                 text: "The grass stain just inside the right numbers marks the corner chasing those crossers. Shallower than the receiver he trails, wider than the safety — he runs the route with him.",
                 constraints: [.nearEvidence(player: "cb", evidence: "stain", radius: 0.08), .variantIs(player: "cb", variant: .fast)],
                 evidence: ["stain"]),
                (player: "fs", family: .orderDepth, difficulty: .hard,
                 text: "The cleat marks at the very top of the picture, dead center, are the last line's post. Every crosser runs under him; nothing runs over him.",
                 constraints: [.nearEvidence(player: "fs", evidence: "marks", radius: 0.08), .variantIs(player: "fs", variant: .veteran)],
                 evidence: ["marks"])
            ],
            hints: [
                (player: "qb", text: "Dead center in the gun — at the loose football."),
                (player: "te", text: "Left slot, off the tackle — where the tape roll lies."),
                (player: "wr", text: "Right sideline at the numbers — by the sports drink cup."),
                (player: "rb", text: "Offset right of the passer in the backfield — beside the orange cone."),
                (player: "cb", text: "Right sideline, just past the line — at the grass stain."),
                (player: "fs", text: "Top of the picture, dead center behind everyone — at the cleat marks.")
            ],
            solution: [
                (player: "qb", slot: "qb-gun", variant: .fast),
                (player: "te", slot: "te-left", variant: .power),
                (player: "wr", slot: "wr-right", variant: .fast),
                (player: "rb", slot: "rb-right", variant: .veteran),
                (player: "cb", slot: "cb-right", variant: .fast),
                (player: "fs", slot: "fs-center", variant: .veteran)
            ]
        ),

        // 23 — Under Center, Overloaded (seed 22)
        CaseLibrary.makeCase(
            id: "case_under_center_03", seed: 22, band: 3,
            title: "Under Center, Overloaded",
            heading: "HEAVY LOOK",
            body: "Full house backfield, jumbo personnel — and six empty jerseys.",
            visible: Formation.build { b in
                b.line([0.30, 0.40, 0.50, 0.60])
                b.add(.rb, 0.50, 0.72)
                b.add(.wr, 0.075, 0.53)
                b.add(.wr, 0.925, 0.52)
                b.front([0.28, 0.42, 0.58])
                b.add(.lb, 0.34, 0.36)
                b.add(.cb, 0.925, 0.435)
                b.add(.fs, 0.50, 0.135)
            },
            missing: [
                (key: "qb", position: .qb),
                (key: "ol", position: .ol),
                (key: "te", position: .te),
                (key: "dl", position: .dl),
                (key: "lb", position: .lb),
                (key: "cb", position: .cb)
            ],
            evidence: [
                (key: "ball", kind: .looseFootball, x: 0.50, y: 0.585, rotation: 6),
                (key: "tee", kind: .kickingTee, x: 0.685, y: 0.605, rotation: 10),
                (key: "strap", kind: .chinStrap, x: 0.80, y: 0.61, rotation: -28),
                (key: "divot", kind: .divot, x: 0.725, y: 0.43, rotation: -14),
                (key: "flag", kind: .challengeFlag, x: 0.615, y: 0.30, rotation: 16),
                (key: "stain", kind: .grassStain, x: 0.09, y: 0.40, rotation: 0)
            ],
            slots: [
                (key: "qb-under", x: 0.50, y: 0.63),
                (key: "ol-rt", x: 0.70, y: 0.565),
                (key: "te-right", x: 0.775, y: 0.565),
                (key: "de-right", x: 0.72, y: 0.475),
                (key: "lb-right", x: 0.66, y: 0.36),
                (key: "cb-left", x: 0.075, y: 0.435),
                (key: "ss-box-left", x: 0.32, y: 0.26),
                (key: "gun-left", x: 0.38, y: 0.655),
                (key: "deep-left", x: 0.27, y: 0.14),
                (key: "slot-left", x: 0.14, y: 0.52),
                (key: "edge-left", x: 0.165, y: 0.465),
                (key: "box-deep-right", x: 0.72, y: 0.27),
                (key: "slot-right", x: 0.85, y: 0.46)
            ],
            clues: [
                (player: "qb", family: .formationKnowledge, difficulty: .easy,
                 text: "Full house means the passer is under the center with the ball — the loose football dead center at the line marks the only spot he can be. In this package the read is simple and the clock is short.",
                 constraints: [.nearEvidence(player: "qb", evidence: "ball", radius: 0.08), .variantIs(player: "qb", variant: .veteran)],
                 evidence: ["ball"]),
                (player: "ol", family: .footballResponsibility, difficulty: .medium,
                 text: "The right tackle spot sits empty, and the kicking tee parked in front of it marks the fix. He fires off low and straight — in this formation the whole plan is only as good as his first step.",
                 constraints: [.nearEvidence(player: "ol", evidence: "tee", radius: 0.08), .variantIs(player: "ol", variant: .power)],
                 evidence: ["tee"]),
                (player: "te", family: .footballResponsibility, difficulty: .medium,
                 text: "The second tight end sets outside the new tackle, where the chin strap was flung after the last collision. He is the crunch in the crunch formation — a mass that moves the line forward on its own.",
                 constraints: [.nearEvidence(player: "te", evidence: "strap", radius: 0.08), .variantIs(player: "te", variant: .veteran)],
                 evidence: ["strap"]),
                (player: "dl", family: .scenario, difficulty: .medium,
                 text: "The defense matches mass with mass: the fresh divot just inside the right end marks the slanter's first step, crashing down to shrink the hole before it opens.",
                 constraints: [.nearEvidence(player: "dl", evidence: "divot", radius: 0.08), .variantIs(player: "dl", variant: .power)],
                 evidence: ["divot"]),
                (player: "lb", family: .evidenceRelationship, difficulty: .medium,
                 text: "The challenge flag at the right stack spot marks the run-through backer — the first defender past the front on that side. He has to beat the fullback to the gap, which means speed, not shadow.",
                 constraints: [.nearEvidence(player: "lb", evidence: "flag", radius: 0.08), .variantIs(player: "lb", variant: .fast)],
                 evidence: ["flag"]),
                (player: "cb", family: .relativePosition, difficulty: .hard,
                 text: "Across from the visible left receiver, just past the line of scrimmage, the grass stain marks a corner on his own. With everyone else selling out against the run, he is the only body on that half of the field — recovery speed is the only insurance.",
                 constraints: [.nearEvidence(player: "cb", evidence: "stain", radius: 0.08), .variantIs(player: "cb", variant: .fast)],
                 evidence: ["stain"])
            ],
            hints: [
                (player: "qb", text: "Under the quarterback, dead center — the loose football marks the spot."),
                (player: "ol", text: "The right tackle spot — the kicking tee parked there marks it."),
                (player: "te", text: "Right side, just past the new right tackle — where the chin strap lies."),
                (player: "dl", text: "Right end, tucked inside the edge — over the divot, crashing down."),
                (player: "lb", text: "Right stack spot, first past the front — at the challenge flag."),
                (player: "cb", text: "Left sideline, mirroring the visible receiver — where the grass stain shows.")
            ],
            solution: [
                (player: "qb", slot: "qb-under", variant: .veteran),
                (player: "ol", slot: "ol-rt", variant: .power),
                (player: "te", slot: "te-right", variant: .veteran),
                (player: "dl", slot: "de-right", variant: .power),
                (player: "lb", slot: "lb-right", variant: .fast),
                (player: "cb", slot: "cb-left", variant: .fast)
            ]
        ),

        // 24 — The Disappearing Deep Man (seed 23)
        CaseLibrary.makeCase(
            id: "case_deep_safety_read_04", seed: 23, band: 3,
            title: "The Disappearing Deep Man",
            heading: "SHELL BROKEN",
            body: "The deep middle is open for business. Somebody has to close it.",
            visible: Formation.build { b in
                b.line([0.30, 0.40, 0.50, 0.60, 0.70])
                b.add(.qb, 0.50, 0.655)
                b.add(.wr, 0.925, 0.52)
                b.front([0.28, 0.42, 0.58, 0.72])
                b.add(.lb, 0.50, 0.36)
                b.add(.lb, 0.34, 0.36)
                b.add(.cb, 0.925, 0.435)
                b.add(.ss, 0.35, 0.24)
            },
            missing: [
                (key: "wr", position: .wr),
                (key: "rb", position: .rb),
                (key: "cb", position: .cb),
                (key: "fs", position: .fs),
                (key: "lb", position: .lb)
            ],
            evidence: [
                (key: "card", kind: .droppedPlayCard, x: 0.09, y: 0.575, rotation: -10),
                (key: "stain", kind: .grassStain, x: 0.09, y: 0.40, rotation: 0),
                (key: "tape", kind: .tapeRoll, x: 0.375, y: 0.745, rotation: 36),
                (key: "marks", kind: .cleatMarks, x: 0.49, y: 0.095, rotation: 20),
                (key: "flag", kind: .challengeFlag, x: 0.675, y: 0.315, rotation: 16)
            ],
            slots: [
                (key: "wr-left", x: 0.075, y: 0.53),
                (key: "rb-left", x: 0.38, y: 0.70),
                (key: "cb-left", x: 0.075, y: 0.435),
                (key: "fs-center", x: 0.50, y: 0.13),
                (key: "lb-right", x: 0.66, y: 0.36),
                (key: "slot-right", x: 0.80, y: 0.44),
                (key: "box-left", x: 0.30, y: 0.28),
                (key: "deep-right", x: 0.70, y: 0.155),
                (key: "rb-right", x: 0.62, y: 0.70),
                (key: "edge-left", x: 0.165, y: 0.465)
            ],
            clues: [
                (player: "rb", family: .scenario, difficulty: .easy,
                 text: "With the deep shell cracked, the offense runs more — the tape roll in the left backfield marks the back who takes the handoff downhill and makes the defense respect the ground first.",
                 constraints: [.nearEvidence(player: "rb", evidence: "tape", radius: 0.08), .variantIs(player: "rb", variant: .power)],
                 evidence: ["tape"]),
                (player: "wr", family: .relativePosition, difficulty: .medium,
                 text: "The left sideline is bare, and the dropped play card at the numbers marks the receiver who fills it. Wider than the corner below him, shallower than the back behind him — and the deepest threat on the field.",
                 constraints: [.nearEvidence(player: "wr", evidence: "card", radius: 0.08), .variantIs(player: "wr", variant: .fast)],
                 evidence: ["card"]),
                (player: "cb", family: .evidenceRelationship, difficulty: .medium,
                 text: "The grass stain across from the visible right receiver's new mirror marks the corner pressed to the line. No cushion, no safety net — he wins at the snap or not at all.",
                 constraints: [.nearEvidence(player: "cb", evidence: "stain", radius: 0.08), .variantIs(player: "cb", variant: .fast)],
                 evidence: ["stain"]),
                (player: "lb", family: .footballResponsibility, difficulty: .medium,
                 text: "The challenge flag at the right inside backer spot marks the hole player. With the deep man gone, his zone is the middle of the field below the safeties — he plugs the run and sits on everything shallow.",
                 constraints: [.nearEvidence(player: "lb", evidence: "flag", radius: 0.08), .variantIs(player: "lb", variant: .veteran)],
                 evidence: ["flag"]),
                (player: "fs", family: .orderDepth, difficulty: .hard,
                 text: "The cleat marks at the very top of the picture, dead center, mark the deep man everyone forgot — the last wall between a recovered shell and a touchdown.",
                 constraints: [.nearEvidence(player: "fs", evidence: "marks", radius: 0.08), .variantIs(player: "fs", variant: .veteran)],
                 evidence: ["marks"])
            ],
            hints: [
                (player: "rb", text: "Left backfield — at the tape roll."),
                (player: "wr", text: "Left sideline at the numbers — by the dropped play card."),
                (player: "cb", text: "Left sideline, across from the right-side corner's mirror — at the grass stain."),
                (player: "lb", text: "Right inside backer spot — at the challenge flag."),
                (player: "fs", text: "Dead center at the very top of the field — the cleat marks give it away.")
            ],
            solution: [
                (player: "wr", slot: "wr-left", variant: .fast),
                (player: "rb", slot: "rb-left", variant: .power),
                (player: "cb", slot: "cb-left", variant: .fast),
                (player: "fs", slot: "fs-center", variant: .veteran),
                (player: "lb", slot: "lb-right", variant: .veteran)
            ]
        ),

        // 25 — The Unblocked Edge (seed 24)
        CaseLibrary.makeCase(
            id: "case_edge_concern_05", seed: 24, band: 3,
            title: "The Unblocked Edge",
            heading: "BLIND SIDE WATCH",
            body: "Their best rusher has a runway. Someone has to take it away.",
            visible: Formation.build { b in
                b.line([0.30, 0.40, 0.50, 0.60])
                b.add(.rb, 0.42, 0.68)
                b.add(.te, 0.225, 0.565)
                b.add(.wr, 0.075, 0.53)
                b.add(.wr, 0.925, 0.52)
                b.front([0.28, 0.42, 0.58, 0.72])
                b.add(.lb, 0.50, 0.36)
                b.add(.lb, 0.34, 0.36)
                b.add(.cb, 0.075, 0.435)
                b.add(.fs, 0.50, 0.135)
            },
            missing: [
                (key: "qb", position: .qb),
                (key: "ol", position: .ol),
                (key: "de", position: .dl),
                (key: "cb", position: .cb),
                (key: "ss", position: .ss)
            ],
            evidence: [
                (key: "mud", kind: .muddyFootprints, x: 0.51, y: 0.715, rotation: 55),
                (key: "tee", kind: .kickingTee, x: 0.71, y: 0.605, rotation: 10),
                (key: "strap", kind: .brokenHelmetStrap, x: 0.83, y: 0.51, rotation: -22),
                (key: "visor", kind: .visorCloth, x: 0.945, y: 0.475, rotation: 30),
                (key: "strap2", kind: .shoulderPadStrap, x: 0.645, y: 0.335, rotation: -35)
            ],
            slots: [
                (key: "qb-gun", x: 0.50, y: 0.655),
                (key: "ol-rt", x: 0.70, y: 0.565),
                (key: "de-edge", x: 0.835, y: 0.465),
                (key: "cb-right", x: 0.925, y: 0.435),
                (key: "ss-box", x: 0.66, y: 0.295),
                (key: "under-center", x: 0.50, y: 0.63),
                (key: "slot-right", x: 0.85, y: 0.42),
                (key: "deep-right", x: 0.70, y: 0.155),
                (key: "back-left", x: 0.38, y: 0.70),
                (key: "box-left", x: 0.30, y: 0.28),
                (key: "deep-left", x: 0.27, y: 0.14)
            ],
            clues: [
                (player: "qb", family: .scenario, difficulty: .easy,
                 text: "The right tackle spot is empty against their best rusher — the muddy footprints in the gun mark the passer who has to feel it coming and leave in a heartbeat.",
                 constraints: [.nearEvidence(player: "qb", evidence: "mud", radius: 0.08), .variantIs(player: "qb", variant: .fast)],
                 evidence: ["mud"]),
                (player: "ol", family: .footballResponsibility, difficulty: .medium,
                 text: "The kicking tee in front of the vacant right tackle spot is where the replacement warmed up. He is not blocking a man tonight — he is blocking a stampede.",
                 constraints: [.nearEvidence(player: "ol", evidence: "tee", radius: 0.08), .variantIs(player: "ol", variant: .power)],
                 evidence: ["tee"]),
                (player: "de", family: .evidenceRelationship, difficulty: .medium,
                 text: "The broken helmet strap just beyond the tackle marks the rush lane the defense drew up. Full speed, wide arc, straight for the blind side.",
                 constraints: [.nearEvidence(player: "de", evidence: "strap", radius: 0.08), .variantIs(player: "de", variant: .fast)],
                 evidence: ["strap"]),
                (player: "cb", family: .elimination, difficulty: .medium,
                 text: "The visor cloth at the right corner's post marks the island. The call sheet rules out the veteran and the power build — out there alone, only recovery speed matters.",
                 constraints: [.nearEvidence(player: "cb", evidence: "visor", radius: 0.08), .variantIsNot(player: "cb", variant: .veteran), .variantIsNot(player: "cb", variant: .power)],
                 evidence: ["visor"]),
                (player: "ss", family: .chainedDeduction, difficulty: .hard,
                 text: "The shoulder-pad strap on the right second level marks the box safety. He sits well up the field of the wide rusher's lane, between the front and the deep middle — the extra hat against the run the empty right side invites.",
                 constraints: [.nearEvidence(player: "ss", evidence: "strap2", radius: 0.08), .yAbove(a: "ss", b: "de", gap: 0.15), .variantIs(player: "ss", variant: .power)],
                 evidence: ["strap2"])
            ],
            hints: [
                (player: "qb", text: "Dead center of the gun — the muddy footprints mark the spot."),
                (player: "ol", text: "Right tackle spot, unfilled — the kicking tee sits ahead of it."),
                (player: "de", text: "Right edge, beyond the tackle — at the broken helmet strap."),
                (player: "cb", text: "Right sideline across from the visible receiver — at the visor cloth."),
                (player: "ss", text: "Right second level, higher than the edge rusher's lane — at the shoulder-pad strap.")
            ],
            solution: [
                (player: "qb", slot: "qb-gun", variant: .fast),
                (player: "ol", slot: "ol-rt", variant: .power),
                (player: "de", slot: "de-edge", variant: .fast),
                (player: "cb", slot: "cb-right", variant: .fast),
                (player: "ss", slot: "ss-box", variant: .power)
            ]
        ),

        // 26 — The Option Pitch (seed 25)
        CaseLibrary.makeCase(
            id: "case_option_pitch_06", seed: 25, band: 3,
            title: "The Option Pitch",
            heading: "READ GAME",
            body: "The quarterback is reading one man. Everyone else is improvising.",
            visible: Formation.build { b in
                b.line([0.30, 0.40, 0.50, 0.60, 0.70])
                b.add(.te, 0.775, 0.565)
                b.add(.wr, 0.075, 0.53)
                b.front([0.28, 0.42, 0.58])
                b.add(.lb, 0.50, 0.36)
                b.add(.lb, 0.34, 0.36)
                b.add(.cb, 0.075, 0.435)
                b.add(.cb, 0.925, 0.435)
                b.add(.ss, 0.66, 0.24)
            },
            missing: [
                (key: "qb", position: .qb),
                (key: "rb", position: .rb),
                (key: "wr", position: .wr),
                (key: "dl", position: .dl),
                (key: "fs", position: .fs)
            ],
            evidence: [
                (key: "warmer", kind: .handWarmer, x: 0.51, y: 0.72, rotation: -6),
                (key: "glove", kind: .droppedGlove, x: 0.365, y: 0.75, rotation: 24),
                (key: "bottle", kind: .waterBottle, x: 0.955, y: 0.555, rotation: 65),
                (key: "skid", kind: .skidMarks, x: 0.725, y: 0.435, rotation: 12),
                (key: "wet", kind: .wetPatch, x: 0.52, y: 0.10, rotation: 0)
            ],
            slots: [
                (key: "qb-gun", x: 0.50, y: 0.655),
                (key: "rb-left", x: 0.38, y: 0.70),
                (key: "wr-right", x: 0.925, y: 0.52),
                (key: "de-right", x: 0.72, y: 0.475),
                (key: "fs-center", x: 0.50, y: 0.13),
                (key: "under-center", x: 0.50, y: 0.63),
                (key: "back-right", x: 0.62, y: 0.70),
                (key: "slot-left", x: 0.205, y: 0.525),
                (key: "box-right", x: 0.66, y: 0.295),
                (key: "deep-right", x: 0.70, y: 0.155),
                (key: "edge-left", x: 0.165, y: 0.465)
            ],
            clues: [
                (player: "qb", family: .scenario, difficulty: .easy,
                 text: "The option lives or dies with the man holding it: the hand warmer dropped dead center in the gun marks the read man himself. He extends the play laterally at top speed.",
                 constraints: [.nearEvidence(player: "qb", evidence: "warmer", radius: 0.08), .variantIs(player: "qb", variant: .fast)],
                 evidence: ["warmer"]),
                (player: "rb", family: .evidenceRelationship, difficulty: .medium,
                 text: "The pitch man aligns left of the passer, where the dropped glove lies — he takes the ball on the move and turns the corner before anyone squares up.",
                 constraints: [.nearEvidence(player: "rb", evidence: "glove", radius: 0.08), .variantIs(player: "rb", variant: .fast)],
                 evidence: ["glove"]),
                (player: "wr", family: .formationKnowledge, difficulty: .medium,
                 text: "While the option works the left, the right sideline stays honest — the water bottle at the far numbers marks the receiver who blocks ten yards downfield, every rep, without a catch.",
                 constraints: [.nearEvidence(player: "wr", evidence: "bottle", radius: 0.08), .variantIs(player: "wr", variant: .veteran)],
                 evidence: ["bottle"]),
                (player: "dl", family: .footballResponsibility, difficulty: .medium,
                 text: "The skid marks just inside the right end mark the dive key — the man the quarterback reads first. He must crash the mesh point without losing the edge behind him.",
                 constraints: [.nearEvidence(player: "dl", evidence: "skid", radius: 0.08), .variantIs(player: "dl", variant: .power)],
                 evidence: ["skid"]),
                (player: "fs", family: .orderDepth, difficulty: .hard,
                 text: "The wet patch at the very top of the picture, dead center, is the last line. Against an option that stretches sideways, he is the only defender who can erase a busted edge.",
                 constraints: [.nearEvidence(player: "fs", evidence: "wet", radius: 0.08), .variantIs(player: "fs", variant: .veteran)],
                 evidence: ["wet"])
            ],
            hints: [
                (player: "qb", text: "Dead center in the gun — at the hand warmer. He is the read man."),
                (player: "rb", text: "Left of the passer in the backfield — at the dropped glove."),
                (player: "wr", text: "Right sideline at the numbers — by the water bottle."),
                (player: "dl", text: "Right end, inside of the edge — over the skid marks."),
                (player: "fs", text: "The deepest post on the field, dead center — beside the wet patch.")
            ],
            solution: [
                (player: "qb", slot: "qb-gun", variant: .fast),
                (player: "rb", slot: "rb-left", variant: .fast),
                (player: "wr", slot: "wr-right", variant: .veteran),
                (player: "dl", slot: "de-right", variant: .power),
                (player: "fs", slot: "fs-center", variant: .veteran)
            ]
        ),

        // 27 — Doubling the Star (seed 26)
        CaseLibrary.makeCase(
            id: "case_doubling_star_07", seed: 26, band: 3,
            title: "Doubling the Star",
            heading: "STAR HUNTED",
            body: "The league's best target needs two shadows. Find everyone else first.",
            visible: Formation.build { b in
                b.line([0.30, 0.40, 0.50, 0.60, 0.70])
                b.add(.rb, 0.42, 0.68)
                b.add(.wr, 0.075, 0.53)
                b.front([0.28, 0.42, 0.58, 0.72])
                b.add(.lb, 0.50, 0.36)
                b.add(.lb, 0.34, 0.36)
                b.add(.fs, 0.50, 0.135)
            },
            missing: [
                (key: "wr1", position: .wr),
                (key: "wr2", position: .wr),
                (key: "te", position: .te),
                (key: "cb1", position: .cb),
                (key: "cb2", position: .cb),
                (key: "ss", position: .ss)
            ],
            evidence: [
                (key: "cup", kind: .sportsDrinkCup, x: 0.945, y: 0.565, rotation: 18),
                (key: "band", kind: .wristband, x: 0.775, y: 0.585, rotation: 8),
                (key: "tape", kind: .tapeRoll, x: 0.235, y: 0.525, rotation: 40),
                (key: "stain", kind: .grassStain, x: 0.905, y: 0.395, rotation: 0),
                (key: "towel", kind: .orangeTowel, x: 0.09, y: 0.39, rotation: -22),
                (key: "strap", kind: .shoulderPadStrap, x: 0.675, y: 0.335, rotation: -35)
            ],
            slots: [
                (key: "wr1-right", x: 0.925, y: 0.52),
                (key: "wr2-slot", x: 0.80, y: 0.535),
                (key: "te-left", x: 0.245, y: 0.565),
                (key: "cb1-right", x: 0.925, y: 0.435),
                (key: "cb2-left", x: 0.075, y: 0.435),
                (key: "ss-box", x: 0.66, y: 0.295),
                (key: "slot-left", x: 0.14, y: 0.52),
                (key: "deep-left", x: 0.30, y: 0.155),
                (key: "deep-right", x: 0.70, y: 0.155),
                (key: "box-left", x: 0.30, y: 0.28),
                (key: "back-right", x: 0.62, y: 0.70),
                (key: "under-center", x: 0.50, y: 0.63)
            ],
            clues: [
                (player: "te", family: .footballResponsibility, difficulty: .easy,
                 text: "With the receivers doubled elsewhere, the left side needs raw muscle: the tape roll outside the left tackle marks the tight end who seals the edge so nothing comes free inside.",
                 constraints: [.nearEvidence(player: "te", evidence: "tape", radius: 0.08), .variantIs(player: "te", variant: .power)],
                 evidence: ["tape"]),
                (player: "wr2", family: .formationKnowledge, difficulty: .medium,
                 text: "The slot man lines up off the right tackle, where the wristband was tossed — the quick separator who gets the ball before the double-team can rotate to him.",
                 constraints: [.nearEvidence(player: "wr2", evidence: "band", radius: 0.08), .variantIs(player: "wr2", variant: .fast)],
                 evidence: ["band"]),
                (player: "wr1", family: .relativePosition, difficulty: .medium,
                 text: "The star himself splits to the far right numbers, where the sports drink cup sits. Wider than the slot, shallower than the corner's cushion — and about to see two defenders.",
                 constraints: [.nearEvidence(player: "wr1", evidence: "cup", radius: 0.08), .variantIs(player: "wr1", variant: .veteran)],
                 evidence: ["cup"]),
                (player: "cb2", family: .evidenceRelationship, difficulty: .medium,
                 text: "The orange towel at the left corner's post marks the one-on-one island. Across from the visible receiver, no safety net — just press and pray.",
                 constraints: [.nearEvidence(player: "cb2", evidence: "towel", radius: 0.08), .variantIs(player: "cb2", variant: .fast)],
                 evidence: ["towel"]),
                (player: "cb1", family: .elimination, difficulty: .hard,
                 text: "The grass stain inside the star's alignment marks the shadow. The staff's note is blunt: not the veteran, not the speedster — the one who plays with his hands and drags receivers off their routes.",
                 constraints: [.nearEvidence(player: "cb1", evidence: "stain", radius: 0.08), .variantIsNot(player: "cb1", variant: .veteran), .variantIsNot(player: "cb1", variant: .fast)],
                 evidence: ["stain"]),
                (player: "ss", family: .orderDepth, difficulty: .medium,
                 text: "The shoulder-pad strap in the right second level marks the roamer helping on the double — between the front and the deep middle, reading the star's first move.",
                 constraints: [.nearEvidence(player: "ss", evidence: "strap", radius: 0.08), .variantIs(player: "ss", variant: .veteran)],
                 evidence: ["strap"])
            ],
            hints: [
                (player: "te", text: "Left side, just beyond the left tackle — where the tape roll sits."),
                (player: "wr2", text: "The right slot, just off the tackle — the wristband marks him."),
                (player: "wr1", text: "Far right numbers — by the sports drink cup."),
                (player: "cb2", text: "Left sideline, across from the visible receiver — at the orange towel."),
                (player: "cb1", text: "Inside the star's alignment on the right — at the grass stain. Hands, not heels."),
                (player: "ss", text: "Right second level, between the front and the deep middle — at the shoulder-pad strap.")
            ],
            solution: [
                (player: "wr1", slot: "wr1-right", variant: .veteran),
                (player: "wr2", slot: "wr2-slot", variant: .fast),
                (player: "te", slot: "te-left", variant: .power),
                (player: "cb1", slot: "cb1-right", variant: .power),
                (player: "cb2", slot: "cb2-left", variant: .fast),
                (player: "ss", slot: "ss-box", variant: .veteran)
            ]
        ),

        // 28 — The Interior Stunt (seed 27)
        CaseLibrary.makeCase(
            id: "case_interior_stunt_08", seed: 27, band: 3,
            title: "The Interior Stunt",
            heading: "GAMES UP FRONT",
            body: "The defensive line is trading jobs mid-snap. The protection has to know who is who.",
            visible: Formation.build { b in
                b.line([0.30, 0.40, 0.50, 0.60])
                b.add(.rb, 0.42, 0.68)
                b.add(.te, 0.775, 0.565)
                b.add(.wr, 0.075, 0.53)
                b.add(.wr, 0.925, 0.52)
                b.front([0.28])
                b.add(.lb, 0.34, 0.36)
                b.add(.cb, 0.075, 0.435)
                b.add(.cb, 0.925, 0.435)
                b.add(.ss, 0.35, 0.24)
            },
            missing: [
                (key: "ol", position: .ol),
                (key: "dt1", position: .dl),
                (key: "dt2", position: .dl),
                (key: "lb", position: .lb),
                (key: "fs", position: .fs)
            ],
            evidence: [
                (key: "mud", kind: .muddyFootprints, x: 0.415, y: 0.43, rotation: 55),
                (key: "divot", kind: .divot, x: 0.585, y: 0.43, rotation: -14),
                (key: "flag", kind: .challengeFlag, x: 0.615, y: 0.30, rotation: 16),
                (key: "tee", kind: .kickingTee, x: 0.71, y: 0.605, rotation: 10),
                (key: "marks", kind: .cleatMarks, x: 0.49, y: 0.095, rotation: 20)
            ],
            slots: [
                (key: "ol-rt", x: 0.70, y: 0.565),
                (key: "dt-nose", x: 0.42, y: 0.475),
                (key: "dt-3tech", x: 0.58, y: 0.475),
                (key: "lb-right", x: 0.655, y: 0.35),
                (key: "fs-center", x: 0.50, y: 0.13),
                (key: "edge-left", x: 0.165, y: 0.465),
                (key: "deep-left", x: 0.30, y: 0.155),
                (key: "deep-right", x: 0.70, y: 0.155),
                (key: "box-left", x: 0.30, y: 0.28),
                (key: "slot-right", x: 0.80, y: 0.44),
                (key: "back-left", x: 0.38, y: 0.70)
            ],
            clues: [
                (player: "ol", family: .footballResponsibility, difficulty: .easy,
                 text: "Against a stunting front the fifth blocker matters most: the kicking tee in front of the vacant right tackle spot marks the fix. He picks the wrong man once and the whole pocket folds.",
                 constraints: [.nearEvidence(player: "ol", evidence: "tee", radius: 0.08), .variantIs(player: "ol", variant: .power)],
                 evidence: ["tee"]),
                (player: "dt1", family: .evidenceRelationship, difficulty: .medium,
                 text: "The muddy footprints churned over the nose spot mark the anchor — the man the stunt pivots around. He takes on two blockers so his partner can run free.",
                 constraints: [.nearEvidence(player: "dt1", evidence: "mud", radius: 0.08), .variantIs(player: "dt1", variant: .power)],
                 evidence: ["mud"]),
                (player: "dt2", family: .scenario, difficulty: .medium,
                 text: "The fresh divot at the three-technique is the slant lane: while the nose holds the double, this man shoots the gap he vacates. First-step quickness is the whole trick.",
                 constraints: [.nearEvidence(player: "dt2", evidence: "divot", radius: 0.08), .variantIs(player: "dt2", variant: .fast)],
                 evidence: ["divot"]),
                (player: "lb", family: .profileDeduction, difficulty: .hard,
                 text: "The challenge flag at the right stack spot marks the scraper — the backer who flows over the stunt. Ten years of seeing this exact twist is worth more than any forty time.",
                 constraints: [.nearEvidence(player: "lb", evidence: "flag", radius: 0.08), .variantIs(player: "lb", variant: .veteran)],
                 evidence: ["flag"]),
                (player: "fs", family: .orderDepth, difficulty: .medium,
                 text: "The cleat marks at the very top of the picture, dead center, are the last line's post: behind every stunt, every scrape, every scraped-up protection.",
                 constraints: [.nearEvidence(player: "fs", evidence: "marks", radius: 0.08), .variantIs(player: "fs", variant: .veteran)],
                 evidence: ["marks"])
            ],
            hints: [
                (player: "ol", text: "The vacant right tackle hole — with the kicking tee resting before it."),
                (player: "dt1", text: "Over the nose spot, in the front's middle — at the muddy churn."),
                (player: "dt2", text: "At the three-technique, off the guard's outside shoulder — over the divot."),
                (player: "fs", text: "Highest spot on the field, dead center — beside the cleat marks."),
                (player: "lb", text: "The right stack, first defender past the front — where the challenge flag lies.")
            ],
            solution: [
                (player: "ol", slot: "ol-rt", variant: .power),
                (player: "dt1", slot: "dt-nose", variant: .power),
                (player: "dt2", slot: "dt-3tech", variant: .fast),
                (player: "lb", slot: "lb-right", variant: .veteran),
                (player: "fs", slot: "fs-center", variant: .veteran)
            ]
        ),

        // 29 — The Bootleg Rollout (seed 28)
        CaseLibrary.makeCase(
            id: "case_bootleg_right_09", seed: 28, band: 3,
            title: "The Bootleg Rollout",
            heading: "SELL THE FAKE",
            body: "The back sold the dive. The quarterback is rolling — and someone is missing.",
            visible: Formation.build { b in
                b.line([0.30, 0.40, 0.50, 0.60, 0.70])
                b.add(.rb, 0.50, 0.70)
                b.add(.wr, 0.075, 0.53)
                b.front([0.28, 0.42, 0.58])
                b.add(.lb, 0.50, 0.36)
                b.add(.lb, 0.34, 0.36)
                b.add(.cb, 0.075, 0.435)
                b.add(.cb, 0.925, 0.435)
                b.add(.ss, 0.66, 0.24)
                b.add(.fs, 0.50, 0.135)
            },
            missing: [
                (key: "qb", position: .qb),
                (key: "te", position: .te),
                (key: "wr", position: .wr),
                (key: "dl", position: .dl),
                (key: "lb", position: .lb)
            ],
            evidence: [
                (key: "cone", kind: .orangeCone, x: 0.65, y: 0.67, rotation: -10),
                (key: "strap", kind: .chinStrap, x: 0.79, y: 0.615, rotation: -28),
                (key: "bottle", kind: .waterBottle, x: 0.955, y: 0.555, rotation: 65),
                (key: "skid", kind: .skidMarks, x: 0.725, y: 0.435, rotation: 12),
                (key: "flag", kind: .challengeFlag, x: 0.615, y: 0.30, rotation: 16)
            ],
            slots: [
                (key: "qb-rollout", x: 0.66, y: 0.62),
                (key: "te-right", x: 0.775, y: 0.565),
                (key: "wr-right", x: 0.925, y: 0.52),
                (key: "de-right", x: 0.72, y: 0.475),
                (key: "lb-right", x: 0.645, y: 0.35),
                (key: "back-right", x: 0.55, y: 0.72),
                (key: "slot-left", x: 0.14, y: 0.52),
                (key: "deep-left", x: 0.30, y: 0.155),
                (key: "edge-left", x: 0.165, y: 0.465),
                (key: "box-deep-right", x: 0.70, y: 0.27),
                (key: "deep-right", x: 0.70, y: 0.155)
            ],
            clues: [
                (player: "qb", family: .scenario, difficulty: .easy,
                 text: "The fake pulled the whole defense left, and the orange cone out on the right marks the rollout lane — the passer is running that way with the ball, on the move.",
                 constraints: [.nearEvidence(player: "qb", evidence: "cone", radius: 0.08), .variantIs(player: "qb", variant: .fast)],
                 evidence: ["cone"]),
                (player: "te", family: .footballResponsibility, difficulty: .medium,
                 text: "The boot needs a lead blocker on the edge: the chin strap just outside the right tackle marks where the tight end releases to wall off the first defender he sees.",
                 constraints: [.nearEvidence(player: "te", evidence: "strap", radius: 0.08), .variantIs(player: "te", variant: .power)],
                 evidence: ["strap"]),
                (player: "wr", family: .formationKnowledge, difficulty: .medium,
                 text: "The water bottle at the far right numbers marks the deep target — the one who stays wide, holds the corner's eyes, and never comes inside to help.",
                 constraints: [.nearEvidence(player: "wr", evidence: "bottle", radius: 0.08), .variantIs(player: "wr", variant: .veteran)],
                 evidence: ["bottle"]),
                (player: "dl", family: .evidenceRelationship, difficulty: .medium,
                 text: "The skid marks just inside the right end show the chaser's first step — the man assigned to run the passer down from behind. He wins with the first three yards, not the last forty.",
                 constraints: [.nearEvidence(player: "dl", evidence: "skid", radius: 0.08), .variantIs(player: "dl", variant: .power)],
                 evidence: ["skid"]),
                (player: "lb", family: .profileDeduction, difficulty: .hard,
                 text: "The challenge flag at the right backer spot marks the cutback player. When the rollout stretches the field sideways, only pure closing burst can shrink it back.",
                 constraints: [.nearEvidence(player: "lb", evidence: "flag", radius: 0.08), .variantIs(player: "lb", variant: .fast)],
                 evidence: ["flag"])
            ],
            hints: [
                (player: "qb", text: "Right of the line, on the rollout lane — at the orange cone."),
                (player: "te", text: "The right side, attached to the tackle's outside shoulder — at the chin strap."),
                (player: "wr", text: "Far right numbers — by the water bottle."),
                (player: "dl", text: "Right end, tucked inside the edge — right over the skid marks."),
                (player: "lb", text: "Right backer spot, the cutback lane — at the challenge flag.")
            ],
            solution: [
                (player: "qb", slot: "qb-rollout", variant: .fast),
                (player: "te", slot: "te-right", variant: .power),
                (player: "wr", slot: "wr-right", variant: .veteran),
                (player: "dl", slot: "de-right", variant: .power),
                (player: "lb", slot: "lb-right", variant: .fast)
            ]
        ),

        // 30 — The Shell That Leaked (seed 29)
        CaseLibrary.makeCase(
            id: "case_cover_two_shell_10", seed: 29, band: 3,
            title: "The Shell That Leaked",
            heading: "TWO DEEP, FOUR UNDER",
            body: "The coverage looks airtight. It has exactly one hole.",
            visible: Formation.build { b in
                b.line([0.30, 0.40, 0.50, 0.60, 0.70])
                b.add(.qb, 0.50, 0.655)
                b.add(.wr, 0.075, 0.53)
                b.front([0.28, 0.42, 0.58, 0.72])
                b.add(.lb, 0.50, 0.36)
                b.add(.lb, 0.34, 0.36)
                b.add(.cb, 0.075, 0.435)
                b.add(.cb, 0.925, 0.435)
                b.add(.ss, 0.35, 0.24)
                b.add(.ss, 0.66, 0.24)
            },
            missing: [
                (key: "wr", position: .wr),
                (key: "rb", position: .rb),
                (key: "te", position: .te),
                (key: "dl", position: .dl),
                (key: "fs", position: .fs)
            ],
            evidence: [
                (key: "cup", kind: .sportsDrinkCup, x: 0.945, y: 0.565, rotation: 18),
                (key: "cone", kind: .orangeCone, x: 0.635, y: 0.745, rotation: -10),
                (key: "strap", kind: .chinStrap, x: 0.79, y: 0.615, rotation: -28),
                (key: "divot", kind: .divot, x: 0.505, y: 0.43, rotation: -14),
                (key: "marks", kind: .cleatMarks, x: 0.51, y: 0.095, rotation: 20)
            ],
            slots: [
                (key: "wr-right", x: 0.925, y: 0.52),
                (key: "rb-right", x: 0.62, y: 0.70),
                (key: "te-right", x: 0.775, y: 0.565),
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
                (player: "rb", family: .scenario, difficulty: .easy,
                 text: "Against a shell this deep, the offense runs downhill: the orange cone in the right backfield marks the back who gets the ball early and often.",
                 constraints: [.nearEvidence(player: "rb", evidence: "cone", radius: 0.08), .variantIs(player: "rb", variant: .fast)],
                 evidence: ["cone"]),
                (player: "wr", family: .relativePosition, difficulty: .medium,
                 text: "The sports drink cup at the far right numbers marks the receiver between both deep defenders — wider than the safety, shallower than the corner behind him. The seam is his office.",
                 constraints: [.nearEvidence(player: "wr", evidence: "cup", radius: 0.08), .variantIs(player: "wr", variant: .veteran)],
                 evidence: ["cup"]),
                (player: "te", family: .footballResponsibility, difficulty: .medium,
                 text: "The chin strap outside the right tackle marks the extra blocker — in a shell this patient, the fight is underneath, and it is won with hands.",
                 constraints: [.nearEvidence(player: "te", evidence: "strap", radius: 0.08), .variantIs(player: "te", variant: .power)],
                 evidence: ["strap"]),
                (player: "dl", family: .evidenceRelationship, difficulty: .medium,
                 text: "The fresh divot dead center in the front marks the nose who eats the double team — the reason the four rushers behind him all go one-on-one.",
                 constraints: [.nearEvidence(player: "dl", evidence: "divot", radius: 0.08), .variantIs(player: "dl", variant: .power)],
                 evidence: ["divot"]),
                (player: "fs", family: .orderDepth, difficulty: .hard,
                 text: "The cleat marks at the very top of the picture, dead center between the two deep halves, are the hole patcher — the man who erases the seam the shell leaves open.",
                 constraints: [.nearEvidence(player: "fs", evidence: "marks", radius: 0.08), .variantIs(player: "fs", variant: .fast)],
                 evidence: ["marks"])
            ],
            hints: [
                (player: "rb", text: "Backfield right, off the quarterback's hip — at the orange cone."),
                (player: "wr", text: "Far right numbers — by the sports drink cup, between the deep defenders."),
                (player: "te", text: "Right side, hugging the right tackle — the chin strap marks his post."),
                (player: "dl", text: "Dead center in the front — over the fresh divot."),
                (player: "fs", text: "Top center, in the seam between the deep halves — at the cleat marks.")
            ],
            solution: [
                (player: "wr", slot: "wr-right", variant: .veteran),
                (player: "rb", slot: "rb-right", variant: .fast),
                (player: "te", slot: "te-right", variant: .power),
                (player: "dl", slot: "dt-nose", variant: .power),
                (player: "fs", slot: "fs-center", variant: .fast)
            ]
        )
    ]
}

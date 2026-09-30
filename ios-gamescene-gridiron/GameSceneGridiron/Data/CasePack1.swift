import Foundation

/// Band 1 — first-quarter cases: approachable entries with 4–5 missing players,
/// 1–2 easy starting deductions and a mix of clue families. Every case is
/// validated by `CaseSolver` so the clues pin exactly one solution.
nonisolated enum CasePack1 {
    static let all: [QuarterCase] = [

        // 1 — The Open Sideline (seed 0)
        CaseLibrary.makeCase(
            id: "case_spread_sideline_01", seed: 0, band: 1,
            title: "The Open Sideline",
            heading: "OPENING DRIVE",
            body: "A fresh spread look, and five jerseys never came out of the tunnel.",
            visible: Formation.build { b in
                b.line([0.30, 0.40, 0.50, 0.60, 0.70])
                b.add(.qb, 0.50, 0.655)
                b.add(.wr, 0.075, 0.53)
                b.add(.wr, 0.28, 0.525)
                b.front([0.28, 0.42, 0.58, 0.72])
                b.add(.lb, 0.50, 0.36)
                b.add(.cb, 0.925, 0.435)
            },
            missing: [
                (key: "rb", position: .rb),
                (key: "te", position: .te),
                (key: "wr", position: .wr),
                (key: "cb", position: .cb),
                (key: "fs", position: .fs)
            ],
            evidence: [
                (key: "cone", kind: .orangeCone, x: 0.63, y: 0.745, rotation: -12),
                (key: "tape", kind: .tapeRoll, x: 0.785, y: 0.60, rotation: 40),
                (key: "card", kind: .droppedPlayCard, x: 0.90, y: 0.565, rotation: -8),
                (key: "stain", kind: .grassStain, x: 0.09, y: 0.415, rotation: 0),
                (key: "wet", kind: .wetPatch, x: 0.48, y: 0.165, rotation: 0)
            ],
            slots: [
                (key: "rb-right", x: 0.62, y: 0.70),
                (key: "te-right", x: 0.775, y: 0.565),
                (key: "wr-right", x: 0.925, y: 0.53),
                (key: "cb-left", x: 0.075, y: 0.435),
                (key: "fs-center", x: 0.50, y: 0.13),
                (key: "rb-left", x: 0.38, y: 0.70),
                (key: "slot-left", x: 0.205, y: 0.525),
                (key: "box-right", x: 0.66, y: 0.295),
                (key: "deep-left", x: 0.30, y: 0.17)
            ],
            clues: [
                (player: "rb", family: .evidenceRelationship, difficulty: .easy,
                 text: "Everything runs through the right side. The orange cone sits in the backfield's right lane — the back who owns that lane needs instant acceleration to hit the hole before it closes.",
                 constraints: [.nearEvidence(player: "rb", evidence: "cone", radius: 0.08), .variantIs(player: "rb", variant: .fast)],
                 evidence: ["cone"]),
                (player: "te", family: .footballResponsibility, difficulty: .medium,
                 text: "The right tackle needs help on his shoulder. The tape roll abandoned there says the last rep was a fight — an extra blocker glues on tight to the line, strength over everything.",
                 constraints: [.nearEvidence(player: "te", evidence: "tape", radius: 0.08), .variantIs(player: "te", variant: .power)],
                 evidence: ["tape"]),
                (player: "wr", family: .formationKnowledge, difficulty: .medium,
                 text: "One receiver already holds the left sideline. The other takes the right, split wide where a dropped play card marks the grass — twelve seasons of route discipline, no wasted motion.",
                 constraints: [.nearEvidence(player: "wr", evidence: "card", radius: 0.08), .variantIs(player: "wr", variant: .veteran)],
                 evidence: ["card"]),
                (player: "cb", family: .evidenceRelationship, difficulty: .medium,
                 text: "Straight across from the visible left receiver, just past the line of scrimmage, a grass stain shows where someone back-pedaled all night. No safety help over there — recovery speed only.",
                 constraints: [.nearEvidence(player: "cb", evidence: "stain", radius: 0.08), .variantIs(player: "cb", variant: .fast)],
                 evidence: ["stain"]),
                (player: "fs", family: .orderDepth, difficulty: .hard,
                 text: "The single-high post, dead center, higher than anyone else on the field. The wet patch at his heel says he has been alone back there all game — the last line, and the steadiest head on the roster.",
                 constraints: [.nearEvidence(player: "fs", evidence: "wet", radius: 0.08), .variantIs(player: "fs", variant: .veteran)],
                 evidence: ["wet"])
            ],
            hints: [
                (player: "rb", text: "Look right of the offensive line in the backfield — the cone marks his lane."),
                (player: "te", text: "Tight against the line on the right tackle's outside shoulder — right where the tape roll sits."),
                (player: "wr", text: "Right sideline, on the line of scrimmage, beside the dropped play card."),
                (player: "cb", text: "Left sideline across from the visible receiver, just past the line — the grass stain gives it away."),
                (player: "fs", text: "Top center of the picture, deepest man on the field, beside the wet patch.")
            ],
            solution: [
                (player: "rb", slot: "rb-right", variant: .fast),
                (player: "te", slot: "te-right", variant: .power),
                (player: "wr", slot: "wr-right", variant: .veteran),
                (player: "cb", slot: "cb-left", variant: .fast),
                (player: "fs", slot: "fs-center", variant: .veteran)
            ]
        ),

        // 2 — The Unblinking Gun (seed 1)
        CaseLibrary.makeCase(
            id: "case_gun_protection_02", seed: 1, band: 1,
            title: "The Unblinking Gun",
            heading: "PROTECTION CHECK",
            body: "A gun formation with a hole in it. Somebody needs to be found before the snap count dies.",
            visible: Formation.build { b in
                b.line([0.30, 0.40, 0.50, 0.70])
                b.add(.rb, 0.42, 0.66)
                b.add(.wr, 0.075, 0.53)
                b.add(.wr, 0.925, 0.52)
                b.front([0.28, 0.42, 0.58, 0.72])
                b.add(.lb, 0.50, 0.36)
                b.add(.fs, 0.50, 0.135)
            },
            missing: [
                (key: "qb", position: .qb),
                (key: "ol", position: .ol),
                (key: "cb", position: .cb),
                (key: "ss", position: .ss)
            ],
            evidence: [
                (key: "chalk", kind: .chalkMark, x: 0.495, y: 0.71, rotation: 45),
                (key: "tee", kind: .kickingTee, x: 0.59, y: 0.595, rotation: 10),
                (key: "whistle", kind: .whistle, x: 0.32, y: 0.33, rotation: -20),
                (key: "bag", kind: .equipmentBag, x: 0.93, y: 0.38, rotation: 8)
            ],
            slots: [
                (key: "qb-gun", x: 0.50, y: 0.655),
                (key: "ol-gap", x: 0.60, y: 0.565),
                (key: "cb-right", x: 0.925, y: 0.435),
                (key: "ss-box", x: 0.34, y: 0.295),
                (key: "back-left", x: 0.38, y: 0.70),
                (key: "under-center", x: 0.50, y: 0.615),
                (key: "box-right", x: 0.66, y: 0.295),
                (key: "deep-right", x: 0.82, y: 0.155),
                (key: "slot-left", x: 0.205, y: 0.525)
            ],
            clues: [
                (player: "qb", family: .scenario, difficulty: .easy,
                 text: "The center's hands are empty and the chalk mark sits four yards behind the line, dead center. The passer who takes the snap from there can leave the pocket at a sprint — this drive wants legs, not a statue.",
                 constraints: [.nearEvidence(player: "qb", evidence: "chalk", radius: 0.08), .variantIs(player: "qb", variant: .fast)],
                 evidence: ["chalk"]),
                (player: "ol", family: .footballResponsibility, difficulty: .medium,
                 text: "There is a hole in the wall between the center and the right tackle. The kicking tee rolled to exactly that spot — whoever fills the gap anchors against a bull rush and does not move an inch.",
                 constraints: [.nearEvidence(player: "ol", evidence: "tee", radius: 0.08), .variantIs(player: "ol", variant: .power)],
                 evidence: ["tee"]),
                (player: "cb", family: .elimination, difficulty: .medium,
                 text: "The receiver on the right sideline gets no help over the top. The equipment bag dumped near the numbers marks his island. Whoever takes that spot is neither the veteran nor the power build — only recovery speed survives alone out there.",
                 constraints: [.nearEvidence(player: "cb", evidence: "bag", radius: 0.08), .variantIsNot(player: "cb", variant: .veteran), .variantIsNot(player: "cb", variant: .power)],
                 evidence: ["bag"]),
                (player: "ss", family: .orderDepth, difficulty: .hard,
                 text: "The deep men split duties: the free safety stays tallest at the very top of the picture. The other crashes down to the left, where a whistle abandoned on the grass marks his post — between the front and the second level, below the corner's heel, with a decade of run reads.",
                 constraints: [.nearEvidence(player: "ss", evidence: "whistle", radius: 0.08), .yAbove(a: "ss", b: "cb", gap: 0.1), .variantIs(player: "ss", variant: .veteran)],
                 evidence: ["whistle"])
            ],
            hints: [
                (player: "qb", text: "Dead center in the gun, four yards behind the ball — the chalk mark sits at his feet."),
                (player: "ol", text: "Between the center and the right tackle, no daylight on either shoulder — right by the kicking tee."),
                (player: "cb", text: "Right sideline, on the line of scrimmage, across from the receiver — by the equipment bag."),
                (player: "ss", text: "Left side between the line and the linebackers, higher up the field than the corner — the whistle marks his post.")
            ],
            solution: [
                (player: "qb", slot: "qb-gun", variant: .fast),
                (player: "ol", slot: "ol-gap", variant: .power),
                (player: "cb", slot: "cb-right", variant: .fast),
                (player: "ss", slot: "ss-box", variant: .veteran)
            ]
        ),

        // 3 — The Unplugged Gap (seed 2)
        CaseLibrary.makeCase(
            id: "case_singleback_gap_03", seed: 2, band: 1,
            title: "The Unplugged Gap",
            heading: "RHYTHM BROKEN",
            body: "A single-back set is missing its rhythm — and four of its pieces.",
            visible: Formation.build { b in
                b.line([0.30, 0.40, 0.50, 0.60, 0.70])
                b.add(.qb, 0.50, 0.63)
                b.add(.te, 0.775, 0.565)
                b.add(.wr, 0.925, 0.52)
                b.front([0.28, 0.42, 0.58, 0.72])
                b.add(.lb, 0.34, 0.36)
                b.add(.cb, 0.075, 0.435)
            },
            missing: [
                (key: "rb", position: .rb),
                (key: "wr", position: .wr),
                (key: "lb", position: .lb),
                (key: "fs", position: .fs)
            ],
            evidence: [
                (key: "cleat", kind: .looseCleat, x: 0.375, y: 0.745, rotation: -16),
                (key: "chain", kind: .chainMarker, x: 0.08, y: 0.48, rotation: 4),
                (key: "stain", kind: .grassStain, x: 0.67, y: 0.315, rotation: 0),
                (key: "trail", kind: .draggedFootTrail, x: 0.31, y: 0.185, rotation: 30)
            ],
            slots: [
                (key: "rb-left", x: 0.38, y: 0.70),
                (key: "wr-left", x: 0.075, y: 0.53),
                (key: "lb-right", x: 0.66, y: 0.36),
                (key: "fs-left", x: 0.32, y: 0.15),
                (key: "rb-right", x: 0.62, y: 0.70),
                (key: "slot-right", x: 0.80, y: 0.44),
                (key: "mike-left", x: 0.34, y: 0.365),
                (key: "deep-center", x: 0.50, y: 0.115)
            ],
            clues: [
                (player: "rb", family: .evidenceRelationship, difficulty: .medium,
                 text: "The handoff goes to the left. A loose cleat lies in the left backfield lane, flung off in the churn — the back who runs behind it drags tacklers with him instead of dancing around them.",
                 constraints: [.nearEvidence(player: "rb", evidence: "cleat", radius: 0.08), .variantIs(player: "rb", variant: .power)],
                 evidence: ["cleat"]),
                (player: "wr", family: .footballResponsibility, difficulty: .easy,
                 text: "The right side already has a target. The left sideline is bare, and the chain marker dragged down near the numbers shows exactly where the next man lines up. A burner, to make the defense honor the whole field.",
                 constraints: [.nearEvidence(player: "wr", evidence: "chain", radius: 0.08), .variantIs(player: "wr", variant: .fast)],
                 evidence: ["chain"]),
                (player: "lb", family: .scenario, difficulty: .medium,
                 text: "The run is coming off tackle to the right. The grass stain ground into the second level, on that side, marks the stack point — a seasoned backer who reads the guard's hips before the ball moves.",
                 constraints: [.nearEvidence(player: "lb", evidence: "stain", radius: 0.08), .variantIs(player: "lb", variant: .veteran)],
                 evidence: ["stain"]),
                (player: "fs", family: .chainedDeduction, difficulty: .hard,
                 text: "Follow the dragged-foot trail in the deep left third — someone shuffled back there all quarter. He stands higher up the field than the right-side backer by a wide margin, and nothing that gets past the front is his problem to chase slowly.",
                 constraints: [.nearEvidence(player: "fs", evidence: "trail", radius: 0.08), .yAbove(a: "fs", b: "lb", gap: 0.15), .variantIs(player: "fs", variant: .fast)],
                 evidence: ["trail"])
            ],
            hints: [
                (player: "rb", text: "Left backfield, beside the loose cleat — between the tackle and the numbers."),
                (player: "wr", text: "Left sideline, on the line of scrimmage — where the chain marker was dragged."),
                (player: "lb", text: "Right side of the second level, where the grass stain is ground in."),
                (player: "fs", text: "Deep left third, higher than the linebacker by a wide gap — follow the dragged-foot trail.")
            ],
            solution: [
                (player: "rb", slot: "rb-left", variant: .power),
                (player: "wr", slot: "wr-left", variant: .fast),
                (player: "lb", slot: "lb-right", variant: .veteran),
                (player: "fs", slot: "fs-left", variant: .fast)
            ]
        ),

        // 4 — The Quiet Edge (seed 3)
        CaseLibrary.makeCase(
            id: "case_tight_edge_04", seed: 3, band: 1,
            title: "The Quiet Edge",
            heading: "EDGE WATCH",
            body: "The line is patched and the edge is exposed. Read it quietly.",
            visible: Formation.build { b in
                b.line([0.30, 0.40, 0.50, 0.70])
                b.add(.qb, 0.50, 0.63)
                b.add(.wr, 0.075, 0.53)
                b.add(.wr, 0.925, 0.52)
                b.front([0.28, 0.42, 0.58, 0.72])
                b.add(.lb, 0.50, 0.36)
                b.add(.cb, 0.925, 0.435)
                b.add(.ss, 0.68, 0.22)
            },
            missing: [
                (key: "te", position: .te),
                (key: "ol", position: .ol),
                (key: "dl", position: .dl),
                (key: "cb", position: .cb)
            ],
            evidence: [
                (key: "strap", kind: .chinStrap, x: 0.585, y: 0.52, rotation: -30),
                (key: "playbook", kind: .wristPlaybook, x: 0.79, y: 0.61, rotation: 12),
                (key: "divot", kind: .divot, x: 0.175, y: 0.43, rotation: -14),
                (key: "towel", kind: .orangeTowel, x: 0.09, y: 0.39, rotation: -22)
            ],
            slots: [
                (key: "ol-gap", x: 0.60, y: 0.565),
                (key: "te-right", x: 0.775, y: 0.565),
                (key: "dl-edge", x: 0.165, y: 0.465),
                (key: "cb-left", x: 0.075, y: 0.435),
                (key: "te-left", x: 0.245, y: 0.565),
                (key: "slot-left", x: 0.215, y: 0.545),
                (key: "edge-right", x: 0.835, y: 0.465),
                (key: "box-left", x: 0.30, y: 0.28)
            ],
            clues: [
                (player: "te", family: .formationKnowledge, difficulty: .medium,
                 text: "The right side of the formation is naked. An eligible target attaches outside the right tackle, where the wrist playbook was dropped mid-practice — a mauler who seals the edge before anything else.",
                 constraints: [.nearEvidence(player: "te", evidence: "playbook", radius: 0.08), .variantIs(player: "te", variant: .power)],
                 evidence: ["playbook"]),
                (player: "ol", family: .footballResponsibility, difficulty: .medium,
                 text: "A gap gapes between the center and the right tackle. The chin strap lying there tells you how hard the last man to try it got beaten — the replacement needs seasoned hands and perfect placement more than raw juice.",
                 constraints: [.nearEvidence(player: "ol", evidence: "strap", radius: 0.08), .variantIs(player: "ol", variant: .veteran)],
                 evidence: ["strap"]),
                (player: "dl", family: .scenario, difficulty: .hard,
                 text: "The defense loads the box, so their widest rusher stands up beyond the tackles on the side away from the visible corner — right over the fresh divot. Straight down the hill at the quarterback.",
                 constraints: [.nearEvidence(player: "dl", evidence: "divot", radius: 0.08), .variantIs(player: "dl", variant: .power)],
                 evidence: ["divot"]),
                (player: "cb", family: .evidenceRelationship, difficulty: .easy,
                 text: "Across from the visible left receiver, just past the line of scrimmage, an orange towel lies where someone worked all night. Press coverage, one-on-one, quick feet required.",
                 constraints: [.nearEvidence(player: "cb", evidence: "towel", radius: 0.08), .variantIs(player: "cb", variant: .fast)],
                 evidence: ["towel"])
            ],
            hints: [
                (player: "te", text: "Right side, outside the right tackle's shoulder — next to the dropped wrist playbook."),
                (player: "ol", text: "The gap between the center and the right tackle — where the chin strap lies."),
                (player: "dl", text: "Left edge, standing up wider than every down lineman — over the fresh divot."),
                (player: "cb", text: "Left sideline, across from the visible receiver — beside the orange towel.")
            ],
            solution: [
                (player: "te", slot: "te-right", variant: .power),
                (player: "ol", slot: "ol-gap", variant: .veteran),
                (player: "dl", slot: "dl-edge", variant: .power),
                (player: "cb", slot: "cb-left", variant: .fast)
            ]
        ),

        // 5 — The Telegraphed Blitz (seed 4)
        CaseLibrary.makeCase(
            id: "case_two_back_blitz_05", seed: 4, band: 1,
            title: "The Telegraphed Blitz",
            heading: "PRESSURE COMING",
            body: "Two backs, one tell, and a defense about to sell out.",
            visible: Formation.build { b in
                b.line([0.30, 0.40, 0.50, 0.60, 0.70])
                b.add(.rb, 0.50, 0.72)
                b.add(.te, 0.775, 0.565)
                b.add(.wr, 0.075, 0.53)
                b.front([0.28, 0.42, 0.58, 0.72])
                b.add(.lb, 0.50, 0.36)
                b.add(.lb, 0.34, 0.36)
                b.add(.cb, 0.075, 0.435)
                b.add(.cb, 0.925, 0.435)
                b.add(.fs, 0.50, 0.135)
            },
            missing: [
                (key: "qb", position: .qb),
                (key: "rb", position: .rb),
                (key: "wr", position: .wr),
                (key: "ss", position: .ss)
            ],
            evidence: [
                (key: "warmer", kind: .handWarmer, x: 0.51, y: 0.72, rotation: -6),
                (key: "cone", kind: .orangeCone, x: 0.63, y: 0.75, rotation: -10),
                (key: "bottle", kind: .waterBottle, x: 0.955, y: 0.555, rotation: 65),
                (key: "mud", kind: .muddyFootprints, x: 0.67, y: 0.34, rotation: 55)
            ],
            slots: [
                (key: "qb-gun", x: 0.50, y: 0.655),
                (key: "rb-right", x: 0.62, y: 0.70),
                (key: "wr-right", x: 0.925, y: 0.52),
                (key: "ss-box", x: 0.66, y: 0.295),
                (key: "under-center", x: 0.50, y: 0.63),
                (key: "rb-left", x: 0.38, y: 0.70),
                (key: "slot-right", x: 0.80, y: 0.44),
                (key: "deep-right", x: 0.82, y: 0.155),
                (key: "box-left", x: 0.34, y: 0.295)
            ],
            clues: [
                (player: "qb", family: .scenario, difficulty: .easy,
                 text: "The hand warmer dropped dead center in the gun tells you the passer stands there — four yards deep, ball exposed, and about to feel seven attackers. He has to be gone from the spot in a heartbeat.",
                 constraints: [.nearEvidence(player: "qb", evidence: "warmer", radius: 0.08), .variantIs(player: "qb", variant: .fast)],
                 evidence: ["warmer"]),
                (player: "rb", family: .profileDeduction, difficulty: .medium,
                 text: "With a blitz incoming, the back beside the orange cone is really a sixth blocker. Recognition matters more than wheels here — he must read the guard's slide, pick the right man and hold his block.",
                 constraints: [.nearEvidence(player: "rb", evidence: "cone", radius: 0.08), .variantIs(player: "rb", variant: .veteran)],
                 evidence: ["cone"]),
                (player: "wr", family: .formationKnowledge, difficulty: .medium,
                 text: "With everyone else packed inside, one receiver keeps the right sideline honest — split wide where the water bottle lies, daring the corner to cheat into the box.",
                 constraints: [.nearEvidence(player: "wr", evidence: "bottle", radius: 0.08), .variantIs(player: "wr", variant: .fast)],
                 evidence: ["bottle"]),
                (player: "ss", family: .evidenceRelationship, difficulty: .hard,
                 text: "The muddy footprints churned into the right second level mark the box crash. The defense wants a thumper there — a body that arrives angry and finishes the pile.",
                 constraints: [.nearEvidence(player: "ss", evidence: "mud", radius: 0.08), .variantIs(player: "ss", variant: .power)],
                 evidence: ["mud"])
            ],
            hints: [
                (player: "qb", text: "Dead center in the gun, four yards deep — the hand warmer marks his spot."),
                (player: "rb", text: "Right of the quarterback in the backfield, by the orange cone — a blocker first, runner second."),
                (player: "wr", text: "Right sideline, split wide where the water bottle lies."),
                (player: "ss", text: "Right second level, where the muddy footprints churn — between the front and the deep middle.")
            ],
            solution: [
                (player: "qb", slot: "qb-gun", variant: .fast),
                (player: "rb", slot: "rb-right", variant: .veteran),
                (player: "wr", slot: "wr-right", variant: .fast),
                (player: "ss", slot: "ss-box", variant: .power)
            ]
        ),

        // 6 — Trips, Unannounced (seed 5)
        CaseLibrary.makeCase(
            id: "case_trips_assignment_06", seed: 5, band: 1,
            title: "Trips, Unannounced",
            heading: "FORMATION SHIFT",
            body: "Three receivers crowd one side. Somebody has to account for all of them.",
            visible: Formation.build { b in
                b.line([0.30, 0.40, 0.50, 0.60, 0.70])
                b.add(.qb, 0.50, 0.655)
                b.add(.wr, 0.075, 0.53)
                b.add(.wr, 0.80, 0.525)
                b.add(.wr, 0.87, 0.545)
                b.front([0.28, 0.42, 0.58, 0.72])
                b.add(.lb, 0.50, 0.36)
                b.add(.cb, 0.925, 0.435)
                b.add(.ss, 0.35, 0.24)
            },
            missing: [
                (key: "wr", position: .wr),
                (key: "te", position: .te),
                (key: "lb", position: .lb),
                (key: "fs", position: .fs)
            ],
            evidence: [
                (key: "cup", kind: .sportsDrinkCup, x: 0.955, y: 0.565, rotation: 18),
                (key: "band", kind: .wristband, x: 0.235, y: 0.525, rotation: 8),
                (key: "board", kind: .markerBoard, x: 0.675, y: 0.315, rotation: -8),
                (key: "marks", kind: .cleatMarks, x: 0.49, y: 0.10, rotation: 20)
            ],
            slots: [
                (key: "wr-trips", x: 0.935, y: 0.53),
                (key: "te-left", x: 0.245, y: 0.565),
                (key: "lb-right", x: 0.66, y: 0.36),
                (key: "fs-center", x: 0.50, y: 0.135),
                (key: "slot-left", x: 0.14, y: 0.52),
                (key: "bunch-inside", x: 0.855, y: 0.48),
                (key: "box-left", x: 0.30, y: 0.28),
                (key: "deep-left", x: 0.30, y: 0.155)
            ],
            clues: [
                (player: "wr", family: .formationKnowledge, difficulty: .medium,
                 text: "Three receivers already crowd the right side and the outside of that bunch is where the sports drink cup got left. The fourth man takes it — the fastest of the group, because trips only works if the widest threat is a real one.",
                 constraints: [.nearEvidence(player: "wr", evidence: "cup", radius: 0.08), .variantIs(player: "wr", variant: .fast)],
                 evidence: ["cup"]),
                (player: "te", family: .footballResponsibility, difficulty: .easy,
                 text: "The left side has nobody but the tackle. An extra blocker attaches outside him, tight to the line, where the wristband was tossed — sealed fists, no finesse.",
                 constraints: [.nearEvidence(player: "te", evidence: "band", radius: 0.08), .variantIs(player: "te", variant: .power)],
                 evidence: ["band"]),
                (player: "lb", family: .evidenceRelationship, difficulty: .medium,
                 text: "The marker board dropped in the right second level shows the checked call: a seasoned backer walks up on that side to match the bunch strength and reroute everything underneath.",
                 constraints: [.nearEvidence(player: "lb", evidence: "board", radius: 0.08), .variantIs(player: "lb", variant: .veteran)],
                 evidence: ["board"]),
                (player: "fs", family: .orderDepth, difficulty: .hard,
                 text: "First man from the top of the picture: the cleat marks at the very back of the end zone are his. Dead center, behind everyone — the last wall before six points.",
                 constraints: [.nearEvidence(player: "fs", evidence: "marks", radius: 0.08), .variantIs(player: "fs", variant: .fast)],
                 evidence: ["marks"])
            ],
            hints: [
                (player: "wr", text: "The bunch is on the right — the empty spot is the OUTSIDE of the trio, by the sports drink cup."),
                (player: "te", text: "Left side, outside the left tackle, tight to the line — where the wristband sits."),
                (player: "lb", text: "Right second level, where the marker board was dropped."),
                (player: "fs", text: "Top center of the picture, deeper than every defender — at the cleat marks.")
            ],
            solution: [
                (player: "wr", slot: "wr-trips", variant: .fast),
                (player: "te", slot: "te-left", variant: .power),
                (player: "lb", slot: "lb-right", variant: .veteran),
                (player: "fs", slot: "fs-center", variant: .fast)
            ]
        ),

        // 7 — The Interior Push (seed 6)
        CaseLibrary.makeCase(
            id: "case_power_interior_07", seed: 6, band: 1,
            title: "The Interior Push",
            heading: "SHORT YARDAGE",
            body: "One yard to grinding out. Everything funnels inside.",
            visible: Formation.build { b in
                b.line([0.30, 0.40, 0.50, 0.60])
                b.add(.qb, 0.50, 0.63)
                b.add(.te, 0.225, 0.565)
                b.add(.wr, 0.925, 0.52)
                b.front([0.28, 0.42, 0.58])
                b.add(.lb, 0.50, 0.36)
                b.add(.cb, 0.075, 0.435)
                b.add(.ss, 0.66, 0.24)
            },
            missing: [
                (key: "rb", position: .rb),
                (key: "ol", position: .ol),
                (key: "de", position: .dl),
                (key: "fs", position: .fs)
            ],
            evidence: [
                (key: "brace", kind: .kneeBrace, x: 0.505, y: 0.835, rotation: -4),
                (key: "strap", kind: .brokenHelmetStrap, x: 0.69, y: 0.60, rotation: -20),
                (key: "skid", kind: .skidMarks, x: 0.725, y: 0.435, rotation: 12),
                (key: "wet", kind: .wetPatch, x: 0.52, y: 0.10, rotation: 0)
            ],
            slots: [
                (key: "rb-deep", x: 0.50, y: 0.79),
                (key: "ol-rt", x: 0.70, y: 0.565),
                (key: "de-right", x: 0.72, y: 0.475),
                (key: "fs-center", x: 0.50, y: 0.13),
                (key: "rb-left", x: 0.38, y: 0.70),
                (key: "slot-right", x: 0.83, y: 0.42),
                (key: "box-right", x: 0.66, y: 0.295),
                (key: "deep-right", x: 0.70, y: 0.155)
            ],
            clues: [
                (player: "rb", family: .orderDepth, difficulty: .easy,
                 text: "Deepest man in the backfield, straight behind the fullback — the knee brace left at his heels belongs to a downhill runner. From a foot out, muscle beats wiggle.",
                 constraints: [.nearEvidence(player: "rb", evidence: "brace", radius: 0.08), .variantIs(player: "rb", variant: .power)],
                 evidence: ["brace"]),
                (player: "ol", family: .footballResponsibility, difficulty: .medium,
                 text: "The right tackle spot sits empty and the broken helmet strap in front of it says why. The replacement drives forward, not sideways — a wall, not a gate.",
                 constraints: [.nearEvidence(player: "ol", evidence: "strap", radius: 0.08), .variantIs(player: "ol", variant: .power)],
                 evidence: ["strap"]),
                (player: "de", family: .scenario, difficulty: .medium,
                 text: "The defense answers by slanting their widest man hard inside over the new blocker — the skid marks show where his first step bit the turf. No runway, no angle, just violence.",
                 constraints: [.nearEvidence(player: "de", evidence: "skid", radius: 0.08), .variantIs(player: "de", variant: .fast)],
                 evidence: ["skid"]),
                (player: "fs", family: .evidenceRelationship, difficulty: .hard,
                 text: "The wet patch dead center at the very top of the picture marks the last man standing. He has been alone there all night, and if the interior push ever squirts loose, only his range saves six points.",
                 constraints: [.nearEvidence(player: "fs", evidence: "wet", radius: 0.08), .variantIs(player: "fs", variant: .fast)],
                 evidence: ["wet"])
            ],
            hints: [
                (player: "rb", text: "Straight behind the fullback, deepest in the backfield — at the knee brace."),
                (player: "ol", text: "The right tackle spot — shoulder to shoulder with the guard, by the broken strap."),
                (player: "de", text: "Right end, wider than the front — over the skid marks, slanting inside."),
                (player: "fs", text: "Top center, deepest man on the field — beside the wet patch.")
            ],
            solution: [
                (player: "rb", slot: "rb-deep", variant: .power),
                (player: "ol", slot: "ol-rt", variant: .power),
                (player: "de", slot: "de-right", variant: .fast),
                (player: "fs", slot: "fs-center", variant: .fast)
            ]
        ),

        // 8 — The Crowded Bunch (seed 7)
        CaseLibrary.makeCase(
            id: "case_bunch_right_08", seed: 7, band: 1,
            title: "The Crowded Bunch",
            heading: "TRAFFIC JAM",
            body: "A bunch set, a busy left side, and five missing men.",
            visible: Formation.build { b in
                b.line([0.30, 0.40, 0.50, 0.60, 0.70])
                b.add(.rb, 0.42, 0.68)
                b.add(.wr, 0.14, 0.53)
                b.add(.wr, 0.205, 0.545)
                b.add(.wr, 0.925, 0.52)
                b.front([0.28, 0.42, 0.58, 0.72])
                b.add(.lb, 0.50, 0.36)
                b.add(.cb, 0.075, 0.435)
                b.add(.fs, 0.50, 0.135)
            },
            missing: [
                (key: "qb", position: .qb),
                (key: "te", position: .te),
                (key: "wr", position: .wr),
                (key: "cb", position: .cb),
                (key: "ss", position: .ss)
            ],
            evidence: [
                (key: "mouth", kind: .mouthguard, x: 0.51, y: 0.715, rotation: 6),
                (key: "flag", kind: .challengeFlag, x: 0.79, y: 0.615, rotation: 14),
                (key: "glove", kind: .droppedGlove, x: 0.285, y: 0.51, rotation: 24),
                (key: "visor", kind: .visorCloth, x: 0.945, y: 0.475, rotation: 30),
                (key: "strap", kind: .shoulderPadStrap, x: 0.325, y: 0.335, rotation: -35)
            ],
            slots: [
                (key: "qb-gun", x: 0.50, y: 0.655),
                (key: "te-right", x: 0.775, y: 0.565),
                (key: "wr-bunch-in", x: 0.27, y: 0.545),
                (key: "cb-right", x: 0.925, y: 0.435),
                (key: "ss-box-left", x: 0.34, y: 0.295),
                (key: "under-center", x: 0.50, y: 0.63),
                (key: "te-left", x: 0.215, y: 0.575),
                (key: "slot-left", x: 0.14, y: 0.52),
                (key: "box-right", x: 0.66, y: 0.295),
                (key: "deep-right", x: 0.80, y: 0.155),
                (key: "edge-left", x: 0.165, y: 0.465)
            ],
            clues: [
                (player: "qb", family: .scenario, difficulty: .easy,
                 text: "The mouthguard spat out dead center in the gun tells you the passer stands four yards deep — with a stacked look in front of him, he needs poise more than legs to find the right man in the trash.",
                 constraints: [.nearEvidence(player: "qb", evidence: "mouth", radius: 0.08), .variantIs(player: "qb", variant: .veteran)],
                 evidence: ["mouth"]),
                (player: "te", family: .footballResponsibility, difficulty: .medium,
                 text: "The right tackle is alone on an island with their best rusher. The challenge flag lying at the blocker's spot says the staff already argued about it once — a sledgehammer attaches to that shoulder and settles the argument.",
                 constraints: [.nearEvidence(player: "te", evidence: "flag", radius: 0.08), .variantIs(player: "te", variant: .power)],
                 evidence: ["flag"]),
                (player: "wr", family: .formationKnowledge, difficulty: .medium,
                 text: "Two receivers already form the bunch on the left. The inside man of the trio lines up where the dropped glove lies — the quick-twitch one who wins in two steps, not forty yards.",
                 constraints: [.nearEvidence(player: "wr", evidence: "glove", radius: 0.08), .variantIs(player: "wr", variant: .fast)],
                 evidence: ["glove"]),
                (player: "cb", family: .elimination, difficulty: .medium,
                 text: "The wide receiver across the field gets single coverage by the visor cloth at the corner's spot — and the call sheet says that man is neither the veteran nor the speedster. They want a press-mauler with hands like clamps.",
                 constraints: [.nearEvidence(player: "cb", evidence: "visor", radius: 0.08), .variantIsNot(player: "cb", variant: .veteran), .variantIsNot(player: "cb", variant: .fast)],
                 evidence: ["visor"]),
                (player: "ss", family: .evidenceRelationship, difficulty: .hard,
                 text: "The shoulder-pad strap abandoned in the left second level marks the roamer's post: between the front and the deep men on the bunch side, reading three receivers at once.",
                 constraints: [.nearEvidence(player: "ss", evidence: "strap", radius: 0.08), .variantIs(player: "ss", variant: .veteran)],
                 evidence: ["strap"])
            ],
            hints: [
                (player: "qb", text: "Dead center in the gun, four yards deep — the mouthguard marks him."),
                (player: "te", text: "Right side, outside the right tackle — where the challenge flag lies."),
                (player: "wr", text: "The bunch is on the LEFT. The empty spot is the INSIDE of the trio, by the dropped glove."),
                (player: "cb", text: "Right sideline, across from the lone wide receiver — by the visor cloth."),
                (player: "ss", text: "Left second level, between the line and the safeties — at the shoulder-pad strap.")
            ],
            solution: [
                (player: "qb", slot: "qb-gun", variant: .veteran),
                (player: "te", slot: "te-right", variant: .power),
                (player: "wr", slot: "wr-bunch-in", variant: .fast),
                (player: "cb", slot: "cb-right", variant: .power),
                (player: "ss", slot: "ss-box-left", variant: .veteran)
            ]
        ),

        // 9 — The Leftward Drift (seed 8)
        CaseLibrary.makeCase(
            id: "case_motion_left_09", seed: 8, band: 1,
            title: "The Leftward Drift",
            heading: "MOTION READ",
            body: "The whole formation leans left. The defense has to lean with it.",
            visible: Formation.build { b in
                b.line([0.30, 0.40, 0.50, 0.60, 0.70])
                b.add(.qb, 0.50, 0.655)
                b.add(.te, 0.775, 0.565)
                b.add(.wr, 0.925, 0.52)
                b.front([0.28, 0.42, 0.58])
                b.add(.lb, 0.50, 0.36)
                b.add(.lb, 0.34, 0.36)
                b.add(.cb, 0.925, 0.435)
                b.add(.ss, 0.35, 0.24)
            },
            missing: [
                (key: "wr", position: .wr),
                (key: "rb", position: .rb),
                (key: "dl", position: .dl),
                (key: "cb", position: .cb),
                (key: "fs", position: .fs)
            ],
            evidence: [
                (key: "card", kind: .droppedPlayCard, x: 0.09, y: 0.575, rotation: -10),
                (key: "tape", kind: .tapeRoll, x: 0.375, y: 0.745, rotation: 36),
                (key: "wet", kind: .wetPatch, x: 0.175, y: 0.42, rotation: 0),
                (key: "stain", kind: .grassStain, x: 0.09, y: 0.40, rotation: 0),
                (key: "ball", kind: .looseFootball, x: 0.48, y: 0.095, rotation: -6)
            ],
            slots: [
                (key: "wr-left", x: 0.075, y: 0.53),
                (key: "rb-left", x: 0.38, y: 0.70),
                (key: "dl-edge", x: 0.165, y: 0.465),
                (key: "cb-left", x: 0.075, y: 0.435),
                (key: "fs-center", x: 0.50, y: 0.13),
                (key: "slot-right", x: 0.80, y: 0.44),
                (key: "box-right", x: 0.66, y: 0.295),
                (key: "deep-right", x: 0.70, y: 0.155),
                (key: "rb-right", x: 0.62, y: 0.70),
                (key: "edge-right", x: 0.835, y: 0.465)
            ],
            clues: [
                (player: "wr", family: .relativePosition, difficulty: .medium,
                 text: "The motion drifts left, and the receiver on that flank lines up just outside the numbers on the line of scrimmage — the dropped play card at his feet is the tip sheet for it. Wider than the corner, shallower than the back.",
                 constraints: [.nearEvidence(player: "wr", evidence: "card", radius: 0.08), .variantIs(player: "wr", variant: .veteran)],
                 evidence: ["card"]),
                (player: "rb", family: .scenario, difficulty: .easy,
                 text: "With the defense tilted left, the back offsets left of the gun — the tape roll in the left backfield lane marks him. His job is the first cut into the light.",
                 constraints: [.nearEvidence(player: "rb", evidence: "tape", radius: 0.08), .variantIs(player: "rb", variant: .fast)],
                 evidence: ["tape"]),
                (player: "dl", family: .evidenceRelationship, difficulty: .medium,
                 text: "The defense slides a fifth rusher to the overloaded side, standing up beyond the tackles over the wet patch. He hunts the edge before the ball is even snapped.",
                 constraints: [.nearEvidence(player: "dl", evidence: "wet", radius: 0.08), .variantIs(player: "dl", variant: .power)],
                 evidence: ["wet"]),
                (player: "cb", family: .elimination, difficulty: .medium,
                 text: "Across from the new receiver, the grass stain marks the corner's post. He is neither the speedster nor the press-mauler on the call sheet — the staff trusts him to see the motion coming before anyone else does.",
                 constraints: [.nearEvidence(player: "cb", evidence: "stain", radius: 0.08), .variantIsNot(player: "cb", variant: .fast), .variantIsNot(player: "cb", variant: .power)],
                 evidence: ["stain"]),
                (player: "fs", family: .orderDepth, difficulty: .hard,
                 text: "The loose football at the very top of the picture, dead center, is where the last line stands — behind everyone, guarding against the deep shot the motion is trying to open.",
                 constraints: [.nearEvidence(player: "fs", evidence: "ball", radius: 0.08), .variantIs(player: "fs", variant: .veteran)],
                 evidence: ["ball"])
            ],
            hints: [
                (player: "wr", text: "Left sideline, on the line of scrimmage — the play card sits at his feet."),
                (player: "rb", text: "Left of the quarterback in the backfield — by the tape roll."),
                (player: "dl", text: "Left edge, wider than every down lineman — over the wet patch."),
                (player: "cb", text: "Left sideline across from the new receiver — at the grass stain."),
                (player: "fs", text: "Top center, deepest man on the field — at the loose football.")
            ],
            solution: [
                (player: "wr", slot: "wr-left", variant: .veteran),
                (player: "rb", slot: "rb-left", variant: .fast),
                (player: "dl", slot: "dl-edge", variant: .power),
                (player: "cb", slot: "cb-left", variant: .veteran),
                (player: "fs", slot: "fs-center", variant: .veteran)
            ]
        ),

        // 10 — Red Zone Mirror (seed 9)
        CaseLibrary.makeCase(
            id: "case_red_zone_look_10", seed: 9, band: 1,
            title: "Red Zone Mirror",
            heading: "SCORING POSITION",
            body: "Twenty-two yards from paying dirt and the picture doesn't add up.",
            visible: Formation.build { b in
                b.line([0.30, 0.40, 0.50, 0.60])
                b.add(.qb, 0.50, 0.63)
                b.add(.rb, 0.50, 0.72)
                b.add(.wr, 0.075, 0.53)
                b.front([0.28, 0.42, 0.58, 0.72])
                b.add(.lb, 0.50, 0.36)
                b.add(.cb, 0.925, 0.435)
                b.add(.fs, 0.50, 0.135)
            },
            missing: [
                (key: "te", position: .te),
                (key: "ol", position: .ol),
                (key: "lb", position: .lb),
                (key: "ss", position: .ss)
            ],
            evidence: [
                (key: "sheet", kind: .laminatedPlaySheet, x: 0.795, y: 0.62, rotation: -6),
                (key: "tee", kind: .kickingTee, x: 0.69, y: 0.61, rotation: 10),
                (key: "flag", kind: .challengeFlag, x: 0.675, y: 0.315, rotation: 16),
                (key: "band", kind: .wristband, x: 0.305, y: 0.305, rotation: 8)
            ],
            slots: [
                (key: "te-right", x: 0.775, y: 0.565),
                (key: "ol-rt", x: 0.70, y: 0.565),
                (key: "lb-right", x: 0.66, y: 0.36),
                (key: "ss-box-left", x: 0.32, y: 0.26),
                (key: "te-left", x: 0.245, y: 0.565),
                (key: "slot-right", x: 0.85, y: 0.46),
                (key: "box-deep-right", x: 0.78, y: 0.25),
                (key: "deep-left", x: 0.30, y: 0.155),
                (key: "left-slot", x: 0.14, y: 0.52)
            ],
            clues: [
                (player: "te", family: .footballResponsibility, difficulty: .medium,
                 text: "In the red zone the staff wants a second giant on the right. The laminated play sheet dropped just outside the right tackle is the goal-line package — the man there has hands like shovels and blocks like one too.",
                 constraints: [.nearEvidence(player: "te", evidence: "sheet", radius: 0.08), .variantIs(player: "te", variant: .veteran)],
                 evidence: ["sheet"]),
                (player: "ol", family: .formationKnowledge, difficulty: .easy,
                 text: "The right tackle spot is empty, and the kicking tee parked in front of it says the backup has been warming there. He fires off the ball low and straight — no pyrotechnics, just a wall.",
                 constraints: [.nearEvidence(player: "ol", evidence: "tee", radius: 0.08), .variantIs(player: "ol", variant: .power)],
                 evidence: ["tee"]),
                (player: "lb", family: .evidenceRelationship, difficulty: .medium,
                 text: "The challenge flag in the right second level marks where the run-stopper aligns. Goal line means no space to run around anything — he has to arrive fast and hit the gap before the fullback does.",
                 constraints: [.nearEvidence(player: "lb", evidence: "flag", radius: 0.08), .variantIs(player: "lb", variant: .fast)],
                 evidence: ["flag"]),
                (player: "ss", family: .chainedDeduction, difficulty: .hard,
                 text: "Follow the wristband on the left: the roamer aligns there, higher up the field than the right-side backer, between the front and the deep middle — close enough to smell the run, smart enough not to bite on play action.",
                 constraints: [.nearEvidence(player: "ss", evidence: "band", radius: 0.08), .yAbove(a: "ss", b: "lb", gap: 0.05), .variantIs(player: "ss", variant: .power)],
                 evidence: ["band"])
            ],
            hints: [
                (player: "te", text: "Right side, outside the right tackle — at the laminated play sheet."),
                (player: "ol", text: "The right tackle spot — where the kicking tee was warming up."),
                (player: "lb", text: "Right second level — the challenge flag marks his alignment."),
                (player: "ss", text: "Left side, higher than the right backer, between the front and the deep middle — by the wristband.")
            ],
            solution: [
                (player: "te", slot: "te-right", variant: .veteran),
                (player: "ol", slot: "ol-rt", variant: .power),
                (player: "lb", slot: "lb-right", variant: .fast),
                (player: "ss", slot: "ss-box-left", variant: .power)
            ]
        )
    ]
}

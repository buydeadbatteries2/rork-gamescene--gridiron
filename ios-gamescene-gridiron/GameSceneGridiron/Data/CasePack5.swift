import Foundation

/// Band 5 — overtime and high-leverage cases: winner-take-all situations with
/// the deepest deduction chains in the library.
nonisolated enum CasePack5 {
    static let all: [QuarterCase] = [

        // 41 — Final Drive, Empty Set (seed 40)
        CaseLibrary.makeCase(
            id: "case_final_drive_empty_01", seed: 40, band: 5,
            title: "Final Drive, Empty Set",
            heading: "OVERTIME",
            body: "One situation. One drive. Five empty jerseys decide everything.",
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
                (key: "cb", position: .cb)
            ],
            evidence: [
                (key: "mud", kind: .muddyFootprints, x: 0.515, y: 0.715, rotation: 55),
                (key: "band", kind: .wristband, x: 0.775, y: 0.585, rotation: 8),
                (key: "bottle", kind: .waterBottle, x: 0.97, y: 0.565, rotation: 70),
                (key: "strap", kind: .brokenHelmetStrap, x: 0.87, y: 0.525, rotation: -22),
                (key: "cone", kind: .orangeCone, x: 0.805, y: 0.385, rotation: -12)
            ],
            slots: [
                (key: "qb-gun", x: 0.50, y: 0.655),
                (key: "wr1-right", x: 0.955, y: 0.52),
                (key: "wr2-slot", x: 0.765, y: 0.535),
                (key: "de-edge", x: 0.87, y: 0.465),
                (key: "cb-slot", x: 0.80, y: 0.43),
                (key: "gun-left", x: 0.38, y: 0.655),
                (key: "deep-gun", x: 0.38, y: 0.79),
                (key: "slot-left", x: 0.14, y: 0.52),
                (key: "box-left", x: 0.30, y: 0.28),
                (key: "edge-left", x: 0.165, y: 0.465),
                (key: "deep-right", x: 0.70, y: 0.155)
            ],
            clues: [
                (player: "qb", family: .scenario, difficulty: .easy,
                 text: "Final drive, empty set, season on the line — the muddy footprints four yards behind the line mark the passer. He calls his own number here, and his legs count as much as his arm.",
                 constraints: [.nearEvidence(player: "qb", evidence: "mud", radius: 0.08), .variantIs(player: "qb", variant: .fast)],
                 evidence: ["mud"]),
                (player: "wr1", family: .relativePosition, difficulty: .medium,
                 text: "The water bottle at the far right numbers marks the sideline specialist — wider than the slot, shallower than the corner, the man the whole drive is aimed at. He always knows where the white paint is.",
                 constraints: [.nearEvidence(player: "wr1", evidence: "bottle", radius: 0.08), .variantIs(player: "wr1", variant: .veteran)],
                 evidence: ["bottle"]),
                (player: "wr2", family: .formationKnowledge, difficulty: .medium,
                 text: "The wristband inside of him marks the quick outlet: off the tackle, at the sticks, the throw that keeps the drive breathing while the defense panics.",
                 constraints: [.nearEvidence(player: "wr2", evidence: "band", radius: 0.08), .variantIs(player: "wr2", variant: .fast)],
                 evidence: ["band"]),
                (player: "de", family: .footballResponsibility, difficulty: .medium,
                 text: "The broken helmet strap beyond the tackle marks the rusher the drive fears most — with no back to help, he has a free path and a mandate to use it.",
                 constraints: [.nearEvidence(player: "de", evidence: "strap", radius: 0.08), .variantIs(player: "de", variant: .fast)],
                 evidence: ["strap"]),
                (player: "cb", family: .elimination, difficulty: .hard,
                 text: "The orange cone at the slot's heel marks the nickel's post. The staff crossed off the veteran and the speedster — they want the press-mauler who ends the drive with his hands at the line.",
                 constraints: [.nearEvidence(player: "cb", evidence: "cone", radius: 0.08), .variantIsNot(player: "cb", variant: .veteran), .variantIsNot(player: "cb", variant: .fast)],
                 evidence: ["cone"])
            ],
            hints: [
                (player: "qb", text: "Four yards deep in the gun, dead center — the muddy footprints are the tell."),
                (player: "wr1", text: "Far right numbers — by the water bottle. The sideline specialist."),
                (player: "wr2", text: "Inside right, off the tackle's shoulder — where the wristband was tossed."),
                (player: "de", text: "Right edge, wide of the tackle — where the broken helmet strap lies."),
                (player: "cb", text: "At the slot receiver's heel — the orange cone. Hands at the line.")
            ],
            solution: [
                (player: "qb", slot: "qb-gun", variant: .fast),
                (player: "wr1", slot: "wr1-right", variant: .veteran),
                (player: "wr2", slot: "wr2-slot", variant: .fast),
                (player: "de", slot: "de-edge", variant: .fast),
                (player: "cb", slot: "cb-slot", variant: .power)
            ]
        ),

        // 42 — One Yard of Turf (seed 41)
        CaseLibrary.makeCase(
            id: "case_goal_line_power_02", seed: 41, band: 5,
            title: "One Yard of Turf",
            heading: "GOAL TO GO",
            body: "The whole season is one yard wide. Win the collision, win the game.",
            visible: Formation.build { b in
                b.line([0.30, 0.50, 0.60, 0.70])
                b.add(.te, 0.225, 0.565)
                b.add(.qb, 0.50, 0.63)
                b.add(.rb, 0.50, 0.71)
                b.add(.wr, 0.925, 0.52)
                b.front([0.28, 0.42, 0.58, 0.72])
                b.add(.lb, 0.50, 0.36)
                b.add(.cb, 0.075, 0.435)
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
                (key: "board", kind: .markerBoard, x: 0.385, y: 0.605, rotation: -8),
                (key: "divot", kind: .divot, x: 0.505, y: 0.43, rotation: -14),
                (key: "flag", kind: .challengeFlag, x: 0.675, y: 0.315, rotation: 16),
                (key: "strap", kind: .chinStrap, x: 0.79, y: 0.615, rotation: -28)
            ],
            slots: [
                (key: "rb-deep", x: 0.50, y: 0.79),
                (key: "ol-lg", x: 0.40, y: 0.565),
                (key: "dl-nose", x: 0.50, y: 0.475),
                (key: "lb-right", x: 0.66, y: 0.36),
                (key: "te-right", x: 0.775, y: 0.565),
                (key: "back-left", x: 0.38, y: 0.70),
                (key: "te-left", x: 0.245, y: 0.565),
                (key: "edge-left", x: 0.165, y: 0.465),
                (key: "slot-right", x: 0.85, y: 0.46),
                (key: "box-right", x: 0.76, y: 0.25),
                (key: "deep-center", x: 0.50, y: 0.115)
            ],
            clues: [
                (player: "rb", family: .orderDepth, difficulty: .easy,
                 text: "The knee brace at the deepest backfield spot marks the finisher: no cut, no dance — lower pads, forward lean, and the pile moves or it doesn't.",
                 constraints: [.nearEvidence(player: "rb", evidence: "brace", radius: 0.08), .variantIs(player: "rb", variant: .power)],
                 evidence: ["brace"]),
                (player: "ol", family: .formationKnowledge, difficulty: .medium,
                 text: "The marker board parked at the empty left guard spot shows the last-ditch fix — the sixth body across, assigned to a gap and forbidden from leaving it.",
                 constraints: [.nearEvidence(player: "ol", evidence: "board", radius: 0.08), .variantIs(player: "ol", variant: .veteran)],
                 evidence: ["board"]),
                (player: "dl", family: .evidenceRelationship, difficulty: .medium,
                 text: "The fresh divot dead center in the front marks the nose: he is the anchor of the goal-line stand, and everything the defense does depends on him not moving backward an inch.",
                 constraints: [.nearEvidence(player: "dl", evidence: "divot", radius: 0.08), .variantIs(player: "dl", variant: .power)],
                 evidence: ["divot"]),
                (player: "lb", family: .scenario, difficulty: .hard,
                 text: "The challenge flag at the right inside backer spot marks the hole shooter. In this pile there is no room to run around anything — he has to be the fastest thing moving forward.",
                 constraints: [.nearEvidence(player: "lb", evidence: "flag", radius: 0.08), .variantIs(player: "lb", variant: .fast)],
                 evidence: ["flag"]),
                (player: "te", family: .footballResponsibility, difficulty: .medium,
                 text: "The chin strap flung outside the right tackle marks the second giant — eligible, but nobody is throwing him the ball. He is here to move a wall.",
                 constraints: [.nearEvidence(player: "te", evidence: "strap", radius: 0.08), .variantIs(player: "te", variant: .power)],
                 evidence: ["strap"])
            ],
            hints: [
                (player: "rb", text: "Straight behind the fullback, deepest backfield spot — where the knee brace sits."),
                (player: "ol", text: "The empty left guard spot — the marker board is parked there."),
                (player: "dl", text: "Middle of the front, dead center — over the fresh divot."),
                (player: "lb", text: "Right inside backer spot — at the challenge flag. Fastest thing moving forward."),
                (player: "te", text: "Right side of the formation, outside the tackle — right where the chin strap lies.")
            ],
            solution: [
                (player: "rb", slot: "rb-deep", variant: .power),
                (player: "te", slot: "te-right", variant: .power),
                (player: "ol", slot: "ol-lg", variant: .veteran),
                (player: "dl", slot: "dl-nose", variant: .power),
                (player: "lb", slot: "lb-right", variant: .fast)
            ]
        ),

        // 43 — Trips Right, Two Deep (seed 42)
        CaseLibrary.makeCase(
            id: "case_trips_coverage_03", seed: 42, band: 5,
            title: "Trips Right, Two Deep",
            heading: "MAX PROTECTION",
            body: "Three receivers on one side, two safeties on top. Someone is unaccounted for.",
            visible: Formation.build { b in
                b.line([0.30, 0.40, 0.50, 0.60, 0.70])
                b.add(.qb, 0.50, 0.655)
                b.add(.rb, 0.42, 0.68)
                b.add(.wr, 0.075, 0.53)
                b.front([0.28, 0.42, 0.58, 0.72])
                b.add(.lb, 0.50, 0.36)
                b.add(.lb, 0.34, 0.36)
            },
            missing: [
                (key: "wr1", position: .wr),
                (key: "wr2", position: .wr),
                (key: "te", position: .te),
                (key: "cb", position: .cb),
                (key: "ss", position: .ss),
                (key: "fs", position: .fs)
            ],
            evidence: [
                (key: "cup", kind: .sportsDrinkCup, x: 0.955, y: 0.575, rotation: 18),
                (key: "band", kind: .wristband, x: 0.775, y: 0.585, rotation: 8),
                (key: "tape", kind: .tapeRoll, x: 0.235, y: 0.525, rotation: 40),
                (key: "cone", kind: .orangeCone, x: 0.945, y: 0.395, rotation: -12),
                (key: "strap", kind: .shoulderPadStrap, x: 0.675, y: 0.335, rotation: -35),
                (key: "marks", kind: .cleatMarks, x: 0.49, y: 0.10, rotation: 20)
            ],
            slots: [
                (key: "wr1-trips", x: 0.935, y: 0.53),
                (key: "wr2-slot", x: 0.80, y: 0.535),
                (key: "te-left", x: 0.245, y: 0.565),
                (key: "cb-trips", x: 0.935, y: 0.435),
                (key: "ss-box", x: 0.66, y: 0.295),
                (key: "fs-center", x: 0.50, y: 0.135),
                (key: "slot-left", x: 0.14, y: 0.52),
                (key: "deep-left", x: 0.27, y: 0.14),
                (key: "deep-right", x: 0.70, y: 0.155),
                (key: "box-left", x: 0.30, y: 0.28),
                (key: "edge-right", x: 0.855, y: 0.475),
                (key: "back-right", x: 0.62, y: 0.70)
            ],
            clues: [
                (player: "wr2", family: .formationKnowledge, difficulty: .easy,
                 text: "The wristband inside of him marks the slot man — the trips concept only works if the inside target wins in under two seconds, before any help can rotate.",
                 constraints: [.nearEvidence(player: "wr2", evidence: "band", radius: 0.08), .variantIs(player: "wr2", variant: .fast)],
                 evidence: ["band"]),
                (player: "te", family: .footballResponsibility, difficulty: .medium,
                 text: "The left side is empty of receivers, so the tape roll outside the left tackle marks the attached blocker: seal the edge, buy the passer his full read.",
                 constraints: [.nearEvidence(player: "te", evidence: "tape", radius: 0.08), .variantIs(player: "te", variant: .power)],
                 evidence: ["tape"]),
                (player: "wr1", family: .relativePosition, difficulty: .medium,
                 text: "The sports drink cup at the far right numbers marks the outside man of the trio — wider than the slot, deeper than the corner's heel. The deep shot belongs to him.",
                 constraints: [.nearEvidence(player: "wr1", evidence: "cup", radius: 0.08), .variantIs(player: "wr1", variant: .veteran)],
                 evidence: ["cup"]),
                (player: "cb", family: .elimination, difficulty: .hard,
                 text: "The orange cone at the trio's heel marks the trips corner. The staff crossed off the veteran and the speedster — they want the press-mauler who wrecks the bunch before it forms.",
                 constraints: [.nearEvidence(player: "cb", evidence: "cone", radius: 0.08), .variantIsNot(player: "cb", variant: .veteran), .variantIsNot(player: "cb", variant: .fast)],
                 evidence: ["cone"]),
                (player: "ss", family: .evidenceRelationship, difficulty: .medium,
                 text: "The shoulder-pad strap on the right second level marks the trips-side rover: between the front and the deep halves, reading three receivers at once.",
                 constraints: [.nearEvidence(player: "ss", evidence: "strap", radius: 0.08), .variantIs(player: "ss", variant: .veteran)],
                 evidence: ["strap"]),
                (player: "fs", family: .orderDepth, difficulty: .medium,
                 text: "The cleat marks at the very top of the picture, dead center, are the single-deep post — behind the trips, behind the rover, guarding against the one shot the whole concept hides.",
                 constraints: [.nearEvidence(player: "fs", evidence: "marks", radius: 0.08), .variantIs(player: "fs", variant: .fast)],
                 evidence: ["marks"])
            ],
            hints: [
                (player: "wr2", text: "Right slot alignment, off the tackle — at the discarded wristband."),
                (player: "te", text: "The left edge of the line, outside the tackle — at the tape roll."),
                (player: "wr1", text: "Far right numbers, outside of the trio — by the sports drink cup."),
                (player: "cb", text: "At the trio's heel on the right — the orange cone. Wreck the bunch."),
                (player: "ss", text: "Right second level — at the shoulder-pad strap."),
                (player: "fs", text: "Top center, single-deep — at the cleat marks.")
            ],
            solution: [
                (player: "wr1", slot: "wr1-trips", variant: .veteran),
                (player: "wr2", slot: "wr2-slot", variant: .fast),
                (player: "te", slot: "te-left", variant: .power),
                (player: "cb", slot: "cb-trips", variant: .power),
                (player: "ss", slot: "ss-box", variant: .veteran),
                (player: "fs", slot: "fs-center", variant: .fast)
            ]
        ),

        // 44 — Fifty-Seven Yards of Air (seed 43)
        CaseLibrary.makeCase(
            id: "case_hail_mary_04", seed: 43, band: 5,
            title: "Fifty-Seven Yards of Air",
            heading: "ONE PLAY LEFT",
            body: "No clock, no plan B. Everybody goes deep.",
            visible: Formation.build { b in
                b.line([0.30, 0.40, 0.50, 0.60, 0.70])
                b.add(.wr, 0.075, 0.53)
                b.add(.wr, 0.22, 0.525)
                b.front([0.28, 0.42, 0.58])
                b.add(.lb, 0.50, 0.36)
                b.add(.lb, 0.34, 0.36)
                b.add(.cb, 0.075, 0.435)
                b.add(.cb, 0.925, 0.435)
                b.add(.ss, 0.35, 0.24)
            },
            missing: [
                (key: "qb", position: .qb),
                (key: "wr1", position: .wr),
                (key: "wr2", position: .wr),
                (key: "dl", position: .dl),
                (key: "fs", position: .fs)
            ],
            evidence: [
                (key: "chalk", kind: .chalkMark, x: 0.50, y: 0.775, rotation: 45),
                (key: "cup", kind: .sportsDrinkCup, x: 0.945, y: 0.565, rotation: 18),
                (key: "band", kind: .wristband, x: 0.775, y: 0.585, rotation: 8),
                (key: "divot", kind: .divot, x: 0.505, y: 0.43, rotation: -14),
                (key: "marks", kind: .cleatMarks, x: 0.49, y: 0.08, rotation: 20)
            ],
            slots: [
                (key: "qb-deep", x: 0.50, y: 0.72),
                (key: "wr1-right", x: 0.925, y: 0.52),
                (key: "wr2-slot", x: 0.80, y: 0.535),
                (key: "dl-nose", x: 0.50, y: 0.475),
                (key: "fs-center", x: 0.50, y: 0.115),
                (key: "gun-short", x: 0.50, y: 0.655),
                (key: "back-right", x: 0.62, y: 0.70),
                (key: "slot-left", x: 0.14, y: 0.52),
                (key: "edge-right", x: 0.835, y: 0.465),
                (key: "deep-right", x: 0.70, y: 0.155),
                (key: "box-left", x: 0.30, y: 0.28)
            ],
            clues: [
                (player: "qb", family: .orderDepth, difficulty: .easy,
                 text: "The chalk mark deeper than any normal gun — six yards behind the line — is the heaver's spot. He steps up into the storm and throws the entire game into the night sky.",
                 constraints: [.nearEvidence(player: "qb", evidence: "chalk", radius: 0.08), .variantIs(player: "qb", variant: .veteran)],
                 evidence: ["chalk"]),
                (player: "wr1", family: .relativePosition, difficulty: .medium,
                 text: "The sports drink cup at the far right numbers marks the primary jump-ball man — wider than the slot, deepest of the targets. Height and body control, not separation.",
                 constraints: [.nearEvidence(player: "wr1", evidence: "cup", radius: 0.08), .variantIs(player: "wr1", variant: .fast)],
                 evidence: ["cup"]),
                (player: "wr2", family: .formationKnowledge, difficulty: .medium,
                 text: "The wristband inside of him marks the tip-drill man: he runs to the spot where overthrows go to die and fishes them out of the air.",
                 constraints: [.nearEvidence(player: "wr2", evidence: "band", radius: 0.08), .variantIs(player: "wr2", variant: .veteran)],
                 evidence: ["band"]),
                (player: "dl", family: .footballResponsibility, difficulty: .medium,
                 text: "The divot dead center in the front marks the interior push. In five seconds he will not reach the passer — but he can shorten the throw, and a short throw is a dead drive.",
                 constraints: [.nearEvidence(player: "dl", evidence: "divot", radius: 0.08), .variantIs(player: "dl", variant: .power)],
                 evidence: ["divot"]),
                (player: "fs", family: .evidenceRelationship, difficulty: .hard,
                 text: "The cleat marks at the very top of the picture, dead center, are the last defender's post. Every Hail Mary is a jump ball between strangers — his job is to make sure it lands in traffic, not in history.",
                 constraints: [.nearEvidence(player: "fs", evidence: "marks", radius: 0.08), .variantIs(player: "fs", variant: .fast)],
                 evidence: ["marks"])
            ],
            hints: [
                (player: "qb", text: "Six yards deep in the gun — at the chalk mark. Deeper than normal."),
                (player: "wr1", text: "Far right numbers — by the sports drink cup. The jump-ball man."),
                (player: "wr2", text: "Right slot — where the wristband lies. The tip-drill man."),
                (player: "dl", text: "Dead center in the front — over the divot."),
                (player: "fs", text: "Top center, the deepest man on the field — at the cleat marks.")
            ],
            solution: [
                (player: "qb", slot: "qb-deep", variant: .veteran),
                (player: "wr1", slot: "wr1-right", variant: .fast),
                (player: "wr2", slot: "wr2-slot", variant: .veteran),
                (player: "dl", slot: "dl-nose", variant: .power),
                (player: "fs", slot: "fs-center", variant: .fast)
            ]
        ),

        // 45 — All-Out, Nothing Left (seed 44)
        CaseLibrary.makeCase(
            id: "case_all_out_pressure_05", seed: 44, band: 5,
            title: "All-Out, Nothing Left",
            heading: "MAX PRESSURE",
            body: "The defense sold out to reach the quarterback. The offense sold out to stop them.",
            visible: Formation.build { b in
                b.line([0.30, 0.40, 0.50, 0.60])
                b.add(.rb, 0.50, 0.71)
                b.add(.wr, 0.075, 0.53)
                b.add(.wr, 0.925, 0.52)
                b.front([0.28, 0.42, 0.58])
                b.add(.lb, 0.34, 0.36)
                b.add(.cb, 0.925, 0.435)
                b.add(.fs, 0.50, 0.135)
            },
            missing: [
                (key: "ol", position: .ol),
                (key: "te", position: .te),
                (key: "dl", position: .dl),
                (key: "lb", position: .lb),
                (key: "ss", position: .ss)
            ],
            evidence: [
                (key: "tee", kind: .kickingTee, x: 0.685, y: 0.605, rotation: 10),
                (key: "strap", kind: .chinStrap, x: 0.79, y: 0.615, rotation: -28),
                (key: "divot", kind: .divot, x: 0.725, y: 0.43, rotation: -14),
                (key: "flag", kind: .challengeFlag, x: 0.615, y: 0.30, rotation: 16),
                (key: "board", kind: .markerBoard, x: 0.715, y: 0.245, rotation: -8)
            ],
            slots: [
                (key: "ol-rt", x: 0.70, y: 0.565),
                (key: "te-right", x: 0.775, y: 0.565),
                (key: "de-right", x: 0.72, y: 0.475),
                (key: "lb-right", x: 0.645, y: 0.355),
                (key: "ss-box", x: 0.70, y: 0.27),
                (key: "te-left", x: 0.245, y: 0.565),
                (key: "edge-left", x: 0.165, y: 0.465),
                (key: "box-left", x: 0.30, y: 0.28),
                (key: "slot-right", x: 0.85, y: 0.46),
                (key: "deep-center", x: 0.50, y: 0.115),
                (key: "deep-left", x: 0.27, y: 0.14)
            ],
            clues: [
                (player: "ol", family: .formationKnowledge, difficulty: .easy,
                 text: "Against an all-out attack, the kicking tee in front of the vacant right tackle spot marks the patched wall — a backup, in the biggest moment, asked to be a fortress.",
                 constraints: [.nearEvidence(player: "ol", evidence: "tee", radius: 0.08), .variantIs(player: "ol", variant: .veteran)],
                 evidence: ["tee"]),
                (player: "te", family: .footballResponsibility, difficulty: .medium,
                 text: "The chin strap outside the new tackle marks the second wall: the tight end gives up his route and becomes a guard with longer arms.",
                 constraints: [.nearEvidence(player: "te", evidence: "strap", radius: 0.08), .variantIs(player: "te", variant: .power)],
                 evidence: ["strap"]),
                (player: "dl", family: .scenario, difficulty: .medium,
                 text: "The divot at the right end marks the crunch — the defender the protection fears most, slanting into the seam the patch creates.",
                 constraints: [.nearEvidence(player: "dl", evidence: "divot", radius: 0.08), .variantIs(player: "dl", variant: .power)],
                 evidence: ["divot"]),
                (player: "lb", family: .evidenceRelationship, difficulty: .medium,
                 text: "The challenge flag at the right stack spot marks the A-gap killer — the last unblocked man, arriving through the middle with nothing but bad intentions.",
                 constraints: [.nearEvidence(player: "lb", evidence: "flag", radius: 0.08), .variantIs(player: "lb", variant: .veteran)],
                 evidence: ["flag"]),
                (player: "ss", family: .orderDepth, difficulty: .hard,
                 text: "The marker board at the right box alignment marks the ninth rusher: above the stack backer, below the deep men, the extra body that turns pressure into a landslide.",
                 constraints: [.nearEvidence(player: "ss", evidence: "board", radius: 0.08), .yAbove(a: "ss", b: "lb", gap: 0.05), .variantIs(player: "ss", variant: .power)],
                 evidence: ["board"])
            ],
            hints: [
                (player: "ol", text: "Right tackle spot, still empty — the kicking tee waits in front."),
                (player: "te", text: "The right side's new shoulder to fill — at the chin strap."),
                (player: "dl", text: "Right end, crashing inside — right over the divot."),
                (player: "lb", text: "Right stack spot — at the challenge flag. The A-gap killer."),
                (player: "ss", text: "Right box alignment, above the stack — at the marker board.")
            ],
            solution: [
                (player: "ol", slot: "ol-rt", variant: .veteran),
                (player: "te", slot: "te-right", variant: .power),
                (player: "dl", slot: "de-right", variant: .power),
                (player: "lb", slot: "lb-right", variant: .veteran),
                (player: "ss", slot: "ss-box", variant: .power)
            ]
        ),

        // 46 — The Stand at Midfield (seed 45)
        CaseLibrary.makeCase(
            id: "case_kneel_down_war_06", seed: 45, band: 5,
            title: "The Stand at Midfield",
            heading: "KNEEL-DOWN WAR",
            body: "The other team wants the ball back. The defense refuses to leave the field.",
            visible: Formation.build { b in
                b.line([0.30, 0.40, 0.50, 0.60])
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
                (key: "rb", position: .rb),
                (key: "ol", position: .ol),
                (key: "dl", position: .dl),
                (key: "lb", position: .lb),
                (key: "cb", position: .cb)
            ],
            evidence: [
                (key: "brace", kind: .kneeBrace, x: 0.505, y: 0.835, rotation: -4),
                (key: "tee", kind: .kickingTee, x: 0.71, y: 0.605, rotation: 10),
                (key: "mud", kind: .muddyFootprints, x: 0.585, y: 0.43, rotation: 55),
                (key: "flag", kind: .challengeFlag, x: 0.615, y: 0.30, rotation: 16),
                (key: "stain", kind: .grassStain, x: 0.905, y: 0.395, rotation: 0)
            ],
            slots: [
                (key: "rb-deep", x: 0.50, y: 0.79),
                (key: "ol-rt", x: 0.70, y: 0.565),
                (key: "dt-3tech", x: 0.58, y: 0.475),
                (key: "lb-right", x: 0.655, y: 0.35),
                (key: "cb-right", x: 0.925, y: 0.435),
                (key: "back-left", x: 0.38, y: 0.70),
                (key: "te-left", x: 0.245, y: 0.565),
                (key: "edge-left", x: 0.165, y: 0.465),
                (key: "box-left", x: 0.30, y: 0.28),
                (key: "slot-right", x: 0.83, y: 0.45),
                (key: "deep-center", x: 0.50, y: 0.115)
            ],
            clues: [
                (player: "rb", family: .orderDepth, difficulty: .easy,
                 text: "The knee brace at the deepest backfield spot marks the closer: take the handoff, fall forward, and make the clock the real opponent.",
                 constraints: [.nearEvidence(player: "rb", evidence: "brace", radius: 0.08), .variantIs(player: "rb", variant: .power)],
                 evidence: ["brace"]),
                (player: "ol", family: .footballResponsibility, difficulty: .medium,
                 text: "The kicking tee in front of the vacant right tackle spot marks the finisher up front — zero yards is a win, minus two is a catastrophe.",
                 constraints: [.nearEvidence(player: "ol", evidence: "tee", radius: 0.08), .variantIs(player: "ol", variant: .power)],
                 evidence: ["tee"]),
                (player: "dl", family: .evidenceRelationship, difficulty: .medium,
                 text: "The muddy footprints at the three-technique mark the penetrator — the defender betting everything on splitting the guard and tackle before the ball is even secure.",
                 constraints: [.nearEvidence(player: "dl", evidence: "mud", radius: 0.08), .variantIs(player: "dl", variant: .fast)],
                 evidence: ["mud"]),
                (player: "lb", family: .scenario, difficulty: .hard,
                 text: "The challenge flag at the right stack spot marks the keeper of the pile. Everyone knows where the ball is going; his job is to make sure nobody ever finds out if they were right.",
                 constraints: [.nearEvidence(player: "lb", evidence: "flag", radius: 0.08), .variantIs(player: "lb", variant: .veteran)],
                 evidence: ["flag"]),
                (player: "cb", family: .relativePosition, difficulty: .medium,
                 text: "The grass stain across from the visible right receiver marks the edge contain man. Shallower than the safety, wider than the front — he strkes first and holds the boundary.",
                 constraints: [.nearEvidence(player: "cb", evidence: "stain", radius: 0.08), .variantIs(player: "cb", variant: .veteran)],
                 evidence: ["stain"])
            ],
            hints: [
                (player: "rb", text: "The deepest backfield spot — the knee brace marks it."),
                (player: "ol", text: "The missing right tackle spot — the kicking tee parked ahead of it."),
                (player: "dl", text: "At the three-technique — over the muddy churn, penetrating."),
                (player: "lb", text: "The right stack alignment — where the challenge flag lies."),
                (player: "cb", text: "Right sideline across from the visible receiver — at the grass stain.")
            ],
            solution: [
                (player: "rb", slot: "rb-deep", variant: .power),
                (player: "ol", slot: "ol-rt", variant: .power),
                (player: "dl", slot: "dt-3tech", variant: .fast),
                (player: "lb", slot: "lb-right", variant: .veteran),
                (player: "cb", slot: "cb-right", variant: .veteran)
            ]
        ),

        // 47 — The Deep Crosser (seed 46)
        CaseLibrary.makeCase(
            id: "case_deep_crosser_07", seed: 46, band: 5,
            title: "The Deep Crosser",
            heading: "CROSSING DANGER",
            body: "The most dangerous route in football is crossing the middle. Find everyone it endangers.",
            visible: Formation.build { b in
                b.line([0.30, 0.40, 0.50, 0.60, 0.70])
                b.add(.rb, 0.42, 0.68)
                b.add(.wr, 0.075, 0.53)
                b.front([0.28, 0.42, 0.58, 0.72])
                b.add(.lb, 0.50, 0.36)
                b.add(.lb, 0.34, 0.36)
                b.add(.ss, 0.35, 0.24)
            },
            missing: [
                (key: "qb", position: .qb),
                (key: "wr", position: .wr),
                (key: "te", position: .te),
                (key: "lb", position: .lb),
                (key: "cb", position: .cb),
                (key: "fs", position: .fs)
            ],
            evidence: [
                (key: "ball", kind: .looseFootball, x: 0.545, y: 0.615, rotation: 8),
                (key: "cup", kind: .sportsDrinkCup, x: 0.945, y: 0.565, rotation: 18),
                (key: "strap", kind: .chinStrap, x: 0.79, y: 0.615, rotation: -28),
                (key: "flag", kind: .challengeFlag, x: 0.675, y: 0.315, rotation: 16),
                (key: "stain", kind: .grassStain, x: 0.905, y: 0.395, rotation: 0),
                (key: "wet", kind: .wetPatch, x: 0.48, y: 0.165, rotation: 0)
            ],
            slots: [
                (key: "qb-gun", x: 0.50, y: 0.655),
                (key: "wr-right", x: 0.925, y: 0.52),
                (key: "te-right", x: 0.775, y: 0.565),
                (key: "lb-right", x: 0.66, y: 0.36),
                (key: "cb-right", x: 0.925, y: 0.435),
                (key: "fs-center", x: 0.50, y: 0.13),
                (key: "deep-gun", x: 0.50, y: 0.72),
                (key: "back-right", x: 0.62, y: 0.70),
                (key: "slot-left", x: 0.205, y: 0.525),
                (key: "box-left", x: 0.30, y: 0.28),
                (key: "deep-right", x: 0.70, y: 0.155),
                (key: "edge-right", x: 0.835, y: 0.465)
            ],
            clues: [
                (player: "qb", family: .scenario, difficulty: .easy,
                 text: "The loose football four yards behind the line, dead center, marks the passer in the gun — the man who will throw into the most crowded area of the field and live with it.",
                 constraints: [.nearEvidence(player: "qb", evidence: "ball", radius: 0.08), .variantIs(player: "qb", variant: .fast)],
                 evidence: ["ball"]),
                (player: "wr", family: .relativePosition, difficulty: .medium,
                 text: "The sports drink cup at the far right numbers marks the crosser's start: wider than the tight end below him, deeper than the corner opposite. He runs behind everything toward everything.",
                 constraints: [.nearEvidence(player: "wr", evidence: "cup", radius: 0.08), .variantIs(player: "wr", variant: .veteran)],
                 evidence: ["cup"]),
                (player: "te", family: .footballResponsibility, difficulty: .medium,
                 text: "The chin strap outside the right tackle marks the traffic creator — his only job is to occupy the inside linebacker for one count so the crosser runs free.",
                 constraints: [.nearEvidence(player: "te", evidence: "strap", radius: 0.08), .variantIs(player: "te", variant: .power)],
                 evidence: ["strap"]),
                (player: "lb", family: .profileDeduction, difficulty: .medium,
                 text: "The challenge flag at the right stack spot marks the wall. Against crossing routes, defenders who chase never catch anything — the staff wants the one who plants, holds the wall, and lets the play come to him.",
                 constraints: [.nearEvidence(player: "lb", evidence: "flag", radius: 0.08), .variantIs(player: "lb", variant: .fast)],
                 evidence: ["flag"]),
                (player: "cb", family: .elimination, difficulty: .medium,
                 text: "The grass stain inside the receiver's alignment marks the chase corner. The call sheet says neither the veteran nor the power build — someone has to run with the crosser for forty yards, and only fresh legs can.",
                 constraints: [.nearEvidence(player: "cb", evidence: "stain", radius: 0.08), .variantIsNot(player: "cb", variant: .power), .variantIsNot(player: "cb", variant: .veteran)],
                 evidence: ["stain"]),
                (player: "fs", family: .evidenceRelationship, difficulty: .hard,
                 text: "The wet patch at the very top of the picture, dead center, is the deep-half post. The crosser is designed to vacate his zone the moment he commits — the throw that kills this coverage happens behind him.",
                 constraints: [.nearEvidence(player: "fs", evidence: "wet", radius: 0.08), .variantIs(player: "fs", variant: .veteran)],
                 evidence: ["wet"])
            ],
            hints: [
                (player: "qb", text: "Center of the gun — right at the loose football."),
                (player: "wr", text: "Far right numbers — by the sports drink cup. The crosser's start."),
                (player: "te", text: "Right side, on the tackle's shoulder — at the flung chin strap."),
                (player: "lb", text: "Right stack spot — at the challenge flag. Plant and hold the wall."),
                (player: "cb", text: "Inside the receiver's alignment — at the grass stain. Fresh legs only."),
                (player: "fs", text: "Top center — beside the wet patch. The deep shot is his problem.")
            ],
            solution: [
                (player: "qb", slot: "qb-gun", variant: .fast),
                (player: "wr", slot: "wr-right", variant: .veteran),
                (player: "te", slot: "te-right", variant: .power),
                (player: "lb", slot: "lb-right", variant: .fast),
                (player: "cb", slot: "cb-right", variant: .fast),
                (player: "fs", slot: "fs-center", variant: .veteran)
            ]
        ),

        // 48 — Edge or Die (seed 47)
        CaseLibrary.makeCase(
            id: "case_edge_or_die_08", seed: 47, band: 5,
            title: "Edge or Die",
            heading: "CONTAINMENT CRISIS",
            body: "The quarterback is a runner tonight. Contain him or lose everything.",
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
            },
            missing: [
                (key: "qb", position: .qb),
                (key: "ol", position: .ol),
                (key: "de", position: .dl),
                (key: "ss", position: .ss),
                (key: "fs", position: .fs)
            ],
            evidence: [
                (key: "mud", kind: .muddyFootprints, x: 0.515, y: 0.715, rotation: 55),
                (key: "tee", kind: .kickingTee, x: 0.71, y: 0.605, rotation: 10),
                (key: "strap", kind: .brokenHelmetStrap, x: 0.83, y: 0.51, rotation: -22),
                (key: "strap2", kind: .shoulderPadStrap, x: 0.645, y: 0.335, rotation: -35),
                (key: "bottle", kind: .waterBottle, x: 0.70, y: 0.11, rotation: 68)
            ],
            slots: [
                (key: "qb-gun", x: 0.50, y: 0.655),
                (key: "ol-rt", x: 0.70, y: 0.565),
                (key: "de-edge", x: 0.835, y: 0.465),
                (key: "ss-box", x: 0.66, y: 0.295),
                (key: "fs-deep-right", x: 0.68, y: 0.15),
                (key: "under-center", x: 0.50, y: 0.63),
                (key: "back-left", x: 0.38, y: 0.70),
                (key: "slot-right", x: 0.85, y: 0.42),
                (key: "box-left", x: 0.30, y: 0.28),
                (key: "deep-left", x: 0.27, y: 0.14),
                (key: "deep-center", x: 0.50, y: 0.115)
            ],
            clues: [
                (player: "qb", family: .scenario, difficulty: .easy,
                 text: "The muddy footprints in the gun mark the problem itself: a passer who treats every broken play as a kickoff return. Everything the defense does tonight bends around him.",
                 constraints: [.nearEvidence(player: "qb", evidence: "mud", radius: 0.08), .variantIs(player: "qb", variant: .fast)],
                 evidence: ["mud"]),
                (player: "ol", family: .footballResponsibility, difficulty: .medium,
                 text: "The kicking tee in front of the vacant right tackle spot marks the containment blocker. His job description tonight has one line: nobody gets to the quarterback's blind side.",
                 constraints: [.nearEvidence(player: "ol", evidence: "tee", radius: 0.08), .variantIs(player: "ol", variant: .power)],
                 evidence: ["tee"]),
                (player: "de", family: .evidenceRelationship, difficulty: .medium,
                 text: "The broken helmet strap beyond the tackle marks the edge rusher with the longest night. He cannot just rush — he has to rush under control, or the runner he hunts escapes out his own door.",
                 constraints: [.nearEvidence(player: "de", evidence: "strap", radius: 0.08), .variantIs(player: "de", variant: .fast)],
                 evidence: ["strap"]),
                (player: "ss", family: .orderDepth, difficulty: .medium,
                 text: "The shoulder-pad strap on the right second level marks the force player: below the deep men, above the backers, the first defender the QB sees when the edge breaks.",
                 constraints: [.nearEvidence(player: "ss", evidence: "strap2", radius: 0.08), .yAbove(a: "ss", b: "de", gap: 0.15), .variantIs(player: "ss", variant: .power)],
                 evidence: ["strap2"]),
                (player: "fs", family: .profileDeduction, difficulty: .hard,
                 text: "The water bottle at the top right marks the post half. Against a runner, this is the loneliest job in football: the whole field opens the moment containment fails, and his range is the only fence left standing.",
                 constraints: [.nearEvidence(player: "fs", evidence: "bottle", radius: 0.08), .variantIs(player: "fs", variant: .veteran)],
                 evidence: ["bottle"])
            ],
            hints: [
                (player: "qb", text: "Dead center in the gun — at the muddy footprints. He is the problem."),
                (player: "ol", text: "Right tackle spot, vacant — just before the kicking tee."),
                (player: "de", text: "Right edge — at the broken helmet strap. Rush under control."),
                (player: "ss", text: "Right second level, up the field of the rusher's lane — where the shoulder-pad strap lies."),
                (player: "fs", text: "Top right, single-high — beside the water bottle. Range is the last fence.")
            ],
            solution: [
                (player: "qb", slot: "qb-gun", variant: .fast),
                (player: "ol", slot: "ol-rt", variant: .power),
                (player: "de", slot: "de-edge", variant: .fast),
                (player: "ss", slot: "ss-box", variant: .power),
                (player: "fs", slot: "fs-deep-right", variant: .veteran)
            ]
        ),

        // 49 — Two Points or Nothing (seed 48)
        CaseLibrary.makeCase(
            id: "case_two_point_call_09", seed: 48, band: 5,
            title: "Two Points or Nothing",
            heading: "WIN OR GO HOME",
            body: "The call is in. Two points, one play, no second chances.",
            visible: Formation.build { b in
                b.line([0.30, 0.40, 0.50, 0.60, 0.70])
                b.add(.te, 0.775, 0.565)
                b.add(.wr, 0.075, 0.53)
                b.front([0.28, 0.42, 0.58, 0.72])
                b.add(.lb, 0.50, 0.36)
                b.add(.lb, 0.34, 0.36)
                b.add(.cb, 0.075, 0.435)
                b.add(.ss, 0.66, 0.24)
                b.add(.fs, 0.50, 0.135)
            },
            missing: [
                (key: "qb", position: .qb),
                (key: "rb", position: .rb),
                (key: "wr", position: .wr),
                (key: "cb", position: .cb),
                (key: "lb", position: .lb)
            ],
            evidence: [
                (key: "chalk", kind: .chalkMark, x: 0.49, y: 0.715, rotation: 45),
                (key: "cone", kind: .orangeCone, x: 0.635, y: 0.745, rotation: -10),
                (key: "bottle", kind: .waterBottle, x: 0.955, y: 0.555, rotation: 65),
                (key: "stain", kind: .grassStain, x: 0.905, y: 0.395, rotation: 0),
                (key: "flag", kind: .challengeFlag, x: 0.675, y: 0.315, rotation: 16)
            ],
            slots: [
                (key: "qb-gun", x: 0.50, y: 0.655),
                (key: "rb-right", x: 0.62, y: 0.70),
                (key: "wr-right", x: 0.925, y: 0.52),
                (key: "cb-right", x: 0.925, y: 0.435),
                (key: "lb-right", x: 0.66, y: 0.36),
                (key: "under-center", x: 0.50, y: 0.63),
                (key: "back-left", x: 0.38, y: 0.70),
                (key: "slot-left", x: 0.205, y: 0.525),
                (key: "box-left", x: 0.30, y: 0.28),
                (key: "edge-right", x: 0.835, y: 0.465),
                (key: "deep-right", x: 0.70, y: 0.155)
            ],
            clues: [
                (player: "qb", family: .scenario, difficulty: .easy,
                 text: "The chalk mark in the gun, just right of center, marks the passer on the most-watched snap of the season. One read, one throw, one heartbeat — and a cool head beats a quick trigger.",
                 constraints: [.nearEvidence(player: "qb", evidence: "chalk", radius: 0.08), .variantIs(player: "qb", variant: .veteran)],
                 evidence: ["chalk"]),
                (player: "rb", family: .evidenceRelationship, difficulty: .medium,
                 text: "The orange cone in the right backfield lane marks the swing-threat back: he flares right to drag a defender out of the box, and if nobody follows him, he is the emergency answer.",
                 constraints: [.nearEvidence(player: "rb", evidence: "cone", radius: 0.08), .variantIs(player: "rb", variant: .fast)],
                 evidence: ["cone"]),
                (player: "wr", family: .formationKnowledge, difficulty: .medium,
                 text: "The water bottle at the far right numbers marks the primary — the receiver whose route was drawn in the dirt fifteen years ago and has never lost a game it won. Timeout-proof, forget-proof.",
                 constraints: [.nearEvidence(player: "wr", evidence: "bottle", radius: 0.08), .variantIs(player: "wr", variant: .veteran)],
                 evidence: ["bottle"]),
                (player: "cb", family: .relativePosition, difficulty: .medium,
                 text: "The grass stain inside the primary's alignment marks his shadow. Shallower than the safety, glued to the receiver's hip — wherever the ball goes, he is already on the way.",
                 constraints: [.nearEvidence(player: "cb", evidence: "stain", radius: 0.08), .variantIs(player: "cb", variant: .fast)],
                 evidence: ["stain"]),
                (player: "lb", family: .profileDeduction, difficulty: .hard,
                 text: "The challenge flag at the right stack spot marks the blitz-keeper. Everybody knows where the ball is going; the defense needs the one player strong enough to be there first and end the argument.",
                 constraints: [.nearEvidence(player: "lb", evidence: "flag", radius: 0.08), .variantIs(player: "lb", variant: .power)],
                 evidence: ["flag"])
            ],
            hints: [
                (player: "qb", text: "In the gun, just right of center — at the chalk mark."),
                (player: "rb", text: "Right of the passer in the backfield — at the orange cone."),
                (player: "wr", text: "Far right numbers — by the water bottle. The primary."),
                (player: "cb", text: "Inside the primary's alignment — at the grass stain. Glued to his hip."),
                (player: "lb", text: "Right stack spot — at the challenge flag. Be there first.")
            ],
            solution: [
                (player: "qb", slot: "qb-gun", variant: .veteran),
                (player: "rb", slot: "rb-right", variant: .fast),
                (player: "wr", slot: "wr-right", variant: .veteran),
                (player: "cb", slot: "cb-right", variant: .fast),
                (player: "lb", slot: "lb-right", variant: .power)
            ]
        ),

        // 50 — The Last Read (seed 49)
        CaseLibrary.makeCase(
            id: "case_victory_formation_10", seed: 49, band: 5,
            title: "The Last Read",
            heading: "FINAL SNAP",
            body: "One incomplete read ends the game. One correct read wins it.",
            visible: Formation.build { b in
                b.line([0.30, 0.40, 0.50, 0.60, 0.70])
                b.add(.qb, 0.50, 0.655)
                b.add(.rb, 0.42, 0.68)
                b.add(.wr, 0.075, 0.53)
                b.front([0.28, 0.42, 0.58])
                b.add(.lb, 0.50, 0.36)
                b.add(.lb, 0.34, 0.36)
                b.add(.cb, 0.075, 0.435)
                b.add(.ss, 0.66, 0.24)
            },
            missing: [
                (key: "wr", position: .wr),
                (key: "te", position: .te),
                (key: "dl", position: .dl),
                (key: "cb", position: .cb),
                (key: "fs", position: .fs)
            ],
            evidence: [
                (key: "cup", kind: .sportsDrinkCup, x: 0.945, y: 0.565, rotation: 18),
                (key: "playbook", kind: .wristPlaybook, x: 0.79, y: 0.615, rotation: 12),
                (key: "skid", kind: .skidMarks, x: 0.725, y: 0.435, rotation: 12),
                (key: "stain", kind: .grassStain, x: 0.905, y: 0.395, rotation: 0),
                (key: "wet", kind: .wetPatch, x: 0.48, y: 0.165, rotation: 0)
            ],
            slots: [
                (key: "wr-right", x: 0.925, y: 0.52),
                (key: "te-right", x: 0.775, y: 0.565),
                (key: "de-right", x: 0.72, y: 0.475),
                (key: "cb-right", x: 0.925, y: 0.435),
                (key: "fs-center", x: 0.50, y: 0.13),
                (key: "slot-left", x: 0.205, y: 0.525),
                (key: "edge-left", x: 0.165, y: 0.465),
                (key: "box-right", x: 0.66, y: 0.295),
                (key: "deep-right", x: 0.70, y: 0.155),
                (key: "back-right", x: 0.62, y: 0.70),
                (key: "te-left", x: 0.245, y: 0.565)
            ],
            clues: [
                (player: "te", family: .footballResponsibility, difficulty: .easy,
                 text: "The wrist playbook outside the right tackle marks the keeper: the tight end who holds the edge for exactly as long as the play needs, and not one second longer.",
                 constraints: [.nearEvidence(player: "te", evidence: "playbook", radius: 0.08), .variantIs(player: "te", variant: .power)],
                 evidence: ["playbook"]),
                (player: "wr", family: .relativePosition, difficulty: .medium,
                 text: "The sports drink cup at the far right numbers marks the primary read — wider than the tight end, deeper than the corner, the man the quarterback looks at first and last.",
                 constraints: [.nearEvidence(player: "wr", evidence: "cup", radius: 0.08), .variantIs(player: "wr", variant: .veteran)],
                 evidence: ["cup"]),
                (player: "dl", family: .scenario, difficulty: .medium,
                 text: "The skid marks at the right end mark the closer — the rusher whose entire season is measured in the next two seconds of violence off the edge.",
                 constraints: [.nearEvidence(player: "dl", evidence: "skid", radius: 0.08), .variantIs(player: "dl", variant: .power)],
                 evidence: ["skid"]),
                (player: "cb", family: .elimination, difficulty: .medium,
                 text: "The grass stain across from the primary marks the final island. The call sheet crossed out the power build and the veteran — this match is decided by raw recovery speed or not at all.",
                 constraints: [.nearEvidence(player: "cb", evidence: "stain", radius: 0.08), .variantIsNot(player: "cb", variant: .power), .variantIsNot(player: "cb", variant: .veteran)],
                 evidence: ["stain"]),
                (player: "fs", family: .evidenceRelationship, difficulty: .hard,
                 text: "The wet patch at the very top of the picture, dead center, is the last line — the defender whose read decides whether this case file ends in celebration or a cold case.",
                 constraints: [.nearEvidence(player: "fs", evidence: "wet", radius: 0.08), .variantIs(player: "fs", variant: .veteran)],
                 evidence: ["wet"])
            ],
            hints: [
                (player: "te", text: "Attached right, outside the tackle — beside the wrist playbook."),
                (player: "wr", text: "Far right numbers — by the sports drink cup. The primary read."),
                (player: "dl", text: "Right end — over the skid marks. Two seconds of violence."),
                (player: "cb", text: "Across from the primary — at the grass stain. Wheels only."),
                (player: "fs", text: "Top center — beside the wet patch. The read decides everything.")
            ],
            solution: [
                (player: "wr", slot: "wr-right", variant: .veteran),
                (player: "te", slot: "te-right", variant: .power),
                (player: "dl", slot: "de-right", variant: .power),
                (player: "cb", slot: "cb-right", variant: .fast),
                (player: "fs", slot: "fs-center", variant: .veteran)
            ]
        )
    ]
}

import Foundation

// MARK: - Runtime difficulty adaptation
//
// A case's deduction content is never rewritten — difficulty changes the
// puzzle around it: decoy zones, the missing-player count, hint strength and
// clue presentation. Every structural change (removing or adding slots,
// dropping a player) is re-verified with `CaseSolver`, so an adapted case
// still has exactly one valid solution. Difficulty never buys ambiguity —
// Hall of Famer is harder, not guessier.

nonisolated enum CaseDifficultyAdapter {
    /// Adapts an authored case to the resolved difficulty target. Structural
    /// knobs apply first (so later knobs see the final field shape); present-
    /// ation knobs (clue order, hint text) apply last.
    static func adapt(_ puzzleCase: QuarterCase, to target: DifficultyTarget) -> QuarterCase {
        var adapted = puzzleCase
        adapted = trimMissingPlayers(adapted, to: target.maxMissingPlayers)
        adapted = trimDecoys(adapted, to: target.maxDecoys)
        adapted = addDecoys(adapted, count: target.addedDecoys)
        adapted = reorderClues(adapted, ordering: target.clueOrdering)
        adapted = rewriteHints(adapted, strength: target.hintStrength)
        return adapted
    }

    // MARK: Missing players

    /// Rookie lever: a 5-missing case becomes 4 when one player can be
    /// dropped without breaking the single-solution guarantee. Candidates are
    /// tried in a deterministic order and only accepted when the solver
    /// proves uniqueness — otherwise the authored count stands.
    private static func trimMissingPlayers(_ puzzleCase: QuarterCase, to maxMissing: Int) -> QuarterCase {
        guard puzzleCase.missing.count > maxMissing else { return puzzleCase }

        for candidate in puzzleCase.missing.sorted(by: { $0.key < $1.key }) {
            let keptClues = puzzleCase.clues.filter { $0.playerKey != candidate.key }
            // Remaining clues must not lean on the dropped player's position.
            let referencedElsewhere = keptClues.contains { clue in
                clue.constraints.contains { referencedPlayers(of: $0).contains(candidate.key) }
            }
            guard !referencedElsewhere else { continue }

            let reduced = replacing(
                puzzleCase,
                missing: puzzleCase.missing.filter { $0.key != candidate.key },
                evidence: referencedEvidence(in: puzzleCase, clues: keptClues),
                clues: keptClues,
                hints: puzzleCase.hints.filter { $0.playerKey != candidate.key },
                solution: puzzleCase.solution.filter { $0.playerKey != candidate.key }
            )
            guard CaseSolver.isUnique(reduced) else { continue }
            return reduced
        }
        return puzzleCase
    }

    // MARK: Decoy zones

    /// Fewer decoy locations for approachable tiers. Slots that are not part
    /// of the solution can always be removed — pruning choices can never
    /// break the single-solution guarantee. The most confusable decoys
    /// (nearest to any solution slot) go first, so the ones that remain are
    /// clearly distinct.
    private static func trimDecoys(_ puzzleCase: QuarterCase, to maxDecoys: Int?) -> QuarterCase {
        guard let maxDecoys else { return puzzleCase }
        let solutionSlots = Set(puzzleCase.solution.map(\.slotKey))
        let decoys = puzzleCase.slots.filter { !solutionSlots.contains($0.key) }
        guard decoys.count > maxDecoys else { return puzzleCase }

        let solutionPoints = puzzleCase.solution.compactMap { entry -> (Double, Double)? in
            puzzleCase.slot(withKey: entry.slotKey).map { ($0.x, $0.y) }
        }
        func distanceToSolution(_ slot: CaseSlot) -> Double {
            solutionPoints.map { hypot($0.0 - slot.x, $0.1 - slot.y) }.min() ?? 1
        }
        let remove = Set(
            decoys
                .sorted { lhs, rhs in
                    let dl = distanceToSolution(lhs)
                    let dr = distanceToSolution(rhs)
                    return dl == dr ? lhs.key < rhs.key : dl < dr
                }
                .prefix(decoys.count - maxDecoys)
                .map(\.key)
        )
        return replacing(puzzleCase, slots: puzzleCase.slots.filter { !remove.contains($0.key) })
    }

    /// More decoy locations for tougher tiers. Candidates come from a
    /// deterministic lattice (seeded by the case id), kept clear of existing
    /// slots, visible players and evidence so a decoy never implies a fake
    /// evidence relationship. A candidate is only added when the solver
    /// proves the case still has exactly one solution.
    private static func addDecoys(_ puzzleCase: QuarterCase, count: Int) -> QuarterCase {
        guard count > 0 else { return puzzleCase }
        var slots = puzzleCase.slots
        var added = 0

        for (x, y) in decoyCandidates(for: puzzleCase) where added < count {
            let slot = CaseSlot(key: "decoy-\(added + 1)", x: x, y: y)
            guard !slots.contains(where: { hypot($0.x - x, $0.y - y) < 0.07 }) else { continue }
            let trial = replacing(puzzleCase, slots: slots + [slot])
            guard CaseSolver.isUnique(trial) else { continue }
            slots.append(slot)
            added += 1
        }
        return added == 0 ? puzzleCase : replacing(puzzleCase, slots: slots)
    }

    /// Deterministic, believable decoy positions for one case.
    private static func decoyCandidates(for puzzleCase: QuarterCase) -> [(x: Double, y: Double)] {
        var rng = SeededGenerator(seed: SeededGenerator.hash(["gridiron-decoys", puzzleCase.id]))
        var candidates: [(x: Double, y: Double)] = []
        var y = 0.15
        while y <= 0.8 {
            var x = 0.1
            while x <= 0.9 {
                let jitterX = x + rng.nextDouble() * 0.04 - 0.02
                let jitterY = y + rng.nextDouble() * 0.04 - 0.02
                candidates.append((min(0.93, max(0.07, jitterX)), min(0.82, max(0.12, jitterY))))
                x += 0.09
            }
            y += 0.09
        }
        return candidates.filter { x, y in
            puzzleCase.slots.allSatisfy { hypot($0.x - x, $0.y - y) >= 0.08 }
                && puzzleCase.visible.allSatisfy { hypot($0.x - x, $0.y - y) >= 0.06 }
                && puzzleCase.evidence.allSatisfy { hypot($0.x - x, $0.y - y) >= 0.09 }
        }
    }

    // MARK: Clue presentation

    /// Rookie reads easiest-first (teach the deduction); Hall of Famer reads
    /// hardest-first (the easy entry point is earned). Ordering never touches
    /// the clue set itself, so uniqueness is untouched.
    private static func reorderClues(_ puzzleCase: QuarterCase, ordering: ClueOrdering) -> QuarterCase {
        guard ordering != .authored else { return puzzleCase }

        let sorted = puzzleCase.clues.enumerated()
            .map { (index: $0.offset, clue: $0.element, rank: difficultyRank($0.element.difficulty)) }
            .sorted { lhs, rhs in
                if lhs.rank != rhs.rank {
                    return ordering == .easiestFirst ? lhs.rank < rhs.rank : lhs.rank > rhs.rank
                }
                return lhs.index < rhs.index
            }
            .map(\.clue)
        return replacing(puzzleCase, clues: sorted)
    }

    private static func difficultyRank(_ difficulty: ClueDifficulty) -> Int {
        switch difficulty {
        case .easy: 0
        case .medium: 1
        case .hard: 2
        }
    }

    // MARK: Hint strength

    /// Hint strength is a difficulty knob: Rookie gets generated, geometry-
    /// based guidance; Pro reads the authored hint; All-Pro loses the
    /// giveaway clause; Hall of Famer gets non-directional guidance only.
    private static func rewriteHints(_ puzzleCase: QuarterCase, strength: HintStrength) -> QuarterCase {
        guard strength != .balanced else { return puzzleCase }

        let hints = puzzleCase.hints.enumerated().map { index, hint in
            CaseHint(playerKey: hint.playerKey, text: rewrittenHint(hint, ordinal: index, in: puzzleCase, strength: strength))
        }
        return replacing(puzzleCase, hints: hints)
    }

    private static func rewrittenHint(_ hint: CaseHint, ordinal: Int, in puzzleCase: QuarterCase, strength: HintStrength) -> String {
        switch strength {
        case .balanced:
            hint.text
        case .direct:
            directHint(hint, in: puzzleCase)
        case .subtle:
            subtleHint(hint)
        case .minimal:
            minimalGuidance[ordinal % minimalGuidance.count]
        }
    }

    /// Rookie hints are rebuilt from the solution's geometry: position, side,
    /// depth band and the nearest piece of evidence — still short of the
    /// slot and the profile. "Focus on the RB near the left sideline."
    private static func directHint(_ hint: CaseHint, in puzzleCase: QuarterCase) -> String {
        guard let player = puzzleCase.player(withKey: hint.playerKey),
              let entry = puzzleCase.solution.first(where: { $0.playerKey == hint.playerKey }),
              let slot = puzzleCase.slot(withKey: entry.slotKey) else {
            return hint.text
        }

        let side: String = switch slot.x {
        case ..<0.3: "on the left side"
        case 0.3..<0.7: "through the middle"
        default: "on the right side"
        }
        let depth: String = switch slot.y {
        case ..<0.3: "deep downfield"
        case 0.3..<0.52: "in the second level"
        case 0.52..<0.66: "near the line of scrimmage"
        default: "in the backfield"
        }

        let nearest = puzzleCase.evidence
            .map { ($0, hypot($0.x - slot.x, $0.y - slot.y)) }
            .filter { $0.1 <= 0.12 }
            .min { $0.1 < $1.1 }?.0
        let evidencePhrase = nearest.map { ", right by the \($0.kind.title.lowercased())" } ?? ""

        return "Focus on the \(player.position.fullName) — \(side), \(depth)\(evidencePhrase)."
    }

    /// Authored hints read "direction — the giveaway". All-Pro keeps only
    /// the direction; the giveaway clause is cut.
    private static func subtleHint(_ hint: CaseHint) -> String {
        if let range = hint.text.range(of: " — ") {
            return String(hint.text[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
        }
        if let end = hint.text.firstIndex(of: ".") {
            return String(hint.text[...end])
        }
        return hint.text
    }

    /// Hall of Famer guidance: never names evidence, a side or a position —
    /// only how to think. One entry per player, drawn by ordinal.
    private static let minimalGuidance: [String] = [
        "No shortcuts — let the field's geometry argue the case.",
        "Start from the imbalance and read outward.",
        "The relationships between clues narrow this faster than any single statement.",
        "Count what the formation already proves before touching anything.",
        "Read the evidence relationships against each other, not one at a time.",
    ]

    // MARK: Helpers

    /// Rebuilds the case with any subset of collections replaced.
    private static func replacing(
        _ puzzleCase: QuarterCase,
        missing: [CasePlayer]? = nil,
        evidence: [CaseEvidence]? = nil,
        slots: [CaseSlot]? = nil,
        clues: [CaseClue]? = nil,
        hints: [CaseHint]? = nil,
        solution: [CaseSolution]? = nil
    ) -> QuarterCase {
        QuarterCase(
            id: puzzleCase.id,
            band: puzzleCase.band,
            rosterSeed: puzzleCase.rosterSeed,
            title: puzzleCase.title,
            introHeading: puzzleCase.introHeading,
            introBody: puzzleCase.introBody,
            visible: puzzleCase.visible,
            missing: missing ?? puzzleCase.missing,
            evidence: evidence ?? puzzleCase.evidence,
            slots: slots ?? puzzleCase.slots,
            clues: clues ?? puzzleCase.clues,
            hints: hints ?? puzzleCase.hints,
            solution: solution ?? puzzleCase.solution
        )
    }

    private static func referencedPlayers(of constraint: CaseConstraint) -> [String] {
        switch constraint {
        case .nearEvidence(let player, _, _),
             .nearestToEvidence(let player, _),
             .farthestFromEvidence(let player, _),
             .depthBand(let player, _, _),
             .xBand(let player, _, _),
             .variantIs(let player, _),
             .variantIsNot(let player, _):
            [player]
        case .yAbove(let a, let b, _),
             .yBelow(let a, let b, _),
             .sameSideOfBall(let a, let b),
             .oppositeSideOfBall(let a, let b):
            [a, b]
        }
    }

    /// Evidence still referenced by the kept clues — via their evidence keys
    /// and their constraints — so a dropped player never leaves decorative
    /// objects on the field.
    private static func referencedEvidence(in puzzleCase: QuarterCase, clues: [CaseClue]) -> [CaseEvidence] {
        var referenced: Set<String> = []
        for clue in clues {
            referenced.formUnion(clue.evidenceKeys)
            for constraint in clue.constraints {
                switch constraint {
                case .nearEvidence(_, let key, _),
                     .nearestToEvidence(_, let key),
                     .farthestFromEvidence(_, let key):
                    referenced.insert(key)
                default: break
                }
            }
        }
        return puzzleCase.evidence.filter { referenced.contains($0.key) }
    }
}

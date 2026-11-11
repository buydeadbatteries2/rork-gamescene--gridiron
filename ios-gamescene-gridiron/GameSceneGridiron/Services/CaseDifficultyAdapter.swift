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
    /// Adapts an authored case to the resolved difficulty target. Profile
    /// adaptation applies first (every later knob sees the final profile
    /// pool), then structural knobs (so later knobs see the final field
    /// shape); presentation knobs (clue order, hint text) apply last.
    static func adapt(_ puzzleCase: QuarterCase, to target: DifficultyTarget) -> QuarterCase {
        var adapted = puzzleCase
        adapted = adaptProfiles(adapted, pool: target.profilePool)
        adapted = trimMissingPlayers(adapted, to: target.maxMissingPlayers)
        adapted = trimDecoys(adapted, to: target.maxDecoys)
        adapted = addDecoys(adapted, count: target.addedDecoys)
        adapted = reorderClues(adapted, ordering: target.clueOrdering)
        adapted = rewriteHints(adapted, strength: target.hintStrength)
        let signalTier: DifficultyLevel
        if target.profilePool == PlayerProfile.pool(for: .rookie) { signalTier = .rookie }
        else if target.profilePool == PlayerProfile.pool(for: .pro) { signalTier = .pro }
        else { signalTier = target.tier == .hallOfFamer ? .hallOfFamer : .allPro }
        adapted = replacing(adapted, clues: adapted.clues.enumerated().map { index, clue in
            guard let answer = adapted.solution.first(where: { $0.playerKey == clue.playerKey }) else { return clue }
            return ProfileDialect.addingSignal(to: clue, profile: answer.profile, tier: signalTier,
                                               key: "\(adapted.id)/\(clue.playerKey)/\(index)")
        })
        return adapted
    }

    // MARK: Profile pool adaptation

    /// Remaps every profile requirement onto the difficulty's available pool.
    /// Nothing is merely hidden: the intended answers, the pinning constraints
    /// and the profile-dialect clue text all move together, and the solver
    /// re-verifies uniqueness through the normal validation tests.
    private static func adaptProfiles(_ puzzleCase: QuarterCase, pool: [PlayerProfile]) -> QuarterCase {
        // Preserve the shipped five-answer contract. New profiles pass through.
        guard Set(pool) != Set(PlayerProfile.pool(for: .hallOfFamer)),
              Set(pool) != Set(PlayerProfile.allCases) else { return puzzleCase }

        // New profile per player: identity when the authored profile is
        // available, deterministic remap otherwise.
        var newProfileFor: [String: PlayerProfile] = [:]
        for entry in puzzleCase.solution {
            newProfileFor[entry.playerKey] = ProfilePoolAdapter.remap(entry.profile, into: pool)
        }
        let remappedSolution = puzzleCase.solution.map { entry in
            CaseSolution(
                playerKey: entry.playerKey,
                slotKey: entry.slotKey,
                profile: newProfileFor[entry.playerKey] ?? entry.profile
            )
        }

        // Profiles the case can speak about but the difficulty's pool hides:
        // they must be explicitly excluded per player so the deduction space
        // truly shrinks with the pool ("not the veteran, not the power build"
        // cannot keep pinning an answer once those options are gone).
        let referenced = Set(puzzleCase.clues.flatMap(\.constraints).compactMap { constraint -> PlayerProfile? in
            switch constraint {
            case .profileIs(_, let profile), .profileIsNot(_, let profile): profile
            default: nil
            }
        })
        let caseUniverse = Set([PlayerProfile.fast, .powerful, .veteran]).union(referenced)
        let outOfPool = Set(caseUniverse.filter { ProfilePoolAdapter.remap($0, into: pool) != $0 })
        var exclusionsPerPlayer: [String: [CaseConstraint]] = [:]
        for playerKey in puzzleCase.missing.map(\.key) {
            exclusionsPerPlayer[playerKey] = outOfPool.map { .profileIsNot(player: playerKey, profile: $0) }.sorted { $0.hashValue < $1.hashValue }
        }
        var hasAddedExclusions = Set<String>()

        let remappedClues = puzzleCase.clues.map { clue in
            var addedExclusions = exclusionsPerPlayer[clue.playerKey] ?? []
            if hasAddedExclusions.contains(clue.playerKey) { addedExclusions = [] }
            else if !addedExclusions.isEmpty { hasAddedExclusions.insert(clue.playerKey) }
            let remapped = CaseClue(
                playerKey: clue.playerKey,
                family: clue.family,
                difficulty: clue.difficulty,
                text: adaptedProfileText(
                    clue.profileSignal.map { clue.text.replacingOccurrences(of: $0.phrase, with: "").trimmingCharacters(in: .whitespacesAndNewlines) } ?? clue.text,
                    oldProfile: puzzleCase.solution.first { $0.playerKey == clue.playerKey }?.profile,
                    newProfile: newProfileFor[clue.playerKey],
                    context: profileContext(for: clue, in: puzzleCase)
                ),
                constraints: clue.constraints.map { constraint in
                    switch constraint {
                    case .profileIs(let player, _):
                        guard let newProfile = newProfileFor[player] else { return constraint }
                        return .profileIs(player: player, profile: newProfile)
                    case .profileIsNot(let player, let profile):
                        guard let newProfile = newProfileFor[player] else { return constraint }
                        let mapped = ProfilePoolAdapter.remap(profile, into: pool)
                        // A collapsed mapping can land on the player's own new
                        // answer ("not Fast" where Fast merged into Rookie);
                        // flip it to exclude the pool's other member instead,
                        // which preserves the pin without self-contradiction.
                        if mapped != newProfile {
                            return .profileIsNot(player: player, profile: mapped)
                        }
                        return .profileIsNot(player: player, profile: ProfilePoolAdapter.other(in: pool, of: newProfile))
                    default:
                        return constraint
                    }
                } + addedExclusions,
                evidenceKeys: clue.evidenceKeys
            )
            guard let profile = newProfileFor[clue.playerKey] else { return remapped }
            return ProfileDialect.addingSignal(to: remapped, profile: profile,
                tier: pool == PlayerProfile.pool(for: .rookie) ? .rookie : .pro,
                key: "\(puzzleCase.id)/\(clue.playerKey)")
        }

        return QuarterCase(
            id: puzzleCase.id,
            band: puzzleCase.band,
            rosterSeed: puzzleCase.rosterSeed,
            title: puzzleCase.title,
            introHeading: puzzleCase.introHeading,
            introBody: puzzleCase.introBody,
            visible: puzzleCase.visible,
            missing: puzzleCase.missing,
            evidence: puzzleCase.evidence,
            slots: puzzleCase.slots,
            clues: remappedClues,
            hints: puzzleCase.hints,
            solution: remappedSolution,
            metadata: puzzleCase.metadata
        )
    }

    /// Remapping replaces old prose with a typed spatial context; the new
    /// signal is attached immediately afterward. No regex-only dialect guessing.
    static func adaptedProfileText(
        _ text: String,
        oldProfile: PlayerProfile?,
        newProfile: PlayerProfile?,
        context: String
    ) -> String {
        guard let oldProfile, let newProfile, oldProfile != newProfile else { return text }
        // Rebuild from typed spatial constraints, not keyword deletion. This
        // cannot leave an old profile's synonym behind or erase field evidence.
        return context
    }

    private static func profileContext(for clue: CaseClue, in puzzle: QuarterCase) -> String {
        func player(_ key: String) -> String { puzzle.player(withKey: key)?.position.fullName.lowercased() ?? "other missing player" }
        func evidence(_ key: String) -> String { puzzle.evidence(withKey: key)?.kind.title.lowercased() ?? "marked evidence" }
        let subject = player(clue.playerKey)
        var lines = ["Read the \(subject)'s assignment against the field."]
        for constraint in clue.constraints {
            switch constraint {
            case .nearEvidence(let key, let item, _):
                lines.append("The \(player(key)) belongs beside the \(evidence(item)).")
            case .nearestToEvidence(let key, let item):
                lines.append("Of the missing players, the \(player(key)) is closest to the \(evidence(item)).")
            case .farthestFromEvidence(let key, let item):
                lines.append("Of the missing players, the \(player(key)) is farthest from the \(evidence(item)).")
            case .yAbove(let a, let b, _):
                lines.append("The \(player(a)) stands farther toward the top of the field than the \(player(b)).")
            case .yBelow(let a, let b, _):
                lines.append("The \(player(a)) stands farther toward the bottom of the field than the \(player(b)).")
            case .sameSideOfBall(let a, let b):
                lines.append("The \(player(a)) and \(player(b)) share the same left-or-right half of the field.")
            case .oppositeSideOfBall(let a, let b):
                lines.append("The \(player(a)) and \(player(b)) occupy opposite left-or-right halves of the field.")
            case .depthBand(let key, let low, let high):
                let area = high < 0.3 ? "deep downfield" : low >= 0.6 ? "in the backfield" : "between the deep posts and the backfield"
                lines.append("Look \(area) for the \(player(key)).")
            case .xBand(let key, let low, let high):
                let side = high <= 0.5 ? "left half" : low >= 0.5 ? "right half" : "middle lanes"
                lines.append("The \(player(key)) works the \(side) of the field.")
            case .profileIs, .profileIsNot: break
            }
        }
        return lines.joined(separator: " ")
    }

    /// Implying (never naming) language for a remapped profile.
    static func profileClause(_ profile: PlayerProfile, ordinal: Int) -> String {
        let clauses = ProfileDialect.phrases(profile, tier: .pro)
        return clauses[Int(ordinal.magnitude % UInt(clauses.count))]
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
            solution: solution ?? puzzleCase.solution,
            metadata: puzzleCase.metadata
        )
    }

    private static func referencedPlayers(of constraint: CaseConstraint) -> [String] {
        switch constraint {
        case .nearEvidence(let player, _, _),
             .nearestToEvidence(let player, _),
             .farthestFromEvidence(let player, _),
             .depthBand(let player, _, _),
             .xBand(let player, _, _),
             .profileIs(let player, _),
             .profileIsNot(let player, _):
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

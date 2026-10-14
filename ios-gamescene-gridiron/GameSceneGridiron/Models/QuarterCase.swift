import Foundation

// MARK: - Case authoring model
//
// A `QuarterCase` is one hand-authored case file in the local puzzle library.
// Cases are written with short authoring keys (player, evidence, slot) and are
// converted into the runtime `QuarterPuzzle` by `CaseLibrary`. Every case also
// carries machine-checkable `CaseConstraint`s so tests can prove the written
// clues, evidence and formation produce exactly one valid solution.

/// The ten clue families mixed within every case.
nonisolated enum ClueFamily: String, CaseIterable, Hashable, Sendable {
    case footballResponsibility   // A — describes the job, not the position
    case relativePosition         // B — compared to another player
    case evidenceRelationship     // C — tied to a physical object
    case profileDeduction         // D — profile is the answer
    case elimination              // E — rules options out
    case chainedDeduction         // F — combines two or more statements
    case formationKnowledge       // G — alignment/formation logic
    case scenario                 // H — game situation drives the need
    case negative                 // I — "not here, not that"
    case orderDepth               // J — ordering along the field
}

/// A machine-checkable statement about one candidate placement. All authoring
/// keys resolve inside the owning case. Field coordinates: x 0 = left sideline,
/// 1 = right sideline; y 0 = top of the picture (defense's side), 1 = bottom.
nonisolated enum CaseConstraint: Hashable, Sendable {
    /// Player stands within `radius` of the evidence object.
    case nearEvidence(player: String, evidence: String, radius: Double)
    /// Player is strictly the closest missing player to the evidence object.
    case nearestToEvidence(player: String, evidence: String)
    /// Player is strictly the farthest missing player from the evidence object.
    case farthestFromEvidence(player: String, evidence: String)
    /// Player's depth sits between the two bounds (inclusive).
    case depthBand(player: String, yMin: Double, yMax: Double)
    /// Player's width sits between the two bounds (inclusive).
    case xBand(player: String, xMin: Double, xMax: Double)
    /// Player a sits toward the top of the field (defense's side) of b by at least `gap`.
    case yAbove(a: String, b: String, gap: Double)
    /// Player a sits toward the bottom of the field (offense's side) of b by at least `gap`.
    case yBelow(a: String, b: String, gap: Double)
    /// Both players on the same side of the ball (left/right of x 0.5).
    case sameSideOfBall(a: String, b: String)
    /// Players on opposite sides of the ball.
    case oppositeSideOfBall(a: String, b: String)
    /// Player must be deployed with this profile.
    case profileIs(player: String, profile: PlayerProfile)
    /// Player must NOT be deployed with this profile.
    case profileIsNot(player: String, profile: PlayerProfile)
}

nonisolated struct CasePlayer: Hashable, Sendable {
    let key: String
    let position: FootballPosition
}

nonisolated struct CaseEvidence: Hashable, Sendable {
    let key: String
    let kind: EvidenceItem.Kind
    let x: Double
    let y: Double
    let rotation: Double
}

nonisolated struct CaseSlot: Hashable, Sendable {
    let key: String
    let x: Double
    let y: Double
}

nonisolated struct CaseClue: Hashable, Sendable {
    let playerKey: String
    let family: ClueFamily
    let difficulty: ClueDifficulty
    let text: String
    /// Machine-checkable statements this clue makes. The intended solution
    /// satisfies all of them; together across the case they pin one answer.
    let constraints: [CaseConstraint]
    /// Evidence object keys this clue is about (validated against the case).
    let evidenceKeys: [String]
}

nonisolated struct CaseHint: Hashable, Sendable {
    let playerKey: String
    let text: String
}

nonisolated struct CaseSolution: Hashable, Sendable {
    let playerKey: String
    let slotKey: String
    let profile: PlayerProfile
}

/// One validated case definition in the local library.
// MARK: - Case metadata (Phase 11.6)

/// Authored library metadata for one case. `tier` is the difficulty the case
/// was written for (the primary matchmaking bucket); `difficultyScore` is the
/// 1–100 numeric rating used for fair competitive case assignment;
/// `isCompetitiveEligible` marks cases validated for future ranked play.
nonisolated struct CaseMetadata: Hashable, Sendable {
    /// Authored primary difficulty tier.
    var tier: DifficultyLevel
    /// 1...100 authored difficulty score (competitive matchmaking input).
    var difficultyScore: Int
    /// True when the case is validated for future competitive play: exactly
    /// one solution, no ambiguous clues, supported profiles, a validated
    /// difficulty score and stable deterministic content.
    var isCompetitiveEligible: Bool
}

nonisolated struct QuarterCase: Hashable, Sendable {
    /// Unique id, e.g. "case_trips_coverage_03".
    let id: String
    /// 1...5: which quarter band the case belongs to (5 = overtime).
    let band: Int
    /// Deterministic seed assigning this case's roster names from the shared pool.
    let rosterSeed: Int
    let title: String
    let introHeading: String
    let introBody: String
    let visible: [FieldPlayer]
    let missing: [CasePlayer]
    let evidence: [CaseEvidence]
    let slots: [CaseSlot]
    let clues: [CaseClue]
    let hints: [CaseHint]
    let solution: [CaseSolution]
    /// Authored library metadata. nil only on adapted copies built before the
    /// metadata existed — every `CaseLibrary.all` case carries it.
    var metadata: CaseMetadata?

    var tier: DifficultyLevel? { metadata?.tier }
    var difficultyScore: Int? { metadata?.difficultyScore }
    var isCompetitiveEligible: Bool { metadata?.isCompetitiveEligible ?? true }

    /// The difficulties this case genuinely plays at: the authored case
    /// adapted to each level's profile pool must still solve to exactly one
    /// answer, with every authored solution profile available. Derived — never
    /// assumed — so a case that only works at its own tier reports just that.
    var supportedDifficulties: Set<DifficultyLevel> {
        Set(DifficultyLevel.allCases.filter { level in
            let pool = PlayerProfile.pool(for: level)
            let adapted = CaseDifficultyAdapter.adapt(self, to: DifficultyResolver.target(selected: level, stage: .midSeason))
            return adapted.solution.allSatisfy { pool.contains($0.profile) }
                && CaseSolver.isUnique(adapted)
        })
    }

    func slot(withKey key: String) -> CaseSlot? { slots.first { $0.key == key } }
    func evidence(withKey key: String) -> CaseEvidence? { evidence.first { $0.key == key } }
    func player(withKey key: String) -> CasePlayer? { missing.first { $0.key == key } }
}

// MARK: - Uniqueness solver

/// Brute-force validator for authored cases. Proves the intended solution
/// satisfies every constraint AND that no other assignment of missing players
/// to slots (with any profile choices) satisfies them all.
nonisolated enum CaseSolver {
    struct Diagnosis: Sendable {
        /// Number of valid player→slot assignments (capped for safety).
        let validAssignments: Int
        /// Profiles each player may take under the profile constraints.
        let allowedVariants: [String: Set<PlayerProfile>]
        /// Slots each player may take under their single-player constraints.
        let allowedSlots: [String: Set<String>]
        /// Up to two valid assignments (playerKey → slotKey) for diagnosis.
        let exampleAssignments: [[String: String]]
        /// Constraints the intended solution violates (should always be empty).
        let intendedViolations: [String]

        var totalSolutionCount: Int {
            guard validAssignments > 0 else { return 0 }
            return validAssignments * allowedVariants.values.reduce(1) { $0 * $1.count }
        }

        var isUnique: Bool {
            validAssignments == 1
                && allowedVariants.values.allSatisfy { $0.count == 1 }
                && intendedViolations.isEmpty
        }
    }

    typealias Position = (x: Double, y: Double)

    /// Full diagnostic pass over a case. Runs in well under a millisecond per
    /// case thanks to per-player slot prefiltering.
    static func diagnose(_ puzzleCase: QuarterCase, exampleCap: Int = 2) -> Diagnosis {
        let slotPositions: [String: Position] = Dictionary(
            uniqueKeysWithValues: puzzleCase.slots.map { ($0.key, ($0.x, $0.y)) }
        )
        let evidencePositions: [String: Position] = Dictionary(
            uniqueKeysWithValues: puzzleCase.evidence.map { ($0.key, ($0.x, $0.y)) }
        )
        let playerKeys = puzzleCase.missing.map(\.key)

        var singleConstraints: [String: [CaseConstraint]] = [:]
        var multiConstraints: [CaseConstraint] = []
        var profileConstraints: [String: [CaseConstraint]] = [:]
        for constraint in puzzleCase.clues.flatMap(\.constraints) {
            switch constraint {
            case .profileIs(let player, _), .profileIsNot(let player, _):
                profileConstraints[player, default: []].append(constraint)
            case .nearEvidence, .depthBand, .xBand:
                singleConstraints[subject(of: constraint), default: []].append(constraint)
            default:
                multiConstraints.append(constraint)
            }
        }

        // Per-player profile options. The candidate universe is the legacy
        // three-archetype dialect plus any profile the case explicitly
        // references: older cases that pin by exclusion ("not the veteran,
        // not the power build") must keep reading as a three-option question,
        // while cases that name Rookie/Overrated bring those into play.
        let referencedProfiles = Set(
            puzzleCase.clues.flatMap(\.constraints).compactMap { constraint -> PlayerProfile? in
                switch constraint {
                case .profileIs(_, let profile), .profileIsNot(_, let profile): profile
                default: nil
                }
            }
        )
        let profileUniverse = Set([PlayerProfile.fast, .powerful, .veteran]).union(referencedProfiles)

        var allowedVariants: [String: Set<PlayerProfile>] = [:]
        for key in playerKeys {
            var options = profileUniverse
            for constraint in profileConstraints[key] ?? [] {
                switch constraint {
                case .profileIs(_, let profile): options = [profile]
                case .profileIsNot(_, let profile): options.remove(profile)
                default: break
                }
            }
            allowedVariants[key] = options
        }

        // Per-player slot options from single-player constraints.
        var allowedSlots: [String: Set<String>] = [:]
        for key in playerKeys {
            let constraints = singleConstraints[key] ?? []
            if constraints.isEmpty {
                allowedSlots[key] = Set(puzzleCase.slots.map(\.key))
            } else {
                allowedSlots[key] = Set(
                    puzzleCase.slots
                        .filter { slot in
                            let position: Position = (slot.x, slot.y)
                            return constraints.allSatisfy {
                                isSatisfied($0, subject: key, position: position, evidence: evidencePositions)
                            }
                        }
                        .map(\.key)
                )
            }
        }

        // Intended solution check.
        var intendedViolations: [String] = []
        var intendedAssignment: [String: Position] = [:]
        var intendedVariants: [String: PlayerProfile] = [:]
        for entry in puzzleCase.solution {
            if let slot = puzzleCase.slot(withKey: entry.slotKey) {
                intendedAssignment[entry.playerKey] = (slot.x, slot.y)
            }
            intendedVariants[entry.playerKey] = entry.profile
        }
        let allConstraints = puzzleCase.clues.flatMap(\.constraints)
        for constraint in allConstraints {
            if !isSatisfied(constraint, assignment: intendedAssignment, variants: intendedVariants, evidence: evidencePositions) {
                intendedViolations.append(String(describing: constraint))
            }
        }
        for entry in puzzleCase.solution where allowedVariants[entry.playerKey]?.contains(entry.profile) != true {
            intendedViolations.append("profile not allowed for \(entry.playerKey)")
        }
        for entry in puzzleCase.solution
        where allowedSlots[entry.playerKey]?.contains(entry.slotKey) != true {
            intendedViolations.append("slot not allowed for \(entry.playerKey)")
        }

        // Brute-force all assignments with pruning.
        var validCount = 0
        var examples: [[String: String]] = []
        let orderedKeys = playerKeys.sorted()

        func assign(_ index: Int, used: Set<String>, current: [String: String]) {
            guard validCount < 10_000 else { return }
            if index == orderedKeys.count {
                var assignment: [String: Position] = [:]
                for (key, slotKey) in current {
                    if let slot = slotPositions[slotKey] { assignment[key] = slot }
                }
                if multiConstraints.allSatisfy({ isSatisfied($0, assignment: assignment, variants: [:], evidence: evidencePositions) }) {
                    validCount += 1
                    if examples.count < exampleCap { examples.append(current) }
                }
                return
            }
            let key = orderedKeys[index]
            for slotKey in allowedSlots[key] ?? [] where !used.contains(slotKey) {
                var next = current
                next[key] = slotKey
                // Prune with any multi constraints now fully assigned.
                var slotAssignment: [String: Position] = [:]
                for (assignedKey, assignedSlot) in next {
                    if let slot = slotPositions[assignedSlot] { slotAssignment[assignedKey] = slot }
                }
                let checkable = multiConstraints.filter { constraint in
                    referencedPlayers(of: constraint).allSatisfy { next[$0] != nil }
                }
                if checkable.allSatisfy({ isSatisfied($0, assignment: slotAssignment, variants: [:], evidence: evidencePositions) }) {
                    assign(index + 1, used: used.union([slotKey]), current: next)
                }
            }
        }
        assign(0, used: [], current: [:])

        return Diagnosis(
            validAssignments: validCount,
            allowedVariants: allowedVariants,
            allowedSlots: allowedSlots,
            exampleAssignments: examples,
            intendedViolations: intendedViolations
        )
    }

    /// True when the case's clues, evidence, formation and profile information
    /// produce exactly one valid solution: the intended one.
    static func isUnique(_ puzzleCase: QuarterCase) -> Bool {
        diagnose(puzzleCase).isUnique
    }

    // MARK: Constraint evaluation

    static func isSatisfied(
        _ constraint: CaseConstraint,
        assignment: [String: Position],
        variants: [String: PlayerProfile],
        evidence: [String: Position]
    ) -> Bool {
        func position(_ key: String) -> Position? { assignment[key] }
        switch constraint {
        case .nearEvidence(let player, let evidenceKey, let radius):
            guard let p = position(player), let e = evidence[evidenceKey] else { return false }
            return distance(p, e) <= radius
        case .nearestToEvidence(let player, let evidenceKey):
            guard let p = position(player), let e = evidence[evidenceKey] else { return false }
            return assignment.allSatisfy { key, q in
                key == player || distance(p, e) < distance(q, e)
            }
        case .farthestFromEvidence(let player, let evidenceKey):
            guard let p = position(player), let e = evidence[evidenceKey] else { return false }
            return assignment.allSatisfy { key, q in
                key == player || distance(p, e) > distance(q, e)
            }
        case .depthBand(let player, let yMin, let yMax):
            guard let p = position(player) else { return false }
            return p.y >= yMin && p.y <= yMax
        case .xBand(let player, let xMin, let xMax):
            guard let p = position(player) else { return false }
            return p.x >= xMin && p.x <= xMax
        case .yAbove(let a, let b, let gap):
            guard let pa = position(a), let pb = position(b) else { return false }
            return pa.y <= pb.y - gap
        case .yBelow(let a, let b, let gap):
            guard let pa = position(a), let pb = position(b) else { return false }
            return pa.y >= pb.y + gap
        case .sameSideOfBall(let a, let b):
            guard let pa = position(a), let pb = position(b) else { return false }
            return (pa.x < 0.5) == (pb.x < 0.5)
        case .oppositeSideOfBall(let a, let b):
            guard let pa = position(a), let pb = position(b) else { return false }
            return (pa.x < 0.5) != (pb.x < 0.5)
        case .profileIs(let player, let profile):
            return variants[player] == profile
        case .profileIsNot(let player, let profile):
            guard let chosen = variants[player] else { return true }
            return chosen != profile
        }
    }

    /// Single-player positional variant used during slot prefiltering.
    private static func isSatisfied(
        _ constraint: CaseConstraint,
        subject: String,
        position: Position,
        evidence: [String: Position]
    ) -> Bool {
        switch constraint {
        case .nearEvidence(_, let evidenceKey, let radius):
            guard let e = evidence[evidenceKey] else { return false }
            return distance(position, e) <= radius
        case .depthBand(_, let yMin, let yMax):
            return position.y >= yMin && position.y <= yMax
        case .xBand(_, let xMin, let xMax):
            return position.x >= xMin && position.x <= xMax
        default:
            return true
        }
    }

    private static func subject(of constraint: CaseConstraint) -> String {
        switch constraint {
        case .nearEvidence(let player, _, _),
             .depthBand(let player, _, _),
             .xBand(let player, _, _):
            player
        default:
            ""
        }
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

    private static func distance(_ a: Position, _ b: Position) -> Double {
        sqrt((a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y))
    }
}

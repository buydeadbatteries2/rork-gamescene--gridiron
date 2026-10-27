import Foundation

// MARK: - Phase 14A — calibrated competitive difficulty score

/// The ONE model that turns a case's authored content into its 1–100
/// competitive difficulty score. Every library case carries the result as an
/// explicit `difficultyScore:` (written by scripts/calibrate_case_difficulty.py,
/// an exact port of this type in scripts/case_difficulty_features.py), and
/// `Phase14ACalibrationTests` recomputes it here and fails on any drift — no
/// case can hold a placeholder, default or hand-guessed score.
///
/// Score = tier floor + tier span × content complexity, where the tier sets
/// the sanity band (the profile pool and assist level of the tier) and the
/// authored content places the case inside it:
///   * missing players, decoy zones, evidence objects
///   * clue complexity (difficulty mix + chained/order/negative families)
///   * share of hard clues, chained deductions, negative deductions
///     (negative/elimination families or `profileIsNot` constraints) and
///     relational clues (relative-position/order families or any two-player
///     constraint)
///   * profile load: distinct solution profiles relative to the tier's pool
///   * Hall of Famer only: 40-second play-clock pressure (more placements
///     under the clock)
nonisolated enum CaseDifficultyCalibration {
    static let bandFloor: [DifficultyLevel: Double] = [.rookie: 10, .pro: 30, .allPro: 50, .hallOfFamer: 70]
    static let bandSpan: [DifficultyLevel: Double] = [.rookie: 25, .pro: 25, .allPro: 25, .hallOfFamer: 30]

    /// Validation guidance bands (inclusive) — every calibrated score lands
    /// inside its tier's band by construction; the tests prove it.
    static let sanityBand: [DifficultyLevel: ClosedRange<Int>] = [
        .rookie: 10...35, .pro: 30...55, .allPro: 50...75, .hallOfFamer: 70...100,
    ]

    struct Features: Hashable, Sendable {
        let missing: Int
        let decoys: Int
        let evidence: Int
        let clueComplexity: Double
        let hardShare: Double
        let chainedShare: Double
        let negativeShare: Double
        let relationalShare: Double
        let distinctProfiles: Int
    }

    static func features(of puzzleCase: QuarterCase) -> Features {
        let clues = puzzleCase.clues
        let n = Double(max(1, clues.count))
        var complexity = 0.0
        var hard = 0, chained = 0, negative = 0, relational = 0
        for clue in clues {
            var s: Double = switch clue.difficulty {
            case .easy: 0.2
            case .medium: 0.5
            case .hard: 1.0
            }
            let bonus: Double = switch clue.family {
            case .chainedDeduction: 0.3
            case .orderDepth: 0.15
            case .negative, .elimination: 0.1
            default: 0.0
            }
            s = min(1.0, s + bonus)
            complexity += s
            if clue.difficulty == .hard { hard += 1 }
            if clue.family == .chainedDeduction { chained += 1 }
            if clue.family == .negative || clue.family == .elimination
                || clue.constraints.contains(where: \.isNegativeProfile) {
                negative += 1
            }
            if clue.family == .relativePosition || clue.family == .orderDepth
                || clue.constraints.contains(where: \.isTwoPlayer) {
                relational += 1
            }
        }
        return Features(
            missing: puzzleCase.missing.count,
            decoys: puzzleCase.slots.count - puzzleCase.solution.count,
            evidence: puzzleCase.evidence.count,
            clueComplexity: complexity / n,
            hardShare: Double(hard) / n,
            chainedShare: Double(chained) / n,
            negativeShare: Double(negative) / n,
            relationalShare: Double(relational) / n,
            distinctProfiles: Set(puzzleCase.solution.map(\.profile)).count
        )
    }

    private static func clamp01(_ x: Double) -> Double { min(1.0, max(0.0, x)) }

    /// 0…1 authored-content complexity. Normalizers span the library's
    /// authoring envelope; fixed constants, so adding a case never moves
    /// another case's score.
    static func contentComplexity(_ f: Features, tier: DifficultyLevel) -> Double {
        let pool = PlayerProfile.pool(for: tier).count
        return clamp01(
            0.22 * clamp01(Double(f.missing - 4) / 2)
                + 0.14 * clamp01(Double(f.decoys - 4) / 3)
                + 0.06 * clamp01(Double(f.evidence - 4) / 2)
                + 0.20 * clamp01((f.clueComplexity - 0.5) / 0.25)
                + 0.10 * clamp01((f.hardShare - 0.1) / 0.4)
                + 0.08 * clamp01(f.chainedShare / 0.25)
                + 0.07 * clamp01(f.negativeShare / 0.25)
                + 0.07 * clamp01(f.relationalShare / 0.5)
                + 0.06 * clamp01(Double(f.distinctProfiles - 1) / Double(max(1, pool - 1)))
        )
    }

    static func timerPressure(_ f: Features, tier: DifficultyLevel) -> Double {
        guard tier == .hallOfFamer else { return 0 }
        return clamp01(Double(f.missing - 4) / 2)
    }

    static func score(of puzzleCase: QuarterCase, tier: DifficultyLevel) -> Int {
        let f = features(of: puzzleCase)
        let cc = contentComplexity(f, tier: tier)
        let blended = tier == .hallOfFamer ? 0.8 * cc + 0.2 * timerPressure(f, tier: tier) : cc
        let raw = (bandFloor[tier] ?? 0) + (bandSpan[tier] ?? 0) * blended
        // Half away from zero — matches the export script's int(raw + 0.5).
        return max(1, min(100, Int((raw + 0.5).rounded(.down))))
    }
}

private extension CaseConstraint {
    var isNegativeProfile: Bool {
        if case .profileIsNot = self { return true }
        return false
    }

    var isTwoPlayer: Bool {
        switch self {
        case .yAbove, .yBelow, .sameSideOfBall, .oppositeSideOfBall: true
        default: false
        }
    }
}

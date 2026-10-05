import Foundation

// MARK: - Case difficulty tags

/// Difficulty tags for the case library: Easy / Moderate / Hard / Expert.
/// Deriving them from real case content (never hand-waved) keeps the
/// difficulty-ordered schedule honest.
nonisolated enum CaseDifficultyTag: String, Hashable, Sendable, CaseIterable {
    case easy
    case moderate
    case hard
    case expert

    var title: String { rawValue.uppercased() }
}

// MARK: - Case difficulty profile

/// Machine-readable difficulty metadata for one authored case, computed from
/// its real content: missing players, decoy zones, clue families, clue
/// difficulty mix and hint directness. Drives both the difficulty-ordered
/// season schedule and the runtime adaptation targets.
nonisolated struct CaseDifficultyProfile: Hashable, Sendable {
    let missingPlayerCount: Int
    let decoyCount: Int
    let evidenceCount: Int
    let directClueCount: Int
    let chainedClueCount: Int
    let negativeClueCount: Int
    /// 0...1 — how much the clue set leans on chained/hard reasoning.
    let clueComplexity: Double
    /// 0...1 — how directly the authored hints point at answers (1 = very).
    let hintDirectness: Double
    /// 0...1 blended difficulty of the whole case.
    let rating: Double
    let tag: CaseDifficultyTag

    init(of puzzleCase: QuarterCase) {
        missingPlayerCount = puzzleCase.missing.count
        decoyCount = puzzleCase.slots.count - puzzleCase.solution.count
        evidenceCount = puzzleCase.evidence.count
        directClueCount = puzzleCase.clues.filter { $0.difficulty == .easy }.count
        chainedClueCount = puzzleCase.clues.filter { $0.family == .chainedDeduction }.count
        negativeClueCount = puzzleCase.clues.filter { $0.family == .negative || $0.family == .elimination }.count

        // Clue complexity: hard clues weigh most; chained/negative/order
        // families add reasoning load on top of their base difficulty.
        var complexityTotal = 0.0
        for clue in puzzleCase.clues {
            var score = switch clue.difficulty {
            case .easy: 0.2
            case .medium: 0.5
            case .hard: 1.0
            }
            switch clue.family {
            case .chainedDeduction: score = min(1, score + 0.3)
            case .orderDepth: score = min(1, score + 0.15)
            case .negative, .elimination: score = min(1, score + 0.1)
            default: break
            }
            complexityTotal += score
        }
        clueComplexity = puzzleCase.clues.isEmpty ? 0 : complexityTotal / Double(puzzleCase.clues.count)

        // Directness: hints that name an evidence object or a field area give
        // the most away.
        var hintTotal = 0.0
        for hint in puzzleCase.hints {
            let text = hint.text.lowercased()
            var score = 0.4
            if puzzleCase.evidence.contains(where: { text.contains($0.kind.title.lowercased()) }) {
                score += 0.4
            }
            if text.contains("sideline") || text.contains("left") || text.contains("right") || text.contains("center") {
                score += 0.2
            }
            hintTotal += min(1, score)
        }
        hintDirectness = puzzleCase.hints.isEmpty ? 0 : hintTotal / Double(puzzleCase.hints.count)

        let clueCount = max(1, puzzleCase.clues.count)
        let normalizedMissing = min(1, max(0, Double(missingPlayerCount - 3) / 3))
        let normalizedDecoys = min(1, Double(decoyCount) / 5)
        let normalizedEvidence = min(1, max(0, Double(evidenceCount - 3) / 3))
        let hardShare = Double(puzzleCase.clues.filter { $0.difficulty == .hard }.count) / Double(clueCount)
        let negativeShare = Double(negativeClueCount) / Double(clueCount)

        rating = min(1, max(0,
            0.25 * normalizedMissing
                + 0.18 * normalizedDecoys
                + 0.24 * clueComplexity
                + 0.13 * hardShare
                + 0.10 * negativeShare
                + 0.05 * normalizedEvidence
                + 0.05 * (1 - hintDirectness)
        ))

        tag = switch rating {
        case ..<0.3: .easy
        case ..<0.5: .moderate
        case ..<0.7: .hard
        default: .expert
        }
    }
}

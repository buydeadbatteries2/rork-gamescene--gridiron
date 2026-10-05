import Foundation

// MARK: - User difficulty levels

/// The four difficulty modes. The player picks one when starting a season and
/// can change it later in Settings; the selection persists locally and
/// combines with the season stage to resolve the effective difficulty of
/// every game.
nonisolated enum DifficultyLevel: String, Codable, CaseIterable, Hashable, Sendable, Comparable {
    case rookie
    case pro
    case allPro
    case hallOfFamer

    var title: String {
        switch self {
        case .rookie: "ROOKIE"
        case .pro: "PRO"
        case .allPro: "ALL-PRO"
        case .hallOfFamer: "HALL OF FAMER"
        }
    }

    /// One-line card copy for the selection screen.
    var blurb: String {
        switch self {
        case .rookie: "More guidance. Fewer missing players. Stronger hints."
        case .pro: "Balanced GameScene experience."
        case .allPro: "More complex clues and tougher deductions."
        case .hallOfFamer: "Maximum deduction challenge."
        }
    }

    /// Short description for Settings.
    var summary: String {
        switch self {
        case .rookie: "Welcoming — direct clues, strong hints, fewer decoys."
        case .pro: "The intended standard experience."
        case .allPro: "Subtle clues, extra decoys, chained deductions."
        case .hallOfFamer: "Elite — minimal hints, maximum decoys, no guessing."
        }
    }

    /// Base difficulty on the 0...3.5 effective scale, before stage offsets.
    var baseRating: Double {
        switch self {
        case .rookie: 0.4
        case .pro: 1.4
        case .allPro: 2.4
        case .hallOfFamer: 3.1
        }
    }

    /// PRO is the recommended default — shown with a stamp on the cards.
    var isRecommended: Bool { self == .pro }

    private var sortOrder: Int {
        switch self {
        case .rookie: 0
        case .pro: 1
        case .allPro: 2
        case .hallOfFamer: 3
        }
    }

    static func < (lhs: DifficultyLevel, rhs: DifficultyLevel) -> Bool {
        lhs.sortOrder < rhs.sortOrder
    }
}

// MARK: - Season stage

/// Where a game sits in the season's difficulty ramp. The regular season
/// ramps smoothly (games 1–3 are intentionally friendly teaching games, 9–10
/// are very challenging); the postseason is a genuine step up and the
/// championship is the hardest standard content.
nonisolated enum SeasonStage: String, CaseIterable, Hashable, Sendable {
    case earlyGames      // weeks 1–3
    case midSeason       // weeks 4–6
    case lateSeason      // weeks 7–8
    case finalStretch    // weeks 9–10
    case playoffs        // week 11 — semifinal
    case championship    // week 12 — the final

    static func forWeek(_ week: Int) -> SeasonStage {
        switch week {
        case 1...3: .earlyGames
        case 4...6: .midSeason
        case 7...8: .lateSeason
        case 9...10: .finalStretch
        case 11: .playoffs
        default: .championship
        }
    }

    /// Added to the selected level's base rating. Adjacent stages never
    /// differ by more than half a tier — the ramp is smooth by construction.
    var difficultyOffset: Double {
        switch self {
        case .earlyGames: -0.55
        case .midSeason: 0
        case .lateSeason: 0.35
        case .finalStretch: 0.6
        case .playoffs: 0.75
        case .championship: 0.9
        }
    }

    var label: String {
        switch self {
        case .earlyGames: "GAMES 1–3"
        case .midSeason: "GAMES 4–6"
        case .lateSeason: "GAMES 7–8"
        case .finalStretch: "GAMES 9–10"
        case .playoffs: "PLAYOFFS"
        case .championship: "CHAMPIONSHIP"
        }
    }
}

// MARK: - Difficulty knobs

/// How strongly the hint button guides. Direct hints name the position, area
/// and nearest evidence; minimal hints never get closer than the field's
/// balance. Hints never state the answer or the exact slot.
nonisolated enum HintStrength: String, Hashable, Sendable {
    case direct      // Rookie — generated from the solution's geometry
    case balanced    // Pro — the case's authored hint
    case subtle      // All-Pro — the authored hint without its giveaway clause
    case minimal     // Hall of Famer — non-directional guidance only
}

/// Whether clues are presented easiest-first, as authored, or hardest-first.
nonisolated enum ClueOrdering: String, Hashable, Sendable {
    case easiestFirst   // Rookie — teach the read
    case authored       // Pro / All-Pro
    case hardestFirst   // Hall of Famer — the easy entry point is earned
}

/// The concrete per-puzzle knobs resolved from (selected level, season
/// stage). Difficulty changes the puzzle itself — never just lives or hints.
nonisolated struct DifficultyTarget: Hashable, Sendable {
    nonisolated enum Tier: String, Hashable, Sendable {
        case rookie
        case pro
        case allPro
        case hallOfFamer
    }

    let tier: Tier
    let hintStrength: HintStrength
    let clueOrdering: ClueOrdering
    /// Decoy slots are pruned down to this cap when set (Rookie).
    let maxDecoys: Int?
    /// Extra decoys to add where the solver confirms uniqueness (All-Pro +1,
    /// Hall of Famer +2).
    let addedDecoys: Int
    /// Missing players are trimmed down to this cap (Rookie trims 5 → 4 when
    /// the solver allows).
    let maxMissingPlayers: Int
    /// Effective rating 0...3.5 this target was resolved from.
    let rating: Double
}

// MARK: - Resolver

/// Combines the user's selected difficulty with the season stage into a
/// single effective rating, then maps that rating onto concrete puzzle knobs.
nonisolated enum DifficultyResolver {
    /// Effective ratings clamp to this scale; Hall of Famer playoffs land here.
    static let maxRating = 3.5

    /// Rookie + Games 1–3 → 0 (very approachable) … Hall of Famer +
    /// Championship → 3.5 (elite). Selected level sets the base, the season
    /// stage shifts it.
    static func effectiveRating(selected: DifficultyLevel, stage: SeasonStage) -> Double {
        min(maxRating, max(0, selected.baseRating + stage.difficultyOffset))
    }

    static func target(selected: DifficultyLevel, stage: SeasonStage) -> DifficultyTarget {
        target(forRating: effectiveRating(selected: selected, stage: stage))
    }

    /// Maps the effective rating onto concrete puzzle knobs:
    /// - Rookie   (<1.0): few decoys, fewer players, direct hints, easy-first
    /// - Pro   (1.0..<2.0): the authored case, as written
    /// - All-Pro (2.0..<3.0): +1 verified decoy, hints lose their giveaway
    /// - Hall of Famer (≥3.0): +2 verified decoys, minimal hints, hard-first
    static func target(forRating rating: Double) -> DifficultyTarget {
        switch rating {
        case ..<1.0:
            DifficultyTarget(
                tier: .rookie, hintStrength: .direct, clueOrdering: .easiestFirst,
                maxDecoys: 2, addedDecoys: 0, maxMissingPlayers: 4, rating: rating
            )
        case ..<2.0:
            DifficultyTarget(
                tier: .pro, hintStrength: .balanced, clueOrdering: .authored,
                maxDecoys: nil, addedDecoys: 0, maxMissingPlayers: .max, rating: rating
            )
        case ..<3.0:
            DifficultyTarget(
                tier: .allPro, hintStrength: .subtle, clueOrdering: .authored,
                maxDecoys: nil, addedDecoys: 1, maxMissingPlayers: .max, rating: rating
            )
        default:
            DifficultyTarget(
                tier: .hallOfFamer, hintStrength: .minimal, clueOrdering: .hardestFirst,
                maxDecoys: nil, addedDecoys: 2, maxMissingPlayers: .max, rating: rating
            )
        }
    }
}

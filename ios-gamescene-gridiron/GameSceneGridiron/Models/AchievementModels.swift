import Foundation

// MARK: - Categories

/// The seven achievement drawers in the case cabinet. Each groups achievements
/// by the kind of accomplishment it recognizes.
nonisolated enum AchievementCategory: String, Codable, Hashable, Sendable, CaseIterable {
    case gameplay
    case deduction
    case season
    case postseason
    case player
    case franchise
    case difficulty

    var displayName: String {
        switch self {
        case .gameplay: "GAMEPLAY"
        case .deduction: "DEDUCTION"
        case .season: "SEASON"
        case .postseason: "POSTSEASON"
        case .player: "PLAYER"
        case .franchise: "FRANCHISE"
        case .difficulty: "DIFFICULTY"
        }
    }

    var symbol: String {
        switch self {
        case .gameplay: "sportscourt.fill"
        case .deduction: "magnifyingglass"
        case .season: "calendar"
        case .postseason: "trophy.fill"
        case .player: "person.fill"
        case .franchise: "building.columns.fill"
        case .difficulty: "shield.fill"
        }
    }
}

// MARK: - IDs

/// Stable identifiers for every achievement. Raw values persist — never rename.
nonisolated enum AchievementID: String, Codable, Hashable, Sendable, CaseIterable {
    // Gameplay
    case firstCase
    case cleanRead
    case noHelpNeeded
    case perfectGame
    case clutch
    case comebackCase
    case perfectEvidence
    // Deduction
    case fieldInvestigator
    case caseSpecialist
    case masterInvestigator
    case ironMind
    case coldCase
    // Season
    case winningSeason
    case undefeated
    case backToBack
    case dynasty
    // Postseason
    case playoffBound
    case finalFour
    case caseClosed
    // Difficulty
    case proven
    case allProMaterial
    case eliteRead
    case hallWorthy
    // Player
    case ballHawk
    case sackSpecialist
    case tackleMachine
    case goToTarget
    case gameChanger
    case franchiseIcon
    // Franchise
    case hotStreak
    case ironFranchise
}

// MARK: - Achievement

/// One achievement definition: what it takes, where it files and what it pays.
/// `goal == nil` marks a one-shot milestone; otherwise the value is the
/// progress target shown as "73 / 100 Cases".
nonisolated struct Achievement: Hashable, Sendable, Identifiable {
    let id: AchievementID
    let category: AchievementCategory
    let name: String
    let detail: String
    let symbol: String
    /// Progress target, or nil for a one-shot achievement.
    let goal: Int?
    /// One-time Game Ball reward. Zero for most achievements — recognition,
    /// never a gameplay advantage (see DESIGN.md, Phase 10).
    let reward: Int

    var idString: String { id.rawValue }
}

// MARK: - Catalog

/// The full achievement catalog, grouped by category for presentation and
/// event evaluation. Values here are the single source of truth.
nonisolated enum AchievementCatalog {
    static let all: [Achievement] = [
        // MARK: Gameplay
        Achievement(
            id: .firstCase, category: .gameplay, name: "FIRST CASE",
            detail: "Solve your first quarter.",
            symbol: "magnifyingglass", goal: nil, reward: EconomyConfig.standard.achievementRewardFirstCase
        ),
        Achievement(
            id: .cleanRead, category: .gameplay, name: "CLEAN READ",
            detail: "Solve a quarter without losing a heart.",
            symbol: "heart.fill", goal: nil, reward: 0
        ),
        Achievement(
            id: .noHelpNeeded, category: .gameplay, name: "NO HELP NEEDED",
            detail: "Solve a quarter without using a hint.",
            symbol: "lightbulb.slash", goal: nil, reward: 0
        ),
        Achievement(
            id: .perfectGame, category: .gameplay, name: "PERFECT GAME",
            detail: "Solve all four regulation quarters.",
            symbol: "seal.fill", goal: nil, reward: EconomyConfig.standard.achievementRewardPerfectGame
        ),
        Achievement(
            id: .clutch, category: .gameplay, name: "CLUTCH",
            detail: "Win an overtime case.",
            symbol: "bolt.fill", goal: nil, reward: 0
        ),
        Achievement(
            id: .comebackCase, category: .gameplay, name: "COMEBACK CASE",
            detail: "Enter Q4 down 1–2, force overtime, then win it.",
            symbol: "arrow.uturn.up", goal: nil, reward: 0
        ),
        Achievement(
            id: .perfectEvidence, category: .gameplay, name: "PERFECT EVIDENCE",
            detail: "Complete an entire game without a wrong placement.",
            symbol: "checkmark.seal.fill", goal: nil, reward: 0
        ),
        // MARK: Deduction
        Achievement(
            id: .fieldInvestigator, category: .deduction, name: "FIELD INVESTIGATOR",
            detail: "Solve 25 cases.",
            symbol: "folder.fill", goal: 25, reward: 0
        ),
        Achievement(
            id: .caseSpecialist, category: .deduction, name: "CASE SPECIALIST",
            detail: "Solve 100 cases.",
            symbol: "archivebox.fill", goal: 100, reward: 0
        ),
        Achievement(
            id: .masterInvestigator, category: .deduction, name: "MASTER INVESTIGATOR",
            detail: "Solve 250 cases.",
            symbol: "brain.head.profile", goal: 250, reward: 0
        ),
        Achievement(
            id: .ironMind, category: .deduction, name: "IRON MIND",
            detail: "Solve 500 cases.",
            symbol: "brain", goal: 500, reward: 0
        ),
        Achievement(
            id: .coldCase, category: .deduction, name: "COLD CASE",
            detail: "Solve a Hall of Famer quarter without using a hint.",
            symbol: "snowflake", goal: nil, reward: 0
        ),
        // MARK: Season
        Achievement(
            id: .winningSeason, category: .season, name: "WINNING SEASON",
            detail: "Finish a season above .500.",
            symbol: "chart.line.uptrend.xyaxis", goal: nil, reward: 0
        ),
        Achievement(
            id: .undefeated, category: .season, name: "UNDEFEATED",
            detail: "Finish the 10-game regular season 10–0.",
            symbol: "flag.checkered", goal: nil, reward: EconomyConfig.standard.achievementRewardUndefeated
        ),
        Achievement(
            id: .backToBack, category: .season, name: "BACK TO BACK",
            detail: "Win championships in consecutive seasons.",
            symbol: "rectangle.stack.fill", goal: nil, reward: 0
        ),
        Achievement(
            id: .dynasty, category: .season, name: "DYNASTY",
            detail: "Win 3 championships with the same franchise.",
            symbol: "crown.fill", goal: 3, reward: 0
        ),
        // MARK: Postseason
        Achievement(
            id: .playoffBound, category: .postseason, name: "PLAYOFF BOUND",
            detail: "Qualify for the postseason.",
            symbol: "ticket.fill", goal: nil, reward: 0
        ),
        Achievement(
            id: .finalFour, category: .postseason, name: "FINAL FOUR",
            detail: "Win a playoff semifinal.",
            symbol: "square.grid.2x2.fill", goal: nil, reward: 0
        ),
        Achievement(
            id: .caseClosed, category: .postseason, name: "CASE CLOSED",
            detail: "Win the championship.",
            symbol: "trophy.fill", goal: nil, reward: EconomyConfig.standard.achievementRewardFirstChampionship
        ),
        // MARK: Difficulty
        Achievement(
            id: .proven, category: .difficulty, name: "PROVEN",
            detail: "Win a game on Pro.",
            symbol: "shield.fill", goal: nil, reward: 0
        ),
        Achievement(
            id: .allProMaterial, category: .difficulty, name: "ALL-PRO MATERIAL",
            detail: "Win a playoff game on All-Pro.",
            symbol: "rosette", goal: nil, reward: 0
        ),
        Achievement(
            id: .eliteRead, category: .difficulty, name: "ELITE READ",
            detail: "Win the championship on All-Pro.",
            symbol: "medal.fill", goal: nil, reward: 0
        ),
        Achievement(
            id: .hallWorthy, category: .difficulty, name: "HALL WORTHY",
            detail: "Win the championship on Hall of Famer.",
            symbol: "diamond.fill", goal: nil, reward: EconomyConfig.standard.achievementRewardHallWorthy
        ),
        // MARK: Player
        Achievement(
            id: .ballHawk, category: .player, name: "BALL HAWK",
            detail: "One player reaches 5 career interceptions.",
            symbol: "hand.raised.fill", goal: 5, reward: 0
        ),
        Achievement(
            id: .sackSpecialist, category: .player, name: "SACK SPECIALIST",
            detail: "One player reaches 10 career sacks.",
            symbol: "flame.fill", goal: 10, reward: 0
        ),
        Achievement(
            id: .tackleMachine, category: .player, name: "TACKLE MACHINE",
            detail: "One player reaches 50 career tackles.",
            symbol: "hammer.fill", goal: 50, reward: 0
        ),
        Achievement(
            id: .goToTarget, category: .player, name: "GO-TO TARGET",
            detail: "One player reaches 25 career receptions.",
            symbol: "scope", goal: 25, reward: 0
        ),
        Achievement(
            id: .gameChanger, category: .player, name: "GAME CHANGER",
            detail: "One player earns 5 Player of the Game awards.",
            symbol: "star.fill", goal: 5, reward: 0
        ),
        Achievement(
            id: .franchiseIcon, category: .player, name: "FRANCHISE ICON",
            detail: "One player earns 15 Player of the Game awards.",
            symbol: "person.fill", goal: 15, reward: 0
        ),
        // MARK: Franchise
        Achievement(
            id: .hotStreak, category: .franchise, name: "HOT STREAK",
            detail: "Win 5 games in a row.",
            symbol: "sparkles", goal: nil, reward: 0
        ),
        Achievement(
            id: .ironFranchise, category: .franchise, name: "IRON FRANCHISE",
            detail: "Play 50 games with the same franchise.",
            symbol: "building.columns.fill", goal: 50, reward: 0
        )
    ]

    static func achievement(for id: AchievementID) -> Achievement {
        all.first { $0.id == id } ?? all[0]
    }

    static func achievements(in category: AchievementCategory) -> [Achievement] {
        all.filter { $0.category == category }
    }
}

import Foundation

// MARK: - Economy configuration

/// All reward values, prices and ad frequency in one place so the economy can
/// be rebalanced without touching views or game logic. Nothing in the app
/// hard-codes these numbers.
///
/// Phase 11.7 final economy: Game Balls are the primary earned assistance
/// currency. A solved quarter pays exactly +1 (regulation max +4, solved OT
/// +1); the old large win bonuses (+40 regulation, +50 OT, playoff and
/// championship stacks) are gone. Hints cost 10, and the forced-ad skip
/// prices are 2 (regulation) and 3 (overtime).
nonisolated struct EconomyConfig: Sendable {
    static let standard = EconomyConfig()

    // MARK: Earning

    /// Game Balls earned per solved quarter — regulation and overtime alike.
    let quarterSolvedReward: Int
    /// Starting wallet for a brand-new franchise.
    let startingGameBalls: Int
    /// Free hints a brand-new wallet starts with.
    let startingHints: Int

    // MARK: Spending

    /// Game Ball price of one hint.
    let hintCost: Int
    /// Game Ball price to skip one regulation between-quarter forced ad.
    let regulationAdSkipCost: Int
    /// Game Ball price to skip the overtime forced ad.
    let overtimeAdSkipCost: Int

    // MARK: Forced-ad frequency

    /// Maximum forced full-screen ads in one completed game (includes the
    /// overtime transition). Once reached, every remaining transition is free.
    let maxForcedAdsPerGame: Int

    // MARK: Starter Pack contents

    /// Hints granted by the one-time Starter Pack purchase.
    let starterPackHints: Int
    /// Game Balls granted by the one-time Starter Pack purchase.
    let starterPackGameBalls: Int

    // MARK: Achievement rewards — one-time Game Ball payouts (Phase 11.7 rebalance)

    let achievementRewardFirstCase: Int
    let achievementRewardPerfectGame: Int
    let achievementRewardFirstChampionship: Int
    let achievementRewardUndefeated: Int
    let achievementRewardHallWorthy: Int

    init(
        quarterSolvedReward: Int = 1,
        startingGameBalls: Int = 0,
        startingHints: Int = 3,
        hintCost: Int = 10,
        regulationAdSkipCost: Int = 2,
        overtimeAdSkipCost: Int = 3,
        maxForcedAdsPerGame: Int = 2,
        starterPackHints: Int = 2,
        starterPackGameBalls: Int = 10,
        achievementRewardFirstCase: Int = 2,
        achievementRewardPerfectGame: Int = 3,
        achievementRewardFirstChampionship: Int = 10,
        achievementRewardUndefeated: Int = 15,
        achievementRewardHallWorthy: Int = 25
    ) {
        self.quarterSolvedReward = quarterSolvedReward
        self.startingGameBalls = startingGameBalls
        self.startingHints = startingHints
        self.hintCost = hintCost
        self.regulationAdSkipCost = regulationAdSkipCost
        self.overtimeAdSkipCost = overtimeAdSkipCost
        self.maxForcedAdsPerGame = maxForcedAdsPerGame
        self.starterPackHints = starterPackHints
        self.starterPackGameBalls = starterPackGameBalls
        self.achievementRewardFirstCase = achievementRewardFirstCase
        self.achievementRewardPerfectGame = achievementRewardPerfectGame
        self.achievementRewardFirstChampionship = achievementRewardFirstChampionship
        self.achievementRewardUndefeated = achievementRewardUndefeated
        self.achievementRewardHallWorthy = achievementRewardHallWorthy
    }
}

// MARK: - Reward kinds & transactions

/// What a wallet movement was for. Earned amounts are positive, spent are negative.
nonisolated enum RewardKind: String, Codable, Hashable, Sendable {
    /// Legacy whole-game grant (pre-11.7 economy). Kept so old transaction
    /// history still decodes; nothing new is granted under this kind.
    case matchReward
    case rewardDouble
    case hintPurchase
    case rewardedHint
    case rewardedLife
    case achievementReward
    /// The per-solved-quarter +1 (Phase 11.7).
    case quarterSolved
    /// Game Balls spent to skip a forced ad.
    case adSkip
    /// Game Balls credited by a verified store consumable purchase.
    case storePurchase
    /// Contents granted by the one-time Starter Pack.
    case starterPack
}

/// One immutable wallet movement, kept as a local history for debugging and
/// for idempotency: every granted reward carries a stable id.
nonisolated struct RewardTransaction: Codable, Hashable, Sendable, Identifiable {
    let id: String
    let kind: RewardKind
    /// Positive = earned, negative = spent.
    let amount: Int
    let date: Date
}

// MARK: - Match reward breakdown

/// One line of the postgame CASE REWARD card, e.g. "3 Quarters Solved +3".
nonisolated struct MatchRewardLine: Hashable, Sendable, Identifiable {
    var id: String { label }
    let label: String
    let amount: Int
}

/// The complete Game Ball reward for one finished game, derived purely from
/// the match record. Display-only: each solved quarter was already credited
/// exactly once through the wallet's per-quarter transaction ledger at the
/// moment it was solved (Phase 11.7), so nothing here claims again.
nonisolated struct MatchRewardBreakdown: Hashable, Sendable {
    let transactionID: String
    let lines: [MatchRewardLine]
    let total: Int

    /// Builds the reward summary for a completed match. Losing never
    /// subtracts anything — failed quarters earn 0.
    static func forMatch(
        _ match: GameMatch,
        isPlayoff: Bool,
        isChampionship: Bool,
        transactionID: String,
        config: EconomyConfig = .standard
    ) -> MatchRewardBreakdown {
        var lines: [MatchRewardLine] = []

        let regulationSolved = match.quartersSolved
        if regulationSolved > 0 {
            let label = regulationSolved == 1 ? "1 Quarter Solved" : "\(regulationSolved) Quarters Solved"
            lines.append(MatchRewardLine(label: label, amount: regulationSolved * config.quarterSolvedReward))
        }

        let overtimeSolved = match.overtimeRecord?.outcome == .solved ? 1 : 0
        if overtimeSolved > 0 {
            lines.append(MatchRewardLine(label: "Overtime Solved", amount: overtimeSolved * config.quarterSolvedReward))
        }

        return MatchRewardBreakdown(
            transactionID: transactionID,
            lines: lines,
            total: lines.reduce(0) { $0 + $1.amount }
        )
    }
}

import Foundation

// MARK: - Economy configuration

/// All reward values, prices and ad frequency in one place so the economy can
/// be rebalanced without touching views or game logic. Nothing in the app
/// hard-codes these numbers.
nonisolated struct EconomyConfig: Sendable {
    static let standard = EconomyConfig()

    /// Game Balls earned per solved quarter (regulation or overtime).
    let quarterSolvedReward: Int
    /// Game Balls for winning a regulation game.
    let regulationWinReward: Int
    /// Game Balls for winning a game that went to overtime (replaces the regulation win reward).
    let overtimeWinReward: Int
    /// Additional Game Balls for any postseason win.
    let playoffWinBonus: Int
    /// Additional Game Balls for winning the championship, stacked on the playoff bonus.
    let championshipWinBonus: Int
    /// Starting wallet for a brand-new franchise.
    let startingGameBalls: Int
    /// Free hints a brand-new wallet starts with.
    let startingHints: Int
    /// Game Ball price of one hint.
    let hintCost: Int
    /// Forced interstitial frequency: at most one every N completed games.
    let interstitialEveryNGames: Int

    init(
        quarterSolvedReward: Int = 10,
        regulationWinReward: Int = 40,
        overtimeWinReward: Int = 50,
        playoffWinBonus: Int = 25,
        championshipWinBonus: Int = 100,
        startingGameBalls: Int = 0,
        startingHints: Int = 3,
        hintCost: Int = 50,
        interstitialEveryNGames: Int = 2
    ) {
        self.quarterSolvedReward = quarterSolvedReward
        self.regulationWinReward = regulationWinReward
        self.overtimeWinReward = overtimeWinReward
        self.playoffWinBonus = playoffWinBonus
        self.championshipWinBonus = championshipWinBonus
        self.startingGameBalls = startingGameBalls
        self.startingHints = startingHints
        self.hintCost = hintCost
        self.interstitialEveryNGames = interstitialEveryNGames
    }
}

// MARK: - Reward kinds & transactions

/// What a wallet movement was for. Earned amounts are positive, spent are negative.
nonisolated enum RewardKind: String, Codable, Hashable, Sendable {
    case matchReward
    case rewardDouble
    case hintPurchase
    case rewardedHint
    case rewardedLife
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

/// One line of the postgame CASE REWARD card, e.g. "3 Quarters Solved +30".
nonisolated struct MatchRewardLine: Hashable, Sendable, Identifiable {
    var id: String { label }
    let label: String
    let amount: Int
}

/// The complete Game Ball reward for one finished game, derived purely from
/// the match record and the stage it was played at. The total is granted
/// exactly once under `transactionID`.
nonisolated struct MatchRewardBreakdown: Hashable, Sendable {
    let transactionID: String
    let lines: [MatchRewardLine]
    let total: Int

    /// Builds the reward for a completed match. Losing a game never subtracts
    /// anything — solved quarters still earn their reward.
    static func forMatch(
        _ match: GameMatch,
        isPlayoff: Bool,
        isChampionship: Bool,
        transactionID: String,
        config: EconomyConfig = .standard
    ) -> MatchRewardBreakdown {
        var lines: [MatchRewardLine] = []

        let solved = match.quartersSolved + (match.overtimeRecord?.outcome == .solved ? 1 : 0)
        if solved > 0 {
            let label = solved == 1 ? "1 Quarter Solved" : "\(solved) Quarters Solved"
            lines.append(MatchRewardLine(label: label, amount: solved * config.quarterSolvedReward))
        }

        if let result = match.result, result.isWin {
            let wentToOT = match.overtimeRecord != nil
            lines.append(MatchRewardLine(
                label: wentToOT ? "Overtime Victory" : "Game Victory",
                amount: wentToOT ? config.overtimeWinReward : config.regulationWinReward
            ))
            if isPlayoff {
                lines.append(MatchRewardLine(label: "Playoff Win", amount: config.playoffWinBonus))
            }
            if isChampionship {
                lines.append(MatchRewardLine(label: "Gridiron Champions", amount: config.championshipWinBonus))
            }
        }

        return MatchRewardBreakdown(
            transactionID: transactionID,
            lines: lines,
            total: lines.reduce(0) { $0 + $1.amount }
        )
    }
}

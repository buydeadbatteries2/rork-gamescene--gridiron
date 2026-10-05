import Foundation
import Observation

// MARK: - Player wallet

/// Single source of truth for the player's Game Ball balance, hint inventory,
/// reward transactions and reward-safety ledgers. Everything persists locally
/// (UserDefaults JSON) and survives restarts. Losing a game never subtracts
/// Game Balls; every granted reward is idempotent by its transaction id.
@MainActor
@Observable
final class PlayerWallet {
    static let shared = PlayerWallet()

    static let storageKey = "gamescene.gridiron.economy"

    /// Transactions kept in history for debugging; older ones are trimmed.
    static let transactionHistoryLimit = 150

    private struct PersistedState: Codable {
        var gameBalls: Int = EconomyConfig.standard.startingGameBalls
        var hints: Int = EconomyConfig.standard.startingHints
        var transactions: [RewardTransaction] = []
        var claimedTransactionIDs: Set<String> = []
        var doubledMatchIDs: Set<String> = []
        var lastChanceUsedKeys: Set<String> = []
    }

    private let defaults: UserDefaults

    private(set) var gameBalls: Int
    private(set) var hints: Int
    private(set) var transactions: [RewardTransaction]
    /// Every granted reward id (match rewards, doubles, rewarded grants). The
    /// ledger that makes grants idempotent.
    private(set) var claimedTransactionIDs: Set<String>
    /// Match transaction ids whose reward has already been doubled once.
    private(set) var doubledMatchIDs: Set<String>
    /// Quarter keys ("<matchID>-q<index>") that already used their Last Chance.
    private(set) var lastChanceUsedKeys: Set<String>

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let state = Self.load(from: defaults)
        gameBalls = max(0, state.gameBalls)
        hints = max(0, state.hints)
        transactions = state.transactions
        claimedTransactionIDs = state.claimedTransactionIDs
        doubledMatchIDs = state.doubledMatchIDs
        lastChanceUsedKeys = state.lastChanceUsedKeys
    }

    private static func load(from defaults: UserDefaults) -> PersistedState {
        guard let data = defaults.data(forKey: PlayerWallet.storageKey),
              let state = try? JSONDecoder().decode(PersistedState.self, from: data) else {
            return PersistedState()
        }
        return state
    }

    private func persist() {
        let state = PersistedState(
            gameBalls: gameBalls,
            hints: hints,
            transactions: transactions,
            claimedTransactionIDs: claimedTransactionIDs,
            doubledMatchIDs: doubledMatchIDs,
            lastChanceUsedKeys: lastChanceUsedKeys
        )
        if let data = try? JSONEncoder().encode(state) {
            defaults.set(data, forKey: Self.storageKey)
        }
    }

    private func record(_ transaction: RewardTransaction) {
        transactions.append(transaction)
        if transactions.count > Self.transactionHistoryLimit {
            transactions.removeFirst(transactions.count - Self.transactionHistoryLimit)
        }
        persist()
    }

    // MARK: Earning

    /// Credits Game Balls. With a `transactionID`, the grant is idempotent —
    /// claiming the same id twice never double-credits.
    @discardableResult
    func earn(amount: Int, kind: RewardKind, transactionID: String? = nil) -> Bool {
        guard amount > 0 else { return false }
        if let transactionID {
            guard !claimedTransactionIDs.contains(transactionID) else { return false }
            claimedTransactionIDs.insert(transactionID)
        }
        gameBalls += amount
        record(RewardTransaction(id: transactionID ?? UUID().uuidString, kind: kind, amount: amount, date: .now))
        return true
    }

    // MARK: Spending

    /// Debits Game Balls. Never lets the balance go negative and never spends
    /// more than the player owns.
    @discardableResult
    func spend(amount: Int, kind: RewardKind) -> Bool {
        guard amount > 0, gameBalls >= amount else { return false }
        gameBalls -= amount
        record(RewardTransaction(id: UUID().uuidString, kind: kind, amount: -amount, date: .now))
        return true
    }

    // MARK: Hints

    var canAffordHint: Bool { gameBalls >= EconomyConfig.standard.hintCost }

    /// Buys one hint at the configured price. Atomic: a failed purchase never
    /// deducts and never grants.
    @discardableResult
    func buyHint(config: EconomyConfig = .standard) -> Bool {
        guard spend(amount: config.hintCost, kind: .hintPurchase) else { return false }
        hints += 1
        persist()
        return true
    }

    /// Adds hints — used by rewarded-ad grants. Exactly `count`, no more.
    @discardableResult
    func addHints(_ count: Int) -> Bool {
        guard count > 0 else { return false }
        hints += count
        persist()
        return true
    }

    /// Consumes one hint. Returns false when the inventory is empty.
    @discardableResult
    func consumeHint() -> Bool {
        guard hints > 0 else { return false }
        hints -= 1
        persist()
        return true
    }

    // MARK: Match rewards

    /// Claims a completed game's reward. Returns false when this transaction
    /// id was already claimed — the same game can never pay out twice.
    @discardableResult
    func claimMatchReward(_ breakdown: MatchRewardBreakdown) -> Bool {
        earn(amount: breakdown.total, kind: .matchReward, transactionID: breakdown.transactionID)
    }

    func hasDoubledMatchReward(transactionID: String) -> Bool {
        doubledMatchIDs.contains(transactionID)
    }

    /// Doubles one completed game's earned reward — never the whole wallet —
    /// exactly once per match. Requires the base reward to be claimed already.
    @discardableResult
    func doubleMatchReward(_ breakdown: MatchRewardBreakdown) -> Bool {
        guard breakdown.total > 0 else { return false }
        guard claimedTransactionIDs.contains(breakdown.transactionID) else { return false }
        guard !doubledMatchIDs.contains(breakdown.transactionID) else { return false }
        doubledMatchIDs.insert(breakdown.transactionID)
        persist()
        return earn(
            amount: breakdown.total,
            kind: .rewardDouble,
            transactionID: "double-\(breakdown.transactionID)"
        )
    }

    // MARK: Last Chance (rewarded life)

    func hasUsedLastChance(for key: String) -> Bool {
        lastChanceUsedKeys.contains(key)
    }

    /// Marks a quarter's Last Chance as spent. Returns false when the quarter
    /// already used it — one rewarded life per quarter, ever.
    @discardableResult
    func markLastChanceUsed(for key: String) -> Bool {
        guard !lastChanceUsedKeys.contains(key) else { return false }
        lastChanceUsedKeys.insert(key)
        persist()
        return true
    }
}

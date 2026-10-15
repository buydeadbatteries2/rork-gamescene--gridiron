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

    /// Per-quarter rescue usage. Persisted separately so a force-quit can
    /// never respawn a consumed rescue.
    private struct RescueFlags: Codable, Hashable {
        var usedVideo = false
        var usedHint = false

        var isExhausted: Bool { usedVideo && usedHint }
    }

    private struct PersistedState: Codable {
        var gameBalls: Int = EconomyConfig.standard.startingGameBalls
        var hints: Int = EconomyConfig.standard.startingHints
        var transactions: [RewardTransaction] = []
        var claimedTransactionIDs: Set<String> = []
        var doubledMatchIDs: Set<String> = []
        /// Legacy pre-11.7 Last Chance ledger — migrated into rescue flags.
        var lastChanceUsedKeys: Set<String> = []
        /// Phase 11.7: per-quarter rescue ledger ("video"/"hint" used).
        var rescueFlags: [String: RescueFlags] = [:]
        /// Match ids and how many forced ads actually played in that game.
        var forcedAdCounts: [String: Int] = [:]
        /// The one-time Starter Pack contents grant happened.
        var starterPackGranted = false

        // Custom decoding: every phase's new fields decode with defaults, so
        // a save written by an older version of the app migrates silently
        // instead of falling into the corrupt-backup path.
        init(
            gameBalls: Int = EconomyConfig.standard.startingGameBalls,
            hints: Int = EconomyConfig.standard.startingHints,
            transactions: [RewardTransaction] = [],
            claimedTransactionIDs: Set<String> = [],
            doubledMatchIDs: Set<String> = [],
            lastChanceUsedKeys: Set<String> = [],
            rescueFlags: [String: RescueFlags] = [:],
            forcedAdCounts: [String: Int] = [:],
            starterPackGranted: Bool = false
        ) {
            self.gameBalls = gameBalls
            self.hints = hints
            self.transactions = transactions
            self.claimedTransactionIDs = claimedTransactionIDs
            self.doubledMatchIDs = doubledMatchIDs
            self.lastChanceUsedKeys = lastChanceUsedKeys
            self.rescueFlags = rescueFlags
            self.forcedAdCounts = forcedAdCounts
            self.starterPackGranted = starterPackGranted
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            gameBalls = try container.decodeIfPresent(Int.self, forKey: .gameBalls) ?? EconomyConfig.standard.startingGameBalls
            hints = try container.decodeIfPresent(Int.self, forKey: .hints) ?? EconomyConfig.standard.startingHints
            transactions = try container.decodeIfPresent([RewardTransaction].self, forKey: .transactions) ?? []
            claimedTransactionIDs = try container.decodeIfPresent(Set<String>.self, forKey: .claimedTransactionIDs) ?? []
            doubledMatchIDs = try container.decodeIfPresent(Set<String>.self, forKey: .doubledMatchIDs) ?? []
            lastChanceUsedKeys = try container.decodeIfPresent(Set<String>.self, forKey: .lastChanceUsedKeys) ?? []
            rescueFlags = try container.decodeIfPresent([String: RescueFlags].self, forKey: .rescueFlags) ?? [:]
            forcedAdCounts = try container.decodeIfPresent([String: Int].self, forKey: .forcedAdCounts) ?? [:]
            starterPackGranted = try container.decodeIfPresent(Bool.self, forKey: .starterPackGranted) ?? false
            // Migration: a legacy Last Chance (rewarded life) counts as the
            // quarter's video rescue — same placement in the flow.
            for key in lastChanceUsedKeys where rescueFlags[key] == nil {
                rescueFlags[key] = RescueFlags(usedVideo: true)
            }
        }
    }

    private let defaults: UserDefaults

    private(set) var gameBalls: Int
    private(set) var hints: Int
    private(set) var transactions: [RewardTransaction]
    /// Every granted reward id (match rewards, doubles, rewarded grants,
    /// store purchases). The ledger that makes grants idempotent.
    private(set) var claimedTransactionIDs: Set<String>
    /// Match transaction ids whose reward has already been doubled once.
    private(set) var doubledMatchIDs: Set<String>
    private var rescueFlags: [String: RescueFlags]
    /// Match id → forced ads that actually played in that game.
    private var forcedAdCounts: [String: Int]
    /// Starter Pack contents were granted exactly once.
    private(set) var starterPackGranted: Bool

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let state = Self.load(from: defaults)
        gameBalls = max(0, state.gameBalls)
        hints = max(0, state.hints)
        transactions = state.transactions
        claimedTransactionIDs = state.claimedTransactionIDs
        doubledMatchIDs = state.doubledMatchIDs
        rescueFlags = state.rescueFlags
        forcedAdCounts = state.forcedAdCounts
        starterPackGranted = state.starterPackGranted
    }

    private static func load(from defaults: UserDefaults) -> PersistedState {
        SaveStore.load(PersistedState.self, key: PlayerWallet.storageKey, defaults: defaults) ?? PersistedState()
    }

    private func persist() {
        let state = PersistedState(
            gameBalls: gameBalls,
            hints: hints,
            transactions: transactions,
            claimedTransactionIDs: claimedTransactionIDs,
            doubledMatchIDs: doubledMatchIDs,
            lastChanceUsedKeys: [],
            rescueFlags: rescueFlags,
            forcedAdCounts: forcedAdCounts,
            starterPackGranted: starterPackGranted
        )
        SaveStore.save(state, key: Self.storageKey, defaults: defaults)
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

    /// True when a hint reveal is payable right now: inventory first, then
    /// the Game Ball price.
    var canConsumeHint: Bool { hints > 0 || canAffordHint }

    /// Consumes one owned hint; with an empty inventory charges the standard
    /// Game Ball price. Atomic: a false return never deducts or grants.
    @discardableResult
    func consumeHintOrCharge(config: EconomyConfig = .standard) -> Bool {
        if hints > 0 {
            hints -= 1
            persist()
            return true
        }
        guard spend(amount: config.hintCost, kind: .hintPurchase) else { return false }
        return true
    }

    /// Buys one hint at the configured price into inventory. Atomic: a failed
    /// purchase never deducts and never grants.
    @discardableResult
    func buyHint(config: EconomyConfig = .standard) -> Bool {
        guard spend(amount: config.hintCost, kind: .hintPurchase) else { return false }
        hints += 1
        persist()
        return true
    }

    /// Adds hints — used by rewarded-ad and Starter Pack grants. Exactly
    /// `count`, no more.
    @discardableResult
    func addHints(_ count: Int) -> Bool {
        guard count > 0 else { return false }
        hints += count
        persist()
        return true
    }

    /// Consumes one hint without charging. Returns false when empty.
    @discardableResult
    func consumeHint() -> Bool {
        guard hints > 0 else { return false }
        hints -= 1
        persist()
        return true
    }

    // MARK: Store purchases

    /// Credits a verified store consumable purchase. Idempotent by the store
    /// transaction id — the same purchase can never credit twice.
    @discardableResult
    func grantStoreGameBalls(_ amount: Int, transactionID: String) -> Bool {
        earn(amount: amount, kind: .storePurchase, transactionID: "rc-\(transactionID)")
    }

    /// True when the one-time Starter Pack contents were already granted.
    var hasStarterPackGrant: Bool { starterPackGranted }

    /// Grants the Starter Pack contents (+2 hints, +10 Game Balls) exactly
    /// once, ever. Restores and re-purchases are no-ops after the first grant.
    @discardableResult
    func grantStarterPackContents(config: EconomyConfig = .standard) -> Bool {
        guard !starterPackGranted else { return false }
        starterPackGranted = true
        hints += config.starterPackHints
        gameBalls += config.starterPackGameBalls
        record(RewardTransaction(
            id: "starter-pack-contents",
            kind: .starterPack,
            amount: config.starterPackGameBalls,
            date: .now
        ))
        persist()
        return true
    }

    // MARK: Match rewards

    /// Doubles one completed game's earned reward — never the whole wallet —
    /// exactly once per match.
    @discardableResult
    func doubleMatchReward(_ breakdown: MatchRewardBreakdown) -> Bool {
        guard breakdown.total > 0 else { return false }
        guard !doubledMatchIDs.contains(breakdown.transactionID) else { return false }
        doubledMatchIDs.insert(breakdown.transactionID)
        persist()
        return earn(
            amount: breakdown.total,
            kind: .rewardDouble,
            transactionID: "double-\(breakdown.transactionID)"
        )
    }

    func hasDoubledMatchReward(transactionID: String) -> Bool {
        doubledMatchIDs.contains(transactionID)
    }

    // MARK: Last Chance rescues (Phase 11.7)

    /// The per-quarter rescue path: optional video rescue → optional hint
    /// rescue → quarter loss. Each rescue is usable at most once per quarter,
    /// and the ledgers persist so a force-quit cannot respawn them.

    func canUseVideoRescue(for key: String) -> Bool {
        !(rescueFlags[key]?.usedVideo ?? false)
    }

    func canUseHintRescue(for key: String) -> Bool {
        guard !(rescueFlags[key]?.usedHint ?? false) else { return false }
        return canConsumeHint
    }

    /// Marks the quarter's video rescue as spent. Returns false when it was
    /// already used — one rewarded rescue per quarter, ever.
    @discardableResult
    func markVideoRescueUsed(for key: String) -> Bool {
        var flags = rescueFlags[key] ?? RescueFlags()
        guard !flags.usedVideo else { return false }
        flags.usedVideo = true
        rescueFlags[key] = flags
        persist()
        return true
    }

    /// Marks the quarter's hint rescue as spent. Returns false when it was
    /// already used.
    @discardableResult
    func markHintRescueUsed(for key: String) -> Bool {
        var flags = rescueFlags[key] ?? RescueFlags()
        guard !flags.usedHint else { return false }
        flags.usedHint = true
        rescueFlags[key] = flags
        persist()
        return true
    }

    /// Whether the quarter's hint rescue was already used (regardless of
    /// whether it would be payable now).
    func usedHintRescue(for key: String) -> Bool {
        rescueFlags[key]?.usedHint ?? false
    }

    // MARK: Forced-ad ledger

    /// Forced ads that actually played in this game (by match id).
    func forcedAdCount(for matchKey: String) -> Int {
        forcedAdCounts[matchKey] ?? 0
    }

    /// Records one forced ad that actually played. Returns the new count.
    func recordForcedAd(for matchKey: String) -> Int {
        let count = forcedAdCount(for: matchKey) + 1
        forcedAdCounts[matchKey] = count
        persist()
        return count
    }
}

import Foundation

// MARK: - Forced-ad gate policy

/// What a transition between quarters (or into overtime) requires. Pure and
/// testable so the ad-frequency rules stay provable in one place.
nonisolated enum AdGateDecision: Equatable, Sendable {
    /// Proceed free — no gate, no Game Ball charge.
    case none
    /// Offer WATCH AD or SKIP AD at the given Game Ball cost. The free
    /// WATCH AD route is always available; Game Balls only skip the ad.
    case forced(skipCost: Int)
}

nonisolated enum AdGatePolicy {
    /// Decides the between-quarter / overtime gate.
    ///
    /// Rules (Phase 11.7):
    /// - Remove Forced Ads owners bypass every forced gate.
    /// - A lost regulation quarter never gates and never charges — the free
    ///   route is always available.
    /// - The overtime gate keys on the tie itself (a 2–2 regulation always
    ///   ends with a lost Q4), so it fires regardless of that quarter's outcome.
    /// - The Training Case and the user's first regular-season game are exempt.
    /// - At most `maxForcedAdsPerGame` forced ads per game; once reached,
    ///   every remaining transition is free (no skip charge either).
    static func decision(
        quarterWon: Bool,
        isOvertimeTransition: Bool,
        isAdFree: Bool,
        forcedAdsShown: Int,
        isTraining: Bool = false,
        isFirstSeasonGame: Bool = false,
        config: EconomyConfig = .standard
    ) -> AdGateDecision {
        if isAdFree { return .none }
        if !isOvertimeTransition, !quarterWon { return .none }
        if isTraining || isFirstSeasonGame { return .none }
        guard forcedAdsShown < config.maxForcedAdsPerGame else { return .none }
        return .forced(skipCost: isOvertimeTransition ? config.overtimeAdSkipCost : config.regulationAdSkipCost)
    }
}

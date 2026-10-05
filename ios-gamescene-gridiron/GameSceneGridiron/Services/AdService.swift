import Foundation
import Observation

// MARK: - Ad types

/// Outcome of a rewarded-ad presentation. `.granted` is returned only after
/// the ad SDK's reward callback fired; closing the ad early resolves to
/// `.dismissed` and callers must not grant anything.
enum RewardedAdResult: Sendable, Equatable {
    case granted
    case dismissed
}

/// The rewarded-ad placements this game offers. Rewarded videos are always
/// voluntary and stay available to Ad-Free owners.
enum RewardedAdPlacement: String, Sendable {
    case hint
    case lastChanceLife
    case doubleReward
}

// MARK: - Ad manager

/// Owns every ad surface: the gameplay banner, forced interstitials at natural
/// breaks and the rewarded-video flows. The Google Mobile Ads SDK slots in
/// behind the marked integration points; until live AdMob configuration
/// exists, development builds simulate ads here so the entire economy is
/// exercisable end to end.
@MainActor
@Observable
final class AdManager {
    static let shared = AdManager()

    /// Forced interstitial frequency: at most one every N completed games.
    let interstitialEveryNGames: Int

    private(set) var completedGamesSinceInterstitial = 0
    /// Set right after any rewarded ad completes — the immediately following
    /// forced interstitial is suppressed once.
    private(set) var isNextInterstitialSuppressed = false
    private(set) var isRewardedAdShowing = false

    init(interstitialEveryNGames: Int = EconomyConfig.standard.interstitialEveryNGames) {
        self.interstitialEveryNGames = max(1, interstitialEveryNGames)
    }

    // MARK: Banner

    /// The gameplay banner lives at the absolute bottom, visually separated
    /// from field, clues, tray and controls. Ad-Free owners get no banner at
    /// all and the layout expands naturally into the freed space.
    var showsBannerAds: Bool { !PurchaseManager.shared.hasAdFree }

    // MARK: Interstitials

    var showsInterstitialAds: Bool { !PurchaseManager.shared.hasAdFree }

    /// Call once when a game completes.
    func recordCompletedGame() {
        completedGamesSinceInterstitial += 1
    }

    /// Frequency gate for forced interstitials.
    func canShowInterstitial() -> Bool {
        guard showsInterstitialAds, !isNextInterstitialSuppressed else { return false }
        return completedGamesSinceInterstitial >= interstitialEveryNGames
    }

    /// Presents a forced interstitial at a natural break (after a completed
    /// game / between weeks). Never call during a quarter, clue reading,
    /// drag & drop, between quarters, during overtime or right after a
    /// rewarded ad.
    func maybeShowInterstitial() {
        if isNextInterstitialSuppressed {
            // The forced break right after a rewarded ad is skipped exactly
            // once — the flag clears here so the next eligible break shows.
            isNextInterstitialSuppressed = false
            return
        }
        guard canShowInterstitial() else { return }
        completedGamesSinceInterstitial = 0
        presentInterstitial()
    }

    private func presentInterstitial() {
        // Ad SDK integration point: present the interstitial here.
        #if DEBUG
        print("[AdManager] interstitial presented (development placeholder)")
        #endif
    }

    // MARK: Rewarded video

    /// Presents a rewarded ad. Resolves `.granted` only through the reward
    /// callback; an early close resolves `.dismissed` and nothing may be
    /// granted by the caller.
    func showRewarded(_ placement: RewardedAdPlacement) async -> RewardedAdResult {
        guard !isRewardedAdShowing else { return .dismissed }
        isRewardedAdShowing = true
        defer { isRewardedAdShowing = false }

        // Ad SDK integration point: present the rewarded video and map its
        // reward callback to `.granted`, an early close to `.dismissed`.
        // Development placeholder simulates a short watched ad.
        try? await Task.sleep(for: .seconds(1.2))
        #if DEBUG
        print("[AdManager] rewarded ad granted (\(placement.rawValue), development placeholder)")
        #endif

        isNextInterstitialSuppressed = true
        return .granted
    }
}

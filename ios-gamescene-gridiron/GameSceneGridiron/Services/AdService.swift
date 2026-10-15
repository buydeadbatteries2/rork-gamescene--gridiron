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

/// Outcome of a forced full-screen presentation. `.shown` means an ad
/// actually played; `.unavailable` means nothing was presented (no SDK, no
/// inventory, or an ad-free owner) and the player continues for free.
enum ForcedAdResult: Sendable, Equatable {
    case shown
    case unavailable
}

/// The rewarded-ad placements this game offers. Rewarded videos are always
/// voluntary and stay available to Ad-Free owners.
enum RewardedAdPlacement: String, Sendable {
    case hint
    case lastChanceLife
    case doubleReward
}

// MARK: - Banner policy

/// What the gameplay banner slot displays. Pure and testable so the
/// release-safety rules stay enforced in one place.
nonisolated enum BannerAdPolicy {
    enum BannerVisibility: Equatable, Sendable {
        /// No banner at all — the slot collapses and the layout reclaims it.
        case hidden
        /// DEBUG only: the clearly labeled development placeholder for
        /// layout testing while no real ad is loaded.
        case developmentPlaceholder
        /// A real ad banner has loaded and is displayed.
        case loadedBanner
    }

    /// Release-safety contract:
    /// - Ad-Free always suppresses the banner, loaded or not.
    /// - A release build with no loaded ad shows NOTHING (never a fake or
    ///   "sponsored" strip).
    /// - A loaded real ad always gets the banner space.
    static func visibility(
        isAdFree: Bool,
        isBannerLoaded: Bool,
        isDevelopmentBuild: Bool
    ) -> BannerVisibility {
        if isAdFree { return .hidden }
        if isBannerLoaded { return .loadedBanner }
        return isDevelopmentBuild ? .developmentPlaceholder : .hidden
    }
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
    /// True only after a real banner load callback reports success. A release
    /// build starts (and stays) unloaded until the AdMob integration fires —
    /// meaning the banner slot stays collapsed, showing no fake strip.
    private(set) var isBannerAdLoaded = false

    init(interstitialEveryNGames: Int = 2) {
        self.interstitialEveryNGames = max(1, interstitialEveryNGames)
    }

    // MARK: Banner

    /// The gameplay banner lives at the absolute bottom, visually separated
    /// from field, clues, tray and controls. Ad-Free owners get no banner at
    /// all and the layout expands naturally into the freed space.
    var showsBannerAds: Bool { !PurchaseManager.shared.hasAdFree }

    /// Whether this compile configuration is a development build.
    static var isDevelopmentBuild: Bool {
        #if DEBUG
        true
        #else
        false
        #endif
    }

    /// What the banner slot currently displays (see `BannerAdPolicy`).
    var bannerVisibility: BannerAdPolicy.BannerVisibility {
        BannerAdPolicy.visibility(
            isAdFree: PurchaseManager.shared.hasAdFree,
            isBannerLoaded: isBannerAdLoaded,
            isDevelopmentBuild: Self.isDevelopmentBuild
        )
    }

    /// Begins loading a banner ad. Never called for Ad-Free owners — they are
    /// never asked for a banner at all. The real AdMob load request goes at
    /// the marked integration point; only its success callback may flip
    /// `isBannerAdLoaded`.
    func requestBannerAd() {
        guard showsBannerAds, !isBannerAdLoaded else { return }

        #if DEBUG
        // Development placeholder: simulates a successful banner load so the
        // loaded-banner layout state is exercisable. Release builds never run
        // this — no simulated ad can ever occupy the slot.
        print("[AdManager] banner ad loaded (development placeholder)")
        isBannerAdLoaded = true
        #else
        // Ad SDK integration point (production): request the AdMob banner
        // here and set `isBannerAdLoaded = true` ONLY from its success
        // callback. Until that integration ships, release builds keep the
        // slot collapsed — no fake banner, no reserved space.
        #endif
    }

    /// Pauses/unloads the banner after the entitlement state changes (an
    /// Ad-Free purchase or restore mid-session). The slot collapses and the
    /// layout reclaims the space.
    func handleBannerEntitlementChanged() {
        if !showsBannerAds {
            isBannerAdLoaded = false
        }
    }

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

    // MARK: Forced full-screen gates (between quarters / overtime)

    /// Presents one forced full-screen ad at a between-quarter or overtime
    /// transition. Resolves `.shown` only when an ad actually played — the
    /// caller then records it against the per-game cap. Release builds
    /// without the live AdMob integration resolve `.unavailable`: never a
    /// fake ad, never a fake success, and the player continues for free.
    func showForcedAd() async -> ForcedAdResult {
        guard showsInterstitialAds else { return .unavailable }

        #if DEBUG
        // Development placeholder: simulates a short forced ad so the gate
        // flow (watch/skip/cap) is exercisable end to end.
        try? await Task.sleep(for: .seconds(1.2))
        print("[AdManager] forced full-screen ad shown (development placeholder)")
        return .shown
        #else
        // Ad SDK integration point (production): present the AdMob full-screen
        // interstitial here and return `.shown` from its completion callback.
        // Until that integration ships, release builds never fake an ad.
        return .unavailable
        #endif
    }

    // MARK: Rewarded video

    /// Presents a rewarded ad. Resolves `.granted` only through the reward
    /// callback; an early close resolves `.dismissed` and nothing may be
    /// granted by the caller.
    ///
    /// Production safety: the fake 1.2-second success exists in DEBUG builds
    /// only. A release build without the live AdMob integration can never
    /// grant a mock reward — it resolves `.dismissed`, which every call site
    /// surfaces as "no video is available right now" with nothing spent and
    /// nothing granted.
    func showRewarded(_ placement: RewardedAdPlacement) async -> RewardedAdResult {
        guard !isRewardedAdShowing else { return .dismissed }
        isRewardedAdShowing = true
        defer { isRewardedAdShowing = false }

        #if DEBUG
        // Development placeholder: simulates a short watched ad so the whole
        // economy (hints, Last Chance, 2× rewards) is exercisable end to end.
        try? await Task.sleep(for: .seconds(1.2))
        print("[AdManager] rewarded ad granted (\(placement.rawValue), development placeholder)")
        isNextInterstitialSuppressed = true
        return .granted
        #else
        // Ad SDK integration point (production): present the AdMob rewarded
        // video here and map its reward callback to `.granted`, an early
        // close to `.dismissed`. Until that integration ships, release builds
        // always report unavailability — never a simulated reward.
        return .dismissed
        #endif
    }
}

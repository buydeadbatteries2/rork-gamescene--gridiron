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

// MARK: - Ad manager (facade)

/// The AdService facade every view and view model talks to. Owns the ad
/// policy surfaces: the gameplay banner, forced interstitials at natural
/// breaks, the between-quarter gate presentation and the rewarded-video
/// flows. All Google Mobile Ads SDK work lives behind `AdMobService`.
@MainActor
@Observable
final class AdManager {
    static let shared = AdManager()

    /// Forced interstitial frequency: at most one every N completed games.
    let interstitialEveryNGames: Int

    /// DEBUG-only fallback for builds without a valid AdMob app identifier
    /// (e.g. sandbox previews): simulates short ads so the whole economy stays
    /// exercisable. Tests can disable it to prove the honest `.unavailable`
    /// paths. Release builds never simulate.
    let simulatesAdsWhenUnavailable: Bool

    private(set) var completedGamesSinceInterstitial = 0
    /// Set right after any rewarded ad completes — the immediately following
    /// forced interstitial is suppressed once.
    private(set) var isNextInterstitialSuppressed = false
    private(set) var isRewardedAdShowing = false
    /// True while ANY full-screen ad (forced interstitial or rewarded) is on
    /// screen — the Hall of Famer clock and achievement popups key off this.
    private(set) var isFullScreenAdPresenting = false
    /// True only after a real banner load callback reports success. A release
    /// build starts (and stays) unloaded until the AdMob load fires — meaning
    /// the banner slot stays collapsed, showing no fake strip.
    private(set) var isBannerAdLoaded = false

    init(
        interstitialEveryNGames: Int = 2,
        simulatesAdsWhenUnavailable: Bool = AdManager.defaultSimulationSetting
    ) {
        self.interstitialEveryNGames = max(1, interstitialEveryNGames)
        self.simulatesAdsWhenUnavailable = simulatesAdsWhenUnavailable
        AdMobService.shared.onFullScreenAdDismissed = {
            // A dismissed full-screen ad is the safe moment to surface the
            // next queued achievement popup.
            AchievementManager.shared.presentNextPopupIfSafe()
        }
    }

    /// Simulation is a DEBUG-only escape hatch, never a release behavior.
    private nonisolated static var defaultSimulationSetting: Bool {
        #if DEBUG
        true
        #else
        false
        #endif
    }

    // MARK: Banner

    /// The gameplay banner lives at the absolute bottom, visually separated
    /// from field, clues, tray and controls. Ad-Free owners get no banner at
    /// all and the layout expands naturally into the freed space.
    var showsBannerAds: Bool { !PurchaseManager.shared.hasAdFree }

    /// Whether this compile configuration is a development build.
    nonisolated static var isDevelopmentBuild: Bool {
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

    /// Arms the banner. The banner view itself performs the AdMob load (only
    /// when ad requests are consented and the owner hasn't purchased Remove
    /// Forced Ads); only its load callbacks may flip `isBannerAdLoaded`
    /// (through `noteBannerLoadResult`).
    func requestBannerAd() {
        guard showsBannerAds else { return }
        #if DEBUG
        // Development fallback: without a valid AdMob app identifier there is
        // no real ad SDK session, so the labeled layout placeholder stands in.
        // With real test ads configured, the actual AdMob banner loads instead.
        if !AdMobService.shared.isAdsSupported {
            print("[AdManager] banner slot in development-placeholder mode (no AdMob app ID)")
        }
        #endif
    }

    /// Called by the banner view from the AdMob load callbacks — success shows
    /// the banner, failure collapses the slot (with a delayed retry handled by
    /// the view's next appearance / foreground pass).
    func noteBannerLoadResult(_ loaded: Bool) {
        isBannerAdLoaded = loaded
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
        Task { await presentTrackedInterstitial() }
    }

    // MARK: Forced full-screen gates (between quarters / overtime)

    /// Presents one forced full-screen ad at a between-quarter or overtime
    /// transition. Resolves `.shown` only when an ad actually played — the
    /// caller then records it against the per-game cap. Unavailable/failing
    /// ads resolve `.unavailable`: the player continues for free, nothing is
    /// charged, nothing counts against the cap.
    func showForcedAd() async -> ForcedAdResult {
        guard showsInterstitialAds else { return .unavailable }
        guard !isFullScreenAdPresenting else { return .unavailable }
        guard AdMobService.shared.canServeAds else {
            #if DEBUG
            if simulatesAdsWhenUnavailable {
                isFullScreenAdPresenting = true
                try? await Task.sleep(for: .seconds(1.2))
                isFullScreenAdPresenting = false
                return .shown
            }
            #endif
            return .unavailable
        }
        isFullScreenAdPresenting = true
        let result = await AdMobService.shared.presentInterstitial()
        isFullScreenAdPresenting = false
        return result
    }

    private func presentTrackedInterstitial() {
        guard showsInterstitialAds, !isFullScreenAdPresenting else { return }
        Task { @MainActor in
            guard AdMobService.shared.isAdsSupported else {
                #if DEBUG
                if simulatesAdsWhenUnavailable {
                    isFullScreenAdPresenting = true
                    try? await Task.sleep(for: .seconds(1.2))
                    isFullScreenAdPresenting = false
                    isNextInterstitialSuppressed = true
                }
                #endif
                return
            }
            isFullScreenAdPresenting = true
            let result = await AdMobService.shared.presentInterstitial()
            isFullScreenAdPresenting = false
            if result == .shown { isNextInterstitialSuppressed = true }
        }
    }

    // MARK: Rewarded video

    /// Presents a rewarded ad. Resolves `.granted` only through the Google
    /// earned-reward callback; an early close resolves `.dismissed` and
    /// nothing may be granted by the caller. Rewarded videos stay available
    /// to Remove-Forced-Ads owners — the entitlement never gates this path.
    func showRewarded(_ placement: RewardedAdPlacement) async -> RewardedAdResult {
        guard !isRewardedAdShowing else { return .dismissed }
        isRewardedAdShowing = true
        defer { isRewardedAdShowing = false }
        guard AdMobService.shared.canServeAds else {
            #if DEBUG
            if simulatesAdsWhenUnavailable {
                try? await Task.sleep(for: .seconds(1.2))
                print("[AdManager] rewarded ad granted (\(placement.rawValue), development simulation)")
                isNextInterstitialSuppressed = true
                return .granted
            }
            #endif
            return .dismissed
        }
        isFullScreenAdPresenting = true
        let result = await AdMobService.shared.presentRewarded()
        isFullScreenAdPresenting = false
        if result == .granted { isNextInterstitialSuppressed = true }
        return result
    }
}

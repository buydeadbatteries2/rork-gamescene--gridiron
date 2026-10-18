import Foundation
import Observation
import UIKit
import GoogleMobileAds
import UserMessagingPlatform
import AppTrackingTransparency

// MARK: - AdMob engine
//
// The single Google Mobile Ads integration point. Owns: one-time SDK start,
// the UMP consent flow, ATT preparation, interstitial/rewarded preloading and
// presentation, and the retry/backoff policy. SwiftUI views never touch the
// Google SDK — they ask `AdManager` (the facade) which asks this service.
//
// Safety contracts:
// - Initialization happens exactly once, only with a valid app ID; a missing
//   production ID in RELEASE disables ads gracefully (never crashes, never
//   substitutes test units).
// - Ad requests happen only after UMP reports ads may be requested.
// - A rewarded grant flows only from Google's earned-reward callback.
// - Full-screen presentations are tracked so a present can never double-fire,
//   the Hall of Famer clock can be frozen for their duration, and achievement
//   popups wait until dismissal.
@MainActor
@Observable
final class AdMobService {
    static let shared = AdMobService()

    private(set) var isConfigured = false
    /// True only when this build has a valid app-level AdMob identifier.
    private(set) var isAdsSupported = false
    private(set) var canRequestAds = false
    private(set) var isInterstitialReady = false
    private(set) var isRewardedReady = false
    private(set) var isPresentingFullScreenAd = false
    private(set) var lastLoadError: String?
    private(set) var isPrivacyOptionsRequired = false
    private(set) var hasConsentGathered = false

    /// True when real ad requests are possible this session: a valid app
    /// identifier AND UMP consent allowing requests.
    var canServeAds: Bool { isAdsSupported && canRequestAds }

    private var interstitialAd: InterstitialAd?
    private var rewardedAd: RewardedAd?
    private var interstitialRetryTask: Task<Void, Never>?
    private var rewardedRetryTask: Task<Void, Never>?
    private var interstitialFailures = 0
    private var rewardedFailures = 0
    private var interstitialLoadedAt: Date?
    private var rewardedLoadedAt: Date?

    /// Called after every full-screen ad dismissal — AdManager unblocks the
    /// achievement popup queue there.
    var onFullScreenAdDismissed: (() -> Void)?

    // MARK: Ad unit IDs (build-selected)

    var bannerUnitID: String? {
        AdMobConfig.adUnitID(.banner, isDevelopmentBuild: AdManager.isDevelopmentBuild, injectedUnitIDs: Self.injectedUnitIDs)
    }
    var interstitialUnitID: String? {
        AdMobConfig.adUnitID(.interstitial, isDevelopmentBuild: AdManager.isDevelopmentBuild, injectedUnitIDs: Self.injectedUnitIDs)
    }
    var rewardedUnitID: String? {
        AdMobConfig.adUnitID(.rewarded, isDevelopmentBuild: AdManager.isDevelopmentBuild, injectedUnitIDs: Self.injectedUnitIDs)
    }

    /// The Rork build-injected production identifiers. They arrive through
    /// the app's Info.plist — the project's Info.plist carries `$(ADMOB_...)`
    /// placeholders that the build pipeline expands from the Rork secret
    /// variables. Nothing is ever hard-coded in source; an unexpanded or empty
    /// value simply disables that format (and the app ID disables ads).
    nonisolated private static let injectedAppID: String = {
        let raw = Bundle.main.object(forInfoDictionaryKey: "GADApplicationIdentifier") as? String ?? ""
        // An unexpanded build-setting placeholder must never reach the SDK.
        return raw.contains("$(") ? "" : raw
    }()

    nonisolated private static let injectedUnitIDs: [AdMobConfig.AdFormat: String] = {
        func injected(_ key: String) -> String {
            let raw = Bundle.main.object(forInfoDictionaryKey: key) as? String ?? ""
            return raw.contains("$(") ? "" : raw
        }
        return [
            .banner: injected("AdMobBannerUnitID"),
            .interstitial: injected("AdMobInterstitialUnitID"),
            .rewarded: injected("AdMobRewardedUnitID"),
        ]
    }()

    // MARK: Configuration (call exactly once, from the App's init)

    func configure(appID injected: String? = nil, injectedUnitIDs: [AdMobConfig.AdFormat: String]? = nil) {
        guard !isConfigured else { return }
        // Test hosts relaunch the app dozens of times per run; a live ad SDK
        // session per relaunch destabilizes the simulator harness.
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }
        isConfigured = true

        let resolvedAppID = AdMobConfig.appIdentifier(
            isDevelopmentBuild: AdManager.isDevelopmentBuild,
            injectedAppID: injected ?? Self.injectedAppID
        )
        guard MobileAdsStartGate.shouldStart(hasStarted: false, appIdentifier: resolvedAppID) else {
            // No valid app identifier: ads stay disabled for this build. The
            // game never blocks on it — the banner slot collapses and gate
            // flows resolve "unavailable" for free.
            isAdsSupported = false
            return
        }
        isAdsSupported = true
        MobileAds.shared.start()
        gatherConsentAndPrepareAds()
    }

    // MARK: Consent (UMP) + ATT

    /// Requests updated consent information every launch, presents the consent
    /// form when required, and only then prepares ad loading. ATT is requested
    /// once, only if undetermined, and is never a gate for gameplay or even
    /// for ads (non-IDFA ads remain privacy-compliant).
    private func gatherConsentAndPrepareAds() {
        Task { @MainActor in
            let parameters = RequestParameters()
            do {
                try await ConsentInformation.shared.requestConsentInfoUpdate(with: parameters)
            } catch {
                // Consent info failed: the previous session's status (if any)
                // still applies. Never blocks the game.
                lastLoadError = "consent: \(error.localizedDescription)"
            }

            await Self.requestTrackingAuthorizationIfNeeded()

            do {
                try await ConsentForm.loadAndPresentIfRequired(from: nil)
            } catch {
                lastLoadError = "consent form: \(error.localizedDescription)"
            }

            hasConsentGathered = true
            refreshConsentState()
            if canRequestAds {
                preloadInterstitial()
                preloadRewarded()
            }
        }
    }

    /// Refreshes the UMP-derived state used across the UI (Settings privacy
    /// entry point, ad-request gating).
    func refreshConsentState() {
        canRequestAds = ConsentInformation.shared.canRequestAds
        isPrivacyOptionsRequired =
            ConsentInformation.shared.privacyOptionsRequirementStatus == .required
    }

    /// ATT preparation: one prompt, only when the user hasn't been asked.
    /// A denial never blocks gameplay and never blocks non-IDFA ad requests.
    private static func requestTrackingAuthorizationIfNeeded() async {
        guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else { return }
        _ = await ATTrackingManager.requestTrackingAuthorization()
    }

    /// Settings → PRIVACY OPTIONS: Google's form, only when the consent
    /// configuration says an entry point is required.
    func showPrivacyOptionsForm() async throws {
        try await ConsentForm.presentPrivacyOptionsForm(from: nil)
        refreshConsentState()
    }

    // MARK: Interstitial

    /// Preloads an interstitial if none is ready. Safe to call repeatedly —
    /// a load in flight (or a retry pending) short-circuits.
    func preloadInterstitial() {
        guard isAdsSupported, canRequestAds else { return }
        guard interstitialAd == nil, interstitialRetryTask == nil else { return }
        guard let unit = interstitialUnitID else { return }
        Task { @MainActor in
            do {
                interstitialAd = try await InterstitialAd.load(with: unit, request: Request())
                interstitialFailures = 0
                isInterstitialReady = interstitialAd != nil
                interstitialLoadedAt = .now
            } catch {
                isInterstitialReady = false
                lastLoadError = "interstitial: \(error.localizedDescription)"
                scheduleInterstitialRetry()
            }
        }
    }

    private func scheduleInterstitialRetry() {
        interstitialFailures += 1
        guard let delay = AdRetryBackoff.delay(afterConsecutiveFailures: interstitialFailures) else { return }
        interstitialRetryTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            self?.interstitialRetryTask = nil
            self?.preloadInterstitial()
        }
    }

    /// Presents a preloaded interstitial. `.shown` only when an ad actually
    /// played; `.unavailable` when nothing was presented (no ad, no consent,
    /// presentation failure) — callers continue for free in every `.unavailable`
    /// path. Preloads the next interstitial after dismissal.
    func presentInterstitial() async -> ForcedAdResult {
        guard isAdsSupported, canRequestAds, !isPresentingFullScreenAd, let ad = interstitialAd else {
            return .unavailable
        }
        // One-time-use object: drop it before presenting so nothing can show
        // it twice.
        interstitialAd = nil
        isInterstitialReady = false

        isPresentingFullScreenAd = true
        AudioManager.shared.pauseMusic()
        let played = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            let coordinator = FullScreenContentCoordinator(
                onDismissed: {
                    Task { @MainActor in
                        let didPlay = AdMobService.shared.interstitialPresentationEnded()
                        continuation.resume(returning: didPlay)
                    }
                },
                onFailed: {
                    Task { @MainActor in
                        let didPlay = AdMobService.shared.interstitialPresentationEnded()
                        continuation.resume(returning: didPlay)
                    }
                }
            )
            ad.fullScreenContentDelegate = coordinator
            self.activeCoordinator = coordinator
            ad.present(from: Self.topViewController())
        }
        return played ? .shown : .unavailable
    }

    /// Runs the shared end-of-full-screen-presentation bookkeeping and reports
    /// whether the ad actually played.
    private func interstitialPresentationEnded() -> Bool {
        isPresentingFullScreenAd = false
        AudioManager.shared.resumeMusic()
        onFullScreenAdDismissed?()
        preloadInterstitial()
        return true
    }

    // MARK: Rewarded

    /// Preloads a rewarded ad if none is ready.
    func preloadRewarded() {
        guard isAdsSupported, canRequestAds else { return }
        guard rewardedAd == nil, rewardedRetryTask == nil else { return }
        guard let unit = rewardedUnitID else { return }
        Task { @MainActor in
            do {
                rewardedAd = try await RewardedAd.load(with: unit, request: Request())
                rewardedFailures = 0
                isRewardedReady = rewardedAd != nil
                rewardedLoadedAt = .now
            } catch {
                isRewardedReady = false
                lastLoadError = "rewarded: \(error.localizedDescription)"
                scheduleRewardedRetry()
            }
        }
    }

    private func scheduleRewardedRetry() {
        rewardedFailures += 1
        guard let delay = AdRetryBackoff.delay(afterConsecutiveFailures: rewardedFailures) else { return }
        rewardedRetryTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            self?.rewardedRetryTask = nil
            self?.preloadRewarded()
        }
    }

    /// Presents a preloaded rewarded ad. `.granted` flows ONLY from Google's
    /// earned-reward callback (the completion of `present(from:)`); an early
    /// close, load failure or presentation failure resolves `.dismissed` and
    /// the caller grants nothing. Preloads the next rewarded ad afterwards.
    func presentRewarded() async -> RewardedAdResult {
        guard isAdsSupported, canRequestAds, !isPresentingFullScreenAd, let ad = rewardedAd else {
            return .dismissed
        }
        rewardedAd = nil
        isRewardedReady = false

        isPresentingFullScreenAd = true
        AudioManager.shared.pauseMusic()
        let rewardBox = RewardBox()
        let result = await withCheckedContinuation { (continuation: CheckedContinuation<RewardedAdResult, Never>) in
            let coordinator = FullScreenContentCoordinator(
                onDismissed: {
                    Task { @MainActor in
                        let outcome = AdMobService.shared.rewardedPresentationEnded(rewardBox: rewardBox)
                        continuation.resume(returning: outcome)
                    }
                },
                onFailed: {
                    Task { @MainActor in
                        let outcome = AdMobService.shared.rewardedPresentationEnded(rewardBox: rewardBox)
                        continuation.resume(returning: outcome)
                    }
                }
            )
            ad.fullScreenContentDelegate = coordinator
            self.activeCoordinator = coordinator
            // Google's earned-reward callback — the ONLY grant point.
            ad.present(from: Self.topViewController()) {
                _ = rewardBox.earn()
            }
        }
        return result
    }

    /// Runs the shared end-of-full-screen-presentation bookkeeping and maps
    /// the reward box to the caller's outcome.
    private func rewardedPresentationEnded(rewardBox: RewardBox) -> RewardedAdResult {
        isPresentingFullScreenAd = false
        AudioManager.shared.resumeMusic()
        onFullScreenAdDismissed?()
        preloadRewarded()
        return rewardBox.didEarn ? .granted : .dismissed
    }

    // MARK: Lifecycle

    /// Foregrounding: expired cached ads (≈1h lifetime) are replaced, and a
    /// paused retry schedule re-arms. Backgrounding cancels in-flight retries
    /// so nothing fires while suspended.
    func handleScenePhase(active: Bool) {
        guard isAdsSupported, canRequestAds else { return }
        if active {
            refreshConsentState()
            if let loadedAt = interstitialLoadedAt, Date().timeIntervalSince(loadedAt) > 3_000 {
                interstitialAd = nil
                isInterstitialReady = false
            }
            if let loadedAt = rewardedLoadedAt, Date().timeIntervalSince(loadedAt) > 3_000 {
                rewardedAd = nil
                isRewardedReady = false
            }
            preloadInterstitial()
            preloadRewarded()
        } else {
            interstitialRetryTask?.cancel()
            interstitialRetryTask = nil
            rewardedRetryTask?.cancel()
            rewardedRetryTask = nil
        }
    }

    // MARK: Presentation plumbing

    /// Keeps the current delegate coordinator alive for the presentation.
    private var activeCoordinator: FullScreenContentCoordinator?

    @MainActor
    private static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive } ?? UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        var root = scene?.keyWindow?.rootViewController
        while let presented = root?.presentedViewController { root = presented }
        return root
    }
}

// MARK: - Reward box
//
// The thread-safe grant point for one rewarded presentation: Google's
// earn-reward callback fires on the SDK's schedule; `earn` returns true
// exactly once per presentation.
final class RewardBox: @unchecked Sendable {
    private let lock = NSLock()
    nonisolated(unsafe) private var earned = false

    nonisolated func earn() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !earned else { return false }
        earned = true
        return true
    }

    nonisolated var didEarn: Bool {
        lock.lock()
        defer { lock.unlock() }
        return earned
    }
}

// MARK: - Full-screen delegate coordinator
//
// Bridges the Google delegate callbacks into exactly one continuation resume:
// presentation failure and dismissal can both fire; only the first counts
// (lock-guarded), so a quarter can never advance twice and a reward can never
// double.
final class FullScreenContentCoordinator: NSObject, FullScreenContentDelegate, @unchecked Sendable {
    nonisolated private let lock = NSLock()
    nonisolated(unsafe) private var hasFinished = false
    nonisolated private let onDismissed: @Sendable () -> Void
    nonisolated private let onFailed: @Sendable () -> Void

    nonisolated init(onDismissed: @escaping @Sendable () -> Void, onFailed: @escaping @Sendable () -> Void) {
        self.onDismissed = onDismissed
        self.onFailed = onFailed
    }

    nonisolated private func finish(_ path: @escaping @Sendable () -> Void) {
        lock.lock()
        let isFirst = !hasFinished
        hasFinished = true
        lock.unlock()
        guard isFirst else { return }
        path()
    }

    nonisolated func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        finish(onDismissed)
    }

    nonisolated func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        finish(onFailed)
    }
}

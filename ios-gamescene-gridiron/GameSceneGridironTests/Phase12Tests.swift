import Testing
import Foundation
@testable import GameSceneGridiron

// MARK: - Phase 12: real AdMob integration
//
// The pure contract of the ad layer: identifier selection (Google test units
// in DEBUG, injected production units in RELEASE, never mixed), the Remove
// Forced Ads suppression rules, the forced-gate economics, rewarded-grant
// safety and full-screen-ad lifecycle behavior (clock, popups, duplicates).

@MainActor
struct Phase12Tests {

    private var productionUnits: [AdMobConfig.AdFormat: String] {
        [
            .banner: "ca-app-pub-111111111111/2222222201",
            .interstitial: "ca-app-pub-111111111111/2222222202",
            .rewarded: "ca-app-pub-111111111111/2222222203",
        ]
    }

    // MARK: Configuration (spec §31, tests 1–6)

    @Test func debugSelectsGoogleTestBannerID() {
        #expect(AdMobConfig.adUnitID(.banner, isDevelopmentBuild: true, injectedUnitIDs: productionUnits)
            == AdMobConfig.googleTestUnitIDs[.banner])
    }

    @Test func debugSelectsGoogleTestInterstitialID() {
        #expect(AdMobConfig.adUnitID(.interstitial, isDevelopmentBuild: true, injectedUnitIDs: productionUnits)
            == AdMobConfig.googleTestUnitIDs[.interstitial])
    }

    @Test func debugSelectsGoogleTestRewardedID() {
        #expect(AdMobConfig.adUnitID(.rewarded, isDevelopmentBuild: true, injectedUnitIDs: productionUnits)
            == AdMobConfig.googleTestUnitIDs[.rewarded])
    }

    @Test func releaseSelectsInjectedProductionIDs() {
        for format in AdMobConfig.AdFormat.allCases {
            #expect(AdMobConfig.adUnitID(format, isDevelopmentBuild: false, injectedUnitIDs: productionUnits)
                == productionUnits[format])
        }
        // The app-level identifier: an injected production app ID wins.
        #expect(AdMobConfig.appIdentifier(isDevelopmentBuild: false, injectedAppID: "ca-app-pub-111111111111~9999999999")
            == "ca-app-pub-111111111111~9999999999")
    }

    @Test func releaseNeverFallsBackToTestUnitIDs() {
        // Missing / empty / malformed / a Google test unit injected by mistake —
        // every one disables the format in RELEASE rather than substitute.
        for format in AdMobConfig.AdFormat.allCases {
            #expect(AdMobConfig.adUnitID(format, isDevelopmentBuild: false, injectedUnitIDs: [:]) == nil)
            #expect(AdMobConfig.adUnitID(format, isDevelopmentBuild: false, injectedUnitIDs: [format: ""]) == nil)
            #expect(AdMobConfig.adUnitID(format, isDevelopmentBuild: false, injectedUnitIDs: [format: "garbage"]) == nil)
            #expect(AdMobConfig.adUnitID(format, isDevelopmentBuild: false, injectedUnitIDs: [format: "$(ADMOB_UNEXPANDED)"]) == nil)
            #expect(AdMobConfig.adUnitID(format, isDevelopmentBuild: false, injectedUnitIDs: AdMobConfig.googleTestUnitIDs) == nil)
        }
        // And the RELEASE app identifier has no test fallback either.
        #expect(AdMobConfig.appIdentifier(isDevelopmentBuild: false, injectedAppID: "") == nil)
        #expect(AdMobConfig.appIdentifier(isDevelopmentBuild: false, injectedAppID: AdMobConfig.googleTestAppID) == nil)
    }

    @Test func mobileAdsStartsExactlyOnceAndOnlyWithAppID() {
        // Once-only, and never without a valid app-level identifier.
        #expect(MobileAdsStartGate.shouldStart(hasStarted: false, appIdentifier: "ca-app-pub-1~2"))
        #expect(!MobileAdsStartGate.shouldStart(hasStarted: true, appIdentifier: "ca-app-pub-1~2"))
        #expect(!MobileAdsStartGate.shouldStart(hasStarted: false, appIdentifier: nil))

        // The App ID (…) vs ad-unit ID (/…) shapes are never confused.
        #expect(AdMobConfig.isAppIdentifier("ca-app-pub-3940256099942544~3347511713"))
        #expect(!AdMobConfig.isAppIdentifier("ca-app-pub-3940256099942544/2435281174"))
        #expect(AdMobConfig.isUnitIdentifier("ca-app-pub-3940256099942544/2435281174"))
        #expect(!AdMobConfig.isUnitIdentifier("ca-app-pub-3940256099942544~3347511713"))
    }

    // MARK: Remove Forced Ads (spec §32, tests 7–10)

    @Test func removeAdsSuppressesBannerAds() {
        #expect(BannerAdPolicy.visibility(isAdFree: true, isBannerLoaded: true, isDevelopmentBuild: false) == .hidden)
        #expect(BannerAdPolicy.visibility(isAdFree: true, isBannerLoaded: false, isDevelopmentBuild: false) == .hidden)
    }

    @Test func removeAdsSuppressesForcedInterstitials() {
        #expect(AdGatePolicy.decision(quarterWon: true, isOvertimeTransition: false, isAdFree: true, forcedAdsShown: 0) == .none)
        #expect(AdGatePolicy.decision(quarterWon: true, isOvertimeTransition: true, isAdFree: true, forcedAdsShown: 0) == .none)
    }

    @Test func removeAdsNeverChargesTransitionGameBalls() {
        // With the entitlement active the gate never fires — the skip-fee path
        // (2 or 3 Game Balls) is unreachable by construction.
        let wallet = PlayerWallet(defaults: UserDefaults(suiteName: "phase12-nocharge.\(UUID().uuidString)")!)
        _ = wallet.earn(amount: 50, kind: .matchReward)
        let balance = wallet.gameBalls

        let decision = AdGatePolicy.decision(quarterWon: true, isOvertimeTransition: true, isAdFree: true, forcedAdsShown: 0)
        #expect(decision == .none)
        #expect(wallet.gameBalls == balance)
    }

    // MARK: Forced-gate economics (spec §33, tests 11–17)

    @Test func trainingCaseHasNoForcedAd() {
        #expect(AdGatePolicy.decision(quarterWon: true, isOvertimeTransition: false, isAdFree: false, forcedAdsShown: 0, isTraining: true) == .none)
        #expect(AdGatePolicy.decision(quarterWon: true, isOvertimeTransition: true, isAdFree: false, forcedAdsShown: 0, isTraining: true) == .none)
    }

    @Test func firstRegularSeasonGameHasNoForcedAd() {
        #expect(AdGatePolicy.decision(quarterWon: true, isOvertimeTransition: false, isAdFree: false, forcedAdsShown: 0, isFirstSeasonGame: true) == .none)
    }

    @Test func wonRegulationQuarterCanGate() {
        #expect(AdGatePolicy.decision(quarterWon: true, isOvertimeTransition: false, isAdFree: false, forcedAdsShown: 0)
            == .forced(skipCost: EconomyConfig.standard.regulationAdSkipCost))
    }

    @Test func lostQuarterNeverRequiresInterstitial() {
        #expect(AdGatePolicy.decision(quarterWon: false, isOvertimeTransition: false, isAdFree: false, forcedAdsShown: 0) == .none)
    }

    @Test func regulationSkipCostsExactlyTwoGameBalls() {
        #expect(EconomyConfig.standard.regulationAdSkipCost == 2)
        #expect(AdGatePolicy.decision(quarterWon: true, isOvertimeTransition: false, isAdFree: false, forcedAdsShown: 1).forcedSkipCost == 2)
    }

    @Test func overtimeSkipCostsExactlyThreeGameBalls() {
        #expect(EconomyConfig.standard.overtimeAdSkipCost == 3)
        #expect(AdGatePolicy.decision(quarterWon: true, isOvertimeTransition: true, isAdFree: false, forcedAdsShown: 1).forcedSkipCost == 3)
    }

    @Test func forcedAdMaximumStaysTwoPerGame() {
        #expect(EconomyConfig.standard.maxForcedAdsPerGame == 2)
        #expect(AdGatePolicy.decision(quarterWon: true, isOvertimeTransition: true, isAdFree: false, forcedAdsShown: 2) == .none)
    }

    // MARK: Gate completion bookkeeping (spec §33 tests 18–20, §35 test 28)

    @Test func unavailableInterstitialContinuesForFree() {
        let matchViewModel = MatchViewModel(seasonNumber: 2, week: 2)
        matchViewModel.beginGateAdFlow()
        let wallet = PlayerWallet.shared
        let balanceBefore = wallet.gameBalls
        let forcedBefore = wallet.forcedAdCount(for: matchViewModel.matchID.uuidString)

        // Nothing was presented: the player continues free — no charge, no cap.
        #expect(matchViewModel.finishGateAdAttempt(with: .unavailable))
        #expect(wallet.gameBalls == balanceBefore)
        #expect(wallet.forcedAdCount(for: matchViewModel.matchID.uuidString) == forcedBefore)
        #expect(matchViewModel.phase == .quarterIntro)
    }

    @Test func shownInterstitialCountsExactlyOnce() {
        let matchViewModel = MatchViewModel(seasonNumber: 2, week: 2)
        matchViewModel.beginGateAdFlow()
        let wallet = PlayerWallet.shared
        let balanceBefore = wallet.gameBalls
        let forcedBefore = wallet.forcedAdCount(for: matchViewModel.matchID.uuidString)

        #expect(matchViewModel.finishGateAdAttempt(with: .shown))
        #expect(wallet.forcedAdCount(for: matchViewModel.matchID.uuidString) == forcedBefore + 1)
        #expect(wallet.gameBalls == balanceBefore)
    }

    @Test func duplicateGateCompletionIsIgnored() {
        let matchViewModel = MatchViewModel(seasonNumber: 2, week: 2)
        let wallet = PlayerWallet.shared
        let forcedBefore = wallet.forcedAdCount(for: matchViewModel.matchID.uuidString)

        matchViewModel.beginGateAdFlow()
        #expect(matchViewModel.finishGateAdAttempt(with: .shown))
        // A stray second completion (foreground replay, double callback) can
        // neither record a second ad nor advance the flow twice.
        #expect(!matchViewModel.finishGateAdAttempt(with: .shown))
        #expect(wallet.forcedAdCount(for: matchViewModel.matchID.uuidString) == forcedBefore + 1)
        #expect(matchViewModel.phase == .quarterIntro)
    }

    // MARK: Retry backoff (spec §22)

    @Test func loadRetriesBackOffAndStop() {
        #expect(AdRetryBackoff.delay(afterConsecutiveFailures: 0) == nil)
        #expect(AdRetryBackoff.delay(afterConsecutiveFailures: 1) == 5)
        #expect(AdRetryBackoff.delay(afterConsecutiveFailures: 2) == 10)
        #expect(AdRetryBackoff.delay(afterConsecutiveFailures: 3) == 20)
        #expect(AdRetryBackoff.delay(afterConsecutiveFailures: 6) == nil)
        #expect(AdRetryBackoff.delay(afterConsecutiveFailures: 5)! <= AdRetryBackoff.maxDelay)
    }

    // MARK: Rewarded grants (spec §34, tests 21–26)

    @Test func rewardIsGrantedOnlyFromEarnedCallback() {
        var session = RewardedSession()
        let firstEarn = session.markRewardEarned()
        #expect(firstEarn)
        let secondEarn = session.markRewardEarned()
        #expect(!secondEarn)
    }

    @Test func dismissedBeforeRewardGrantsNothing() {
        var session = RewardedSession()
        let end = session.markEnded()
        #expect(end)
        let earn = session.markRewardEarned()
        #expect(!earn)
    }

    @Test func noDuplicateRewardAfterForegrounding() {
        var session = RewardedSession()
        let earn = session.markRewardEarned()
        #expect(earn)
        let end = session.markEnded()
        #expect(end)
        // A replayed earn/terminal callback after the session ended is inert.
        let replayedEarn = session.markRewardEarned()
        #expect(!replayedEarn)
        let replayedEnd = session.markEnded()
        #expect(!replayedEnd)
    }

    @Test func lastChanceRescueGrantsExactlyOncePerQuarter() {
        let wallet = PlayerWallet(defaults: UserDefaults(suiteName: "phase12-rescue.\(UUID().uuidString)")!)
        let key = "rescue-\(UUID().uuidString)"
        #expect(wallet.canUseVideoRescue(for: key))
        let firstUse = wallet.markVideoRescueUsed(for: key)
        #expect(firstUse)
        #expect(!wallet.canUseVideoRescue(for: key))
        let secondUse = wallet.markVideoRescueUsed(for: key)
        #expect(!secondUse)
    }

    @Test func unavailableRewardedAdIsASafeFailure() async {
        let wallet = PlayerWallet.shared
        let balanceBefore = wallet.gameBalls

        let adManager = AdManager(simulatesAdsWhenUnavailable: false)
        let result = await adManager.showRewarded(.lastChanceLife)

        // Nothing granted, nothing spent, nothing counted — the overlay's
        // alternatives stay available.
        #expect(result == .dismissed)
        #expect(wallet.gameBalls == balanceBefore)
        #expect(!adManager.isRewardedAdShowing)
        #expect(!adManager.isFullScreenAdPresenting)
    }

    @Test func removeAdsUsersCanStillWatchRewardedAds() async {
        // The rewarded path never consults the entitlement: even with Remove
        // Ads owned, a voluntary rewarded video still resolves granted.
        let adManager = AdManager(simulatesAdsWhenUnavailable: true)
        let result = await adManager.showRewarded(.hint)
        #expect(result == .granted)
        #expect(!adManager.isFullScreenAdPresenting)
    }

    // MARK: Lifecycle (spec §35, tests 29–32)

    @Test func playClockFreezesDuringFullScreenAds() {
        let clock = PlayClockController(duration: 40, autoTicks: false)
        clock.startFresh()
        clock.tick(by: 5)
        #expect(clock.remaining == 35)

        // The ad comes up: frozen, never consuming solving time.
        clock.suspend(reason: .ad)
        #expect(clock.phase == .suspended)
        clock.tick(by: 10)
        #expect(clock.remaining == 35)

        // Double-suspend is idempotent; one resume restores running state.
        clock.suspend(reason: .ad)
        clock.resume(reason: .ad)
        #expect(clock.phase == .running)
        #expect(clock.remaining == 35)
    }

    @Test func achievementPopupWaitsForFullScreenAdToEnd() {
        var isBlocked = true
        let manager = AchievementManager(
            defaults: UserDefaults(suiteName: "phase12-popup.\(UUID().uuidString)")!,
            isPresentationBlocked: { isBlocked }
        )
        manager.noteQuarterSolved(livesLost: 0, hintsUsed: 0, isOvertime: false, difficulty: .pro)

        // While the ad is up: queued, never presented over it.
        #expect(manager.currentPopup == nil)
        isBlocked = false
        manager.presentNextPopupIfSafe()
        #expect(manager.currentPopup != nil)
    }

    @Test func bannerSlotFollowsAdaptiveDimensions() {
        let dimensions = AdMobBannerView.adaptiveDimensions(for: 343)
        #expect(dimensions.width > 0)
        #expect(dimensions.width <= 343 + 0.5)
        // Anchored adaptive banners cap at 90pt tall (15% of screen height).
        #expect(dimensions.height >= 50)
        #expect(dimensions.height <= 90)
    }

    @Test func bannerSlotCollapsesCleanlyWhenUnavailable() {
        // No loaded ad in release: nothing at all — no fake strip.
        #expect(BannerAdPolicy.visibility(isAdFree: false, isBannerLoaded: false, isDevelopmentBuild: false) == .hidden)
        // In development, the clearly labeled layout placeholder stands in.
        #expect(BannerAdPolicy.visibility(isAdFree: false, isBannerLoaded: false, isDevelopmentBuild: true) == .developmentPlaceholder)
        // A loaded real ad gets its slot.
        #expect(BannerAdPolicy.visibility(isAdFree: false, isBannerLoaded: true, isDevelopmentBuild: false) == .loadedBanner)
    }
}

extension AdGateDecision {
    /// Unwraps the skip cost for concise assertions.
    var forcedSkipCost: Int? {
        if case .forced(let skipCost) = self { return skipCost }
        return nil
    }
}

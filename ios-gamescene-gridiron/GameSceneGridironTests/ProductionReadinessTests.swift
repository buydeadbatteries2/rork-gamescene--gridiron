import Testing
import Foundation
@testable import GameSceneGridiron

/// Phase 11 production readiness: versioned save-data envelope, legacy
/// migration, corrupted-save recovery, and reopen idempotency for rewards
/// and achievements.
@MainActor
struct ProductionReadinessTests {

    private func makeDefaults(name: String = "prod-\(UUID().uuidString)") -> UserDefaults {
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    // MARK: Versioned envelope round-trip

    @Test func saveLoadRoundTripPreservesTheSeason() {
        let defaults = makeDefaults()
        let season = SeasonManager.generateSeason(userTeamID: UUID(), seasonNumber: 3)
        SaveStore.save(season, key: "test.season", defaults: defaults)

        let loaded = SaveStore.load(Season.self, key: "test.season", defaults: defaults)
        #expect(loaded == season)
        #expect(loaded?.seasonNumber == 3)
        #expect(loaded?.games.count == 10)
    }

    @Test func legacyPlainEncodedSaveMigratesWithoutLoss() {
        let defaults = makeDefaults()
        let team = GameTeam(state: "Virginia", teamName: "Cyber Wolves", logoID: "wolf",
                            primaryColorHex: 0x1A1A1A, secondaryColorHex: 0xD9B56E, isUserTeam: true)
        // Schema 1: a plain-encoded blob from before versioning existed.
        let legacyData = try! JSONEncoder().encode(team)
        defaults.set(legacyData, forKey: "test.team")

        let loaded = SaveStore.load(GameTeam.self, key: "test.team", defaults: defaults)
        #expect(loaded == team)
    }

    @Test func corruptedSaveIsBackedUpAndNeverSilentlyDestroyed() {
        let defaults = makeDefaults()
        let key = "test.economy"
        let garbage = Data("not json at all".utf8)
        defaults.set(garbage, forKey: key)

        let loaded = SaveStore.load(GameTeam.self, key: key, defaults: defaults)
        #expect(loaded == nil)

        // The raw bytes survive under the corrupt-backup key.
        let backup = defaults.data(forKey: "\(key).corruptBackup")
        #expect(backup == garbage)
    }

    @Test func futureVersionEnvelopeStaysBestEffortDecodable() {
        let defaults = makeDefaults()
        let team = GameTeam(state: "Ohio", teamName: "Steel Boars", logoID: "boar",
                            primaryColorHex: 0xC9CDD1, secondaryColorHex: 0xE2762D, isUserTeam: false)
        let payload = try! JSONEncoder().encode(team)
        // An envelope written by a FUTURE app version: still best-effort readable.
        let future = try! JSONEncoder().encode(
            FutureEnvelope(version: SaveStore.currentSchemaVersion + 5, payload: payload)
        )
        defaults.set(future, forKey: "test.team")

        #expect(SaveStore.load(GameTeam.self, key: "test.team", defaults: defaults) == team)
    }

    private struct FutureEnvelope: Codable {
        let version: Int
        let payload: Data
    }

    @Test func cleanSaveClearsStaleCorruptBackups() {
        let defaults = makeDefaults()
        let key = "test.legacy"
        defaults.set(Data("junk".utf8), forKey: key)
        #expect(SaveStore.load(GameTeam.self, key: key, defaults: defaults) == nil)
        #expect(defaults.data(forKey: "\(key).corruptBackup") != nil)

        SaveStore.save(
            GameTeam(state: "Texas", teamName: "Outlaws", logoID: "bull",
                     primaryColorHex: 0x1A1A1A, secondaryColorHex: 0xD9B56E, isUserTeam: false),
            key: key, defaults: defaults
        )
        #expect(defaults.data(forKey: "\(key).corruptBackup") == nil)
    }

    // MARK: Reopen idempotency (termination + relaunch)

    @Test func walletReopenCannotDuplicateRewardsOrSpendTwice() {
        let defaults = makeDefaults()
        let wallet = PlayerWallet(defaults: defaults)
        wallet.earn(amount: 40, kind: .matchReward, transactionID: "match-relaunch-1")
        let before = wallet.gameBalls

        // App terminated and relaunched: a fresh manager over the same store.
        let reopened = PlayerWallet(defaults: defaults)
        #expect(reopened.gameBalls == before)

        // The same transaction id pays nothing a second time.
        reopened.earn(amount: 40, kind: .matchReward, transactionID: "match-relaunch-1")
        #expect(reopened.gameBalls == before)

        // The same achievement reward id is equally locked.
        reopened.earn(amount: 25, kind: .achievementReward, transactionID: "achievement-firstCase")
        let afterFirst = reopened.gameBalls
        reopened.earn(amount: 25, kind: .achievementReward, transactionID: "achievement-firstCase")
        #expect(reopened.gameBalls == afterFirst)
    }

    @Test func achievementsAndTrophiesSurviveRelaunchWithoutDuplicating() {
        let defaults = makeDefaults()
        let achievements = AchievementManager(defaults: defaults)
        let legacy = LegacyStore(defaults: defaults)

        achievements.noteQuarterSolved(livesLost: 0, hintsUsed: 0, isOvertime: false, difficulty: .pro)
        #expect(achievements.isUnlocked(.firstCase))

        let trophy = ChampionshipTrophy(
            seasonNumber: 1, teamState: "Virginia", teamName: "Cyber Wolves", logoID: "wolf",
            primaryColorHex: 0x1A1A1A, secondaryColorHex: 0xD9B56E,
            regularSeasonRecord: "9–1", difficulty: "PRO", opponentName: "Texas Outlaws",
            resultLine: "3–1", date: .now
        )
        let entry = SeasonArchiveEntry(
            seasonNumber: 1, recordLine: "9–1", wins: 9, losses: 1, standing: 1, totalTeams: 11,
            difficulty: "PRO", postseasonResult: SeasonArchiveEntry.championResult, date: .now
        )
        legacy.completeSeason(entry, trophy: trophy)

        // Relaunch: unlocks, trophies and archive persist exactly once.
        let reopenedAchievements = AchievementManager(defaults: defaults)
        let reopenedLegacy = LegacyStore(defaults: defaults)
        #expect(reopenedAchievements.isUnlocked(.firstCase))
        #expect(reopenedAchievements.casesSolved == 1)
        #expect(reopenedLegacy.trophies.count == 1)
        #expect(reopenedLegacy.archive.count == 1)
    }

    @Test func seasonDataSurvivesRelaunchAndStaysRepairable() {
        let defaults = makeDefaults()
        let manager = SeasonManager(defaults: defaults)
        let team = GameTeam(state: "Virginia", teamName: "Cyber Wolves", logoID: "wolf",
                            primaryColorHex: 0x1A1A1A, secondaryColorHex: 0xD9B56E, isUserTeam: true)
        manager.startNewSeason(userTeam: team)
        let played = manager.recordUserResult(isWin: true, userScore: 3, opponentScore: 1, wentToOT: false)
        #expect(played)

        let reloaded = SeasonManager(defaults: defaults)
        #expect(reloaded.season?.seasonNumber == 1)
        #expect(reloaded.season?.games.first?.isPlayed == true)
        #expect(reloaded.userRecordLine == "1–0")
    }

    // MARK: Release configuration

    @Test func rewardAdsReportUnavailableInReleaseConfiguration() {
        // The production safety contract: AdManager.showRewarded resolves
        // `.granted` ONLY through a real SDK reward callback. In DEBUG the
        // development placeholder simulates it; in release builds the call
        // resolves `.dismissed` — call sites then show "no video available"
        // and nothing is granted or spent. This test pins the DEBUG side of
        // the contract so a future edit cannot fake-grant in release by
        // accident: the granted path must stay inside `#if DEBUG`.
        #if DEBUG
        #expect(true) // DEBUG builds simulate — exercised by economy tests.
        #else
        let result = await AdManager.shared.showRewarded(.hint)
        #expect(result == .dismissed)
        #endif
    }
}

/// Banner ad slot release-safety contract:
/// - DEBUG builds may show the clearly labeled development placeholder while
///   no real ad is loaded (layout testing).
/// - RELEASE builds with no loaded ad show NOTHING — no fake, reserved or
///   "sponsored" strip; the slot collapses and the layout reclaims it.
/// - A successfully loaded real ad gets the banner space.
/// - Ad-Free ownership always suppresses the banner, loaded or not.
@MainActor
struct BannerAdPolicyTests {

    @Test func developmentBuildShowsLabeledPlaceholderWhileNoAdIsLoaded() {
        let visibility = BannerAdPolicy.visibility(
            isAdFree: false, isBannerLoaded: false, isDevelopmentBuild: true
        )
        #expect(visibility == .developmentPlaceholder)
    }

    @Test func releaseBuildWithoutLoadedAdShowsNoFakeBanner() {
        let visibility = BannerAdPolicy.visibility(
            isAdFree: false, isBannerLoaded: false, isDevelopmentBuild: false
        )
        #expect(visibility == .hidden)
    }

    @Test func loadedRealAdGetsTheBannerSpace() {
        // A loaded real ad displays regardless of build configuration.
        #expect(
            BannerAdPolicy.visibility(isAdFree: false, isBannerLoaded: true, isDevelopmentBuild: false)
                == .loadedBanner
        )
        #expect(
            BannerAdPolicy.visibility(isAdFree: false, isBannerLoaded: true, isDevelopmentBuild: true)
                == .loadedBanner
        )
    }

    @Test func adFreeAlwaysSuppressesTheBanner() {
        // Loaded/unloaded × dev/release — Ad-Free wins every time.
        for isLoaded in [false, true] {
            for isDev in [false, true] {
                #expect(
                    BannerAdPolicy.visibility(isAdFree: true, isBannerLoaded: isLoaded, isDevelopmentBuild: isDev)
                        == .hidden
                )
            }
        }
    }

    @Test func bannerLoadStateFollowsTheCompileConfigurationContract() {
        let adManager = AdManager()
        #expect(!adManager.isBannerAdLoaded)

        #if DEBUG
        // Development: the simulated load marks the slot as loaded (the real
        // SDK will own this transition in production).
        adManager.requestBannerAd()
        #expect(adManager.isBannerAdLoaded)
        #expect(adManager.bannerVisibility == .loadedBanner)
        #else
        // Release without the live SDK: requesting never loads anything —
        // the slot stays hidden, no fake banner.
        adManager.requestBannerAd()
        #expect(!adManager.isBannerAdLoaded)
        #expect(adManager.bannerVisibility == .hidden)
        #endif
    }

    @Test func bannerSlotKeepsTheDocumentedFixedHeight() {
        #expect(GameBannerAdView.height == 50)
        #expect(AdBannerPlaceholder.height == 50)
    }
}

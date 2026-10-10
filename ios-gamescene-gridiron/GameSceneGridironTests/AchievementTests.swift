import Testing
import Foundation
@testable import GameSceneGridiron

/// Phase 10 achievements, trophies and franchise legacy: unlock conditions,
/// progress, idempotent one-time rewards, popup queueing, persistent
/// historical snapshots, win streaks, player honors and season preservation.
@MainActor
struct AchievementTests {

    // MARK: Helpers

    private func makeDefaults(name: String = "ach-\(UUID().uuidString)") -> UserDefaults {
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    private func makeManager() -> AchievementManager {
        AchievementManager(defaults: makeDefaults())
    }

    private func makeLegacyStore() -> LegacyStore {
        LegacyStore(defaults: makeDefaults())
    }

    /// A finished regulation game with the given quarters solved.
    private func makeMatch(
        solvedQuarters: Set<Int> = [0, 1, 2],
        wrongPlacements: Int = 0,
        wentToOvertime: Bool = false,
        overtimeSolved: Bool = false
    ) -> GameMatch {
        var match = GameMatch.fresh()
        for index in 0..<4 {
            match.recordQuarter(
                index: index,
                label: "Q\(index + 1)",
                isOvertime: false,
                outcome: solvedQuarters.contains(index) ? .solved : .failed,
                correctPlacements: 4,
                wrongPlacements: wrongPlacements,
                livesLost: 0,
                hintsUsed: 0
            )
        }
        if wentToOvertime {
            match.recordQuarter(
                index: 4,
                label: "OT",
                isOvertime: true,
                outcome: overtimeSolved ? .solved : .failed,
                correctPlacements: 4,
                wrongPlacements: 0,
                livesLost: 0,
                hintsUsed: 0
            )
        }
        return match
    }

    private func makeSeasonResult(
        seasonNumber: Int = 1,
        qualified: Bool,
        semifinalWin: Bool,
        reachedChampionship: Bool,
        wonChampionship: Bool
    ) -> SeasonResult {
        SeasonResult(
            seasonNumber: seasonNumber,
            finalRecord: "9–1",
            finalStanding: 1,
            totalTeams: 11,
            qualifiedForPlayoffs: qualified,
            semifinalOutcome: qualified ? (semifinalWin ? .win : .loss) : nil,
            reachedChampionship: reachedChampionship,
            championshipOutcome: reachedChampionship ? (wonChampionship ? .win : .loss) : nil,
            wonChampionship: wonChampionship,
            championID: nil
        )
    }

    // MARK: 1. Unlock only when conditions are met

    @Test func perQuarterAchievementsRequireTheirExactConditions() {
        let manager = makeManager()

        // A solved quarter always unlocks FIRST CASE — and nothing else.
        manager.noteQuarterSolved(livesLost: 1, hintsUsed: 1, isOvertime: false, difficulty: .pro)
        #expect(manager.isUnlocked(.firstCase))
        #expect(!manager.isUnlocked(.cleanRead))
        #expect(!manager.isUnlocked(.noHelpNeeded))
        #expect(!manager.isUnlocked(.clutch))

        // Heart untouched → CLEAN READ.
        manager.noteQuarterSolved(livesLost: 0, hintsUsed: 2, isOvertime: false, difficulty: .pro)
        #expect(manager.isUnlocked(.cleanRead))

        // No hint → NO HELP NEEDED.
        manager.noteQuarterSolved(livesLost: 0, hintsUsed: 0, isOvertime: false, difficulty: .pro)
        #expect(manager.isUnlocked(.noHelpNeeded))

        // OT solved → CLUTCH (also counts for deduction progress).
        manager.noteQuarterSolved(livesLost: 0, hintsUsed: 0, isOvertime: true, difficulty: .pro)
        #expect(manager.isUnlocked(.clutch))
    }

    @Test func coldCaseRequiresHallOfFamerDifficultyAndNoHints() {
        let manager = makeManager()
        manager.noteQuarterSolved(livesLost: 0, hintsUsed: 0, isOvertime: false, difficulty: .hallOfFamer)
        #expect(manager.isUnlocked(.coldCase))

        let other = makeManager()
        other.noteQuarterSolved(livesLost: 0, hintsUsed: 1, isOvertime: false, difficulty: .hallOfFamer)
        #expect(!other.isUnlocked(.coldCase))

        let pro = makeManager()
        pro.noteQuarterSolved(livesLost: 0, hintsUsed: 0, isOvertime: false, difficulty: .pro)
        #expect(!pro.isUnlocked(.coldCase))
    }

    @Test func losingAGameNeverUnlocksGameAchievements() {
        let manager = makeManager()
        let match = makeMatch(solvedQuarters: [0, 1, 2]) // shape of a win, but...
        _ = match
        manager.noteGameCompleted(
            won: false, quartersSolved: 3, wentToOT: false, wonOT: false,
            wrongPlacements: 0, forcedOvertimeFromOneSolved: false,
            difficulty: .pro, stage: .regularSeason
        )
        #expect(!manager.isUnlocked(.perfectGame))
        #expect(!manager.isUnlocked(.perfectEvidence))
        #expect(!manager.isUnlocked(.proven))
    }

    @Test func difficultyAchievementsUseTheQualifyingGamesDifficultyAndStage() {
        let manager = makeManager()

        // Pro regular-season win → PROVEN only.
        manager.noteGameCompleted(won: true, quartersSolved: 3, wentToOT: false, wonOT: false,
                                  wrongPlacements: 0, forcedOvertimeFromOneSolved: false,
                                  difficulty: .pro, stage: .regularSeason)
        #expect(manager.isUnlocked(.proven))
        #expect(!manager.isUnlocked(.allProMaterial))
        #expect(!manager.isUnlocked(.eliteRead))
        #expect(!manager.isUnlocked(.hallWorthy))

        // All-Pro regular-season win does NOT count as a playoff win.
        let regular = makeManager()
        regular.noteGameCompleted(won: true, quartersSolved: 3, wentToOT: false, wonOT: false,
                                  wrongPlacements: 0, forcedOvertimeFromOneSolved: false,
                                  difficulty: .allPro, stage: .regularSeason)
        #expect(!regular.isUnlocked(.allProMaterial))

        // All-Pro semifinal win → ALL-PRO MATERIAL.
        let semi = makeManager()
        semi.noteGameCompleted(won: true, quartersSolved: 3, wentToOT: false, wonOT: false,
                               wrongPlacements: 0, forcedOvertimeFromOneSolved: false,
                               difficulty: .allPro, stage: .semifinal)
        #expect(semi.isUnlocked(.allProMaterial))
        #expect(!semi.isUnlocked(.eliteRead))

        // All-Pro championship win → ELITE READ.
        let champ = makeManager()
        champ.noteGameCompleted(won: true, quartersSolved: 4, wentToOT: false, wonOT: false,
                                wrongPlacements: 0, forcedOvertimeFromOneSolved: false,
                                difficulty: .allPro, stage: .championship)
        #expect(champ.isUnlocked(.eliteRead))

        // Hall of Famer championship win → HALL WORTHY.
        let hof = makeManager()
        hof.noteGameCompleted(won: true, quartersSolved: 4, wentToOT: false, wonOT: false,
                              wrongPlacements: 0, forcedOvertimeFromOneSolved: false,
                              difficulty: .hallOfFamer, stage: .championship)
        #expect(hof.isUnlocked(.hallWorthy))
    }

    @Test func comebackRequiresDownOneThenOTWin() {
        let manager = makeManager()
        manager.noteGameCompleted(won: true, quartersSolved: 3, wentToOT: true, wonOT: true,
                                  wrongPlacements: 0, forcedOvertimeFromOneSolved: true,
                                  difficulty: .pro, stage: .regularSeason)
        #expect(manager.isUnlocked(.comebackCase))
        #expect(manager.isUnlocked(.clutch))

        // OT win without the 1–2 hole is clutch, not a comeback.
        let plainOT = makeManager()
        plainOT.noteGameCompleted(won: true, quartersSolved: 3, wentToOT: true, wonOT: true,
                                  wrongPlacements: 0, forcedOvertimeFromOneSolved: false,
                                  difficulty: .pro, stage: .regularSeason)
        #expect(!plainOT.isUnlocked(.comebackCase))
    }

    @Test func perfectGameAndPerfectEvidenceShapes() {
        // 4/4 quarters solved → PERFECT GAME; zero wrong placements → PERFECT EVIDENCE.
        let sweep = makeManager()
        sweep.noteGameCompleted(won: true, quartersSolved: 4, wentToOT: false, wonOT: false,
                                wrongPlacements: 0, forcedOvertimeFromOneSolved: false,
                                difficulty: .pro, stage: .regularSeason)
        #expect(sweep.isUnlocked(.perfectGame))
        #expect(sweep.isUnlocked(.perfectEvidence))

        // 3–0 win with one wrong placement: perfect game yes, perfect evidence no.
        let flawed = makeManager()
        flawed.noteGameCompleted(won: true, quartersSolved: 3, wentToOT: false, wonOT: false,
                                 wrongPlacements: 2, forcedOvertimeFromOneSolved: false,
                                 difficulty: .pro, stage: .regularSeason)
        #expect(!flawed.isUnlocked(.perfectGame))
        #expect(!flawed.isUnlocked(.perfectEvidence))
    }

    // MARK: 2. Progress achievements update correctly

    @Test func deductionMilestonesTrackTheCaseCounter() {
        let manager = makeManager()
        let achievement = AchievementCatalog.achievement(for: .fieldInvestigator)
        #expect(manager.progressValue(for: achievement) == 0)

        for _ in 0..<25 {
            manager.noteQuarterSolved(livesLost: 1, hintsUsed: 1, isOvertime: false, difficulty: .pro)
        }
        #expect(manager.progressValue(for: achievement) == 25)
        #expect(manager.isUnlocked(.fieldInvestigator))
        #expect(!manager.isUnlocked(.caseSpecialist))

        // 100 cases → CASE SPECIALIST, still short of 250.
        for _ in 0..<75 {
            manager.noteQuarterSolved(livesLost: 0, hintsUsed: 0, isOvertime: false, difficulty: .pro)
        }
        #expect(manager.progressValue(for: AchievementCatalog.achievement(for: .caseSpecialist)) == 100)
        #expect(manager.isUnlocked(.caseSpecialist))
        #expect(!manager.isUnlocked(.masterInvestigator))
        #expect(manager.casesSolved == 100)
    }

    // MARK: 3. Rewards cannot be granted twice

    @Test func achievementRewardsAreOneTimeOnlyThroughTheWalletLedger() {
        let defaults = makeDefaults()
        let wallet = PlayerWallet(defaults: defaults)
        let manager = AchievementManager(defaults: defaults)

        let before = wallet.gameBalls
        manager.noteQuarterSolved(livesLost: 0, hintsUsed: 0, isOvertime: false, difficulty: .pro)
        #expect(manager.isUnlocked(.firstCase))

        // Pay every pending reward the way the coordinator does.
        func claimAll() {
            for achievement in manager.unclaimedRewardAchievements() {
                wallet.earn(
                    amount: achievement.reward,
                    kind: .achievementReward,
                    transactionID: "achievement-\(achievement.id.rawValue)"
                )
                manager.markRewardClaimed(achievement.id)
            }
        }
        claimAll()
        #expect(wallet.gameBalls == before + EconomyConfig.standard.achievementRewardFirstCase)

        // A second claim pass pays nothing — the ledger blocks the repeat.
        manager.markRewardClaimed(.firstCase) // idempotent
        claimAll()
        #expect(wallet.gameBalls == before + EconomyConfig.standard.achievementRewardFirstCase)
        #expect(!wallet.transactions.filter { $0.kind == .achievementReward }.isEmpty)
        #expect(manager.hasClaimedReward(.firstCase))
    }

    @Test func rewardValuesComeFromEconomyConfig() {
        #expect(AchievementCatalog.achievement(for: .firstCase).reward == 25)
        #expect(AchievementCatalog.achievement(for: .perfectGame).reward == 50)
        #expect(AchievementCatalog.achievement(for: .caseClosed).reward == 100)
        #expect(AchievementCatalog.achievement(for: .undefeated).reward == 150)
        #expect(AchievementCatalog.achievement(for: .hallWorthy).reward == 250)
    }

    // MARK: 4. Popup queue: one at a time, never stacked

    @Test func popupsQueueOneAtATimeAndDrainInOrder() {
        let manager = makeManager()
        manager.noteQuarterSolved(livesLost: 0, hintsUsed: 0, isOvertime: false, difficulty: .pro) // firstCase + cleanRead + noHelpNeeded
        manager.noteGameCompleted(won: true, quartersSolved: 4, wentToOT: false, wonOT: false,
                                  wrongPlacements: 0, forcedOvertimeFromOneSolved: false,
                                  difficulty: .pro, stage: .regularSeason) // perfectGame + perfectEvidence + proven

        // One on screen, the rest queued — never stacked over gameplay.
        #expect(manager.currentPopup != nil)
        #expect(manager.popupQueue.count == 5)
        let first = manager.currentPopup

        manager.dismissPopup()
        #expect(manager.currentPopup != nil)
        #expect(manager.currentPopup?.id != first?.id)
        #expect(manager.popupQueue.count == 4)

        // Drain fully.
        for _ in 0..<5 { manager.dismissPopup() }
        #expect(manager.currentPopup == nil)
        #expect(manager.popupQueue.isEmpty)
    }

    // MARK: 5–6. Trophies persist and never get rewritten

    @Test func championshipTrophiesPersistAcrossRelaunch() {
        let defaults = makeDefaults()
        let store = LegacyStore(defaults: defaults)
        let team = GameTeam(state: "Virginia", teamName: "Cyber Wolves", logoID: "wolf",
                            primaryColorHex: 0x1A1A1A, secondaryColorHex: 0xD9B56E, isUserTeam: true)
        let trophy = ChampionshipTrophy(
            seasonNumber: 1, teamState: team.state, teamName: team.teamName, logoID: team.logoID,
            primaryColorHex: team.primaryColorHex, secondaryColorHex: team.secondaryColorHex,
            regularSeasonRecord: "9–1", difficulty: "PRO", opponentName: "Texas Outlaws",
            resultLine: "3–1", date: .now
        )
        let entry = SeasonArchiveEntry(
            seasonNumber: 1, recordLine: "9–1", wins: 9, losses: 1, standing: 1, totalTeams: 11,
            difficulty: "PRO", postseasonResult: SeasonArchiveEntry.championResult, date: .now
        )
        store.completeSeason(entry, trophy: trophy)

        // Fresh instance from the same defaults — a relaunch.
        let reloaded = LegacyStore(defaults: defaults)
        #expect(reloaded.trophies.count == 1)
        #expect(reloaded.trophies.first?.seasonNumber == 1)
        #expect(reloaded.trophies.first?.displayName == "Virginia Cyber Wolves")
        #expect(reloaded.championshipsWon == 1)
    }

    @Test func rebrandingNeverRewritesHistoricalTrophies() {
        let defaults = makeDefaults()
        let store = LegacyStore(defaults: defaults)
        let original = ChampionshipTrophy(
            seasonNumber: 2, teamState: "Virginia", teamName: "Cyber Wolves", logoID: "wolf",
            primaryColorHex: 0x1A1A1A, secondaryColorHex: 0xD9B56E,
            regularSeasonRecord: "8–2", difficulty: "PRO", opponentName: "Arizona Scorpions",
            resultLine: "3–2 OT", date: .now
        )
        let entry = SeasonArchiveEntry(
            seasonNumber: 2, recordLine: "8–2", wins: 8, losses: 2, standing: 2, totalTeams: 11,
            difficulty: "PRO", postseasonResult: SeasonArchiveEntry.championResult, date: .now
        )
        store.completeSeason(entry, trophy: original)

        // Later seasons run under completely different branding.
        let rebranded = ChampionshipTrophy(
            seasonNumber: 3, teamState: "Nevada", teamName: "Thunder Foxes", logoID: "fox",
            primaryColorHex: 0x2FA8C9, secondaryColorHex: 0x1E2A4A,
            regularSeasonRecord: "10–0", difficulty: "ALL-PRO", opponentName: "Ohio Steel Boars",
            resultLine: "4–1", date: .now
        )
        let entry3 = SeasonArchiveEntry(
            seasonNumber: 3, recordLine: "10–0", wins: 10, losses: 0, standing: 1, totalTeams: 11,
            difficulty: "ALL-PRO", postseasonResult: SeasonArchiveEntry.championResult, date: .now
        )
        store.completeSeason(entry3, trophy: rebranded)

        // Season 2's trophy still carries its original identity.
        let season2 = store.trophy(forSeason: 2)
        #expect(season2?.teamName == "Cyber Wolves")
        #expect(season2?.primaryColorHex == 0x1A1A1A)
        #expect(season2?.resultLine == "3–2 OT")
        #expect(store.archiveEntry(forSeason: 2)?.difficulty == "PRO")
    }

    // MARK: 7. Season archive preserves every completed season

    @Test func archiveKeepsEverySeasonAndIgnoresDuplicates() {
        let store = makeLegacyStore()
        for season in 1...4 {
            let entry = SeasonArchiveEntry(
                seasonNumber: season, recordLine: "5–5", wins: 5, losses: 5, standing: 6, totalTeams: 11,
                difficulty: "PRO", postseasonResult: SeasonArchiveEntry.missedPlayoffsResult, date: .now
            )
            #expect(store.completeSeason(entry, trophy: nil))
        }
        // Re-filing the same season is a no-op (replay/dupe safety).
        let duplicate = SeasonArchiveEntry(
            seasonNumber: 4, recordLine: "5–5", wins: 5, losses: 5, standing: 6, totalTeams: 11,
            difficulty: "PRO", postseasonResult: SeasonArchiveEntry.missedPlayoffsResult, date: .now
        )
        #expect(!store.completeSeason(duplicate, trophy: nil))
        #expect(store.archive.count == 4)
        #expect(store.archive.map(\.seasonNumber) == [4, 3, 2, 1]) // newest first
    }

    // MARK: 8. Win streaks

    @Test func winStreaksCountOTWinsAndResetOnAnyLoss() {
        let store = makeLegacyStore()
        store.recordGameResult(isWin: true)
        store.recordGameResult(isWin: true)
        #expect(store.currentWinStreak == 2)
        store.recordGameResult(isWin: false)
        #expect(store.currentWinStreak == 0)
        #expect(store.longestWinStreak == 2)

        for _ in 0..<5 { store.recordGameResult(isWin: true) }
        #expect(store.currentWinStreak == 5)
        #expect(store.longestWinStreak == 5)

        // A loss — regular or OT — resets the current streak only.
        store.recordGameResult(isWin: false)
        #expect(store.currentWinStreak == 0)
        #expect(store.longestWinStreak == 5)
    }

    @Test func hotStreakUnlocksAtFiveStraightWins() {
        let manager = makeManager()
        for _ in 0..<4 {
            manager.noteFranchiseState(gamesPlayed: 10, currentWinStreak: 4, longestWinStreak: 4)
        }
        #expect(!manager.isUnlocked(.hotStreak))
        manager.noteFranchiseState(gamesPlayed: 11, currentWinStreak: 5, longestWinStreak: 5)
        #expect(manager.isUnlocked(.hotStreak))
    }

    // MARK: 9. Player career honors

    @Test func playerMilestonesUnlockWithTheRightHolder() {
        let defaults = makeDefaults()
        let manager = AchievementManager(defaults: defaults)
        let store = LegacyStore(defaults: defaults)

        var hawk = FranchisePlayer(slot: .fs, firstName: "Marcus", lastName: "Reed", bodyAssetID: "football_player_backpedal")
        hawk.apply(PlayerStatEvent(franchisePlayerID: hawk.id, playerName: hawk.fullName, position: hawk.position, stat: .interceptions, count: 5))

        var tackleMachine = FranchisePlayer(slot: .dt, firstName: "Cole", lastName: "Brennan", bodyAssetID: "football_player_lineman")
        tackleMachine.apply(PlayerStatEvent(franchisePlayerID: tackleMachine.id, playerName: tackleMachine.fullName, position: tackleMachine.position, stat: .tackles, count: 51))

        manager.notePlayerMilestones(players: [hawk, tackleMachine])

        #expect(manager.isUnlocked(.ballHawk))
        #expect(manager.holderName(.ballHawk) == "M. Reed")
        #expect(manager.isUnlocked(.tackleMachine))
        #expect(manager.holderName(.tackleMachine) == "C. Brennan")
        #expect(!manager.isUnlocked(.sackSpecialist))
        #expect(!manager.isUnlocked(.gameChanger))

        // Legacy summary surfaces the honors leader.
        let history = FranchiseHistory()
        let legacy = store.franchiseLegacy(history: history, players: [hawk, tackleMachine])
        #expect(legacy.mostPlayerOfTheGame == nil)
    }

    @Test func gameChangerAndFranchiseIconNeedPlayerOfTheGameCounts() {
        let manager = makeManager()
        var star = FranchisePlayer(slot: .qb, firstName: "Trey", lastName: "Kingsley", bodyAssetID: "quarterback_player")
        for _ in 0..<5 { star.awardPlayerOfTheGame() }

        manager.notePlayerMilestones(players: [star])
        #expect(manager.isUnlocked(.gameChanger))
        #expect(!manager.isUnlocked(.franchiseIcon))

        for _ in 0..<10 { star.awardPlayerOfTheGame() }
        manager.notePlayerMilestones(players: [star])
        #expect(manager.isUnlocked(.franchiseIcon))
        #expect(manager.holderName(.franchiseIcon) == "T. Kingsley")
    }

    // MARK: 10. Season achievements + preservation across new seasons

    @Test func seasonAchievementsEvaluateFromTrueResults() {
        let manager = makeManager()

        // Missing playoffs still archives a season: winning season yes, playoff honors no.
        manager.noteSeasonCompleted(
            summary: makeSeasonResult(qualified: false, semifinalWin: false, reachedChampionship: false, wonChampionship: false),
            wins: 7, losses: 3, championshipCount: 0, lastTitleSeasonNumber: nil
        )
        #expect(manager.isUnlocked(.winningSeason))
        #expect(!manager.isUnlocked(.playoffBound))
        #expect(!manager.isUnlocked(.finalFour))
        #expect(!manager.isUnlocked(.caseClosed))

        // Championship run → playoff bound, final four, case closed.
        let champion = makeManager()
        champion.noteSeasonCompleted(
            summary: makeSeasonResult(qualified: true, semifinalWin: true, reachedChampionship: true, wonChampionship: true),
            wins: 10, losses: 0, championshipCount: 1, lastTitleSeasonNumber: 1
        )
        #expect(champion.isUnlocked(.playoffBound))
        #expect(champion.isUnlocked(.finalFour))
        #expect(champion.isUnlocked(.caseClosed))
        #expect(champion.isUnlocked(.undefeated))

        // First title is not BACK TO BACK; consecutive titles are.
        // (lastTitleSeasonNumber = the title BEFORE this one: Season 1 → S2 repeat.)
        let repeatChampion = makeManager()
        repeatChampion.noteSeasonCompleted(
            summary: makeSeasonResult(seasonNumber: 2, qualified: true, semifinalWin: true, reachedChampionship: true, wonChampionship: true),
            wins: 9, losses: 1, championshipCount: 2, lastTitleSeasonNumber: 1
        )
        #expect(repeatChampion.isUnlocked(.backToBack))

        let nonConsecutive = makeManager()
        nonConsecutive.noteSeasonCompleted(
            summary: makeSeasonResult(seasonNumber: 3, qualified: true, semifinalWin: true, reachedChampionship: true, wonChampionship: true),
            wins: 9, losses: 1, championshipCount: 2, lastTitleSeasonNumber: 1
        )
        #expect(!nonConsecutive.isUnlocked(.backToBack))

        // DYNASTY at 3 titles (and progress tracks the count).
        let dynasty = makeManager()
        dynasty.noteSeasonCompleted(
            summary: makeSeasonResult(seasonNumber: 3, qualified: true, semifinalWin: true, reachedChampionship: true, wonChampionship: true),
            wins: 9, losses: 1, championshipCount: 3, lastTitleSeasonNumber: 3
        )
        #expect(dynasty.isUnlocked(.dynasty))
        #expect(dynasty.progressValue(for: AchievementCatalog.achievement(for: .dynasty)) == 3)
    }

    @Test func startingASecondSeasonPreservesAchievementsTrophiesAndArchive() {
        let defaults = makeDefaults()
        let achievements = AchievementManager(defaults: defaults)
        let store = LegacyStore(defaults: defaults)

        achievements.noteQuarterSolved(livesLost: 0, hintsUsed: 0, isOvertime: false, difficulty: .pro)
        let entry = SeasonArchiveEntry(
            seasonNumber: 1, recordLine: "9–1", wins: 9, losses: 1, standing: 1, totalTeams: 11,
            difficulty: "PRO", postseasonResult: SeasonArchiveEntry.championResult, date: .now
        )
        let trophy = ChampionshipTrophy(
            seasonNumber: 1, teamState: "Virginia", teamName: "Cyber Wolves", logoID: "wolf",
            primaryColorHex: 0x1A1A1A, secondaryColorHex: 0xD9B56E,
            regularSeasonRecord: "9–1", difficulty: "PRO", opponentName: "Texas Outlaws",
            resultLine: "3–1", date: .now
        )
        store.completeSeason(entry, trophy: trophy)

        // "Starting Season 2" — fresh instances over the same defaults.
        let achievementsAfter = AchievementManager(defaults: defaults)
        let storeAfter = LegacyStore(defaults: defaults)

        #expect(achievementsAfter.isUnlocked(.firstCase))
        #expect(achievementsAfter.casesSolved == 1)
        #expect(storeAfter.trophies.count == 1)
        #expect(storeAfter.archive.count == 1)
        #expect(storeAfter.bestRecordLine == "9–1")
    }

    // MARK: Catalog integrity

    @Test func catalogCoversEveryCategoryAndAllIDsAreUnique() {
        #expect(Set(AchievementCatalog.all.map(\.id)).count == AchievementCatalog.all.count)
        for category in AchievementCategory.allCases {
            #expect(!AchievementCatalog.achievements(in: category).isEmpty)
        }
        #expect(AchievementCatalog.all.count == AchievementID.allCases.count)
    }
}

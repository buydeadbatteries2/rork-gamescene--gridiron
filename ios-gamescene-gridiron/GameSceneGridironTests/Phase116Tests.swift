import Testing
import Foundation
import CoreGraphics
@testable import GameSceneGridiron

/// Phase 11.6 — the expanded 150-case library: exact count, tier split,
/// profile/difficulty rules, authored metadata and competitive eligibility.
@MainActor
struct Phase116CaseLibraryTests {

    private var library: [QuarterCase] { CaseLibrary.all }

    // MARK: Count and shape

    @Test func libraryHoldsExactly150Cases() {
        #expect(library.count == 150, "the validated library holds exactly 150 cases, found \(library.count)")
        let ids = library.map(\.id)
        #expect(Set(ids).count == ids.count, "duplicate case ids present")
        for band in 1...5 {
            let bandCases = library.filter { $0.band == band }
            #expect(bandCases.count == 30, "band \(band) holds 30 cases, found \(bandCases.count)")
        }
    }

    @Test func tierSplitIs30_40_40_40() {
        for (tier, expected) in [(DifficultyLevel.rookie, 30), (.pro, 40), (.allPro, 40), (.hallOfFamer, 40)] {
            let count = library.filter { $0.tier == tier }.count
            #expect(count == expected, "\(tier.rawValue) tier holds \(expected) cases, found \(count)")
        }
    }

    // MARK: Profile rules per tier

    @Test func rookieTierCasesUseOnlyRookieAndVeteran() {
        for puzzleCase in library where puzzleCase.tier == .rookie {
            let profiles = Set(puzzleCase.solution.map(\.profile))
            #expect(profiles.isSubset(of: [.rookie, .veteran]), "\(puzzleCase.id) uses \(profiles)")
            #expect(puzzleCase.supportedDifficulties.contains(.rookie), "\(puzzleCase.id) must play at Rookie")
        }
    }

    @Test func proTierCasesNeverRequireOverrated() {
        for puzzleCase in library where puzzleCase.tier == .pro {
            let solutions = Set(puzzleCase.solution.map(\.profile))
            #expect(!solutions.contains(.overrated), "\(puzzleCase.id) requires Overrated at Pro")
            let referenced = Set(puzzleCase.clues.flatMap(\.constraints).compactMap { constraint -> PlayerProfile? in
                switch constraint {
                case .profileIs(_, let profile), .profileIsNot(_, let profile): profile
                default: nil
                }
            })
            #expect(!referenced.contains(.overrated), "\(puzzleCase.id) clues reference Overrated at Pro")
            #expect(puzzleCase.supportedDifficulties.contains(.pro), "\(puzzleCase.id) must play at Pro")
        }
    }

    @Test func allProAndHallOfFamerTiersOpenAllFiveProfiles() {
        #expect(PlayerProfile.pool(for: .allPro).count == 5)
        #expect(PlayerProfile.pool(for: .hallOfFamer).count == 5)
        for tier in [DifficultyLevel.allPro, .hallOfFamer] {
            for puzzleCase in library where puzzleCase.tier == tier {
                #expect(puzzleCase.supportedDifficulties.contains(tier), "\(puzzleCase.id) must play at \(tier.rawValue)")
            }
        }
        // Overrated genuinely appears in the upper tiers' content.
        let overratedCases = library.filter { puzzleCase in
            puzzleCase.solution.contains { $0.profile == .overrated }
        }
        #expect(overratedCases.count >= 10, "Overrated must anchor real content, found \(overratedCases.count) cases")
        #expect(overratedCases.allSatisfy { $0.tier == .allPro || $0.tier == .hallOfFamer })
    }

    // MARK: Metadata and competitive eligibility

    @Test func everyCaseCarriesCompleteMetadata() {
        for puzzleCase in library {
            let metadata = puzzleCase.metadata
            #expect(metadata != nil, "\(puzzleCase.id) has no metadata")
            guard let metadata else { continue }
            #expect((1...100).contains(metadata.difficultyScore), "\(puzzleCase.id) score \(metadata.difficultyScore) out of range")
        }
    }

    @Test func competitiveEligibleCasesAreValidated() {
        let eligible = library.filter(\.isCompetitiveEligible)
        #expect(eligible.count > 100, "the competitive pool should be the bulk of the library")
        for puzzleCase in eligible {
            #expect((1...100).contains(puzzleCase.difficultyScore ?? 0), "\(puzzleCase.id) has no valid difficulty score")
            #expect(CaseSolver.isUnique(puzzleCase), "\(puzzleCase.id) is not uniquely solvable")
            #expect(!puzzleCase.supportedDifficulties.isEmpty, "\(puzzleCase.id) supports no difficulty")
        }
    }

    @Test func everyCasePlaysAtItsOwnTier() {
        for puzzleCase in library {
            let tier = puzzleCase.tier
            #expect(tier != nil, "\(puzzleCase.id) has no tier")
            #expect(puzzleCase.supportedDifficulties.contains(tier ?? .pro), "\(puzzleCase.id) does not validate at its own tier \(tier?.rawValue ?? "?")")
        }
    }
}

/// Phase 11.6 Part 2 — difficulty lock during an active season.
@MainActor
struct DifficultyLockTests {

    private func makeDefaults(_ name: String) -> UserDefaults {
        let suite = "\(name)-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    @Test func difficultyCannotChangeWhileASeasonIsInProgress() {
        let manager = DifficultyManager(defaults: makeDefaults("lock"))
        manager.lockEvaluator = { true }
        let before = manager.selected
        manager.select(.hallOfFamer)
        #expect(manager.selected == before, "a running season pins the difficulty")
    }

    @Test func difficultyIsFreeBetweenSeasons() {
        let manager = DifficultyManager(defaults: makeDefaults("unlock"))
        manager.lockEvaluator = { false }
        manager.select(.allPro)
        #expect(manager.selected == .allPro)
        #expect(manager.lockEvaluator() == false)
    }

    @Test func currentDifficultyStaysVisibleWhileLocked() {
        let manager = DifficultyManager(defaults: makeDefaults("visible"))
        manager.lockEvaluator = { true }
        // The selection is never cleared or hidden — only modification is blocked.
        #expect(manager.selected == .pro)
        manager.select(.rookie)
        #expect(manager.selected == .pro)
    }

    @Test func seasonStoresTheDifficultyItWasStartedWith() {
        let defaults = makeDefaults("season-difficulty")
        var season = SeasonManager.generateSeason(userTeamID: UUID(), seasonNumber: 7)
        season.difficulty = .hallOfFamer
        SaveStore.save(season, key: SeasonManager.storageKey, defaults: defaults)
        let manager = SeasonManager(defaults: defaults)
        #expect(manager.activeSeasonDifficulty == .hallOfFamer)
        #expect(manager.hasSeasonInProgress)
    }

    @Test func historicalRecordsKeepTheirOriginalDifficulty() {
        let defaults = makeDefaults("season-difficulty-2")
        var season = SeasonManager.generateSeason(userTeamID: UUID(), seasonNumber: 3)
        season.difficulty = .rookie
        season.phase = .complete
        // Real progress marks the season legitimate — the corruption repair
        // must never rebuild a completed season.
        let opponent = season.games[0].opponentID
        season.applyResult(GameResult(
            winnerID: opponent, loserID: season.userTeamID,
            winnerScore: 3, loserScore: 1, wentToOT: false
        ))
        season.games[0].result = GameResult(
            winnerID: opponent, loserID: season.userTeamID,
            winnerScore: 3, loserScore: 1, wentToOT: false
        )
        SaveStore.save(season, key: SeasonManager.storageKey, defaults: defaults)
        let manager = SeasonManager(defaults: defaults)
        // A completed season no longer locks — but its recorded difficulty is
        // untouched, whatever the player selects for the next season.
        #expect(!manager.hasSeasonInProgress)
        #expect(manager.activeSeasonDifficulty == .rookie)
        DifficultyManager(defaults: defaults).select(.hallOfFamer)
        #expect(manager.activeSeasonDifficulty == .rookie, "history never rewrites")
    }

    @Test func preLockSeasonsBackfillWithTheSelectedDifficulty() {
        let defaults = makeDefaults("season-migrate")
        var season = SeasonManager.generateSeason(userTeamID: UUID(), seasonNumber: 1)
        season.difficulty = nil
        SaveStore.save(season, key: SeasonManager.storageKey, defaults: defaults)
        let manager = SeasonManager(defaults: defaults)
        #expect(manager.activeSeasonDifficulty == DifficultyManager.shared.selected, "legacy saves adopt the live selection")
    }
}

/// Phase 11.6 Part 4 — leaving and reopening resumes the same investigation.
@MainActor
struct InvestigationResumeTests {

    private func makeDefaults() -> UserDefaults {
        let suite = "resume-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        defaults.set(true, forKey: GameViewModel.clockIntroKey)
        return defaults
    }

    private func makeViewModel(difficulty: DifficultyLevel, defaults: UserDefaults) -> GameViewModel {
        GameViewModel(
            puzzle: SampleQuarter.puzzle,
            wallet: PlayerWallet(defaults: defaults),
            difficulty: difficulty,
            defaults: defaults,
            makeClock: { PlayClockController(duration: $0, autoTicks: false) }
        )
    }

    private func drag(_ viewModel: GameViewModel, playerID: String, x: Double, y: Double) {
        viewModel.fieldFrame = CGRect(x: 0, y: 0, width: 400, height: 300)
        let point = viewModel.point(x: x, y: y)
        guard viewModel.beginDrag(playerID: playerID, at: CGPoint(x: point.x, y: point.y + GameViewModel.dragLift)) else {
            Issue.record("beginDrag failed for \(playerID)")
            return
        }
        viewModel.endDrag()
    }

    @Test func untimedQuarterRestoresPlacementsAndLives() {
        let defaults = makeDefaults()
        let key = "match-abc-q2"
        let first = makeViewModel(difficulty: .pro, defaults: defaults)
        first.lastChanceKey = key
        first.selectProfile(.fast, for: "p-rb")
        drag(first, playerID: "p-rb", x: 0.50, y: 0.78) // correct
        first.selectProfile(.rookie, for: "p-te")
        drag(first, playerID: "p-te", x: 0.775, y: 0.565) // right slot, wrong profile — a life gone

        let reopened = makeViewModel(difficulty: .pro, defaults: defaults)
        reopened.lastChanceKey = key
        #expect(reopened.placements.count == 1, "the solved placement survives the exit")
        #expect(reopened.lives == 2, "the lost life is never respawned")
        #expect(reopened.result == .inProgress)
    }

    @Test func timedQuarterRestoresClockAndTimeoutsExactly() {
        let defaults = makeDefaults()
        let key = "match-abc-q3"
        let first = makeViewModel(difficulty: .hallOfFamer, defaults: defaults)
        first.lastChanceKey = key
        first.beginPlacementClock()
        first.selectProfile(.fast, for: "p-rb")
        drag(first, playerID: "p-rb", x: 0.50, y: 0.78) // correct
        first.callTimeout() // one timeout consumed, clock frozen mid-placement

        let reopened = makeViewModel(difficulty: .hallOfFamer, defaults: defaults)
        reopened.lastChanceKey = key
        #expect(reopened.timeoutsRemaining == 1, "consumed timeouts stay consumed")
        #expect(reopened.placements.count == 1)
        #expect(reopened.playClock?.phase == .suspended, "a resumed quarter returns frozen, never reset")
        #expect(reopened.playClock?.remaining == 40)
    }

    @Test func aFreshMatchNeverInheritsAnotherInvestigation() {
        let defaults = makeDefaults()
        let first = makeViewModel(difficulty: .pro, defaults: defaults)
        first.lastChanceKey = "match-abc-q1"
        first.selectProfile(.fast, for: "p-rb")
        drag(first, playerID: "p-rb", x: 0.50, y: 0.78)

        let fresh = makeViewModel(difficulty: .pro, defaults: defaults)
        fresh.lastChanceKey = "match-other-q1"
        #expect(fresh.placements.isEmpty, "a different match starts clean")
        #expect(fresh.lives == 3)
    }

    @Test func activeMatchRecordRoundTrips() {
        let defaults = makeDefaults()
        var match = GameMatch.fresh()
        match.recordQuarter(index: 0, label: "Q1", isOvertime: false, outcome: .solved,
                            correctPlacements: 4, wrongPlacements: 1, livesLost: 1, hintsUsed: 0)
        let matchID = UUID()
        ActiveInvestigationStore.save(ActiveMatchRecord(
            seasonNumber: 2, week: 5, isPlayoff: false, isChampionship: false,
            matchID: matchID, match: match
        ), defaults: defaults)
        let loaded = ActiveInvestigationStore.load(defaults: defaults)
        #expect(loaded?.matchID == matchID)
        #expect(loaded?.match.quarterRecords.count == 1)
        #expect(loaded?.week == 5)
        #expect(ActiveInvestigationStore.matches(loaded!, seasonNumber: 2, week: 5, isPlayoff: false, isChampionship: false))
        #expect(!ActiveInvestigationStore.matches(loaded!, seasonNumber: 2, week: 6, isPlayoff: false, isChampionship: false))

        ActiveInvestigationStore.clear(defaults: defaults)
        #expect(ActiveInvestigationStore.load(defaults: defaults) == nil)
    }

    @Test func seasonMatchesGetStableMatchIDs() {
        let a = MatchViewModel(seasonNumber: 4, week: 6)
        let b = MatchViewModel(seasonNumber: 4, week: 6)
        #expect(a.matchID == b.matchID, "a season game's identity is stable across launches")
        let otherWeek = MatchViewModel(seasonNumber: 4, week: 7)
        #expect(otherWeek.matchID != a.matchID)
        let standalone = MatchViewModel()
        let standalone2 = MatchViewModel()
        #expect(standalone.matchID != standalone2.matchID, "standalone replays stay one-time")
    }

    @Test func resumingAMatchRestoresTheSavedQuarter() {
        let defaults = makeDefaults()
        var match = GameMatch.fresh()
        match.recordQuarter(index: 0, label: "Q1", isOvertime: false, outcome: .solved,
                            correctPlacements: 4, wrongPlacements: 0, livesLost: 0, hintsUsed: 0)
        let matchID = MatchViewModel(seasonNumber: 2, week: 3).matchID
        let record = ActiveMatchRecord(
            seasonNumber: 2, week: 3, isPlayoff: false, isChampionship: false,
            matchID: matchID, match: match
        )
        let resumed = MatchViewModel(seasonNumber: 2, week: 3, resume: record)
        #expect(resumed.match.quarterRecords.count == 1, "quarters already played are never replayed")
        #expect(resumed.matchID == matchID)
        #expect(resumed.match.currentQuarterIndex == 1)
    }
}

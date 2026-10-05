import Foundation
import Testing
@testable import GameSceneGridiron

/// Phase 7 difficulty coverage: the (selected level × season stage) ramp,
/// difficulty-ordered case scheduling, runtime adaptation (decoys, missing
/// players, hints, clue order), persistence, and the single-solution
/// guarantee for every adapted variant across the whole library.
@MainActor
@Suite("DifficultyTests")
struct DifficultyTests {
    private let suiteName: String
    private let defaults: UserDefaults
    private let manager: DifficultyManager

    init() {
        suiteName = "gamescene.difficulty-tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        manager = DifficultyManager(defaults: defaults)
    }

    private static let rookieTarget = DifficultyResolver.target(selected: .rookie, stage: .earlyGames)
    private static let proTarget = DifficultyResolver.target(selected: .pro, stage: .midSeason)
    private static let allProTarget = DifficultyResolver.target(selected: .allPro, stage: .midSeason)
    private static let hallOfFamerTarget = DifficultyResolver.target(selected: .hallOfFamer, stage: .finalStretch)

    // MARK: Resolver

    @Test("Season stages ramp smoothly for every selected mode")
    func seasonRampIsSmooth() {
        for level in DifficultyLevel.allCases {
            let ratings = SeasonStage.allCases.map { DifficultyResolver.effectiveRating(selected: level, stage: $0) }
            #expect(ratings == ratings.sorted(), "\(level.title): stage ratings must ascend")
            #expect(ratings.last! <= DifficultyResolver.maxRating)
            #expect(ratings.last! > ratings.first!)
        }

        // Spec anchors: Pro 9–10 is hard, All-Pro 9–10 very hard, and Hall of
        // Famer playoffs/championship land on the elite ceiling.
        let proStretch = DifficultyResolver.target(selected: .pro, stage: .finalStretch)
        let allProStretch = DifficultyResolver.target(selected: .allPro, stage: .finalStretch)
        let hallOfFamerPlayoffs = DifficultyResolver.target(selected: .hallOfFamer, stage: .playoffs)
        let hallOfFamerPlayoffRating = DifficultyResolver.effectiveRating(selected: .hallOfFamer, stage: .playoffs)
        #expect(proStretch.tier == .allPro, "Pro 9–10 = hard")
        #expect(allProStretch.tier == .hallOfFamer, "All-Pro 9–10 = very hard")
        #expect(hallOfFamerPlayoffs.tier == .hallOfFamer, "Hall of Famer playoffs = elite")
        #expect(hallOfFamerPlayoffRating == DifficultyResolver.maxRating)

        // Games 1–3 stay approachable even in the hardest modes.
        let proEarly = DifficultyResolver.target(selected: .pro, stage: .earlyGames)
        let hallOfFamerEarly = DifficultyResolver.target(selected: .hallOfFamer, stage: .earlyGames)
        #expect(proEarly.tier != .allPro)
        #expect(hallOfFamerEarly.tier != .hallOfFamer)
    }

    // MARK: Case selection

    @Test("Games 1–3 select easier cases than Games 9–10")
    func earlyGamesSelectEasierCases() {
        for seasonNumber in 1...3 {
            for band in 1...5 {
                let order = CaseScheduler.bandOrder(seasonNumber: seasonNumber, band: band)
                let early = order.prefix(3).map { rating(ofID: $0) }
                let late = order.suffix(3).map { rating(ofID: $0) }
                let earlyAverage = early.reduce(0, +) / 3
                let lateAverage = late.reduce(0, +) / 3
                #expect(
                    earlyAverage < lateAverage,
                    "season \(seasonNumber) band \(band): early games must draw easier cases"
                )
            }
        }
    }

    @Test("Playoffs draw harder cases than the early regular season")
    func playoffsDrawHarderCases() {
        for seasonNumber in 1...3 {
            let playoffIDs = CaseScheduler.regulationCaseIDs(seasonNumber: seasonNumber, week: 12)
                + [CaseScheduler.overtimeCaseID(seasonNumber: seasonNumber, week: 12)]
            let earlyIDs = (1...3).flatMap { week in
                CaseScheduler.regulationCaseIDs(seasonNumber: seasonNumber, week: week)
            }
            let playoffRating = averageRating(playoffIDs)
            let earlyRating = averageRating(earlyIDs)
            #expect(
                playoffRating > earlyRating,
                "season \(seasonNumber): playoffs must out-rate the early season"
            )
        }
    }

    @Test("Scheduler stays repeat-free and deterministic with difficulty ordering")
    func schedulerStaysRepeatFree() {
        for seasonNumber in 1...3 {
            let schedule = CaseScheduler.seasonSchedule(seasonNumber: seasonNumber)
            #expect(schedule.count == 40)
            #expect(Set(schedule).count == schedule.count, "season \(seasonNumber): case repeated across the season")
            // Same season number, same schedule — persisted content can never reshuffle.
            #expect(schedule == CaseScheduler.seasonSchedule(seasonNumber: seasonNumber))
            for week in 1...10 {
                let game = CaseScheduler.gameCaseIDs(seasonNumber: seasonNumber, week: week)
                #expect(Set(game.regulation).count == game.regulation.count)
                #expect(!game.regulation.contains(game.overtime))
            }
        }
    }

    // MARK: Adaptation

    @Test("Pro presents the authored case unchanged")
    func proIsTheAuthoredCase() {
        for puzzleCase in CaseLibrary.all {
            let adapted = CaseDifficultyAdapter.adapt(puzzleCase, to: Self.proTarget)
            #expect(adapted == puzzleCase, "\(puzzleCase.id): Pro must be the authored case")
        }
    }

    @Test("Rookie receives fewer missing players and decoys than Hall of Famer")
    func rookieIsLighterThanHallOfFamer() {
        var rookieMissingTotal = 0
        var hallOfFamerMissingTotal = 0
        var rookieDecoyTotal = 0
        var hallOfFamerDecoyTotal = 0

        for puzzleCase in CaseLibrary.all {
            let rookie = CaseDifficultyAdapter.adapt(puzzleCase, to: Self.rookieTarget)
            let hallOfFamer = CaseDifficultyAdapter.adapt(puzzleCase, to: Self.hallOfFamerTarget)
            #expect(rookie.missing.count <= hallOfFamer.missing.count, "\(puzzleCase.id)")
            #expect(decoyCount(rookie) <= decoyCount(hallOfFamer), "\(puzzleCase.id)")
            #expect(decoyCount(rookie) <= 2, "\(puzzleCase.id): rookie decoys must be capped")
            rookieMissingTotal += rookie.missing.count
            hallOfFamerMissingTotal += hallOfFamer.missing.count
            rookieDecoyTotal += decoyCount(rookie)
            hallOfFamerDecoyTotal += decoyCount(hallOfFamer)
        }

        #expect(rookieMissingTotal < hallOfFamerMissingTotal, "rookie must trim missing players somewhere")
        #expect(rookieDecoyTotal < hallOfFamerDecoyTotal, "Hall of Famer must add decoys somewhere")
    }

    @Test("Every adapted variant keeps exactly one valid solution")
    func adaptedVariantsStayUnique() {
        var failures: [String] = []
        let tiers: [(DifficultyLevel, SeasonStage)] = [
            (.rookie, .earlyGames), (.pro, .midSeason), (.allPro, .midSeason), (.hallOfFamer, .finalStretch)
        ]
        for puzzleCase in CaseLibrary.all {
            for (level, stage) in tiers {
                let target = DifficultyResolver.target(selected: level, stage: stage)
                let adapted = CaseDifficultyAdapter.adapt(puzzleCase, to: target)
                if !CaseSolver.isUnique(adapted) {
                    failures.append("\(puzzleCase.id)/\(level.title): adapted case lost uniqueness")
                }
                if !wellFormed(adapted) {
                    failures.append("\(puzzleCase.id)/\(level.title): adapted case not well formed")
                }
            }
        }
        let detail = failures.joined(separator: "\n")
        #expect(failures.isEmpty, "\(detail)")
    }

    @Test("Hint strength changes with the tier and never reveals the answer")
    func hintStrengthChangesByTier() throws {
        let puzzleCase = try #require(CaseLibrary.all.first)
        let authored = CaseDifficultyAdapter.adapt(puzzleCase, to: Self.proTarget)
        let rookie = CaseDifficultyAdapter.adapt(puzzleCase, to: Self.rookieTarget)
        let allPro = CaseDifficultyAdapter.adapt(puzzleCase, to: Self.allProTarget)
        let hallOfFamer = CaseDifficultyAdapter.adapt(puzzleCase, to: Self.hallOfFamerTarget)

        // Rookie hints are regenerated, direct, and name the position.
        for hint in rookie.hints {
            let authoredHint = try #require(authored.hints.first { $0.playerKey == hint.playerKey })
            #expect(hint.text != authoredHint.text)
            #expect(hint.text.hasPrefix("Focus on the"), "rookie hint must be direct: \(hint.text)")
        }

        // All-Pro keeps only the direction — the authored giveaway clause is cut.
        for hint in allPro.hints {
            let authoredHint = try #require(authored.hints.first { $0.playerKey == hint.playerKey })
            if hint.text != authoredHint.text {
                #expect(authoredHint.text.hasPrefix(hint.text), "subtle hints are prefixes: \(hint.text)")
            }
        }

        // Hall of Famer: minimal guidance — never names evidence or a side.
        let evidenceTitles = puzzleCase.evidence.map { $0.kind.title.lowercased() }
        for hint in hallOfFamer.hints {
            let text = hint.text.lowercased()
            for title in evidenceTitles {
                #expect(!text.contains(title), "\(hint.text) reveals \(title)")
            }
            #expect(
                !text.contains("sideline") && !text.contains("left") && !text.contains("right"),
                "minimal hint is non-directional: \(hint.text)"
            )
        }
    }

    @Test("Rookie presents clues easiest-first; Hall of Famer hardest-first")
    func clueOrderingByTier() throws {
        let puzzleCase = try #require(CaseLibrary.all.first { puzzleCase in
            puzzleCase.clues.contains { $0.difficulty == .easy }
                && puzzleCase.clues.contains { $0.difficulty == .hard }
        })
        let rookie = CaseDifficultyAdapter.adapt(puzzleCase, to: Self.rookieTarget)
        let hallOfFamer = CaseDifficultyAdapter.adapt(puzzleCase, to: Self.hallOfFamerTarget)
        #expect(rookie.clues.first?.difficulty == .easy)
        #expect(hallOfFamer.clues.first?.difficulty == .hard)
    }

    @Test("Difficulty tags span the library from Easy to Expert")
    func difficultyTagsSpanTheLibrary() {
        let counts = Dictionary(grouping: CaseLibrary.all, by: { CaseDifficultyProfile(of: $0).tag })
            .mapValues(\.count)
        for tag in CaseDifficultyTag.allCases {
            #expect((counts[tag] ?? 0) > 0, "no \(tag.title) cases in the library: \(counts)")
        }
    }

    // MARK: Persistence & isolation

    @Test("Selected difficulty persists and defaults to PRO")
    func persistence() {
        #expect(manager.selected == .pro, "PRO is the default")
        manager.select(.hallOfFamer)
        #expect(DifficultyManager(defaults: defaults).selected == .hallOfFamer)
        manager.select(.rookie)
        #expect(DifficultyManager(defaults: defaults).selected == .rookie)
    }

    @Test("Changing difficulty never reshuffles a season's scheduled content")
    func difficultyChangeKeepsScheduleStable() {
        let seasonManager = SeasonManager(defaults: defaults)
        let userTeam = GameTeam(
            state: "Nevada", teamName: "Case Stags", logoID: "wolf",
            primaryColorHex: 0x1E2A4A, secondaryColorHex: 0xC9CDD1, isUserTeam: true
        )
        seasonManager.startNewSeason(userTeam: userTeam)
        let schedule = seasonManager.season?.scheduledCaseIDs

        manager.select(.hallOfFamer)
        let reloaded = SeasonManager(defaults: defaults)
        #expect(reloaded.season?.scheduledCaseIDs == schedule)
        #expect(reloaded.season == seasonManager.season)
    }

    @Test("Adaptation is deterministic for the same target")
    func adaptationIsDeterministic() {
        for puzzleCase in CaseLibrary.all {
            let first = CaseDifficultyAdapter.adapt(puzzleCase, to: Self.hallOfFamerTarget)
            let second = CaseDifficultyAdapter.adapt(puzzleCase, to: Self.hallOfFamerTarget)
            #expect(first == second, "\(puzzleCase.id): adaptation must be deterministic")
        }
    }

    // MARK: Match integration

    @Test("Match difficulty flows through to the puzzles")
    func matchViewModelAppliesDifficulty() {
        let rookie = MatchViewModel(seasonNumber: 1, week: 9, difficulty: .rookie)
        let hallOfFamer = MatchViewModel(seasonNumber: 1, week: 9, difficulty: .hallOfFamer)
        // The selection shapes adaptation, not the schedule — same cases,
        // but Rookie's field is never harder than Hall of Famer's.
        #expect(rookie.currentPuzzle.id == hallOfFamer.currentPuzzle.id)
        #expect(rookie.currentPuzzle.slots.count <= hallOfFamer.currentPuzzle.slots.count)
        #expect(rookie.currentPuzzle.missingPlayers.count <= hallOfFamer.currentPuzzle.missingPlayers.count)
    }

    // MARK: Helpers

    private func rating(ofID id: String) -> Double {
        CaseDifficultyProfile(of: CaseLibrary.caseByID(id)!).rating
    }

    private func averageRating(_ ids: [String]) -> Double {
        ids.map { rating(ofID: $0) }.reduce(0, +) / Double(ids.count)
    }

    private func decoyCount(_ puzzleCase: QuarterCase) -> Int {
        let solutionSlots = Set(puzzleCase.solution.map(\.slotKey))
        return puzzleCase.slots.filter { !solutionSlots.contains($0.key) }.count
    }

    private func wellFormed(_ puzzleCase: QuarterCase) -> Bool {
        puzzleCase.solution.count == puzzleCase.missing.count
            && Set(puzzleCase.solution.map(\.playerKey)).count == puzzleCase.solution.count
            && Set(puzzleCase.solution.map(\.slotKey)).count == puzzleCase.solution.count
            && puzzleCase.solution.allSatisfy { entry in
                puzzleCase.player(withKey: entry.playerKey) != nil
                    && puzzleCase.slot(withKey: entry.slotKey) != nil
            }
    }
}

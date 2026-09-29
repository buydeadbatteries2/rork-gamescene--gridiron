import CoreGraphics
import Foundation
import Testing
@testable import GameSceneGridiron

// MARK: - Puzzle integrity

struct PuzzleIntegrityTests {

    /// Every puzzle in the match (4 regulation + overtime) is data-driven and well-formed:
    /// unique correct slots, full player coverage, valid clue/hint references.
    @Test(arguments: MatchPuzzles.regulation + [MatchPuzzles.overtime])
    func puzzleIsWellFormed(puzzle: QuarterPuzzle) {
        #expect(puzzle.isWellFormed, "Puzzle \(puzzle.id) is not well-formed")

        // Every clue and hint must reference a real missing player.
        let missingIDs = Set(puzzle.missingPlayers.map(\.id))
        #expect(puzzle.clues.allSatisfy { missingIDs.contains($0.playerID) })
        #expect(puzzle.hints.allSatisfy { missingIDs.contains($0.playerID) })

        // Every missing player has exactly one clue, one hint and one solution.
        for id in missingIDs {
            #expect(puzzle.clues.filter { $0.playerID == id }.count == 1, "\(puzzle.id): no unique clue for \(id)")
            #expect(puzzle.hints.contains { $0.playerID == id }, "\(puzzle.id): no hint for \(id)")
            #expect(puzzle.solutions[id] != nil, "\(puzzle.id): no solution for \(id)")
        }

        // Clue ids are unique and ordered 1...n.
        let clueIDs = puzzle.clues.map(\.id)
        #expect(Set(clueIDs).count == clueIDs.count)
        #expect(clueIDs == Array(1...clueIDs.count))

        // Slot ids are unique across the whole board (correct + decoys).
        let slotIDs = puzzle.slots.map(\.id)
        #expect(Set(slotIDs).count == slotIDs.count)

        // Evidence ids are unique.
        let evidenceIDs = puzzle.evidence.map(\.id)
        #expect(Set(evidenceIDs).count == evidenceIDs.count)
    }

    @Test func matchContainsFourRegulationQuartersAndOvertime() {
        #expect(MatchPuzzles.regulation.count == GameMatch.regulationQuarters)
        #expect(MatchPuzzles.regulation.map(\.quarterLabel) == ["Q1", "Q2", "Q3", "Q4"])
        #expect(MatchPuzzles.overtime.quarterLabel == "OT")
        #expect(MatchPuzzles.overtime.index == 4)

        // Each quarter has its own formation: no duplicate visible-player layouts.
        let layouts = (MatchPuzzles.regulation + [MatchPuzzles.overtime]).map { puzzle in
            puzzle.visiblePlayers.map { "\($0.position)-\($0.x)-\($0.y)" }.sorted().joined(separator: "|")
        }
        #expect(Set(layouts).count == layouts.count, "Two puzzles reuse the same formation")

        // Difficulty ramp: Q1 carries easy on-ramp clues; later quarters lean harder.
        func count(_ puzzle: QuarterPuzzle, _ difficulty: ClueDifficulty) -> Int {
            puzzle.clues.filter { $0.difficulty == difficulty }.count
        }
        #expect(count(MatchPuzzles.regulation[0], .easy) == 2)
        #expect(count(MatchPuzzles.regulation[0], .medium) == 3)
        #expect(count(MatchPuzzles.regulation[0], .hard) == 1)
        #expect(count(MatchPuzzles.regulation[1], .easy) >= 1)
        #expect(count(MatchPuzzles.regulation[2], .easy) == 0)
        #expect(count(MatchPuzzles.regulation[3], .hard) >= 3)
        #expect(count(MatchPuzzles.overtime, .easy) == 0)
    }
}

// MARK: - Match result rules

/// Simulates full games through `GameMatch` for every required outcome.
struct MatchResultRuleTests {

    private func playRegulation(
        outcomes: [QuarterOutcome],
        correct: Int = 6,
        wrong: Int = 0,
        livesLost: Int = 0,
        hintsUsed: Int = 0
    ) -> GameMatch {
        var match = GameMatch.fresh()
        for (index, outcome) in outcomes.enumerated() {
            let failed = outcome == .failed
            match.recordQuarter(
                index: index,
                label: "Q\(index + 1)",
                isOvertime: false,
                outcome: outcome,
                correctPlacements: failed ? 2 : correct,
                wrongPlacements: failed ? 4 : wrong,
                livesLost: failed ? 3 : livesLost,
                hintsUsed: hintsUsed
            )
        }
        return match
    }

    @Test func fourOhIsVictory() {
        let match = playRegulation(outcomes: [.solved, .solved, .solved, .solved])
        #expect(match.isComplete)
        #expect(!match.needsOvertime)
        #expect(match.result == .victory)
        #expect(match.scoreLine == "4–0")
    }

    @Test func threeOneIsVictory() {
        let match = playRegulation(outcomes: [.solved, .failed, .solved, .solved])
        #expect(match.isComplete)
        #expect(match.result == .victory)
        #expect(match.scoreLine == "3–1")
    }

    @Test func twoTwoGoesToOvertimeAndWinIsOTVictory() {
        var match = playRegulation(outcomes: [.solved, .failed, .solved, .failed])
        #expect(match.needsOvertime)
        #expect(!match.isComplete)
        #expect(match.result == nil)
        #expect(match.isOvertime)
        #expect(match.currentQuarterIndex == 4)

        match.recordQuarter(
            index: 4,
            label: "OT",
            isOvertime: true,
            outcome: .solved,
            correctPlacements: 5,
            wrongPlacements: 1,
            livesLost: 1,
            hintsUsed: 1
        )
        #expect(match.isComplete)
        #expect(match.result == .victoryOT)
        #expect(match.scoreLine == "3–2 OT")
    }

    @Test func twoTwoGoesToOvertimeAndLossIsOTDefeat() {
        var match = playRegulation(outcomes: [.solved, .failed, .solved, .failed])
        match.recordQuarter(
            index: 4,
            label: "OT",
            isOvertime: true,
            outcome: .failed,
            correctPlacements: 3,
            wrongPlacements: 3,
            livesLost: 3,
            hintsUsed: 2
        )
        #expect(match.isComplete)
        #expect(match.result == .defeatOT)
        #expect(match.scoreLine == "2–3 OT")
    }

    @Test func oneThreeIsDefeat() {
        let match = playRegulation(outcomes: [.failed, .failed, .solved, .failed])
        #expect(match.isComplete)
        #expect(!match.needsOvertime)
        #expect(match.result == .defeat)
        #expect(match.scoreLine == "1–3")
    }

    @Test func ohFourIsDefeat() {
        let match = playRegulation(outcomes: [.failed, .failed, .failed, .failed])
        #expect(match.isComplete)
        #expect(match.result == .defeat)
        #expect(match.scoreLine == "0–4")
    }

    @Test func losingAQuarterNeverEndsTheMatch() {
        let match = playRegulation(outcomes: [.failed, .failed])
        #expect(match.quarterRecords.count == 2)
        #expect(!match.isComplete)
        #expect(match.quartersFailed == 2)
        #expect(match.currentLabel == "Q3")
    }

    @Test func statisticsAccumulateAcrossQuarters() {
        var match = playRegulation(outcomes: [.solved, .failed], correct: 6, wrong: 1, livesLost: 0, hintsUsed: 2)
        match.recordQuarter(
            index: 4,
            label: "OT",
            isOvertime: true,
            outcome: .solved,
            correctPlacements: 5,
            wrongPlacements: 0,
            livesLost: 0,
            hintsUsed: 1
        )
        #expect(match.totalCorrectPlacements == 13) // 6 solved + 2 (failed quarter) + 5 OT
        #expect(match.totalWrongPlacements == 5)    // 1 solved + 4 (failed quarter) + 0 OT
        #expect(match.totalHintsUsed == 5)          // 2 + 2 + 1
    }

    @Test func freshMatchResetsEverything() {
        var match = playRegulation(outcomes: [.solved, .failed])
        match = .fresh()
        #expect(match.quarterRecords.isEmpty)
        #expect(match.overtimeRecord == nil)
        #expect(match.totalCorrectPlacements == 0)
        #expect(match.totalWrongPlacements == 0)
        #expect(match.totalLivesLost == 0)
        #expect(match.totalHintsUsed == 0)
        #expect(match.currentLabel == "Q1")
        #expect(match.result == nil)
    }
}

// MARK: - Match flow orchestration

@MainActor
struct MatchViewModelTests {

    /// Drives the real puzzle engine (variant select → hold-drag → drop) to place
    /// every missing player on their correct slot. Awaited: the verdict lands ~1.1s
    /// after the last correct placement.
    private func solveQuarter(_ viewModel: GameViewModel) async {
        viewModel.fieldFrame = CGRect(x: 0, y: 0, width: 360, height: 480)
        for (playerID, solution) in viewModel.puzzle.solutions {
            guard let slot = viewModel.puzzle.slot(id: solution.slotID) else {
                Issue.record("Missing slot \(solution.slotID) in \(viewModel.puzzle.id)")
                continue
            }
            viewModel.selectVariant(solution.variant, for: playerID)
            let point = viewModel.point(x: slot.x, y: slot.y)
            let dropLocation = CGPoint(x: point.x, y: point.y + GameViewModel.dragLift)
            #expect(viewModel.beginDrag(playerID: playerID, at: dropLocation))
            viewModel.updateDrag(to: dropLocation)
            viewModel.endDrag()
        }
        // finish(with:) sets the verdict after a short cinematic delay.
        for _ in 0..<50 where viewModel.result == .inProgress {
            try? await Task.sleep(for: .milliseconds(100))
        }
    }

    @Test func newGameStartsAtQuarterOneIntro() {
        let matchViewModel = MatchViewModel()
        #expect(matchViewModel.match.currentQuarterIndex == 0)
        #expect(matchViewModel.phase == .quarterIntro)
        #expect(matchViewModel.currentPuzzle.id == MatchPuzzles.regulation[0].id)
    }

    @Test func solvedQuarterIsRecordedAndMatchAdvancesToNextQuarter() async {
        let matchViewModel = MatchViewModel()
        let quarterViewModel = GameViewModel(puzzle: matchViewModel.currentPuzzle)
        matchViewModel.beginQuarter()
        #expect(matchViewModel.phase == .playing)

        await solveQuarter(quarterViewModel)
        #expect(quarterViewModel.result == .won)
        #expect(quarterViewModel.placements.count == quarterViewModel.puzzle.missingPlayers.count)

        matchViewModel.finishQuarter(with: quarterViewModel)
        #expect(matchViewModel.phase == .quarterResult)
        #expect(matchViewModel.match.quarterRecords.count == 1)
        #expect(matchViewModel.match.quarterRecords[0].outcome == .solved)
        #expect(matchViewModel.match.totalCorrectPlacements == quarterViewModel.puzzle.missingPlayers.count)
        #expect(matchViewModel.match.currentQuarterIndex == 1)
        #expect(matchViewModel.nextButtonTitle == "NEXT QUARTER")
    }

    @Test func wrongDropCostsALifeButNotTheMatch() async {
        let quarterViewModel = GameViewModel(puzzle: SampleQuarter.puzzle)
        quarterViewModel.fieldFrame = CGRect(x: 0, y: 0, width: 360, height: 480)

        let decoy = SampleQuarter.puzzle.slot(id: "s-left-backfield")!
        quarterViewModel.selectVariant(.fast, for: "p-rb")
        let point = quarterViewModel.point(x: decoy.x, y: decoy.y)
        let dropLocation = CGPoint(x: point.x, y: point.y + GameViewModel.dragLift)
        #expect(quarterViewModel.beginDrag(playerID: "p-rb", at: dropLocation))
        quarterViewModel.updateDrag(to: dropLocation)
        quarterViewModel.endDrag()

        #expect(quarterViewModel.lives == 2)
        #expect(quarterViewModel.placements.isEmpty)
        #expect(quarterViewModel.result == .inProgress)
    }

    @Test func playAgainResetsMatchState() {
        let matchViewModel = MatchViewModel()
        matchViewModel.startGame()
        #expect(matchViewModel.match.quarterRecords.isEmpty)
        #expect(matchViewModel.phase == .quarterIntro)
        #expect(matchViewModel.nextButtonTitle == "NEXT QUARTER")
    }
}

// MARK: - Team identity

/// Phase 3 catalogs: 50 states, 50 original names, 50 fictional logos, 15 colors.
struct TeamCatalogTests {

    @Test func stateCatalogHasAllFiftyUniqueStates() {
        #expect(StateCatalog.states.count == 50)
        #expect(Set(StateCatalog.stateNames).count == 50)
        let abbreviations = StateCatalog.states.map(\.abbreviation)
        #expect(Set(abbreviations).count == 50)
        #expect(abbreviations.allSatisfy { $0.count == 2 })
        #expect(StateCatalog.abbreviation(for: "Virginia") == "VA")
        #expect(StateCatalog.abbreviation(for: "Nowhere") == nil)
    }

    @Test func teamNameCatalogHasFiftyOriginalNames() {
        #expect(TeamNameCatalog.names.count == 50)
        #expect(Set(TeamNameCatalog.names).count == 50)

        // No existing NFL franchise name may appear inside any catalog entry.
        let banned = [
            "Bills", "Dolphins", "Patriots", "Jets", "Ravens", "Bengals", "Browns",
            "Steelers", "Texans", "Colts", "Jaguars", "Titans", "Broncos", "Chiefs",
            "Raiders", "Chargers", "Cowboys", "Giants", "Eagles", "Commanders",
            "Bears", "Lions", "Packers", "Vikings", "Falcons", "Panthers", "Saints",
            "Buccaneers", "Cardinals", "Rams", "49ers", "Seahawks"
        ]
        for name in TeamNameCatalog.names {
            // Whole-word match — "Stallions" is original even though it contains "lions".
            let words = name.split(separator: " ").map { $0.lowercased() }
            for word in banned {
                #expect(!words.contains(word.lowercased()), "Catalog name \"\(name)\" imitates \"\(word)\"")
            }
        }
    }

    @Test func logoCatalogHasFiftyUniqueEmblems() {
        #expect(LogoCatalog.logos.count == 50)
        #expect(Set(LogoCatalog.logos.map(\.id)).count == 50)
        #expect(Set(LogoCatalog.logos.map(\.name)).count == 50)
        #expect(LogoCatalog.logos.allSatisfy { !$0.id.isEmpty })
        #expect(LogoCatalog.contains(id: "wolf"))
        #expect(!LogoCatalog.contains(id: "nfl"))
    }

    @Test func colorCatalogHasFifteenDistinctColors() {
        #expect(ColorCatalog.colors.count == 15)
        #expect(Set(ColorCatalog.colors.map(\.hex)).count == 15)
        #expect(Set(ColorCatalog.colors.map(\.name)).count == 15)
    }
}

struct GameTeamTests {

    private func makeTeam(
        state: String = "Virginia",
        name: String = "Cyber Wolves",
        logo: String = "wolf",
        primary: UInt32 = 0x1E2A4A,
        secondary: UInt32 = 0xC9CDD1
    ) -> GameTeam {
        GameTeam(
            state: state, teamName: name, logoID: logo,
            primaryColorHex: primary, secondaryColorHex: secondary, isUserTeam: true
        )
    }

    @Test func displayNameCombinesStateAndName() {
        #expect(makeTeam().displayName == "Virginia Cyber Wolves")
        #expect(makeTeam().shortName == "VA CYBER WOLVES")
    }

    @Test func codableRoundtripPreservesFranchise() throws {
        let team = makeTeam()
        let data = try JSONEncoder().encode(team)
        let decoded = try JSONDecoder().decode(GameTeam.self, from: data)
        #expect(decoded == team)
        #expect(decoded.isUserTeam)
    }

    @Test func opponentTeamsAreValidAndDistinct() {
        let opponents = OpponentTeams.all
        #expect(opponents.count == 10)
        #expect(Set(opponents.map(\.id)).count == 10)
        #expect(Set(opponents.map(\.displayName)).count == 10)
        #expect(opponents.allSatisfy { !$0.isUserTeam })
        #expect(opponents.allSatisfy { LogoCatalog.contains(id: $0.logoID) })
        #expect(opponents.allSatisfy { $0.primaryColorHex != $0.secondaryColorHex })
    }
}

struct TeamKitResolverTests {

    private func team(primary: UInt32, secondary: UInt32) -> GameTeam {
        GameTeam(
            state: "Texas", teamName: "Outlaws", logoID: "bull",
            primaryColorHex: primary, secondaryColorHex: secondary, isUserTeam: false
        )
    }

    @Test func colorDistanceDistinguishesFarColors() {
        #expect(TeamKitResolver.colorDistance(0x000000, 0xFFFFFF) > 0.5)
        #expect(TeamKitResolver.colorDistance(0x1A1A1A, 0x1A1A1A) == 0)
    }

    @Test func similarPrimariesForceOpponentIntoAlternateKit() {
        let user = team(primary: 0x1A1A1A, secondary: 0xD9B56E)         // black / gold
        let navyOpponent = team(primary: 0x1E2A4A, secondary: 0xC9CDD1) // navy — too close to black
        let kits = TeamKitResolver.kits(user: user, opponent: navyOpponent)
        #expect(!kits.user.isAlternate)
        #expect(kits.opponent.isAlternate)

        let limeOpponent = team(primary: 0x7DB84F, secondary: 0x2C5FB8) // lime/royal — clearly distinct
        let clearKits = TeamKitResolver.kits(user: user, opponent: limeOpponent)
        #expect(!clearKits.opponent.isAlternate)
    }

    @Test func standardKitUsesPrimaryJerseyAndSecondaryTrim() {
        let kit = TeamKitResolver.standardKit(for: team(primary: 0x8E1F2F, secondary: 0xF2C230))
        #expect(!kit.isAlternate)
    }

    @Test func contrastColorFlipsOnLightBackgrounds() {
        // Both branches must produce a readable number color; we just verify they differ.
        #expect(TeamKitResolver.contrastColor(on: 0x1A1A1A) != TeamKitResolver.contrastColor(on: 0xF2F2F2))
    }
}

@MainActor
struct TeamStoreTests {

    private func makeStore() -> TeamStore {
        let suiteName = "TeamStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        return TeamStore(defaults: defaults)
    }

    @Test func savePersistsFranchiseLocally() {
        let store = makeStore()
        #expect(store.userTeam == nil)

        let team = GameTeam(
            state: "Nevada", teamName: "Thunder", logoID: "lightning",
            primaryColorHex: 0x6B4FA0, secondaryColorHex: 0xF2C230, isUserTeam: true
        )
        store.save(team)
        #expect(store.hasTeam)
        #expect(store.userTeam == team)
    }

    @Test func loadedStoreRestoresSavedFranchise() {
        let suiteName = "TeamStoreTests.restore.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let team = GameTeam(
            state: "Ohio", teamName: "Steel Boars", logoID: "boar",
            primaryColorHex: 0xC9CDD1, secondaryColorHex: 0xE2762D, isUserTeam: true
        )

        let writer = TeamStore(defaults: defaults)
        writer.save(team)

        let reader = TeamStore(defaults: defaults)
        #expect(reader.userTeam == team)
    }

    @Test func clearRemovesFranchise() {
        let store = makeStore()
        store.save(GameTeam(
            state: "Georgia", teamName: "Firebirds", logoID: "phoenix",
            primaryColorHex: 0xC2412F, secondaryColorHex: 0x1A1A1A, isUserTeam: true
        ))
        #expect(store.hasTeam)
        store.clear()
        #expect(store.userTeam == nil)
        #expect(!store.hasTeam)
    }
}

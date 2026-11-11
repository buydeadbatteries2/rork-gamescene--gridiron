import Foundation
import Testing
@testable import GameSceneGridiron

@MainActor
struct ProfileExpansionTests {
    @Test func allNineProfilesRoundTripAndKeepLegacySpellings() throws {
        #expect(PlayerProfile.allCases.count == 9)
        for profile in PlayerProfile.allCases {
            let data = try JSONEncoder().encode(profile)
            #expect(try JSONDecoder().decode(PlayerProfile.self, from: data) == profile)
            #expect(!profile.title.isEmpty && !profile.summary.isEmpty && !profile.symbol.isEmpty)
        }
        for legacy in PlayerVariant.allCases {
            let data = Data("\"\(legacy.rawValue)\"".utf8)
            #expect(try JSONDecoder().decode(PlayerProfile.self, from: data) == legacy.profile)
            #expect(legacy.profile.legacyVariant == legacy)
        }
        #expect(String(data: try JSONEncoder().encode(PlayerProfile.powerful), encoding: .utf8) == "\"powerful\"")
        #expect(throws: (any Error).self) { try JSONDecoder().decode(PlayerProfile.self, from: Data("\"unknown\"".utf8)) }
    }

    @Test func profilePersistenceSurvivesEnvelopeRoundTrip() throws {
        let suite = "profiles-\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        SaveStore.save(PlayerProfile.allCases, key: "profiles", defaults: defaults)
        #expect(SaveStore.load([PlayerProfile].self, key: "profiles", defaults: defaults) == PlayerProfile.allCases)
    }

    @Test func exactlyFourIncludingEveryPossibleAnswerAtEveryPosition() {
        for position in FootballPosition.allCases {
            for correct in PlayerProfile.allCases {
                for seed in 0..<100 {
                    let options = ProfileOptions.choices(position: position, correct: correct, seed: UInt64(seed))
                    #expect(options.count == 4)
                    #expect(Set(options).count == 4)
                    #expect(options.contains(correct))
                }
            }
        }
    }

    @Test func weightedDistractorsFavorRelevantPositionsWithoutBans() {
        #expect(ProfileOptions.weight(.technical, for: .ol) > ProfileOptions.weight(.elusive, for: .ol))
        #expect(ProfileOptions.weight(.elusive, for: .wr) > ProfileOptions.weight(.powerful, for: .wr))
        for position in FootballPosition.allCases {
            var counts: [PlayerProfile: Int] = [:]
            var combinations: Set<Set<PlayerProfile>> = []
            for seed in 0..<2000 {
                let options = ProfileOptions.choices(position: position, correct: .overrated, seed: UInt64(seed))
                combinations.insert(Set(options))
                for profile in options where profile != .overrated { counts[profile, default: 0] += 1 }
            }
            #expect(counts.count == 8)
            #expect(combinations.count > 35)
            let strongest = ProfileOptions.preferred(for: position).first!
            let unusual = PlayerProfile.allCases.first { !ProfileOptions.preferred(for: position).contains($0) }!
            #expect(counts[strongest, default: 0] > counts[unusual, default: 0] * 2)
        }
    }

    @Test func cachedOptionsSurviveInteractionBackgroundAndReconstruction() {
        let puzzle = CaseLibrary.puzzle(for: CaseLibrary.all[0], quarterIndex: 0)
        let suite = "options-\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let vm = GameViewModel(puzzle: puzzle, wallet: PlayerWallet(defaults: defaults), defaults: defaults)
        vm.lastChanceKey = "persisted-match-q0"
        let original = vm.profileOptions
        let player = puzzle.missingPlayers[0]
        vm.toggleExpanded(player.id); vm.toggleExpanded(player.id)
        vm.showClue(at: 1); vm.isPaused = true; vm.isPaused = false
        vm.selectProfile(original[player.id]![0], for: player.id)
        vm.lastChanceKey = "persisted-match-q0"
        #expect(vm.profileOptions == original)
        let resumed = GameViewModel(puzzle: puzzle, wallet: PlayerWallet(defaults: defaults), defaults: defaults)
        resumed.lastChanceKey = "persisted-match-q0"
        #expect(resumed.profileOptions == original)
        resumed.lastChanceKey = "next-season-match-q0"
        #expect(resumed.profileOptions != original)
        #expect(vm.puzzle.solutions == puzzle.solutions)
    }

    @Test func samePositionCardsAvoidDuplicateCombinations() {
        for puzzleCase in CaseLibrary.all {
            let puzzle = CaseLibrary.puzzle(for: puzzleCase, quarterIndex: 0)
            let options = ProfileOptions.make(puzzle: puzzle, session: "test-match")
            for position in FootballPosition.allCases {
                let cards = puzzle.missingPlayers.filter { $0.position == position }
                let combinations = cards.map { Set(options[$0.id] ?? []) }
                #expect(Set(combinations).count == cards.count)
            }
        }
    }

    @Test func allProfilesHaveEightDistinctSupportedDialectPhrases() {
        for profile in PlayerProfile.allCases {
            let phrases = DifficultyLevel.allCases.flatMap { ProfileDialect.phrases(profile, tier: $0) }
            #expect(phrases.count == 8)
            #expect(Set(phrases).count == 8)
            #expect(!CaseDifficultyAdapter.profileClause(profile, ordinal: 0).isEmpty)
        }
    }

    @Test func everyProductionClueContainsItsTypedReadableSignal() {
        for puzzleCase in CaseLibrary.all {
            #expect(ProfileDialect.failures(in: puzzleCase).isEmpty, "\(puzzleCase.id)")
            for clue in puzzleCase.clues {
                #expect(clue.profileSignal != nil)
                #expect(clue.text.contains(clue.profileSignal!.phrase))
                #expect(puzzleCase.solution.first { $0.playerKey == clue.playerKey }?.profile == clue.profileSignal?.profile)
            }
        }
    }

    @Test func missingOrMislabeledGuidanceFailsValidation() {
        let original = CaseLibrary.all[0]
        let broken = original.clues.map { clue in
            CaseClue(playerKey: clue.playerKey, family: clue.family, difficulty: clue.difficulty,
                     text: "The player is beside the evidence.", constraints: clue.constraints,
                     evidenceKeys: clue.evidenceKeys, profileSignal: clue.profileSignal)
        }
        let copy = QuarterCase(id: original.id, band: original.band, rosterSeed: original.rosterSeed,
            title: original.title, introHeading: original.introHeading, introBody: original.introBody,
            visible: original.visible, missing: original.missing, evidence: original.evidence,
            slots: original.slots, clues: broken, hints: original.hints, solution: original.solution, metadata: original.metadata)
        #expect(ProfileDialect.failures(in: copy).count == original.missing.count)
    }

    @Test func everyProductionVariantIsUniqueAndHasCorrectCardOptions() {
        for level in DifficultyLevel.allCases {
            for original in CaseLibrary.all {
                let adapted = CaseDifficultyAdapter.adapt(original, to: DifficultyResolver.target(selected: level, stage: .midSeason))
                #expect(ProfileDialect.failures(in: adapted).isEmpty, "\(original.id) \(level)")
                let diagnosis = CaseSolver.diagnose(adapted)
                #expect(diagnosis.totalSolutionCount == 1, "\(original.id) \(level)")
                #expect(diagnosis.intendedViolations.isEmpty)
                let puzzle = CaseLibrary.puzzle(for: adapted, quarterIndex: original.band - 1)
                let options = ProfileOptions.make(puzzle: puzzle, session: "production-check")
                for player in puzzle.missingPlayers {
                    #expect(options[player.id]?.count == 4)
                    #expect(Set(options[player.id] ?? []).count == 4)
                    #expect(options[player.id]?.contains(puzzle.solutions[player.id]!.profile) == true)
                }
            }
        }
    }

    @Test func remappingCannotRetainOldDialectOrLoseTypedEvidence() {
        for old in PlayerProfile.allCases {
            for new in PlayerProfile.allCases where old != new {
                let result = CaseDifficultyAdapter.adaptedProfileText(
                    ProfileDialect.phrases(old, tier: .pro)[0], oldProfile: old,
                    newProfile: new, context: "Beside the orange cone.")
                #expect(result == "Beside the orange cone.")
            }
        }
        for original in CaseLibrary.all {
            let adapted = CaseDifficultyAdapter.adapt(original, to: DifficultyResolver.target(selected: .rookie, stage: .midSeason))
            for clue in adapted.clues {
                guard original.solution.first(where: { $0.playerKey == clue.playerKey })?.profile != clue.profileSignal?.profile else { continue }
                for key in clue.evidenceKeys {
                    if let item = adapted.evidence(withKey: key) {
                        #expect(clue.text.localizedCaseInsensitiveContains(item.kind.title), "\(original.id)/\(clue.playerKey): \(item.kind.title)")
                    }
                }
            }
        }
    }

    @Test func hallOfFamerNeverLosesSemanticEvidence() {
        for original in CaseLibrary.all {
            let adapted = CaseDifficultyAdapter.adapt(original, to: DifficultyResolver.target(selected: .hallOfFamer, stage: .championship))
            for clue in adapted.clues {
                #expect(clue.profileSignal?.tier == .hallOfFamer)
                #expect(clue.text.contains(clue.profileSignal!.phrase))
            }
            #expect(ProfileDialect.failures(in: adapted).isEmpty)
        }
    }

    @Test func regularSeasonOvertimeSemifinalAndChampionshipShareFairness() throws {
        var checked = 0
        for level in DifficultyLevel.allCases {
            for week in 1...12 {
                let stage = SeasonStage.forWeek(week)
                let ids = CaseScheduler.gameCaseIDs(seasonNumber: 7, week: week)
                for id in ids.regulation + [ids.overtime] {
                    let original = try #require(CaseLibrary.caseByID(id))
                    let adapted = CaseDifficultyAdapter.adapt(original, to: DifficultyResolver.target(selected: level, stage: stage))
                    #expect(CaseSolver.diagnose(adapted).totalSolutionCount == 1, "week \(week) \(level) \(id)")
                    #expect(ProfileDialect.failures(in: adapted).isEmpty)
                    checked += 1
                }
            }
        }
        #expect(checked == 240)
    }

    @Test func competitiveFingerprintsAndVersionsStayUnchanged() {
        for puzzleCase in CaseLibrary.all {
            #expect(CompetitiveCaseCatalog.fingerprint(of: puzzleCase) == CompetitiveCaseCatalog.entries[puzzleCase.id]?.fingerprint)
            #expect(CompetitiveCaseCatalog.competitiveVersion(forCaseID: puzzleCase.id) == 1)
        }
    }
}

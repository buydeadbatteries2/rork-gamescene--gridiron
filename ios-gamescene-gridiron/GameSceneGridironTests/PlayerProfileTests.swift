import Testing
import Foundation
@testable import GameSceneGridiron

/// Phase 11.5 — player profiles: pools per game difficulty, remapping, and
/// case-authoring validation (never require a profile the difficulty hides).
@MainActor
struct PlayerProfileTests {

    private var defaults: UserDefaults!

    private func makeDefaults() -> UserDefaults {
        let suite = "profile-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    // MARK: Pools by game difficulty

    @Test func profilePoolsFollowTheGameDifficulty() {
        #expect(PlayerProfile.pool(for: .rookie) == [.rookie, .veteran])
        #expect(PlayerProfile.pool(for: .pro) == [.rookie, .veteran, .fast, .powerful])
        #expect(PlayerProfile.pool(for: .allPro).count == 5)
        #expect(PlayerProfile.pool(for: .hallOfFamer).count == 5)
        // Overrated is only available where the full pool is.
        #expect(!PlayerProfile.pool(for: .rookie).contains(.overrated))
        #expect(!PlayerProfile.pool(for: .pro).contains(.overrated))
        #expect(PlayerProfile.pool(for: .allPro).contains(.overrated))
        #expect(PlayerProfile.pool(for: .hallOfFamer).contains(.overrated))
    }

    @Test func profilesStaySeparateFromGameDifficulty() {
        // Two distinct types: the game mode vs. the deployment profile.
        #expect(DifficultyLevel.rookie.rawValue == "rookie")
        #expect(PlayerProfile.rookie.rawValue == "rookie")
        #expect(PlayerProfile(legacy: .power) == .powerful)
        #expect(PlayerProfile(legacy: .fast) == .fast)
        #expect(PlayerProfile(legacy: .veteran) == .veteran)
        #expect(PlayerProfile.powerful.legacyVariant == .power)
        #expect(PlayerProfile.rookie.legacyVariant == nil)
        #expect(PlayerProfile.overrated.legacyVariant == nil)
        // The user-facing label reads POWERFUL, never "Power".
        #expect(PlayerProfile.powerful.title == "Powerful")
    }

    // MARK: Remapping

    @Test func legacyProfilesRemapOntoSmallerPools() {
        let rookiePool = PlayerProfile.pool(for: .rookie)
        #expect(ProfilePoolAdapter.remap(.fast, into: rookiePool) == .rookie)
        #expect(ProfilePoolAdapter.remap(.powerful, into: rookiePool) == .veteran)
        #expect(ProfilePoolAdapter.remap(.veteran, into: rookiePool) == .veteran)

        let proPool = PlayerProfile.pool(for: .pro)
        #expect(ProfilePoolAdapter.remap(.fast, into: proPool) == .fast)
        #expect(ProfilePoolAdapter.remap(.powerful, into: proPool) == .powerful)
        #expect(ProfilePoolAdapter.remap(.overrated, into: proPool) == .rookie)
        #expect(ProfilePoolAdapter.remap(.veteran, into: proPool) == .veteran)
    }

    // MARK: Selection guard

    @Test func selectionOnlyAcceptsProfilesInTheActivePool() {
        let viewModel = GameViewModel(puzzle: SampleQuarter.puzzle, difficulty: .rookie)
        let player = SampleQuarter.puzzle.player(id: "p-rb")!

        viewModel.selectProfile(.fast, for: player.id)
        #expect(viewModel.selectedProfile(for: player.id) == nil, "Rookie difficulty hides Fast — selection must be refused")

        viewModel.selectProfile(.rookie, for: player.id)
        #expect(viewModel.selectedProfile(for: player.id) == .rookie)

        // Picking a different profile replaces the choice…
        viewModel.selectProfile(.veteran, for: player.id)
        #expect(viewModel.selectedProfile(for: player.id) == .veteran)

        // …and tapping it again clears it.
        viewModel.selectProfile(.veteran, for: player.id)
        #expect(viewModel.selectedProfile(for: player.id) == nil)
    }

    @Test func availableProfilesMirrorTheDifficulty() {
        #expect(GameViewModel(puzzle: SampleQuarter.puzzle, difficulty: .rookie).availableProfiles == [.rookie, .veteran])
        #expect(GameViewModel(puzzle: SampleQuarter.puzzle, difficulty: .pro).availableProfiles == [.rookie, .veteran, .fast, .powerful])
        #expect(GameViewModel(puzzle: SampleQuarter.puzzle, difficulty: .hallOfFamer).availableProfiles.count == 5)
    }

    // MARK: Case validation (§30)

    /// Adapts every library case to a difficulty and validates profile legality.
    private func adaptedCases(for level: DifficultyLevel) -> [QuarterCase] {
        let target = DifficultyResolver.target(selected: level, stage: .midSeason)
        return CaseLibrary.all.map { CaseDifficultyAdapter.adapt($0, to: target) }
    }

    @Test func rookieCasesNeverRequireFastPowerfulOrOverrated() {
        let pool = Set(PlayerProfile.pool(for: .rookie))
        for puzzleCase in adaptedCases(for: .rookie) {
            for entry in puzzleCase.solution {
                #expect(pool.contains(entry.profile), "\(puzzleCase.id) requires \(entry.profile) at Rookie")
            }
            for clue in puzzleCase.clues {
                for constraint in clue.constraints {
                    switch constraint {
                    case .profileIs(_, let profile):
                        #expect(pool.contains(profile), "\(puzzleCase.id) clue positively requires unavailable profile \(profile)")
                    case .profileIsNot:
                        // Excluding an out-of-pool profile is exactly how the
                        // adapter encodes "this option is off the table".
                        break
                    default: break
                    }
                }
            }
        }
    }

    @Test func proCasesNeverRequireOverrated() {
        let pool = Set(PlayerProfile.pool(for: .pro))
        for puzzleCase in adaptedCases(for: .pro) {
            for entry in puzzleCase.solution {
                #expect(pool.contains(entry.profile), "\(puzzleCase.id) requires \(entry.profile) at Pro")
            }
        }
    }

    @Test func allProAndHallOfFamerMayUseAllFiveProfiles() {
        let pool = Set(PlayerProfile.allCases)
        for level in [DifficultyLevel.allPro, .hallOfFamer] {
            for puzzleCase in adaptedCases(for: level) {
                for entry in puzzleCase.solution {
                    #expect(pool.contains(entry.profile), "\(puzzleCase.id) requires an unknown profile")
                }
            }
        }
    }

    @Test func overratedCasesStayDeterministicWithOneValidSolution() {
        let target = DifficultyResolver.target(selected: .hallOfFamer, stage: .midSeason)
        for authored in CaseLibrary.all {
            let adapted = CaseDifficultyAdapter.adapt(authored, to: target)
            let usesOverrated = adapted.solution.contains { $0.profile == .overrated }
            guard usesOverrated else { continue }
            let diagnosis = CaseSolver.diagnose(adapted)
            #expect(diagnosis.isUnique, "\(adapted.id) uses Overrated but is not a deterministic single-solution case")
        }
    }

    @Test func everyAdaptedCaseStillHasExactlyOneValidSolution() {
        for level in [DifficultyLevel.rookie, .pro, .allPro, .hallOfFamer] {
            for puzzleCase in adaptedCases(for: level) {
                #expect(CaseSolver.isUnique(puzzleCase), "\(puzzleCase.id) lost uniqueness at \(level.rawValue)")
            }
        }
    }

    @Test func noCluePositivelyRequiresProfileLogicTheDifficultyHides() {
        for level in [DifficultyLevel.rookie, .pro] {
            let pool = Set(PlayerProfile.pool(for: level))
            for puzzleCase in adaptedCases(for: level) {
                for clue in puzzleCase.clues {
                    for constraint in clue.constraints {
                        switch constraint {
                        case .profileIs(_, let profile):
                            #expect(pool.contains(profile), "\(puzzleCase.id) clue \(clue.playerKey) positively uses \(profile) at \(level.rawValue)")
                        case .profileIsNot:
                            break
                        default: break
                        }
                    }
                }
            }
        }
    }
}

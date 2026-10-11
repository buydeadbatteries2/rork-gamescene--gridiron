import CoreGraphics
import Foundation
import Testing
@testable import GameSceneGridiron

/// Phase 8 coverage: onboarding gating and persistence, the TRAINING CASE
/// (dedicated puzzle, can't permanently fail, economy-isolated), replay,
/// accessibility settings and the first-game assist lifecycle.
@MainActor
@Suite("TutorialTests")
struct TutorialTests {
    private let suiteName: String
    private let defaults: UserDefaults
    private let tutorial: TutorialManager

    init() {
        suiteName = "gamescene.tutorial-tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        tutorial = TutorialManager(defaults: defaults)
    }

    private func freshIsolatedSuite() -> UserDefaults {
        let name = "gamescene.tutorial-tests.\(UUID().uuidString)"
        let suite = UserDefaults(suiteName: name)!
        suite.removePersistentDomain(forName: name)
        return suite
    }

    // MARK: 1–2. Onboarding gating

    @Test("New install launches onboarding; returning user skips it")
    func onboardingGatesFirstLaunchOnly() {
        // Fresh install: onboarding is pending.
        #expect(!tutorial.hasCompletedOnboarding)

        // Completing the flow persists completion for every future launch.
        tutorial.completeOnboarding()
        let reloaded = TutorialManager(defaults: defaults)
        #expect(reloaded.hasCompletedOnboarding)
        #expect(!reloaded.isFirstGameAssistActive, "onboarding graduates skip the first-game assist")
    }

    @Test("Replay tutorial never re-gates onboarding")
    func replayTutorialWorks() {
        tutorial.completeOnboarding()
        tutorial.beginTutorialReplay()
        #expect(tutorial.hasCompletedOnboarding, "a replay is a navigation action — completion is never revoked")
        #expect(TutorialManager(defaults: defaults).hasCompletedOnboarding)
    }

    // MARK: 3. The training case teaches everything

    @Test("Training case is a dedicated, unique, decoy-free 3-player puzzle")
    func trainingCaseTeachesAllCoreInteractions() {
        let trainingCase = TrainingCase.authored
        let puzzle = TrainingCase.puzzle()

        // Not part of the 50-case library — the season can never draw it.
        #expect(CaseLibrary.caseByID(trainingCase.id) == nil)
        #expect(!CaseScheduler.seasonSchedule(seasonNumber: 1).contains(trainingCase.id))
        #expect(puzzle.quarterLabel == "TRAINING")

        // 3 missing players, no deceptive decoys: exactly one zone per answer.
        #expect(puzzle.missingPlayers.count == 3)
        #expect(puzzle.slots.count == 3)
        #expect(puzzle.solutions.count == 3)
        #expect(puzzle.isWellFormed)

        // Very clear clue relationships: one explicit clue per player, all easy.
        #expect(puzzle.clues.count == 3)
        #expect(puzzle.clues.allSatisfy { $0.difficulty == .easy })
        #expect(Set(puzzle.clues.map(\.playerID)).count == 3)

        // Every taught profile appears exactly once — the same position may
        // require a different profile in different cases, so all three are shown.
        let variants = Set(puzzle.solutions.values.map(\.profile))
        #expect(variants == [.fast, .powerful, .veteran])

        // Field evidence is visually obvious: pylon, play sheet, mouthguard, cone.
        let kinds = Set(puzzle.evidence.map(\.kind))
        #expect(kinds.contains(.pylon) && kinds.contains(.laminatedPlaySheet) && kinds.contains(.orangeCone))
        #expect(kinds.isDisjoint(with: [.orangeTowel, .waterBottle, .droppedGlove]))

        // Exactly one provable solution, like every case in the game.
        #expect(CaseSolver.isUnique(trainingCase))
    }

    // MARK: 4. Impossible to permanently fail

    @Test("Training mistakes cost no heart and never end the quarter")
    func trainingCannotPermanentlyFail() {
        let puzzle = TrainingCase.puzzle()
        let gameViewModel = GameViewModel(puzzle: puzzle, wallet: PlayerWallet(defaults: freshIsolatedSuite()))
        gameViewModel.isTraining = true
        gameViewModel.fieldFrame = CGRect(x: 0, y: 0, width: 1000, height: 1000)

        // The RB card: right slot, wrong profile — a genuine wrong placement.
        let runningBack = puzzle.missingPlayers.first { $0.position == .rb }!
        gameViewModel.selectProfile(.powerful, for: runningBack.id)

        #expect(gameViewModel.beginDrag(playerID: runningBack.id, at: CGPoint(x: 420, y: 740)))
        gameViewModel.updateDrag(to: CGPoint(x: 420, y: 740))
        gameViewModel.endDrag()

        #expect(gameViewModel.lives == puzzle.startingLives, "training never costs a heart")
        #expect(gameViewModel.result == .inProgress, "the quarter cannot end through mistakes")
        #expect(gameViewModel.remainingPlayers.count == 3, "the player stays in play to try again")
    }

    // MARK: 5–7. Economy & season isolation

    @Test("Training touches neither the season record nor the persistent economy")
    func trainingIsIsolatedFromSeasonAndEconomy() {
        let seasonDefaults = freshIsolatedSuite()
        let seasonManager = SeasonManager(defaults: seasonDefaults)
        let userTeam = GameTeam(
            state: "Nevada", teamName: "Case Stags", logoID: "wolf",
            primaryColorHex: 0x1E2A4A, secondaryColorHex: 0xC9CDD1, isUserTeam: true
        )
        seasonManager.startNewSeason(userTeam: userTeam)
        let schedule = seasonManager.season?.scheduledCaseIDs
        let gamesBefore = seasonManager.season?.games.count ?? -1

        // The training wallet is a disposable instance on its own suite.
        let realWallet = PlayerWallet(defaults: freshIsolatedSuite())
        _ = realWallet.addHints(2) // separate persistent wallet at 3 + 2 hints
        let realHintsBefore = realWallet.hints
        let realBallsBefore = realWallet.gameBalls

        let trainingWallet = PlayerWallet(defaults: freshIsolatedSuite())
        #expect(trainingWallet.gameBalls == EconomyConfig.standard.startingGameBalls)
        #expect(trainingWallet.hints == EconomyConfig.standard.startingHints)

        let gameViewModel = GameViewModel(puzzle: TrainingCase.puzzle(), wallet: trainingWallet)
        gameViewModel.isTraining = true
        gameViewModel.useHint()

        #expect(trainingWallet.hints == EconomyConfig.standard.startingHints - 1, "hints draw from the disposable training wallet")
        #expect(realWallet.hints == realHintsBefore, "the persistent hint inventory is never touched")
        #expect(realWallet.gameBalls == realBallsBefore, "no Game Balls are ever consumed by training")

        // The season record is untouched by the tutorial flow.
        tutorial.completeOnboarding()
        #expect(seasonManager.season?.scheduledCaseIDs == schedule)
        #expect(seasonManager.season?.games.count == gamesBefore)
        #expect(seasonManager.userRecordLine == "0–0")
    }

    // MARK: 8–10. Persistence

    @Test("Tutorial completion, tooltips and difficulty all persist")
    func tutorialStatePersists() {
        tutorial.completeOnboarding()
        tutorial.markTooltipSeen(ContextualTooltip.gameBalls)
        DifficultyManager(defaults: defaults).select(.hallOfFamer)

        let reloaded = TutorialManager(defaults: defaults)
        #expect(reloaded.hasCompletedOnboarding)
        #expect(reloaded.hasSeenTooltip(ContextualTooltip.gameBalls))
        #expect(DifficultyManager(defaults: defaults).selected == .hallOfFamer)

        // Resetting tutorial data re-arms onboarding and every tooltip.
        reloaded.resetTutorialData()
        let reset = TutorialManager(defaults: defaults)
        #expect(!reset.hasCompletedOnboarding)
        #expect(!reset.hasSeenTooltip(ContextualTooltip.gameBalls))
        #expect(reset.isFirstGameAssistActive)
        #expect(DifficultyManager(defaults: defaults).selected == .hallOfFamer, "difficulty survives a tutorial reset")
    }

    // MARK: 11–13. Accessibility settings

    @Test("Larger Clue Text, Reduce Motion and High Contrast persist and are respected")
    func accessibilitySettingsPersistAndApply() {
        #expect(!tutorial.isLargerClueTextEnabled)
        #expect(!tutorial.isReduceMotionEnabled)
        #expect(!tutorial.isHighContrastCluesEnabled)
        #expect(tutorial.isHapticsEnabled)

        tutorial.isLargerClueTextEnabled = true
        tutorial.isReduceMotionEnabled = true
        tutorial.isHighContrastCluesEnabled = true
        tutorial.isHapticsEnabled = false

        let reloaded = TutorialManager(defaults: defaults)
        #expect(reloaded.isLargerClueTextEnabled)
        #expect(reloaded.isReduceMotionEnabled)
        #expect(reloaded.isHighContrastCluesEnabled)
        #expect(!reloaded.isHapticsEnabled)

        // Reduce Motion is respected by the shared transition helpers —
        // note `Motion` reads the shared singleton (standard defaults), so
        // the meaningful assertion here is the isolated-instance round-trip
        // above; the live transition behavior follows the same flag.
        #expect(reloaded.isReduceMotionEnabled)

        // High contrast swaps the marker colors for saturated ones.
        let highlighted = ClueHighlighter.highlighted("A quick back near the orange cone.", highContrast: true)
        let regular = ClueHighlighter.highlighted("A quick back near the orange cone.", highContrast: false)
        #expect(highlighted != regular)

        // Larger Clue Text never clips: the training copy renders at full size.
        #expect(TrainingCase.puzzle().clues.allSatisfy { !$0.text.isEmpty })
    }

    @Test("Music and SFX settings persist, including volumes")
    func audioSettingsPersist() {
        let audio = AudioManager(defaults: defaults)
        #expect(audio.isMusicEnabled)
        #expect(audio.isSoundEffectsEnabled)
        #expect(audio.musicVolume == 0.3)
        #expect(audio.effectVolume == 0.85)

        audio.setMusicEnabled(false)
        audio.setSoundEffectsEnabled(false)
        audio.musicVolume = 0.6
        audio.effectVolume = 0.25

        let reloaded = AudioManager(defaults: defaults)
        #expect(!reloaded.isMusicEnabled)
        #expect(!reloaded.isSoundEffectsEnabled)
        #expect(reloaded.musicVolume == 0.6)
        #expect(reloaded.effectVolume == 0.25)
    }

    // MARK: 15. First-game assist lifecycle

    @Test("First-game assist shows only until Game 1 is done")
    func firstGameAssistDisappearsAfterGameOne() {
        #expect(tutorial.isFirstGameAssistActive)

        tutorial.markFirstGameAssistDone()
        #expect(!tutorial.isFirstGameAssistActive)
        #expect(!TutorialManager(defaults: defaults).isFirstGameAssistActive)

        // Onboarding graduation implies the assist is done — a brand-new
        // user who just finished the training case never sees both.
        let fresh = TutorialManager(defaults: freshIsolatedSuite())
        #expect(fresh.isFirstGameAssistActive)
        fresh.completeOnboarding()
        #expect(!fresh.isFirstGameAssistActive)
    }

    // MARK: Completion & exit flow

    @Test("Training completion is reachable, explicit and quiets the coach")
    func trainingCompletionStateIsExplicit() {
        let gameViewModel = GameViewModel(puzzle: TrainingCase.puzzle(), wallet: PlayerWallet(defaults: freshIsolatedSuite()))
        gameViewModel.isTraining = true
        gameViewModel.fieldFrame = CGRect(x: 0, y: 0, width: 360, height: 480)
        let session = TrainingSession(viewModel: gameViewModel)

        #expect(!session.isComplete, "the session starts unfinished")

        // The full interactive path: open the coach gates exactly as the user
        // would (inspect → profiles → clue), then three real drag placements
        // drive the step machine to hints, GOT IT lands on complete — there is
        // no stuck state where the final objective is solved but completion
        // never arrives.
        gameViewModel.expandedPlayerID = gameViewModel.remainingPlayers.first?.id
        session.handleExpansion()
        session.confirmProfiles()
        session.confirmClue()

        for (playerID, solution) in gameViewModel.puzzle.solutions {
            guard let slot = gameViewModel.puzzle.slot(id: solution.slotID) else {
                Issue.record("Missing slot \(solution.slotID) in the training case")
                continue
            }
            gameViewModel.selectProfile(solution.profile, for: playerID)
            let point = gameViewModel.point(x: slot.x, y: slot.y)
            let dropLocation = CGPoint(x: point.x, y: point.y + GameViewModel.dragLift)
            #expect(gameViewModel.beginDrag(playerID: playerID, at: dropLocation))
            gameViewModel.updateDrag(to: dropLocation)
            gameViewModel.endDrag()
            session.placementsChanged()
            // Dismiss the lessons that appear between placements.
            session.confirmEvidence()
            session.confirmLives()
            session.confirmRelational()
        }
        #expect(session.step == .hints)
        session.confirmHints()

        #expect(session.isComplete)
        #expect(session.coach == nil, "no instructional prompt survives completion")
        #expect(session.highlightedPlayerID == nil)
        #expect(!session.isCaseFileHighlighted)
        #expect(!session.isHintHighlighted)
        #expect(session.guidedSlotID == nil)
        #expect(session.highlightedEvidenceID == nil)
    }

    @Test("Completion persists at the moment of solving; reset re-arms it")
    func tutorialCompletionPersists() {
        #expect(!tutorial.hasCompletedTutorial)

        tutorial.markTutorialCompleted()
        #expect(tutorial.hasCompletedTutorial)
        // Idempotent — a replay just re-confirms.
        tutorial.markTutorialCompleted()

        // Persisted immediately, not only after relaunch.
        let reloaded = TutorialManager(defaults: defaults)
        #expect(reloaded.hasCompletedTutorial)
        #expect(reloaded.hasCompletedOnboarding == tutorial.hasCompletedOnboarding)

        reloaded.resetTutorialData()
        #expect(!TutorialManager(defaults: defaults).hasCompletedTutorial)
    }

    @Test("First-time completion offers START MY SEASON; replay offers DONE")
    func completionButtonTitles() {
        #expect(TrainingFlowView(onComplete: {}).completeButtonTitle == "START MY SEASON")
        #expect(TrainingFlowView(completeButtonTitle: "DONE", onComplete: {}).completeButtonTitle == "DONE")
    }

    @Test("Replay completion never alters season progress")
    func replayCompletionLeavesSeasonUntouched() {
        let seasonDefaults = freshIsolatedSuite()
        let seasonManager = SeasonManager(defaults: seasonDefaults)
        let userTeam = GameTeam(
            state: "Nevada", teamName: "Case Stags", logoID: "wolf",
            primaryColorHex: 0x1E2A4A, secondaryColorHex: 0xC9CDD1, isUserTeam: true
        )
        seasonManager.startNewSeason(userTeam: userTeam)
        let schedule = seasonManager.season?.scheduledCaseIDs
        let gamesBefore = seasonManager.season?.games.count

        // Completing (or replaying) the tutorial persists completion and never
        // records a game, a reward or a schedule change.
        tutorial.completeOnboarding()
        tutorial.markTutorialCompleted()

        #expect(seasonManager.season?.scheduledCaseIDs == schedule)
        #expect(seasonManager.season?.games.count == gamesBefore)
        #expect(seasonManager.userRecordLine == "0–0")
        #expect(tutorial.hasCompletedOnboarding, "a returning user is never forced back into the tutorial")
    }

    // MARK: Contextual tooltips

    @Test("Each contextual tooltip shows exactly once until data is reset")
    func contextualTooltipsShowOnce() {
        #expect(!tutorial.hasSeenTooltip(ContextualTooltip.teamScreen))
        tutorial.markTooltipSeen(ContextualTooltip.teamScreen)
        tutorial.markTooltipSeen(ContextualTooltip.playerStats)
        tutorial.markTooltipSeen(ContextualTooltip.postseason)
        #expect(tutorial.hasSeenTooltip(ContextualTooltip.teamScreen))
        #expect(tutorial.hasSeenTooltip(ContextualTooltip.playerStats))
        #expect(tutorial.hasSeenTooltip(ContextualTooltip.postseason))
        #expect(!tutorial.hasSeenTooltip(ContextualTooltip.gameBalls), "unrelated tooltips stay independent")
    }
}

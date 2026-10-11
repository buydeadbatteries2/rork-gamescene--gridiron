import Testing
import Foundation
import CoreGraphics
@testable import GameSceneGridiron

/// Phase 11.5 Part B/C — the Hall of Famer play clock and timeout system.
/// Rookie, Pro and All-Pro are untimed; Hall of Famer runs a per-placement
/// 40-second clock with two 25-second timeouts per quarter. All controllers
/// in these tests tick deterministically (no real-time waits).
@MainActor
struct HallOfFamerClockTests {

    // MARK: Fixtures

    private func makeDefaults() -> UserDefaults {
        let suite = "hof-clock-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        // Mark the one-time explanation as seen unless a test wants it.
        defaults.set(true, forKey: GameViewModel.clockIntroKey)
        return defaults
    }

    private func makeViewModel(
        difficulty: DifficultyLevel = .hallOfFamer,
        defaults: UserDefaults? = nil
    ) -> GameViewModel {
        GameViewModel(
            puzzle: SampleQuarter.puzzle,
            wallet: PlayerWallet(defaults: defaults ?? makeDefaults()),
            difficulty: difficulty,
            defaults: defaults ?? makeDefaults(),
            makeClock: { PlayClockController(duration: $0, autoTicks: false) }
        )
    }

    /// Drags `playerID` onto the slot `x`/`y` (normalized) and releases.
    private func drag(_ viewModel: GameViewModel, playerID: String, x: Double, y: Double) {
        viewModel.fieldFrame = CGRect(x: 0, y: 0, width: 400, height: 300)
        let point = viewModel.point(x: x, y: y)
        guard viewModel.beginDrag(playerID: playerID, at: CGPoint(x: point.x, y: point.y + GameViewModel.dragLift)) else {
            Issue.record("beginDrag failed for \(playerID)")
            return
        }
        viewModel.endDrag()
    }

    // MARK: Untimed difficulties

    @Test func rookieProAndAllProAreUntimed() {
        for level in [DifficultyLevel.rookie, .pro, .allPro] {
            let viewModel = makeViewModel(difficulty: level)
            #expect(!viewModel.isTimed, "\(level.rawValue) must be untimed")
            #expect(viewModel.playClock == nil)
            #expect(viewModel.timeoutsRemaining == 0)
            viewModel.beginPlacementClock()
            #expect(viewModel.playClock == nil)
            viewModel.callTimeout()
            #expect(viewModel.timeoutClock == nil, "\(level.rawValue) cannot call timeouts")
        }
    }

    @Test func hallOfFamerUsesAFortySecondPerPlacementClock() {
        let viewModel = makeViewModel()
        #expect(viewModel.isTimed)
        #expect(viewModel.playClock?.duration == 40)
        viewModel.beginPlacementClock()
        #expect(viewModel.playClock?.isRunning == true)
        #expect(viewModel.playClock?.remaining == 40)
    }

    @Test func trainingIsNeverTimed() {
        let defaults = makeDefaults()
        let viewModel = GameViewModel(
            puzzle: SampleQuarter.puzzle,
            wallet: PlayerWallet(defaults: defaults),
            difficulty: .hallOfFamer,
            defaults: defaults,
            makeClock: { PlayClockController(duration: $0, autoTicks: false) }
        )
        viewModel.isTraining = true
        viewModel.beginPlacementClock()
        #expect(viewModel.playClock?.isRunning == false)
    }

    // MARK: First-time explanation

    @Test func firstHallOfFamerGameExplainsTheClockBeforeItStarts() {
        let defaults = makeDefaults()
        defaults.removeObject(forKey: GameViewModel.clockIntroKey)
        let viewModel = GameViewModel(
            puzzle: SampleQuarter.puzzle,
            wallet: PlayerWallet(defaults: defaults),
            difficulty: .hallOfFamer,
            defaults: defaults,
            makeClock: { PlayClockController(duration: $0, autoTicks: false) }
        )
        #expect(viewModel.isClockIntroPresented)
        viewModel.beginPlacementClock()
        #expect(viewModel.playClock?.isRunning == false, "The first clock waits for GOT IT")
        viewModel.dismissClockIntro()
        #expect(!viewModel.isClockIntroPresented)
        #expect(viewModel.playClock?.isRunning == true)
        #expect(defaults.bool(forKey: GameViewModel.clockIntroKey))
    }

    // MARK: Expiration

    @Test func expirationCostsExactlyOneLifeAndNeverRevealsTheAnswer() {
        let viewModel = makeViewModel()
        viewModel.lastChanceKey = "match-q0"
        viewModel.beginPlacementClock()
        let livesBefore = viewModel.lives

        viewModel.playClock?.tick(by: 40)

        #expect(viewModel.lives == livesBefore - 1)
        #expect(viewModel.rejectionCount == 1, "Expiration counts as one failed attempt")
        #expect(viewModel.result == .inProgress, "The answer is not revealed on expiration")
        #expect(viewModel.draggingPlayerID == nil, "Any active drag returned to the tray")
        #expect(viewModel.hoveredSlotID == nil)
        #expect(viewModel.rejectedSlotID == nil, "Temporary placement-zone UI cleared")
        // Fresh 40 for the next attempt while the quarter is live.
        #expect(viewModel.playClock?.remaining == 40)
        #expect(viewModel.playClock?.isRunning == true)
    }

    @Test func expirationDrainsIntoLastChanceAndKeepsTimeoutsConsumed() {
        let viewModel = makeViewModel()
        viewModel.lastChanceKey = "match-q0"
        viewModel.beginPlacementClock()
        viewModel.selectProfile(.fast, for: "p-rb")

        // Burn one heart on a wrong placement, two more on the clock.
        drag(viewModel, playerID: "p-rb", x: 0.34, y: 0.70) // wrong slot, profile irrelevant
        for _ in 0..<2 {
            viewModel.playClock?.tick(by: 40)
        }
        #expect(viewModel.lives == 0)
        // Wrong placement + two expirations = 3 failed attempts.
        #expect(viewModel.rejectionCount == 3)

        if viewModel.isLastChancePending {
            let timeoutsBefore = viewModel.timeoutsRemaining
            viewModel.grantLastChanceLife()
            #expect(viewModel.lives == 1)
            #expect(viewModel.timeoutsRemaining == timeoutsBefore, "Last Chance never restores consumed timeouts")
            #expect(viewModel.playClock?.remaining == 40, "The earned life restarts the placement with a fresh clock")
        } else {
            #expect(viewModel.result != .inProgress, "Without the Last Chance offer the quarter ends")
        }
    }

    // MARK: Correct placement resets the clock

    @Test func correctPlacementStopsTheClockAndTheNextPlacementStartsAtForty() {
        let viewModel = makeViewModel()
        viewModel.lastChanceKey = "match-q0"
        viewModel.beginPlacementClock()
        viewModel.playClock?.tick(by: 23) // mid-placement
        viewModel.selectProfile(.fast, for: "p-rb")

        drag(viewModel, playerID: "p-rb", x: 0.50, y: 0.78) // s-backfield — correct

        #expect(viewModel.placements.count == 1)
        #expect(viewModel.remainingPlayers.count == 5)
        #expect(viewModel.playClock?.remaining == 40, "The next placement begins a fresh 40-second clock")
        #expect(viewModel.playClock?.isRunning == true)
    }

    // MARK: Timeouts

    @Test func twoTimeoutsExistPerQuarterAndNeverRegenerate() {
        let viewModel = makeViewModel()
        viewModel.lastChanceKey = "match-q0"
        viewModel.beginPlacementClock()

        #expect(viewModel.timeoutsRemaining == 2)
        viewModel.callTimeout()
        viewModel.resumePlay()
        viewModel.callTimeout()
        viewModel.resumePlay()
        #expect(viewModel.timeoutsRemaining == 0)

        viewModel.callTimeout()
        #expect(viewModel.timeoutClock == nil, "The third timeout is refused — timeouts do not carry over or regenerate")
    }

    @Test func timeoutFreezesTheClockAtItsExactValueAndResumesThere() {
        let viewModel = makeViewModel()
        viewModel.lastChanceKey = "match-q0"
        viewModel.beginPlacementClock()
        viewModel.playClock?.tick(by: 29)

        viewModel.callTimeout()
        #expect(viewModel.timeoutsRemaining == 1)
        #expect(viewModel.playClock?.phase == .suspended)

        // Time passes while the timeout runs — the play clock must not move.
        viewModel.playClock?.tick(by: 100)
        #expect(viewModel.playClock?.remaining == 11, "The play clock is frozen during the timeout")

        viewModel.resumePlay()
        #expect(viewModel.timeoutClock == nil)
        #expect(viewModel.playClock?.isRunning == true)
        #expect(viewModel.playClock?.remaining == 11, "RESUME PLAY returns the exact preserved value, never a reset to 40")

        // Letting the resumed clock run out expires it — one life — and the
        // next placement gets a fresh 40.
        let livesBefore = viewModel.lives
        viewModel.playClock?.tick(by: 12)
        #expect(viewModel.lives == livesBefore - 1)
        #expect(viewModel.playClock?.isRunning == true)
        #expect(viewModel.playClock?.remaining == 40)
    }

    @Test func timeoutLastsNoMoreThanTwentyFiveSecondsThenResumesAutomatically() {
        let viewModel = makeViewModel()
        viewModel.lastChanceKey = "match-q0"
        viewModel.beginPlacementClock()
        viewModel.playClock?.tick(by: 20)

        viewModel.callTimeout()
        #expect(viewModel.timeoutClock?.duration == 25)

        viewModel.timeoutClock?.tick(by: 25)
        #expect(viewModel.timeoutClock == nil, "The full 25 seconds resumes play automatically")
        #expect(viewModel.playClock?.isRunning == true)
        #expect(viewModel.playClock?.remaining == 20)
    }

    @Test func placementsAreBlockedDuringATimeoutButReviewIsNot() {
        let viewModel = makeViewModel()
        viewModel.lastChanceKey = "match-q0"
        viewModel.beginPlacementClock()
        viewModel.selectProfile(.fast, for: "p-rb")

        viewModel.callTimeout()

        viewModel.fieldFrame = CGRect(x: 0, y: 0, width: 400, height: 300)
        let ok = viewModel.beginDrag(playerID: "p-rb", at: CGPoint(x: 200, y: 278))
        #expect(!ok, "No final drag/drop placement while timeout mode is active")
        #expect(viewModel.draggingPlayerID == nil)

        // Review actions stay allowed: profile selection and expansion.
        viewModel.selectProfile(.veteran, for: "p-rb")
        #expect(viewModel.selectedProfile(for: "p-rb") == .veteran)
    }

    // MARK: Automatic pauses

    @Test func backgroundingAdsStoreKitAndAchievementsFreezeTheClock() {
        let reasons: [PlayClockController.SuspendReason] = [.background, .ad, .storeKit, .achievement, .dialog, .transition]
        for reason in reasons {
            let viewModel = makeViewModel()
            viewModel.lastChanceKey = "match-\(reason.rawValue)"
            viewModel.beginPlacementClock()
            viewModel.playClock?.tick(by: 23) // 40 − 23 → 17 left

            viewModel.suspendPlayClock(for: reason)
            viewModel.playClock?.tick(by: 100)
            #expect(viewModel.playClock?.remaining == 17, "\(reason) must freeze the clock")

            viewModel.resumePlayClock(for: reason)
            #expect(viewModel.playClock?.isRunning == true)
            #expect(viewModel.playClock?.remaining == 17)
        }
    }

    // MARK: Persistence (force-quit safety)

    @Test func forceQuitCannotRestoreTimeoutsOrLivesOrResetTheClock() {
        let defaults = makeDefaults()
        let walletDefaults = makeDefaults()

        let first = GameViewModel(
            puzzle: SampleQuarter.puzzle,
            wallet: PlayerWallet(defaults: walletDefaults),
            difficulty: .hallOfFamer,
            defaults: defaults,
            makeClock: { PlayClockController(duration: $0, autoTicks: false) }
        )
        first.lastChanceKey = "match-forcequit-q0"
        first.beginPlacementClock()
        first.selectProfile(.fast, for: "p-rb")
        drag(first, playerID: "p-rb", x: 0.50, y: 0.78) // solved placement
        first.playClock?.tick(by: 31) // 9 seconds left
        first.callTimeout() // one timeout consumed
        first.resumePlay()
        first.playClock?.tick(by: 40) // expiration → one life gone, frozen at 40 again

        let frozenRemaining = first.playClock?.remaining ?? 40

        // "Force quit": a brand-new view model over the same persistence.
        let reopened = GameViewModel(
            puzzle: SampleQuarter.puzzle,
            wallet: PlayerWallet(defaults: walletDefaults),
            difficulty: .hallOfFamer,
            defaults: defaults,
            makeClock: { PlayClockController(duration: $0, autoTicks: false) }
        )
        reopened.lastChanceKey = "match-forcequit-q0"

        #expect(reopened.lives == first.lives, "Lost lives are never restored")
        #expect(reopened.timeoutsRemaining == 1, "Consumed timeouts are never restored")
        #expect(reopened.placements.count == 1, "Solved placements are never duplicated or lost")
        #expect(reopened.playClock?.remaining == frozenRemaining, "The almost-expired clock is never reset to 40")
        #expect(reopened.playClock?.phase == .suspended, "A restored quarter comes back frozen until play resumes")
    }
}

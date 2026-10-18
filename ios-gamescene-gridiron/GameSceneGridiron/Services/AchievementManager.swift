import Foundation
import Observation

// MARK: - Achievement manager

/// Single source of truth for achievement state: progress counters, unlock
/// dates, reward claims and the popup queue. Persistence is a single
/// UserDefaults JSON blob; everything survives restarts and new seasons.
///
/// Evaluation is strictly event-driven (Phase 10): conditions are checked only
/// when `AchievementCoordinator` forwards a gameplay event — never on a timer
/// and never by scanning. Achievements are pure recognition: unlocking one
/// grants at most a one-time Game Ball reward through the wallet's idempotent
/// transaction ledger, never a gameplay advantage.
@MainActor
@Observable
final class AchievementManager {
    static let shared = AchievementManager()

    static let storageKey = "gamescene.gridiron.achievements"

    private struct PersistedState: Codable {
        var casesSolved = 0
        /// Running progress values for goal-based achievements.
        var progress: [AchievementID: Int] = [:]
        var unlocked: [AchievementID: Date] = [:]
        var claimedRewards: Set<AchievementID> = []
        var holderNames: [AchievementID: String] = [:]
    }

    private let defaults: UserDefaults
    private var state: PersistedState
    /// True while a full-screen ad is on screen — popups wait until it's
    /// dismissed. Injectable so tests can drive the gate directly.
    private let isPresentationBlocked: @MainActor () -> Bool

    /// FIFO queue of unlock popups waiting to be presented.
    private(set) var popupQueue: [AchievementID] = []
    /// The achievement currently on screen, if any.
    private(set) var currentPopupID: AchievementID?

    init(
        defaults: UserDefaults = .standard,
        isPresentationBlocked: (@MainActor () -> Bool)? = nil
    ) {
        self.defaults = defaults
        self.isPresentationBlocked = isPresentationBlocked ?? { AdManager.shared.isFullScreenAdPresenting }
        state = SaveStore.load(PersistedState.self, key: Self.storageKey, defaults: defaults) ?? PersistedState()
    }

    // MARK: Queries

    var totalCount: Int { AchievementCatalog.all.count }
    var unlockedCount: Int { state.unlocked.count }

    var casesSolved: Int { state.casesSolved }

    func isUnlocked(_ id: AchievementID) -> Bool { state.unlocked[id] != nil }

    func unlockDate(_ id: AchievementID) -> Date? { state.unlocked[id] }

    /// The roster player who personally earned a player-category achievement.
    func holderName(_ id: AchievementID) -> String? { state.holderNames[id] }

    /// Current progress value for a progress achievement (goal != nil),
    /// clamped to the goal once unlocked.
    func progressValue(for achievement: Achievement) -> Int {
        guard let goal = achievement.goal else { return isUnlocked(achievement.id) ? 1 : 0 }
        if isUnlocked(achievement.id) { return goal }
        return min(goal, state.progress[achievement.id] ?? 0)
    }

    func progressFraction(for achievement: Achievement) -> Double {
        guard let goal = achievement.goal, goal > 0 else { return isUnlocked(achievement.id) ? 1 : 0 }
        return Double(progressValue(for: achievement)) / Double(goal)
    }

    var currentPopup: Achievement? {
        currentPopupID.map(AchievementCatalog.achievement)
    }

    // MARK: Popup queue

    /// Presents the next queued unlock, if any. Called by the popup view when
    /// the current one is dismissed — one premium notification at a time.
    /// Unlocks only ever queue at safe breaks (quarter result, match result,
    /// season completion), so a popup can never interrupt a live drag/drop.
    func presentNextPopup() {
        guard currentPopupID == nil else { return }
        currentPopupID = popupQueue.first
        if currentPopupID != nil { popupQueue.removeFirst() }
    }

    /// Presents the next queued unlock only when no full-screen ad is on
    /// screen — an ACHIEVEMENT UNLOCKED banner never lands on top of a Google
    /// interstitial or rewarded ad. Called when an unlock arrives and again
    /// when a full-screen ad is dismissed.
    func presentNextPopupIfSafe() {
        guard !isPresentationBlocked() else { return }
        presentNextPopup()
    }

    /// Dismisses the visible popup and lets the next queued one come up.
    func dismissPopup() {
        currentPopupID = nil
        presentNextPopup()
    }

    // MARK: Event: quarter solved

    /// One solved quarter (real games only — training never calls this).
    /// Evaluates the per-quarter gameplay achievements and the deduction
    /// milestones. `difficulty` is the selection active for the qualifying game.
    func noteQuarterSolved(livesLost: Int, hintsUsed: Int, isOvertime: Bool, difficulty: DifficultyLevel) {
        state.casesSolved += 1
        unlockIfEligible(.firstCase)

        if livesLost == 0 { unlockIfEligible(.cleanRead) }
        if hintsUsed == 0 { unlockIfEligible(.noHelpNeeded) }
        if isOvertime { unlockIfEligible(.clutch) }
        if difficulty == .hallOfFamer, hintsUsed == 0 { unlockIfEligible(.coldCase) }

        let thresholds: [(Int, AchievementID)] = [
            (25, .fieldInvestigator),
            (100, .caseSpecialist),
            (250, .masterInvestigator),
            (500, .ironMind)
        ]
        for (target, id) in thresholds where state.casesSolved >= target {
            unlockIfEligible(id)
        }
        persist()
    }

    // MARK: Event: game completed

    /// One finished, recorded game (wins only — losses unlock nothing here).
    /// Evaluates game-shape achievements and the difficulty achievements using
    /// the difficulty actually active for the qualifying game.
    func noteGameCompleted(
        won: Bool,
        quartersSolved: Int,
        wentToOT: Bool,
        wonOT: Bool,
        wrongPlacements: Int,
        forcedOvertimeFromOneSolved: Bool,
        difficulty: DifficultyLevel,
        stage: FranchiseGameStage
    ) {
        guard won else { return }

        if quartersSolved == GameMatch.regulationQuarters { unlockIfEligible(.perfectGame) }
        if wentToOT, wonOT { unlockIfEligible(.clutch) }
        if forcedOvertimeFromOneSolved, wentToOT, wonOT { unlockIfEligible(.comebackCase) }
        if wrongPlacements == 0 { unlockIfEligible(.perfectEvidence) }

        // Difficulty achievements use the game's active selection.
        switch difficulty {
        case .pro:
            unlockIfEligible(.proven)
        case .allPro:
            switch stage {
            case .regularSeason:
                break
            case .semifinal:
                unlockIfEligible(.allProMaterial)
            case .championship:
                unlockIfEligible(.allProMaterial)
                unlockIfEligible(.eliteRead)
            }
        case .hallOfFamer:
            if stage == .championship { unlockIfEligible(.hallWorthy) }
        case .rookie:
            break
        }
        persist()
    }

    // MARK: Event: stat awarded / player milestones

    /// Evaluates the player-category achievements against career totals
    /// (career stats plus the live season, since season stats roll into career
    /// only at season end). Records which player earned the honor.
    func notePlayerMilestones(players: [FranchisePlayer]) {
        let thresholds: [(stat: PlayerStat, id: AchievementID)] = [
            (.interceptions, .ballHawk),
            (.sacks, .sackSpecialist),
            (.tackles, .tackleMachine),
            (.receptions, .goToTarget),
            (.playerOfTheGame, .gameChanger),
            (.playerOfTheGame, .franchiseIcon)
        ]
        for threshold in thresholds {
            guard !isUnlocked(threshold.id),
                  let goal = AchievementCatalog.achievement(for: threshold.id).goal else { continue }
            var best: (player: FranchisePlayer, value: Int)?
            for player in players {
                let value = player.seasonStats.value(for: threshold.stat) + player.careerStats.value(for: threshold.stat)
                if value >= goal, value > (best?.value ?? -1) { best = (player, value) }
            }
            if let best {
                state.progress[threshold.id] = best.value
                unlockIfEligible(threshold.id, holder: best.player.displayName)
            }
        }
        persist()
    }

    // MARK: Event: season completed

    /// One fully completed season (postseason resolved or playoffs missed).
    /// `championshipCount` and `lastTitleSeasonNumber` come from the trophy
    /// case so BACK TO BACK and DYNASTY read true history.
    func noteSeasonCompleted(
        summary: SeasonResult,
        wins: Int,
        losses: Int,
        championshipCount: Int,
        lastTitleSeasonNumber: Int?
    ) {
        if wins > losses { unlockIfEligible(.winningSeason) }
        if wins == 10, losses == 0 { unlockIfEligible(.undefeated) }
        if summary.qualifiedForPlayoffs { unlockIfEligible(.playoffBound) }
        if summary.semifinalOutcome?.isWin == true { unlockIfEligible(.finalFour) }
        if summary.wonChampionship {
            unlockIfEligible(.caseClosed)
            if lastTitleSeasonNumber == summary.seasonNumber - 1 { unlockIfEligible(.backToBack) }
        }

        state.progress[.dynasty] = max(championshipCount, state.progress[.dynasty] ?? 0)
        if championshipCount >= 3 { unlockIfEligible(.dynasty) }
        persist()
    }

    // MARK: Event: franchise milestones

    /// Running franchise-wide figures, refreshed after each recorded game.
    /// Streaks count OT wins as wins; any loss resets the current streak.
    func noteFranchiseState(gamesPlayed: Int, currentWinStreak: Int, longestWinStreak: Int) {
        state.progress[.ironFranchise] = gamesPlayed
        if gamesPlayed >= 50 { unlockIfEligible(.ironFranchise) }
        if currentWinStreak >= 5, longestWinStreak >= 5 { unlockIfEligible(.hotStreak) }
        persist()
    }

    // MARK: Rewards

    /// Returns every unlocked-but-unpaid achievement with a Game Ball reward.
    /// The coordinator pays each through the wallet's transaction ledger
    /// (`"achievement-<id>"`), which makes double payment impossible even if
    /// this method ran twice.
    func unclaimedRewardAchievements() -> [Achievement] {
        AchievementCatalog.all.filter {
            $0.reward > 0 && isUnlocked($0.id) && !state.claimedRewards.contains($0.id)
        }
    }

    /// Marks a reward as paid. The wallet's transaction ledger is the real
    /// idempotency guarantee; this keeps the achievement record consistent.
    func markRewardClaimed(_ id: AchievementID) {
        state.claimedRewards.insert(id)
        persist()
    }

    func hasClaimedReward(_ id: AchievementID) -> Bool {
        state.claimedRewards.contains(id)
    }

    // MARK: Internals

    /// Unlocks an achievement exactly once: stamps the date and queues the
    /// popup. If no popup is on screen the new one presents immediately;
    /// otherwise it waits its turn in the queue.
    private func unlockIfEligible(_ id: AchievementID, holder: String? = nil) {
        guard state.unlocked[id] == nil else { return }
        state.unlocked[id] = .now
        if let holder { state.holderNames[id] = holder }
        popupQueue.append(id)
        if currentPopupID == nil { presentNextPopupIfSafe() }
    }

    // MARK: Persistence

    private func persist() {
        SaveStore.save(state, key: Self.storageKey, defaults: defaults)
    }
}

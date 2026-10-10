import Foundation
import Observation

/// Single source of truth for the first-time experience: onboarding completion,
/// one-time contextual tooltips, the first-game assist and the accessibility
/// preferences (haptics, reduce motion, larger clue text, high contrast clues).
/// Everything persists locally (UserDefaults) and survives restarts.
///
/// Observable so Settings and the accessibility-aware views update live.
@MainActor
@Observable
final class TutorialManager {
    static let shared = TutorialManager()

    private enum DefaultsKey {
        static let onboardingComplete = "tutorial.onboardingComplete"
        static let tutorialCompleted = "tutorial.completed"
        static let completedTooltips = "tutorial.completedTooltips"
        static let firstGameAssistDone = "tutorial.firstGameAssistDone"
        static let hapticsEnabled = "accessibility.hapticsEnabled"
        static let reduceMotion = "accessibility.reduceMotion"
        static let largerClueText = "accessibility.largerClueText"
        static let highContrastClues = "accessibility.highContrastClues"
    }

    private let defaults: UserDefaults

    /// False on a fresh install — gates the guided onboarding flow at the root.
    /// True forever after (unless the user replays, which does not re-gate).
    private(set) var hasCompletedOnboarding: Bool

    /// True the moment the final Training Case objective is solved — persisted
    /// immediately at completion, never only after relaunch. Replay completion
    /// is idempotent.
    private(set) var hasCompletedTutorial: Bool

    /// One-time contextual tooltip ids already shown (Game Balls, Team screen,
    /// Player Stats, postseason). They stay dismissed until tutorial data resets.
    private(set) var completedTooltips: Set<String>

    /// The subtle first-game training assists (notebook pulse, profile reminder)
    /// show for the user's first regular-season game only.
    private(set) var hasCompletedFirstGameAssist: Bool

    // MARK: Accessibility preferences

    var isHapticsEnabled: Bool {
        didSet {
            guard oldValue != isHapticsEnabled else { return }
            defaults.set(isHapticsEnabled, forKey: DefaultsKey.hapticsEnabled)
        }
    }

    var isReduceMotionEnabled: Bool {
        didSet {
            guard oldValue != isReduceMotionEnabled else { return }
            defaults.set(isReduceMotionEnabled, forKey: DefaultsKey.reduceMotion)
        }
    }

    var isLargerClueTextEnabled: Bool {
        didSet {
            guard oldValue != isLargerClueTextEnabled else { return }
            defaults.set(isLargerClueTextEnabled, forKey: DefaultsKey.largerClueText)
        }
    }

    var isHighContrastCluesEnabled: Bool {
        didSet {
            guard oldValue != isHighContrastCluesEnabled else { return }
            defaults.set(isHighContrastCluesEnabled, forKey: DefaultsKey.highContrastClues)
        }
    }

    /// Test-injectable: pass an isolated defaults suite for hermetic tests.
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        hasCompletedOnboarding = defaults.bool(forKey: DefaultsKey.onboardingComplete)
        hasCompletedTutorial = defaults.bool(forKey: DefaultsKey.tutorialCompleted)
        completedTooltips = Set(defaults.stringArray(forKey: DefaultsKey.completedTooltips) ?? [])
        hasCompletedFirstGameAssist = defaults.bool(forKey: DefaultsKey.firstGameAssistDone)
        isHapticsEnabled = defaults.object(forKey: DefaultsKey.hapticsEnabled) as? Bool ?? true
        isReduceMotionEnabled = defaults.bool(forKey: DefaultsKey.reduceMotion)
        isLargerClueTextEnabled = defaults.bool(forKey: DefaultsKey.largerClueText)
        isHighContrastCluesEnabled = defaults.bool(forKey: DefaultsKey.highContrastClues)
    }

    // MARK: Onboarding

    /// Called once the full flow finishes (intro → team → difficulty →
    /// training case → season entry). Onboarding never gates again, and
    /// tutorial graduates never need the first-game training wheels.
    func completeOnboarding() {
        hasCompletedOnboarding = true
        defaults.set(true, forKey: DefaultsKey.onboardingComplete)
        markTutorialCompleted()
        markFirstGameAssistDone()
    }

    /// Called the instant the Training Case is solved (not on button tap, not
    /// on relaunch). Idempotent — replays just re-confirm it.
    func markTutorialCompleted() {
        guard !hasCompletedTutorial else { return }
        hasCompletedTutorial = true
        defaults.set(true, forKey: DefaultsKey.tutorialCompleted)
    }

    /// Marks the guided assists done when onboarding is skipped by finishing
    /// the flow — a graduate of the tutorial needs no first-game help.
    func markFirstGameAssistDone() {
        guard !hasCompletedFirstGameAssist else { return }
        hasCompletedFirstGameAssist = true
        defaults.set(true, forKey: DefaultsKey.firstGameAssistDone)
    }

    // MARK: Contextual tooltips

    func hasSeenTooltip(_ id: String) -> Bool {
        completedTooltips.contains(id)
    }

    /// Dismisses a contextual tooltip permanently (until tutorial data resets).
    func markTooltipSeen(_ id: String) {
        guard !completedTooltips.contains(id) else { return }
        completedTooltips.insert(id)
        defaults.set(Array(completedTooltips).sorted(), forKey: DefaultsKey.completedTooltips)
    }

    /// Whether the first regular-season game should still show the subtle
    /// training assists. Onboarding graduates skip them entirely.
    var isFirstGameAssistActive: Bool {
        !hasCompletedFirstGameAssist
    }

    /// REPLAY TUTORIAL (Settings): runs the guided training case again without
    /// re-forcing team creation or difficulty selection.
    func beginTutorialReplay() {
        // No state change needed — replay is a navigation action. Kept as an
        // explicit hook so tests can prove the flag combination replay uses.
    }

    /// Full tutorial-data reset: onboarding runs again on next launch, every
    /// tooltip re-arms and the first-game assist returns. Accessibility,
    /// difficulty, economy and season data are untouched.
    func resetTutorialData() {
        hasCompletedOnboarding = false
        hasCompletedTutorial = false
        completedTooltips = []
        hasCompletedFirstGameAssist = false
        defaults.removeObject(forKey: DefaultsKey.onboardingComplete)
        defaults.removeObject(forKey: DefaultsKey.tutorialCompleted)
        defaults.removeObject(forKey: DefaultsKey.completedTooltips)
        defaults.removeObject(forKey: DefaultsKey.firstGameAssistDone)
    }
}

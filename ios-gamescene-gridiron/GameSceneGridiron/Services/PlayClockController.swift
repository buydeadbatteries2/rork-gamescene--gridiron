import Foundation
import Observation

// MARK: - Hall of Famer play clock
//
// The Hall of Famer pressure system: a per-placement 40-second play clock and
// two 25-second timeouts per quarter. Rookie, Pro and All-Pro stay untimed —
// the controller is simply never created for them.
//
// The clock only ever runs while the player controls the pace. Anything
// outside their control (backgrounding, rewarded ads, StoreKit, achievement
// popups, blocking dialogs, quarter transitions, a called timeout) suspends
// it with the exact remaining value preserved — external UI never consumes
// play-clock time. Ordinary thinking (reading clues, studying evidence,
// choosing profiles) is NOT a pause; that is the point of the pressure.

@MainActor
@Observable
final class PlayClockController {
    enum Phase: Equatable {
        case idle        // not started (untimed, or waiting for the intro)
        case running
        case suspended   // remaining value preserved, waiting to resume
        case expired
    }

    /// Why the clock is currently held. The clock resumes only when every
    /// active reason has been lifted.
    enum SuspendReason: String, Hashable, Sendable {
        case timeout      // the player called a 25-second timeout
        case background   // app backgrounded / system interruption
        case ad           // rewarded ad presentation
        case storeKit     // StoreKit sheet
        case achievement  // achievement popup
        case dialog       // blocking confirmation dialogs
        case transition   // quarter / postgame transitions
    }

    enum Urgency { case normal, warning, critical }

    static let tickInterval: TimeInterval = 0.5

    /// Total duration: 40s for the play clock, 25s for a timeout.
    let duration: TimeInterval
    /// Real-time ticking; tests create controllers with this off and tick by hand.
    private let autoTicks: Bool

    private(set) var remaining: TimeInterval
    private(set) var phase: Phase = .idle
    private var suspendReasons: Set<SuspendReason> = []
    private var ticker: Task<Void, Never>?
    private var didWarn = false
    private var didCritical = false

    var onExpire: (() -> Void)?
    var onWarning: (() -> Void)?
    var onCritical: (() -> Void)?

    init(duration: TimeInterval, autoTicks: Bool = true) {
        self.duration = duration
        self.autoTicks = autoTicks
        self.remaining = duration
    }

    var isRunning: Bool { phase == .running }
    /// True while the clock holds meaningful state (running or frozen).
    var isActive: Bool { phase == .running || phase == .suspended }

    var urgency: Urgency {
        if remaining <= 5 { return .critical }
        if remaining <= 10 { return .warning }
        return .normal
    }

    var remainingSeconds: Int { Int(remaining.rounded(.up)) }

    // MARK: Lifecycle

    /// Restarts from the full duration and runs.
    func startFresh() {
        ticker?.cancel()
        ticker = nil
        remaining = duration
        didWarn = false
        didCritical = false
        phase = .running
        beginTicking()
    }

    /// Stops the clock entirely (placement made, quarter over).
    func stop() {
        ticker?.cancel()
        ticker = nil
        phase = .idle
    }

    /// Freezes the clock at its exact remaining value for `reason`.
    func suspend(reason: SuspendReason) {
        suspendReasons.insert(reason)
        guard phase == .running else { return }
        ticker?.cancel()
        ticker = nil
        phase = .suspended
    }

    /// Resumes from the preserved value once `reason` (and every other active
    /// reason) is lifted.
    func resume(reason: SuspendReason) {
        suspendReasons.remove(reason)
        guard suspendReasons.isEmpty, phase == .suspended else { return }
        phase = .running
        beginTicking()
    }

    /// Restores a persisted frozen state (resumed quarter). The clock comes
    /// back suspended with exactly the saved remaining time — never reset.
    func restore(remaining: TimeInterval) {
        ticker?.cancel()
        ticker = nil
        self.remaining = max(0, min(duration, remaining))
        didWarn = self.remaining <= 10
        didCritical = self.remaining <= 5
        phase = .suspended
    }

    /// Advances the clock by `interval`. The real-time ticker calls this; so
    /// do tests, deterministically, on autoTicks-off controllers.
    func tick(by interval: TimeInterval? = nil) {
        guard phase == .running else { return }
        remaining -= interval ?? Self.tickInterval

        if remaining <= 10, !didWarn {
            didWarn = true
            onWarning?()
        }
        if remaining <= 5, !didCritical {
            didCritical = true
            onCritical?()
        }
        if remaining <= 0 {
            remaining = 0
            phase = .expired
            ticker?.cancel()
            ticker = nil
            onExpire?()
        }
    }

    private func beginTicking() {
        guard autoTicks else { return }
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(500))
                guard !Task.isCancelled else { return }
                self?.tick(by: Self.tickInterval)
            }
        }
    }
}

// MARK: - Investigation snapshot
//
// Active quarter state survives lifecycle changes safely: solved placements,
// remaining lives, consumed hint leads, Hall of Famer timeouts and the frozen
// remaining play clock are persisted under the match+quarter key, so a
// force-quit can never restore consumed timeouts or lives, reset an
// almost-expired clock, or duplicate solved placements — and reopening the
// app resumes the same investigation instead of dealing a fresh puzzle.

nonisolated struct InvestigationSnapshot: Codable, Sendable, Hashable {
    let matchKey: String
    let caseID: String
    let isTimed: Bool
    let remaining: TimeInterval
    let timeoutsRemaining: Int
    let lives: Int
    let placedPlayerIDs: [String]
    let usedHintIDs: [String]
}

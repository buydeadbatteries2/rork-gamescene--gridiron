import SwiftUI

/// Hall of Famer pressure strip: the per-placement 40-second play clock, the
/// two per-quarter timeouts and the timeout countdown with RESUME PLAY. Sits
/// in the HUD row below the top controls — it never covers clues, evidence,
/// player cards or placement zones.
struct PlayClockStrip: View {
    let viewModel: GameViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public var body: some View {
        HStack(spacing: 8) {
            if let timeout = viewModel.timeoutClock {
                timeoutChip(timeout)
                Spacer(minLength: 0)
                resumeButton
            } else {
                clockChip
                Spacer(minLength: 0)
                timeoutChip
                timeoutButton
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: Play clock

    private var clockChip: some View {
        let clock = viewModel.playClock
        return HStack(spacing: 6) {
            Text("PLAY CLOCK")
                .font(.system(size: 10, weight: .heavy).width(.condensed))
                .tracking(1.2)
                .foregroundStyle(Theme.silver.opacity(0.75))
            Text(timeString(clock?.remaining ?? 40))
                .font(.system(size: 15, weight: .black).width(.condensed).monospacedDigit())
                .foregroundStyle(urgencyColor)
                .contentTransition(.numericText())
                // Subtle urgency — no aggressive flashing, and none at all
                // with Reduce Motion on.
                .modifier(UrgencyPulse(urgency: urgency, enabled: !reduceMotion))
        }
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background(urgencyColor.opacity(0.14), in: .capsule)
        .overlay { Capsule().strokeBorder(urgencyColor.opacity(0.5), lineWidth: 1) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Play clock, \(clock?.remainingSeconds ?? 0) seconds remaining")
    }

    private var urgency: PlayClockController.Urgency { viewModel.playClock?.urgency ?? .normal }

    private var urgencyColor: Color {
        switch urgency {
        case .normal: Theme.chalk
        case .warning: Theme.gold
        case .critical: Theme.danger
        }
    }

    // MARK: Timeout chips

    private var timeoutChip: some View {
        HStack(spacing: 6) {
            Text("TO")
                .font(.system(size: 10, weight: .heavy).width(.condensed))
                .tracking(1)
                .foregroundStyle(Theme.silver.opacity(0.75))
            Text("\(viewModel.timeoutsRemaining)")
                .font(.system(size: 14, weight: .black).monospacedDigit())
                .foregroundStyle(viewModel.timeoutsRemaining > 0 ? Theme.goldLight : Theme.silver.opacity(0.4))
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background(Color.white.opacity(0.06), in: .capsule)
        .overlay { Capsule().strokeBorder(Color.white.opacity(0.14), lineWidth: 1) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(viewModel.timeoutsRemaining) timeouts remaining")
    }

    private func timeoutChip(_ timeout: PlayClockController) -> some View {
        HStack(spacing: 6) {
            Text("TIMEOUT")
                .font(.system(size: 10, weight: .heavy).width(.condensed))
                .tracking(1.2)
                .foregroundStyle(Theme.goldLight)
            Text(timeString(timeout.remaining))
                .font(.system(size: 15, weight: .black).width(.condensed).monospacedDigit())
                .foregroundStyle(Theme.goldLight)
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background(Theme.gold.opacity(0.16), in: .capsule)
        .overlay { Capsule().strokeBorder(Theme.gold.opacity(0.55), lineWidth: 1) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Timeout clock, \(timeout.remainingSeconds) seconds remaining")
    }

    // MARK: Buttons

    private var timeoutButton: some View {
        Button(action: { viewModel.callTimeout() }) {
            Text("TIMEOUT")
                .font(.system(size: 10.5, weight: .heavy).width(.condensed))
                .tracking(1)
                .foregroundStyle(canCallTimeout ? Theme.ink : Theme.silver.opacity(0.4))
                .padding(.horizontal, 12)
                .frame(height: 30)
                .background(Theme.goldGradient, in: .capsule)
                .opacity(canCallTimeout ? 1 : 0.35)
        }
        .buttonStyle(PressableButtonStyle(scale: 0.94))
        .disabled(!canCallTimeout)
        .accessibilityLabel("Call timeout")
        .accessibilityHint("Freezes the play clock for 25 seconds of review time")
    }

    private var canCallTimeout: Bool {
        viewModel.timeoutsRemaining > 0 && viewModel.playClock?.isRunning == true
    }

    private var resumeButton: some View {
        Button(action: { viewModel.resumePlay() }) {
            Text("RESUME PLAY")
                .font(.system(size: 10.5, weight: .heavy).width(.condensed))
                .tracking(1.2)
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 14)
                .frame(height: 30)
                .background(Theme.goldGradient, in: .capsule)
        }
        .buttonStyle(PressableButtonStyle(scale: 0.94))
        .accessibilityLabel("Resume play")
        .accessibilityHint("Ends the timeout and restarts the play clock from where it stopped")
    }

    private func timeString(_ interval: TimeInterval) -> String {
        let seconds = Int(max(0, interval).rounded(.up))
        return String(format: "0:%02d", seconds)
    }
}

/// Gentle emphasis for the last five seconds — disabled entirely with
/// Reduce Motion.
private struct UrgencyPulse: ViewModifier {
    let urgency: PlayClockController.Urgency
    let enabled: Bool
    @State private var pulsing = false

    func body(content: Content) -> some View {
        if enabled, urgency == .critical {
            content
                .opacity(pulsing ? 0.55 : 1)
                .animation(.easeInOut(duration: 0.45).repeatForever(autoreverses: true), value: pulsing)
                .onAppear { pulsing = true }
        } else {
            content
        }
    }
}

/// One-time Hall of Famer explanation. The first play clock does not start
/// until the player dismisses it.
struct HallOfFamerIntroOverlay: View {
    let onConfirm: () -> Void

    var body: some View {
        ZStack {
            Theme.ink.opacity(0.82)
                .ignoresSafeArea()
            VStack(spacing: 14) {
                Image(systemName: "timer.hourglass")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(Theme.gold)
                Text("HALL OF FAMER PLAY CLOCK")
                    .font(.system(size: 17, weight: .heavy).width(.condensed))
                    .tracking(1.4)
                    .foregroundStyle(Theme.paperInk)
                    .multilineTextAlignment(.center)
                Text("You have 40 seconds for each placement.\nUse one of your two 25-second timeouts when you need more time to study the evidence.")
                    .font(Theme.typewriter(13, relativeTo: .footnote))
                    .foregroundStyle(Theme.paperInkSoft)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                Button(action: onConfirm) {
                    Text("GOT IT")
                        .font(.system(size: 13, weight: .heavy).width(.condensed))
                        .tracking(1.6)
                        .foregroundStyle(Theme.ink)
                        .padding(.horizontal, 30)
                        .padding(.vertical, 11)
                }
                .buttonStyle(GoldCapsuleButtonStyle())
                .accessibilityLabel("Got it: start the play clock")
            }
            .padding(22)
            .frame(maxWidth: 320)
            .paperCard(cornerRadius: 8)
            .shadow(color: .black.opacity(0.6), radius: 18, y: 8)
        }
        .transition(.opacity)
        .accessibilityAddTraits(.isModal)
    }
}

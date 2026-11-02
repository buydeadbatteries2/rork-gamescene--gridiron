import SwiftUI

// MARK: - Phase 15B — shared Versus case-file pieces

/// Every Versus screen inside the Hub stack.
nonisolated enum VersusRoute: Hashable {
    case find
    case match(UUID)
    case history
    case summary(UUID)
}

/// RankedView-style header: back chevron + compressed gold title +
/// typewriter subtitle, optional Home control. No screen is a dead end.
struct VersusHeader: View {
    let title: String
    let subtitle: String
    var backLabel: String = "Back"
    var onBack: () -> Void
    var onHome: (() -> Void)?
    var trailing: AnyView?

    var body: some View {
        HStack(spacing: 12) {
            circleButton(systemName: "chevron.left", label: backLabel, id: "versus.back", action: onBack)

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.system(size: 26, weight: .black).width(.compressed))
                    .tracking(2)
                    .foregroundStyle(Theme.goldGradient)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(subtitle)
                    .font(Theme.typewriter(11, relativeTo: .caption))
                    .tracking(1.2)
                    .foregroundStyle(Theme.paperInkSoft)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
            if let trailing { trailing }
            if let onHome {
                circleButton(systemName: "house.fill", label: "Home", id: "versus.home", action: onHome)
            }
        }
    }

    private func circleButton(systemName: String, label: String, id: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tick()
            action()
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Theme.goldLight)
                .frame(width: 38, height: 38)
                .background(Color.black.opacity(0.45), in: .circle)
                .overlay { Circle().strokeBorder(Theme.gold.opacity(0.4), lineWidth: 1) }
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel(label)
        .accessibilityIdentifier(id)
    }
}

/// Rubber stamp — WIN / LOSS / TIE / SUBMITTED / EXPIRED.
struct VersusStamp: View {
    let text: String
    var color: Color = Theme.danger
    var size: CGFloat = 44
    var rotation: Double = -6

    var body: some View {
        Text(text)
            .font(.system(size: size, weight: .black).width(.compressed))
            .tracking(3)
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .padding(.horizontal, 18)
            .padding(.vertical, 6)
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(color, lineWidth: 4)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(color.opacity(0.5), lineWidth: 1)
                    .padding(5)
            }
            .rotationEffect(.degrees(rotation))
            .opacity(0.92)
            .blendMode(.multiply)
    }
}

/// Small typed label on manila ("DIFFICULTY", "DEADLINE"…).
struct VersusFileLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .heavy).width(.condensed))
            .tracking(1.8)
            .foregroundStyle(Theme.paperInkSoft)
    }
}

/// One detective in a matchup / result: public identity only (username,
/// football display name, Versus record) — never real names or email.
struct VersusDetectiveColumn: View {
    let tag: String
    let username: String
    let displayName: String?
    let detail: String?
    var accent: Color = Theme.paperInk

    var body: some View {
        VStack(spacing: 5) {
            Text(tag)
                .font(.system(size: 10, weight: .heavy).width(.condensed))
                .tracking(2)
                .foregroundStyle(Theme.paper)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(accent, in: .capsule)
            Text(username)
                .font(.system(size: 17, weight: .black).width(.condensed))
                .foregroundStyle(Theme.paperInk)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            if let displayName, !displayName.isEmpty {
                Text(displayName)
                    .font(Theme.typewriter(11, relativeTo: .caption))
                    .foregroundStyle(Theme.paperInkSoft)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            if let detail {
                Text(detail)
                    .font(Theme.typewriterBold(11, relativeTo: .caption))
                    .foregroundStyle(Theme.paperInk)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

/// Secondary paper row button (MATCH HISTORY, HOME…).
struct VersusPaperButton: View {
    let title: String
    let systemImage: String
    var id: String
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.tick()
            action()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.goldLight)
                    .frame(width: 32, height: 32)
                    .background(Color.black.opacity(0.4), in: .circle)
                Text(title)
                    .font(.system(size: 15, weight: .black).width(.compressed))
                    .tracking(1)
                    .foregroundStyle(Theme.paperInk)
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.paperInk.opacity(0.4))
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .paperCard(cornerRadius: 6)
        }
        .buttonStyle(PressableButtonStyle(scale: 0.98))
        .accessibilityIdentifier(id)
    }
}

/// Signed-in player's public identity for the Hub / matchup.
nonisolated struct VersusIdentity: Equatable {
    let username: String
    let displayName: String

    @MainActor static var current: VersusIdentity? {
        if case .authenticated(let profile) = AuthService.shared.state {
            return VersusIdentity(username: "@\(profile.username)", displayName: profile.footballDisplayName)
        }
        return nil
    }
}

extension VersusPhase {
    /// Hub row status label.
    var rowStatus: String {
        switch self {
        case .waitingCanPlay: "SEARCHING · PLAY NOW"
        case .readyToPlay: "OPPONENT FOUND · YOUR MOVE"
        case .submittedWaiting(let joined): joined ? "SUBMITTED · OPPONENT INVESTIGATING" : "SUBMITTED · AWAITING OPPONENT"
        case .resolved(let outcome, let forfeit): "RESULT IN · \(VersusPresentation.resultTitle(outcome, isForfeit: forfeit))"
        case .expiredNoResult: "MATCH EXPIRED · NO RESULT"
        case .cancelled: "FILE CLOSED"
        }
    }

    var rowColor: Color {
        switch self {
        case .waitingCanPlay, .readyToPlay: Theme.danger
        case .submittedWaiting: Theme.medium
        case .resolved(let outcome, _):
            switch outcome {
            case .win: Theme.turf
            case .loss: Theme.danger
            case .tie: Theme.paperInkSoft
            }
        case .expiredNoResult, .cancelled: Theme.paperInkSoft
        }
    }
}

extension VersusOutcome {
    var stampColor: Color {
        switch self {
        case .win: Theme.turf
        case .loss: Theme.danger
        case .tie: Theme.bronzeDeep
        }
    }
}

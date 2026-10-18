import Foundation

/// Resolution for the Home-screen ACCOUNT entry (mirrored by the Settings
/// ACCOUNT card): what the control shows and where a tap should land.
/// Foundation-only so it is directly unit-testable — `symbol` is an SF Symbol
/// name. Guests land on the account front door; signed-in and recovery-pending
/// players land on the player file (ProfileView carries the FINISH PLAYER FILE
/// card for recovery).
struct AccountHomeState {
    let title: String
    let detail: String
    let symbol: String
    /// True when the tap should open the player file (ProfileView) instead of
    /// the CREATE ACCOUNT / SIGN IN front door.
    let opensProfile: Bool
}

extension AccountHomeState {
    /// Resolves the session state into the entry's presentation and routing.
    init(_ state: AuthSessionState) {
        switch state {
        case .restoring:
            self.init(
                title: "ACCOUNT",
                detail: "Checking player file…",
                symbol: "person.crop.circle.badge.questionmark",
                opensProfile: false
            )
        case .guest:
            self.init(
                title: "ACCOUNT",
                detail: "Guest — solo progress stays local",
                symbol: "person.crop.circle.badge.questionmark",
                opensProfile: false
            )
        case .authenticated(let profile):
            let jersey = profile.footballDisplayName.isEmpty ? profile.username : profile.footballDisplayName
            self.init(
                title: jersey.uppercased(),
                detail: "Signed in · \(profile.username)",
                symbol: "person.crop.circle.badge.checkmark",
                opensProfile: true
            )
        case .needsProfileRecovery:
            self.init(
                title: "FINISH PLAYER FILE",
                detail: "Account found — finish syncing",
                symbol: "person.crop.circle.badge.exclamationmark",
                opensProfile: true
            )
        }
    }
}

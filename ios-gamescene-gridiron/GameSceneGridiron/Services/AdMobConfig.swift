import Foundation

// MARK: - AdMob configuration (pure, testable)
//
// Central selection of the AdMob identifiers for this build:
// - DEBUG always runs Google's official PUBLIC test ad-unit IDs — never the
//   production GameScene units (an account-safety rule, tested).
// - RELEASE uses the build-injected Rork environment values exclusively. A
//   missing production ID disables that ad format gracefully — the Google
//   test units are NEVER a release fallback.
// AdMob IDs are build configuration, not secrets: they ship in every client.
// The Rork secret surface stays untouched by this file.
nonisolated enum AdMobConfig {
    enum AdFormat: String, CaseIterable, Sendable {
        case banner
        case interstitial
        case rewarded
    }

    // Google's public test identifiers (documented for development use).
    static let googleTestAppID = "ca-app-pub-3940256099942544~3347511713"
    static let googleTestUnitIDs: [AdFormat: String] = [
        .banner: "ca-app-pub-3940256099942544/2435281174",
        .interstitial: "ca-app-pub-3940256099942544/4411468910",
        .rewarded: "ca-app-pub-3940256099942544/1712485313",
    ]

    // MARK: Identifier shapes
    //
    // App ID:  ca-app-pub-<digits>~<digits>
    // Unit ID: ca-app-pub-<digits>/<digits>
    // The tildes vs slash distinction is the one the spec warns about.

    static func isAppIdentifier(_ id: String) -> Bool {
        guard id.hasPrefix("ca-app-pub-") else { return false }
        let tail = id.dropFirst("ca-app-pub-".count)
        let parts = tail.split(separator: "~", omittingEmptySubsequences: false)
        return parts.count == 2
            && parts.allSatisfy { !$0.isEmpty && $0.allSatisfy(\.isNumber) }
    }

    static func isUnitIdentifier(_ id: String) -> Bool {
        guard id.hasPrefix("ca-app-pub-") else { return false }
        let tail = id.dropFirst("ca-app-pub-".count)
        let parts = tail.split(separator: "/", omittingEmptySubsequences: false)
        return parts.count == 2
            && parts.allSatisfy { !$0.isEmpty && $0.allSatisfy(\.isNumber) }
    }

    // MARK: Selection

    /// The app-level AdMob identifier for this build. DEBUG may fall back to
    /// Google's public test app ID so development builds run test ads even
    /// before the injected value exists. RELEASE never substitutes anything —
    /// nil disables ads entirely.
    static func appIdentifier(isDevelopmentBuild: Bool, injectedAppID: String) -> String? {
        let trimmed = injectedAppID.trimmingCharacters(in: .whitespacesAndNewlines)
        if isDevelopmentBuild {
            return trimmed.isEmpty || !isAppIdentifier(trimmed) ? googleTestAppID : trimmed
        }
        guard !trimmed.isEmpty, isAppIdentifier(trimmed) else { return nil }
        // The Google test app ID is never a release fallback.
        guard trimmed != googleTestAppID else { return nil }
        return trimmed
    }

    /// The ad-unit ID for one format. DEBUG always resolves to Google's test
    /// unit for that format — even if injection produced a production value.
    /// RELEASE resolves to the injected production unit or nil (format
    /// disabled); the Google test units are explicitly rejected in RELEASE.
    static func adUnitID(
        _ format: AdFormat,
        isDevelopmentBuild: Bool,
        injectedUnitIDs: [AdFormat: String]
    ) -> String? {
        if isDevelopmentBuild {
            return googleTestUnitIDs[format]
        }
        let trimmed = (injectedUnitIDs[format] ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, isUnitIdentifier(trimmed) else { return nil }
        guard trimmed != googleTestUnitIDs[format] else { return nil }
        return trimmed
    }

    /// DEBUG diagnostics only: classifies a unit ID without ever exposing its
    /// value — "google-test", "production" or "none".
    static func debugUnitLabel(for unitID: String?) -> String {
        guard let unitID, !unitID.isEmpty else { return "none" }
        return googleTestUnitIDs.values.contains(unitID) ? "google-test" : "production"
    }
}

// MARK: - Mobile Ads start gate (pure)
//
// Initialization must happen exactly once, and only when a valid app-level
// identifier exists. Kept pure so the once-rule is directly testable.
nonisolated enum MobileAdsStartGate {
    static func shouldStart(hasStarted: Bool, appIdentifier: String?) -> Bool {
        !hasStarted && appIdentifier != nil
    }
}

// MARK: - Load retry backoff (pure)
//
// Failed ad loads retry with exponential backoff and a hard ceiling, then
// stop — the Google SDK is never hammered in a tight loop.
nonisolated enum AdRetryBackoff {
    static let baseDelay: TimeInterval = 5
    static let maxDelay: TimeInterval = 60
    static let maxConsecutiveFailures = 5

    /// nil means "stop retrying" — the next opportunity (foregrounding, a new
    /// configure pass, an entitlement change) re-arms preloading.
    static func delay(afterConsecutiveFailures failures: Int) -> TimeInterval? {
        guard failures > 0, failures <= maxConsecutiveFailures else { return nil }
        return min(maxDelay, baseDelay * pow(2, Double(failures - 1)))
    }
}

// MARK: - Rewarded session (pure)
//
// One rewarded-ad presentation. The grant point is the SDK's earned-reward
// callback; a session can grant at most once, end at most once, and nothing
// can be earned after the session ended (foregrounding, stray callbacks).
nonisolated struct RewardedSession: Equatable, Sendable {
    private(set) var didEarnReward = false
    private(set) var didEnd = false

    /// Returns true exactly when this call is the first earn — the grant.
    mutating func markRewardEarned() -> Bool {
        guard !didEnd, !didEarnReward else { return false }
        didEarnReward = true
        return true
    }

    /// Returns true exactly when this call ends the session (dismissal, error,
    /// or interruption).
    mutating func markEnded() -> Bool {
        guard !didEnd else { return false }
        didEnd = true
        return true
    }
}

import Foundation
import UIKit

// MARK: - App info

/// App version and build, read live from the bundle — never hard-coded in UI.
nonisolated enum AppInfo {
    /// Marketing version from the bundle, e.g. "1.0.0".
    static var version: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "1.0"
    }

    /// Build number from the bundle, e.g. "1".
    static var build: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String) ?? "1"
    }

    /// Settings/About display line, e.g. "Version 1.0.0 (1)".
    static var displayLine: String { "Version \(version) (\(build))" }
}

// MARK: - Production links

/// Support opens email. Legal documents are bundled in LegalDocument;
/// website URLs remain unset until the published addresses are supplied.
nonisolated enum AppLinks {
    static let privacyPolicyURL: URL? = nil
    static let termsOfUseURL: URL? = nil
    static let supportURL: URL? = URL(string: "mailto:support@ndstriistudios.com")
}

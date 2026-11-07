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

/// Configurable production URLs for the About section. Insert the real links
/// before App Store submission — nothing here invents a URL, and a nil link
/// renders a neutral "not yet available" state instead of a dead end.
nonisolated enum AppLinks {
    static let privacyPolicyURL: URL? = nil
    static let termsOfUseURL: URL? = nil
    static let supportURL: URL? = nil
}

import Foundation
import Supabase

// MARK: - Supabase client provider
//
// The single Supabase entry point. Configuration arrives through the app's
// Info.plist build-setting expansion from the Rork secret variables:
//   SUPABASE_URL       — the project URL (https://<ref>.supabase.co)
//   SUPABASE_ANON_KEY  — the public anon key (RLS-protected; NEVER the
//                        service-role key, which must never ship in a client)
// A missing, empty or unexpanded value means Supabase is NOT configured: the
// app runs in guest/local mode and startup is never blocked on it.
@MainActor
@Observable
final class SupabaseClientProvider {
    static let shared = SupabaseClientProvider()

    /// True when both build values are present and usable — only then does a
    /// `SupabaseClient` exist.
    private(set) var isConfigured: Bool
    private let client: SupabaseClient?

    init(url: String? = nil, anonKey: String? = nil) {
        let resolvedURL = url ?? Self.plistValue(forKey: "SUPABASE_URL")
        let resolvedKey = anonKey ?? Self.plistValue(forKey: "SUPABASE_ANON_KEY")
        if let client = Self.makeClient(url: resolvedURL, anonKey: resolvedKey) {
            self.client = client
            isConfigured = true
        } else {
            self.client = nil
            isConfigured = false
        }
    }

    var supabase: SupabaseClient? { client }

    // MARK: Pure configuration logic (testable)

    /// nil/empty/unexpanded-placeholder values are all "not configured".
    nonisolated static func plistValue(forKey key: String) -> String? {
        let raw = Bundle.main.object(forInfoDictionaryKey: key) as? String ?? ""
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains("$(") else { return nil }
        return trimmed
    }

    nonisolated static func makeClient(url: String?, anonKey: String?) -> SupabaseClient? {
        let cleanURL = url?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let cleanKey = anonKey?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        // Unresolved build-setting placeholders can only reach here if the
        // injection failed — treat them exactly like absent configuration.
        guard !cleanURL.isEmpty, !cleanKey.isEmpty,
              !cleanURL.contains("$("), !cleanKey.contains("$("),
              let validURL = URL(string: cleanURL),
              validURL.scheme == "https",
              validURL.host != nil else { return nil }
        return SupabaseClient(supabaseURL: validURL, supabaseKey: cleanKey)
    }

    // MARK: Password-reset deep link

    /// The custom scheme registered for Supabase Auth callbacks
    /// (reset-password). Registration must ALSO exist in the Supabase
    /// dashboard's redirect allowlist — see the phase report.
    nonisolated static let authCallbackScheme = "gamescene"

    /// True when the URL is an app auth callback (password reset return trip).
    nonisolated static func isAuthCallbackURL(_ url: URL) -> Bool {
        url.scheme?.lowercased() == authCallbackScheme
    }
}

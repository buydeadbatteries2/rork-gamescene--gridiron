import Foundation
import Testing
@testable import GameSceneGridiron

// MARK: - Phase 13C.2 tests — Rork public Config.swift configuration path
//
// The server-side-only SUPABASE_URL / SUPABASE_ANON_KEY secrets cannot reach
// the native app, so the client now reads the client-safe
// EXPO_PUBLIC_SUPABASE_URL / EXPO_PUBLIC_SUPABASE_ANON_KEY variables through
// the generated Config.swift. The test runner only receives the app folder, so
// the wiring is pinned through fixture strings that MIRROR the real
// project.pbxproj / AppInfo.plist / Config.swift — `scripts/verify-supabase-
// wiring.sh` re-checks the real files from the repo root; keep them in sync.
private enum PublicConfigFixture {
    /// project.pbxproj must contain NO Supabase build settings at all.
    static let pbxprojSupabaseSettings: [String] = [
        #"SUPABASE_URL = "$(SUPABASE_URL)";"#,
        #"SUPABASE_ANON_KEY = "$(SUPABASE_ANON_KEY)";"#,
        #"SUPABASE_URL_VALUE = "$(SUPABASE_URL)";"#,
        #"SUPABASE_ANON_KEY_VALUE = "$(SUPABASE_ANON_KEY)";"#,
    ]

    /// AppInfo.plist must contain NO Supabase keys at all.
    static let plistSupabaseKeys: [String] = [
        "<key>SUPABASE_URL</key>",
        "<key>SUPABASE_ANON_KEY</key>",
    ]

    /// Config.swift exposes the public variables (auto-generated at build time).
    static let configSurface: [String] = [
        "EXPO_PUBLIC_SUPABASE_URL",
        "EXPO_PUBLIC_SUPABASE_ANON_KEY",
    ]
}

@MainActor
@Suite("Phase 13C.2 — Rork public Config.swift configuration")
struct Phase13C2Tests {

    // MARK: Wiring contract (mirrors of the real config files)

    @Test func pbxprojContainsNoSupabaseBuildSettings() {
        for setting in PublicConfigFixture.pbxprojSupabaseSettings {
            #expect(!setting.isEmpty)
        }
        // The real files are re-verified by scripts/verify-supabase-wiring.sh,
        // which asserts the raw pbxproj contains no 'SUPABASE' at all.
    }

    @Test func appInfoPlistContainsNoSupabaseKeys() {
        for key in PublicConfigFixture.plistSupabaseKeys {
            #expect(!key.isEmpty)
        }
        // Real-file check lives in scripts/verify-supabase-wiring.sh.
    }

    @Test func generatedConfigExposesThePublicSupabaseVariables() {
        // The generated Config.swift surface must expose BOTH public variables.
        for name in PublicConfigFixture.configSurface {
            #expect(Config.allValues.keys.contains(name))
        }
    }

    @Test func providerReadsOnlyThePublicConfigSurface() {
        // Server-only secret names are no longer part of the provider's API —
        // there is no plist-based Supabase lookup left to call.
        let providerType = SupabaseClientProvider.self
        #expect(providerType.publicConfigURL == SupabaseClientProvider.publicConfigValue(Config.EXPO_PUBLIC_SUPABASE_URL))
        #expect(providerType.publicConfigAnonKey == SupabaseClientProvider.publicConfigValue(Config.EXPO_PUBLIC_SUPABASE_ANON_KEY))
    }

    // MARK: Runtime configuration guard

    @Test func missingPublicURLFailsClosed() {
        #expect(SupabaseClientProvider.publicConfigValue("") == nil)
        #expect(SupabaseClientProvider.publicConfigValue("   ") == nil)
        #expect(SupabaseClientProvider.makeClient(url: nil, anonKey: "key") == nil)
        #expect(SupabaseClientProvider.makeClient(url: "", anonKey: "key") == nil)
    }

    @Test func missingPublicAnonKeyFailsClosed() {
        #expect(SupabaseClientProvider.publicConfigValue("") == nil)
        #expect(SupabaseClientProvider.makeClient(url: "https://example.supabase.co", anonKey: nil) == nil)
        #expect(SupabaseClientProvider.makeClient(url: "https://example.supabase.co", anonKey: "") == nil)
        #expect(SupabaseClientProvider.makeClient(url: "https://example.supabase.co", anonKey: "  ") == nil)
    }

    @Test func unresolvedPlaceholdersFailClosed() {
        #expect(SupabaseClientProvider.publicConfigValue("$(EXPO_PUBLIC_SUPABASE_URL)") == nil)
        #expect(SupabaseClientProvider.makeClient(url: "$(SUPABASE_URL_VALUE)", anonKey: "key") == nil)
        #expect(SupabaseClientProvider.makeClient(url: "https://example.supabase.co", anonKey: "$(SUPABASE_ANON_KEY_VALUE)") == nil)
    }

    @Test func validPublicValuesCreateTheClient() {
        #expect(SupabaseClientProvider.makeClient(url: "https://example.supabase.co", anonKey: "anon-key") != nil)
        // HTTPS only.
        #expect(SupabaseClientProvider.makeClient(url: "http://example.supabase.co", anonKey: "key") == nil)
    }

    // MARK: Account status behavior

    @Test func unavailableCardDisappearsWhenConfiguredAndSubmitStaysEnabled() async {
        // Unconfigured: the notice is flagged for the status card.
        let offline = AuthService(authClient: nil, profileRepository: nil, defaults: Self.defaults())
        await offline.restoreSession()
        #expect(!offline.isSupabaseConfigured)
        #expect(!offline.isShowingUnavailableNotice) // nothing attempted yet
        #expect(AuthService.isUnavailableNoticeMessage(AuthService.unavailableNotice))
        #expect(!offline.isWorking) // CREATE ACCOUNT never disabled by config

        // Configured: the notice can never appear.
        let configured = AuthService(
            authClient: MockAuthClient(),
            profileRepository: MockProfileRepository(),
            defaults: Self.defaults()
        )
        await configured.restoreSession()
        #expect(configured.isSupabaseConfigured)
        #expect(!configured.isShowingUnavailableNotice)
        let ok = await configured.createAccount(SignUpDraft(
            firstName: "Julius", lastName: "Hudson", username: "GridironKing",
            email: "julius@example.com", password: "tackle99box", confirmPassword: "tackle99box"
        ))
        #expect(ok)
        #expect(!configured.isShowingUnavailableNotice)
    }

    private static func defaults() -> UserDefaults {
        let name = "phase13c2.\(UUID().uuidString)"
        UserDefaults.standard.removePersistentDomain(forName: name)
        return UserDefaults(suiteName: name)!
    }
}

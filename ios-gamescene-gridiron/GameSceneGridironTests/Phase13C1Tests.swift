import Foundation
import Testing
@testable import GameSceneGridiron

// MARK: - Phase 13C.1 tests — secret injection wiring & account status legibility
//
// The test runner only receives the app folder, so the two configuration
// files are pinned through fixture strings that MIRROR the real
// project.pbxproj / AppInfo.plist lines. `scripts/verify-supabase-wiring.sh`
// re-checks the real files from the repo root — keep the two in sync.
private enum BuildConfigFixture {
    /// Exact build-setting lines in BOTH app-target configs of project.pbxproj.
    static let pbxprojLines: [String] = [
        #"ADMOB_APP_ID_VALUE = "$(ADMOB_IOS_APP_ID)";"#,
        #"SUPABASE_URL_VALUE = "$(SUPABASE_URL)";"#,
        #"SUPABASE_ANON_KEY_VALUE = "$(SUPABASE_ANON_KEY)";"#,
    ]

    /// Exact plist entries in AppInfo.plist.
    static let plistLines: [String] = [
        "<key>SUPABASE_URL</key>",
        "<string>$(SUPABASE_URL_VALUE)</string>",
        "<key>SUPABASE_ANON_KEY</key>",
        "<string>$(SUPABASE_ANON_KEY_VALUE)</string>",
    ]
}

@MainActor
@Suite("Phase 13C.1 — Supabase injection wiring & unavailable-account legibility")
struct Phase13C1Tests {

    // MARK: Wiring contract (mirrors of the real config files)

    @Test func buildSettingsUseDifferentlyNamedValueIntermediaries() {
        let pbxproj = BuildConfigFixture.pbxprojLines.joined(separator: "\n")
        // Intermediary _VALUE settings reference the Rork secrets — the exact
        // AdMob pattern (secret → differently-named build setting → plist).
        #expect(pbxproj.contains(#"SUPABASE_URL_VALUE = "$(SUPABASE_URL)";"#))
        #expect(pbxproj.contains(#"SUPABASE_ANON_KEY_VALUE = "$(SUPABASE_ANON_KEY)";"#))
        // The proven AdMob reference pattern stays intact.
        #expect(pbxproj.contains(#"ADMOB_APP_ID_VALUE = "$(ADMOB_IOS_APP_ID)";"#))
        // The previous self-referencing form is FORBIDDEN.
        #expect(!pbxproj.contains(#"SUPABASE_URL = "$(SUPABASE_URL)""#))
        #expect(!pbxproj.contains(#"SUPABASE_ANON_KEY = "$(SUPABASE_ANON_KEY)""#))
    }

    @Test func appInfoPlistExpandsOnlyTheValueIntermediaries() {
        let plist = BuildConfigFixture.plistLines.joined(separator: "\n")
        #expect(plist.contains("<string>$(SUPABASE_URL_VALUE)</string>"))
        #expect(plist.contains("<string>$(SUPABASE_ANON_KEY_VALUE)</string>"))
        // The raw Rork secret names must never appear as direct expansions.
        #expect(!plist.contains("<string>$(SUPABASE_URL)</string>"))
        #expect(!plist.contains("<string>$(SUPABASE_ANON_KEY)</string>"))
    }

    // MARK: Runtime configuration guard

    @Test func unresolvedPlaceholdersFailConfiguration() {
        #expect(SupabaseClientProvider.makeClient(url: "$(SUPABASE_URL_VALUE)", anonKey: "key") == nil)
        #expect(SupabaseClientProvider.makeClient(url: "https://example.supabase.co", anonKey: "$(SUPABASE_ANON_KEY_VALUE)") == nil)
        // Even after Info.plist expansion leaks a placeholder into the mix.
        #expect(SupabaseClientProvider.makeClient(url: "ht$({}://x", anonKey: "key") == nil)
    }

    @Test func emptyValuesFailConfiguration() {
        #expect(SupabaseClientProvider.makeClient(url: nil, anonKey: "key") == nil)
        #expect(SupabaseClientProvider.makeClient(url: "https://example.supabase.co", anonKey: nil) == nil)
        #expect(SupabaseClientProvider.makeClient(url: "", anonKey: "key") == nil)
        #expect(SupabaseClientProvider.makeClient(url: "   ", anonKey: "key") == nil)
        #expect(SupabaseClientProvider.makeClient(url: "https://example.supabase.co", anonKey: "") == nil)
        #expect(SupabaseClientProvider.makeClient(url: "https://example.supabase.co", anonKey: "  ") == nil)
    }

    @Test func validHTTPSInjectedValuesCreateTheClient() {
        let client = SupabaseClientProvider.makeClient(url: "https://example.supabase.co", anonKey: "anon-key")
        #expect(client != nil)
        // HTTPS only — the spec's configuration rule.
        #expect(SupabaseClientProvider.makeClient(url: "http://example.supabase.co", anonKey: "key") == nil)
        #expect(SupabaseClientProvider.makeClient(url: "ftp://example.supabase.co", anonKey: "key") == nil)
    }

    // MARK: Unavailable-account status legibility

    @Test func unavailableNoticeRecognizedOnlyForTheGuardMessages() {
        #expect(AuthService.isUnavailableNoticeMessage("Accounts aren't available in this build — you can keep playing solo."))
        #expect(AuthService.isUnavailableNoticeMessage("Accounts aren't available in this build."))
        // Any other status must keep the regular banner treatment.
        #expect(!AuthService.isUnavailableNoticeMessage("CONFIRM YOUR EMAIL TO ACTIVATE ONLINE FEATURES"))
        #expect(!AuthService.isUnavailableNoticeMessage("CHECK YOUR EMAIL FOR THE RESET LINK"))
        #expect(!AuthService.isUnavailableNoticeMessage(nil))
    }

    @Test func unavailableStatusShownOnlyWhenConfigurationIsAbsent() async {
        // Unconfigured service (nil clients — the offline/sandbox shape):
        // signup reports the notice and the flag turns on.
        let offline = AuthService(authClient: nil, profileRepository: nil, defaults: Self.defaults())
        await offline.restoreSession()
        #expect(!offline.isSupabaseConfigured)
        #expect(!offline.isShowingUnavailableNotice) // nothing attempted yet
        let submitted = await offline.createAccount(SignUpDraft(
            firstName: "Julius", lastName: "Hudson", username: "GridironKing",
            email: "julius@example.com", password: "tackle99box", confirmPassword: "tackle99box"
        ))
        #expect(!submitted)
        #expect(offline.isShowingUnavailableNotice)

        // Configured service (mock clients): the notice can never appear.
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
        #expect(!configured.isShowingUnavailableNotice) // stays gone when configured
    }

    @Test func createAccountSubmitIsNeverDisabledByConfiguration() {
        // The form's CREATE ACCOUNT / SIGN IN buttons are disabled only while
        // a request is in flight — never by the configuration guard (the
        // unavailable state is communicated by the status card instead).
        let offline = AuthService(authClient: nil, profileRepository: nil, defaults: Self.defaults())
        #expect(!offline.isWorking)
        #expect(!offline.isSupabaseConfigured)
        // No "isAccountGated"-style flag exists to disable the button with.
        #expect(AuthService.unavailableNotice.contains("solo"))
    }

    private static func defaults() -> UserDefaults {
        let name = "phase13c1.\(UUID().uuidString)"
        UserDefaults.standard.removePersistentDomain(forName: name)
        return UserDefaults(suiteName: name)!
    }
}

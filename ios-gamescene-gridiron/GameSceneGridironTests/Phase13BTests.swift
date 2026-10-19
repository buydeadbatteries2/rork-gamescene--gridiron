import Foundation
import Testing
@testable import GameSceneGridiron

// MARK: - Phase 13B tests — account flow exposed in the app
//
// The Home ACCOUNT entry, the Settings ACCOUNT card and the auth screens all
// resolve through the same pieces: `AccountHomeState` (what Home shows and
// where a tap lands) and the AuthService email-confirmation behavior
// (CHECK YOUR EMAIL vs. immediate authentication).
@MainActor
struct Phase13BTests {

    // MARK: Home account entry state

    @Test func homeStateShowsGuestAndOpensFrontDoor() {
        let home = AccountHomeState(.guest)
        #expect(home.title == "ACCOUNT")
        #expect(home.detail.lowercased().contains("guest"))
        #expect(!home.opensProfile)
    }

    @Test func homeStateShowsJerseyNameWhenAuthenticated() {
        let profile = UserProfile(authUserID: UUID(), username: "GridironKing", firstName: "Julius", lastName: "Hudson")
        let home = AccountHomeState(.authenticated(profile))
        #expect(home.title == "J. HUDSON")
        #expect(home.detail.contains("GridironKing"))
        #expect(home.opensProfile)
    }

    @Test func homeStateFallsBackToUsernameWithoutAJerseyName() {
        let profile = UserProfile(authUserID: UUID(), username: "GridironKing", firstName: "", lastName: "")
        let home = AccountHomeState(.authenticated(profile))
        #expect(home.title == "GRIDIRONKING")
        #expect(home.opensProfile)
    }

    @Test func homeStateRoutesRecoveryToThePlayerFile() {
        let home = AccountHomeState(.needsProfileRecovery(
            UserProfile(authUserID: UUID(), username: "PLAYER-ABC123", firstName: "", lastName: "")
        ))
        #expect(home.opensProfile)
        #expect(home.title.contains("FINISH"))
    }

    // MARK: Signup → CHECK YOUR EMAIL vs. immediate authentication

    @Test func signupWithEmailConfirmationShowsCheckEmailWithoutAuthenticating() async {
        let (service, authClient, profiles, _) = Self.makeService()
        await service.restoreSession()
        authClient.signUpResult = .success(AuthSignUpOutcome(userID: UUID(), didCreateSession: false))

        let submitted = await service.createAccount(Self.makeDraft())

        #expect(submitted)
        #expect(service.didSendConfirmationEmail)
        #expect(service.lastUserMessage?.contains("CONFIRM") == true)
        // No session exists yet — the player is NOT authenticated, and the
        // guest state is untouched (guest play continues undisturbed).
        #expect(service.state == .guest)
        #expect(profiles.writeCount == 0) // NO client-side profile insert without a session — the auth.users trigger owns it
    }

    @Test func signupWithoutEmailConfirmationAuthenticatesImmediately() async {
        let (service, authClient, _, _) = Self.makeService()
        await service.restoreSession()
        authClient.signUpResult = .success(AuthSignUpOutcome(userID: UUID(), didCreateSession: true))

        let submitted = await service.createAccount(Self.makeDraft())

        #expect(submitted)
        #expect(!service.didSendConfirmationEmail)
        if case .authenticated(let profile) = service.state {
            #expect(profile.username == "GridironKing")
        } else {
            Issue.record("Expected an authenticated session after signup with session")
        }
    }

    // MARK: Configuration guard

    @Test func configurationGuardRejectsBlankAndPlaceholderValues() {
        #expect(SupabaseClientProvider.makeClient(url: "", anonKey: "key") == nil)
        #expect(SupabaseClientProvider.makeClient(url: "   ", anonKey: "key") == nil)
        #expect(SupabaseClientProvider.makeClient(url: "ftp://example.com", anonKey: "key") == nil)
        #expect(SupabaseClientProvider.makeClient(url: "https://example.supabase.co", anonKey: "") == nil)
        #expect(SupabaseClientProvider.makeClient(url: "https://example.supabase.co", anonKey: "key") != nil)
        // Blank public-configuration values (the source-committed Config.swift
        // literals) are never configured.
        #expect(SupabaseClientProvider.publicConfigValue("") == nil)
        #expect(SupabaseClientProvider.publicConfigValue("$(EXPO_PUBLIC_SUPABASE_URL)") == nil)
    }

    // MARK: Helpers

    private static func makeService(
        suite: String = UUID().uuidString
    ) -> (AuthService, MockAuthClient, MockProfileRepository, UserDefaults) {
        let authClient = MockAuthClient()
        let profiles = MockProfileRepository()
        let defaults = UserDefaults(suiteName: "phase13b.\(suite)")!
        defaults.removePersistentDomain(forName: "phase13b.\(suite)")
        let service = AuthService(
            authClient: authClient,
            profileRepository: profiles,
            defaults: defaults
        )
        return (service, authClient, profiles, defaults)
    }

    private static func makeDraft() -> SignUpDraft {
        SignUpDraft(
            firstName: "Julius",
            lastName: "Hudson",
            username: "GridironKing",
            email: "julius@example.com",
            password: "tackle99box",
            confirmPassword: "tackle99box"
        )
    }
}

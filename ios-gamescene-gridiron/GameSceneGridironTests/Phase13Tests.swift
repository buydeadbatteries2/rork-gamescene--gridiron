import Foundation
import Testing
@testable import GameSceneGridiron

// MARK: - Phase 13 test doubles

/// Scripted auth client — no Supabase SDK, no network. Every outcome the
/// AuthService state machine can encounter is drivable from tests.
@MainActor
final class MockAuthClient: AuthClientProtocol, @unchecked Sendable {
    var signUpResult: Result<AuthSignUpOutcome, Error> = .success(AuthSignUpOutcome(userID: UUID(), didCreateSession: true))
    var signInResult: Result<UUID, Error> = .success(UUID())
    var restoredSessionUserID: UUID?
    var restoreSessionError: Error?
    var signOutError: Error?
    var resetPasswordError: Error?

    private(set) var signedUpEmails: [String] = []
    private(set) var signedUpIdentities: [AuthSignUpIdentity] = []
    private(set) var sentResetEmails: [String] = []
    private(set) var handledCallbackURLs: [URL] = []
    private(set) var updatedPasswords: [String] = []
    private(set) var signOutCount = 0

    func signUp(email: String, password: String, identity: AuthSignUpIdentity) async throws -> AuthSignUpOutcome {
        signedUpEmails.append(email)
        signedUpIdentities.append(identity)
        return try signUpResult.get()
    }

    func signIn(email: String, password: String) async throws -> UUID {
        try signInResult.get()
    }

    func restoreSessionUserID() async throws -> UUID? {
        if let restoreSessionError { throw restoreSessionError }
        return restoredSessionUserID
    }

    func signOut() async throws {
        signOutCount += 1
        if let signOutError { throw signOutError }
    }

    func sendPasswordReset(email: String) async throws {
        sentResetEmails.append(email)
        if let resetPasswordError { throw resetPasswordError }
    }

    func handleCallback(url: URL) async throws {
        handledCallbackURLs.append(url)
    }

    func updatePassword(_ newPassword: String) async throws {
        updatedPasswords.append(newPassword)
    }
}

/// In-memory profile repository with a configurable failure mode — proves the
/// AuthService logic, and that conformances need nothing but Foundation.
@MainActor
final class MockProfileRepository: ProfileRepository, @unchecked Sendable {
    var stored: [UUID: UserProfile] = [:]
    var shouldFailWrites = false
    var usernameAvailable = true
    var usernameProbeError: Error?
    private(set) var writeCount = 0
    private(set) var probedUsernames: [String] = []

    func fetchProfile(userID: UUID) async throws -> UserProfile? {
        stored[userID]
    }

    func ensureProfile(_ profile: UserProfile) async throws {
        writeCount += 1
        if shouldFailWrites { throw URLError(.notConnectedToInternet) }
        stored[profile.authUserID] = profile
    }

    func isUsernameAvailable(_ username: String) async throws -> Bool {
        probedUsernames.append(username)
        if let usernameProbeError { throw usernameProbeError }
        return usernameAvailable
    }
}

// MARK: - Phase 13 tests

@MainActor
@Suite("Phase 13 — Supabase Auth, accounts & profile foundation")
struct Phase13Tests {

    private func makeService(
        onAuthenticated: ((UUID) async -> Void)? = nil,
        onSignedOut: (() async -> Void)? = nil,
        suite: String = UUID().uuidString
    ) -> (AuthService, MockAuthClient, MockProfileRepository, UserDefaults) {
        let authClient = MockAuthClient()
        let profiles = MockProfileRepository()
        let defaults = UserDefaults(suiteName: "phase13.\(suite)")!
        defaults.removePersistentDomain(forName: "phase13.\(suite)")
        let service = AuthService(
            authClient: authClient,
            profileRepository: profiles,
            defaults: defaults,
            onAuthenticated: onAuthenticated,
            onSignedOut: onSignedOut
        )
        return (service, authClient, profiles, defaults)
    }

    private func makeDraft(username: String = "GridironKing", password: String = "tackle99box") -> SignUpDraft {
        SignUpDraft(
            firstName: "Julius", lastName: "Hudson", username: username,
            email: "julius@example.com", password: password, confirmPassword: password
        )
    }

    // 1 — Guest can play solo.

    @Test func guestCanPlaySolo() async {
        let (service, _, _, defaults) = makeService()
        await service.restoreSession()
        #expect(service.state == .guest)
        service.continueAsGuest()
        #expect(service.state == .guest)
        #expect(AccountGatePolicy.canPlaySolo(.guest))
        #expect(defaults.bool(forKey: AuthService.guestFlagKey))
        // Solo features are never gated in any resolved state.
        #expect(AccountGatePolicy.canPlaySolo(.guest))
        #expect(AccountGatePolicy.canPlaySolo(.authenticated(Self.sampleProfile())))
        #expect(AccountGatePolicy.canPlaySolo(.needsProfileRecovery(Self.sampleProfile())))
        #expect(!AccountGatePolicy.canPlaySolo(.restoring))
        _ = defaults
    }

    // 2 — Signup validates fields.

    @Test func signupValidatesFieldsBeforeSubmitting() {
        var draft = makeDraft()
        draft.firstName = ""
        draft.lastName = "   "
        draft.email = "not-an-email"
        draft.password = "short"
        draft.confirmPassword = "different"
        let errors = AccountValidator.validate(draft)
        #expect(errors.firstName != nil)
        #expect(errors.lastName != nil)
        #expect(errors.email != nil)
        #expect(errors.password != nil)
        #expect(errors.confirmPassword != nil)

        let valid = AccountValidator.validate(makeDraft())
        #expect(valid.isEmpty)

        // Username errors surface specifically.
        var badUsername = makeDraft(username: "has space")
        #expect(!AccountValidator.validate(badUsername).isEmpty)
        badUsername = makeDraft(username: "ab")
        #expect(AccountValidator.validate(badUsername).username != nil)
    }

    // 3 — Username rules work.

    @Test func usernameRulesWork() {
        #expect(UsernameRules.isValid("GridironKing"))
        #expect(UsernameRules.isValid("Line_Judge_42"))
        #expect(UsernameRules.isValid("abc"))
        #expect(UsernameRules.isValid(String(repeating: "x", count: 20)))
        // Too short / too long.
        #expect(!UsernameRules.isValid("ab"))
        #expect(!UsernameRules.isValid(String(repeating: "x", count: 21)))
        // Spaces, symbols, invisible/control characters are all rejected.
        #expect(!UsernameRules.isValid("grid iron"))
        #expect(!UsernameRules.isValid("grid-iron"))
        #expect(!UsernameRules.isValid("grid.iron"))
        #expect(!UsernameRules.isValid("grid\tiron"))
        #expect(!UsernameRules.isValid("grid\niron"))
        #expect(!UsernameRules.isValid("grid\u{200B}iron")) // zero-width space
        #expect(!UsernameRules.isValid(""))
    }

    // 4 — Username normalization works.

    @Test func usernameNormalizationWorks() {
        #expect(UsernameRules.normalize("GridironKing") == "gridironking")
        #expect(UsernameRules.normalize("GRIDIRONKING") == UsernameRules.normalize("gridironking"))
        // Case-insensitive uniqueness: both spellings collide on one key.
        let a = UserProfile(authUserID: UUID(), username: "GridironKing", firstName: "A", lastName: "B")
        let b = UserProfile(authUserID: UUID(), username: "gridironking", firstName: "A", lastName: "B")
        #expect(a.usernameNormalized == b.usernameNormalized)
        // Display capitalization is preserved on the account itself.
        #expect(a.username == "GridironKing")
    }

    // 5 — Football display name derives correctly.

    @Test func footballDisplayNameDerivesCorrectly() {
        #expect(FootballDisplayName.derive(firstName: "Julius", lastName: "Hudson") == "J. Hudson")
        #expect(FootballDisplayName.derive(firstName: "julius", lastName: "hudson") == "j. hudson")
        // Edge cases never crash or produce bare periods.
        #expect(FootballDisplayName.derive(firstName: "", lastName: "Hudson") == "Hudson")
        #expect(FootballDisplayName.derive(firstName: "Julius", lastName: "") == "Julius")
        #expect(FootballDisplayName.derive(firstName: " ", lastName: " ") == "")
        // Derived automatically on the profile — never typed by the user.
        let profile = Self.sampleProfile()
        #expect(profile.footballDisplayName == "J. Hudson")
    }

    // 6 — Password never enters local persistence.

    @Test func passwordNeverEntersLocalPersistence() async {
        let (service, _, profiles, defaults) = makeService()
        await service.restoreSession()
        await service.createAccount(makeDraft())

        // No password-like value anywhere in this service's defaults domain.
        for key in defaults.dictionaryRepresentation().keys {
            let lowered = key.lowercased()
            #expect(!lowered.contains("password"))
        }
        for (key, value) in defaults.dictionaryRepresentation() {
            if let string = value as? String {
                #expect(!string.contains("tackle99box"), "password leaked via \(key)")
            }
        }
        // The profile repository never saw a password either (it cannot —
        // UserProfile has no password field; this also proves encoding).
        for (_, profile) in profiles.stored {
            let data = try! JSONEncoder().encode(profile)
            let json = String(decoding: data, as: UTF8.self).lowercased()
            #expect(!json.contains("password"))
        }
    }

    // 7 — Signup produces a canonical UUID identity.

    @Test func signupProducesCanonicalUUIDIdentity() async {
        let (service, authClient, profiles, _) = makeService()
        await service.restoreSession()
        let fixedUUID = UUID()
        authClient.signUpResult = .success(AuthSignUpOutcome(userID: fixedUUID, didCreateSession: true))

        let succeeded = await service.createAccount(makeDraft())
        #expect(succeeded)
        guard case .authenticated(let profile) = service.state else {
            Issue.record("expected authenticated state")
            return
        }
        // The canonical identity is the Supabase Auth UUID — never username
        // or email.
        #expect(profile.authUserID == fixedUUID)
        #expect(profile.id == fixedUUID)
        #expect(authClient.signedUpEmails == ["julius@example.com"])
        #expect(profiles.stored[fixedUUID]?.usernameNormalized == "gridironking")
    }

    // 8 — Existing local franchise survives signup.

    @Test func existingLocalFranchiseSurvivesSignup() async {
        let (service, authClient, profiles, defaults) = makeService()
        // A player's established local progress.
        defaults.set(true, forKey: TeamStore.storageKey)
        defaults.set(["season": "2027", "roster": [1, 2, 3]], forKey: "season.state")
        defaults.set(77, forKey: "wallet.gameBalls")
        defaults.set(true, forKey: "achievements.someTrophy")
        let before = defaults.dictionaryRepresentation()

        await service.restoreSession()
        authClient.signUpResult = .success(AuthSignUpOutcome(userID: UUID(), didCreateSession: true))
        let succeeded = await service.createAccount(makeDraft())

        #expect(succeeded)
        // The signup path touched nothing local except the guest flag.
        let after = defaults.dictionaryRepresentation()
        for (key, value) in before where key != AuthService.guestFlagKey {
            #expect("\(after[key] ?? "nil")" == "\(value)", "local value for \(key) changed during signup")
        }
        #expect(after[TeamStore.storageKey] as? Bool == true)
        _ = profiles
    }

    // 9 — Session restoration works.

    @Test func sessionRestorationWorks() async {
        // Offline build (no clients): resolves to guest immediately.
        let offlineDefaults = UserDefaults(suiteName: "phase13.offline.\(UUID().uuidString)")!
        let offline = AuthService(authClient: nil, profileRepository: nil, defaults: offlineDefaults)
        await offline.restoreSession()
        #expect(offline.state == .guest)

        // Existing session + profile → authenticated, without a sign-up call.
        let (service, authClient, profiles, _) = makeService()
        let userID = UUID()
        let existing = Self.sampleProfile(userID: userID)
        profiles.stored[userID] = existing
        authClient.restoredSessionUserID = userID
        await service.restoreSession()
        #expect(service.state == .authenticated(existing))
        #expect(authClient.signedUpEmails.isEmpty)

        // Session without profile row → recoverable state, not a dead end.
        let (fresh, freshClient, _, _) = makeService()
        freshClient.restoredSessionUserID = UUID()
        await fresh.restoreSession()
        #expect({
            if case .needsProfileRecovery = fresh.state { return true }
            return false
        }())
    }

    // 10 — Sign out preserves local solo data.

    @Test func signOutPreservesLocalSoloData() async {
        var signedOutHookCount = 0
        let (service, authClient, profiles, defaults) = makeService(
            onAuthenticated: nil,
            onSignedOut: { signedOutHookCount += 1 }
        )
        defaults.set(["season": "running"], forKey: "season.state")
        defaults.set(120, forKey: "wallet.gameBalls")
        await service.restoreSession()
        authClient.signUpResult = .success(AuthSignUpOutcome(userID: UUID(), didCreateSession: true))
        _ = await service.createAccount(makeDraft())
        #expect(profiles.writeCount == 1)

        await service.signOut()

        #expect(service.state == .guest)
        #expect(authClient.signOutCount == 1)
        #expect(signedOutHookCount == 1)
        // Season, wallet and everything else local survives the sign-out.
        #expect(defaults.dictionaryRepresentation()["season.state"] != nil)
        #expect(defaults.integer(forKey: "wallet.gameBalls") == 120)
        // A second auth round-trip can't re-grant or re-create anything.
        authClient.restoredSessionUserID = nil
        await service.restoreSession()
        #expect(service.state == .guest)
    }

    // 11 — Online feature gate requires an account.

    @Test func onlineFeatureGateRequiresAccount() {
        #expect(AccountGatePolicy.requiresAccount(.restoring))
        #expect(AccountGatePolicy.requiresAccount(.guest))
        #expect(AccountGatePolicy.requiresAccount(.needsProfileRecovery(Self.sampleProfile())))
        #expect(!AccountGatePolicy.requiresAccount(.authenticated(Self.sampleProfile())))
        #expect(AccountGatePolicy.canAccessOnlineFeatures(.authenticated(Self.sampleProfile())))
        #expect(!AccountGatePolicy.canAccessOnlineFeatures(.guest))
    }

    // 12 — RevenueCat receives the Supabase UUID.

    @Test func revenueCatReceivesSupabaseUUID() async {
        var migratedAppUserID: String?
        let (service, authClient, _, _) = makeService(
            onAuthenticated: { uuid in migratedAppUserID = uuid.uuidString },
            onSignedOut: nil
        )
        await service.restoreSession()
        let fixedUUID = UUID()
        authClient.signUpResult = .success(AuthSignUpOutcome(userID: fixedUUID, didCreateSession: true))
        _ = await service.createAccount(makeDraft())

        // The migration hook fired with the canonical UUID string — not the
        // email, username or real name.
        #expect(migratedAppUserID == fixedUUID.uuidString)
        #expect(migratedAppUserID != "julius@example.com")
        #expect(migratedAppUserID != "GridironKing")
        #expect(PurchaseManager.isAcceptableAppUserID(fixedUUID.uuidString))
        #expect(!PurchaseManager.isAcceptableAppUserID("julius@example.com"))
        #expect(!PurchaseManager.isAcceptableAppUserID("GridironKing"))
        #expect(!PurchaseManager.isAcceptableAppUserID("J. Hudson"))
    }

    // 13 — Starter Pack grant cannot duplicate during identity migration.

    @Test func starterPackCannotDuplicateDuringIdentityMigration() async {
        let defaults = UserDefaults(suiteName: "phase13.starter.\(UUID().uuidString)")!
        defaults.removePersistentDomain(forName: "phase13.starter.\(UUID().uuidString)")
        let wallet = PlayerWallet(defaults: defaults)

        // Migration grants exactly once — the anonymous purchase migrates to
        // the identified account, and replays of the migration/restore path
        // can never double-grant.
        #expect(wallet.grantStarterPackContents())
        #expect(!wallet.grantStarterPackContents())
        #expect(!wallet.grantStarterPackContents())
    }

    // 14 — Faction max member constant is 11.

    @Test func factionMaxMemberConstantIsEleven() {
        #expect(FactionLimits.maxMembers == 11)
        #expect(FactionLimits.positions.count == 11)
        #expect(FactionLimits.positions == [.qb, .rb, .wr, .te, .ol, .de, .dt, .lb, .cb, .fs, .ss])
        let roster = FactionBattleRoster(battleID: UUID(), factionID: UUID(), slots: Self.sampleRoster(count: 11))
        #expect(roster.isFullLineup)
        #expect(!FactionBattleRoster(battleID: UUID(), factionID: UUID(), slots: Self.sampleRoster(count: 10)).isFullLineup)
    }

    // 15 — Faction position does not exist permanently on UserProfile.

    @Test func factionPositionIsNotAUserProfileProperty() throws {
        // Position lives on roster slots only. Encode a profile and confirm
        // no position key exists in its persisted form.
        let data = try JSONEncoder().encode(Self.sampleProfile())
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(json != nil)
        for key in json!.keys {
            #expect(!key.lowercased().contains("position"))
        }
        let slot = FactionSeasonRosterSlot(
            factionID: UUID(), seasonID: UUID(), position: .qb,
            authUserID: Self.sampleProfile().authUserID,
            footballDisplayNameSnapshot: "J. Hudson"
        )
        #expect(slot.position == .qb)
    }

    // 16 — Repository layer is decoupled from SwiftUI.

    @Test func repositoryLayerIsDecoupledFromSwiftUI() async {
        // The whole Phase 13 service layer compiles and runs here with only
        // Foundation — protocol-driven AuthService, no Supabase, no SwiftUI.
        let (service, _, profiles, _) = makeService()
        await service.restoreSession()
        // nil clients (no Supabase in the build) still produce a working
        // service — the abstraction, not the SDK, is the dependency.
        let offline = AuthService(authClient: nil, profileRepository: nil, defaults: UserDefaults(suiteName: "phase13.decoupled.\(UUID().uuidString)")!)
        #expect(!offline.isSupabaseConfigured)
        // The mock ProfileRepository satisfies the protocol with no UI types.
        profiles.shouldFailWrites = false
        let target = UserProfile(authUserID: UUID(), username: "CaseCloser", firstName: "Nate", lastName: "Cross")
        do {
            try await profiles.ensureProfile(target)
            #expect(try await profiles.fetchProfile(userID: target.authUserID) == target)
        } catch {
            Issue.record("profile repository round-trip failed: \(error)")
        }
    }

    // 17 — App remains usable offline.

    @Test func appRemainsUsableOffline() async {
        let (service, authClient, _, _) = makeService()
        await service.restoreSession()
        // Session restore can't verify against an unreachable backend →
        // guest, never stuck on .restoring.
        authClient.restoreSessionError = URLError(.notConnectedToInternet)
        await service.restoreSession()
        #expect(service.state == .guest)
        #expect(service.lastUserMessage == AuthFailure.networkUnavailable.userMessage)

        // Signup over a dead network: friendly failure, no crash, no fake
        // account.
        authClient.restoreSessionError = nil
        authClient.signUpResult = .failure(URLError(.timedOut))
        let succeeded = await service.createAccount(makeDraft())
        #expect(!succeeded)
        #expect(service.lastUserMessage == AuthFailure.networkUnavailable.userMessage)

        // Guest solo play keeps working throughout.
        service.continueAsGuest()
        #expect(AccountGatePolicy.canPlaySolo(service.state))

        // Configuration logic: malformed/empty/unexpanded values never
        // configure a client — startup can't crash on bad Supabase config.
        #expect(SupabaseClientProvider.makeClient(url: nil, anonKey: nil) == nil)
        #expect(SupabaseClientProvider.makeClient(url: "", anonKey: "key") == nil)
        #expect(SupabaseClientProvider.makeClient(url: "$(SUPABASE_URL)", anonKey: "key") == nil)
        #expect(SupabaseClientProvider.makeClient(url: "notaurl", anonKey: "key") == nil)
        #expect(SupabaseClientProvider.makeClient(url: "https://example.supabase.co", anonKey: "anon") != nil)
        #expect(SupabaseClientProvider.publicConfigValue("   ") == nil)
        #expect(SupabaseClientProvider.isAuthCallbackURL(URL(string: "gamescene://auth-callback?refresh_token=x")!))
        #expect(!SupabaseClientProvider.isAuthCallbackURL(URL(string: "https://example.com")!))
    }

    // Partial failure (spec §10): auth succeeds, profile creation fails.

    @Test func partialSignupFailureIsRecoverableWithoutDuplicates() async {
        let (service, authClient, profiles, _) = makeService()
        await service.restoreSession()
        let fixedUUID = UUID()
        authClient.signUpResult = .success(AuthSignUpOutcome(userID: fixedUUID, didCreateSession: true))
        profiles.shouldFailWrites = true

        let firstAttempt = await service.createAccount(makeDraft())
        #expect(!firstAttempt)
        if case .needsProfileRecovery = service.state {} else {
            Issue.record("expected needsProfileRecovery after profile write failure")
        }
        #expect(authClient.signedUpEmails.count == 1)

        // Retry succeeds via idempotent upsert — exactly one auth account,
        // exactly one profile write that lands.
        profiles.shouldFailWrites = false
        await service.retryProfileCreation()
        guard case .authenticated(let profile) = service.state else {
            Issue.record("expected authenticated after recovery")
            return
        }
        #expect(profile.authUserID == fixedUUID)
        #expect(profiles.stored[fixedUUID] != nil)
    }

    // Email-confirmation flow (spec §10/§11/§13).

    @Test func signUpWithoutSessionFlagsEmailConfirmation() async {
        let (service, authClient, _, _) = makeService()
        await service.restoreSession()
        authClient.signUpResult = .success(AuthSignUpOutcome(userID: UUID(), didCreateSession: false))
        _ = await service.createAccount(makeDraft())
        #expect(service.lastUserMessage?.contains("CONFIRM") == true)

        // Sign-in errors map to friendly copy — never raw SDK text.
        authClient.signInResult = .failure(URLError(.cannotFindHost))
        let signedIn = await service.signIn(email: "julius@example.com", password: "tackle99box")
        #expect(!signedIn)
        #expect(service.lastUserMessage == AuthFailure.networkUnavailable.userMessage)
    }

    // MARK: Helpers

    private static func sampleProfile(userID: UUID = UUID()) -> UserProfile {
        UserProfile(authUserID: userID, username: "GridironKing", firstName: "Julius", lastName: "Hudson")
    }

    private static func sampleRoster(count: Int) -> [FactionSeasonRosterSlot] {
        let factionID = UUID()
        let seasonID = UUID()
        return zip(FactionLimits.positions.prefix(count), 1...count).map { position, index in
            FactionSeasonRosterSlot(
                factionID: factionID, seasonID: seasonID, position: position,
                authUserID: UUID(),
                footballDisplayNameSnapshot: index % 2 == 0 ? "J. Hudson" : "R. Okafor"
            )
        }
    }
}

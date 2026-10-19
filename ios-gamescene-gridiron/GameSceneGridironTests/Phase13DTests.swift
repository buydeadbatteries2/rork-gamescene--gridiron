import Foundation
import Testing
@testable import GameSceneGridiron

// MARK: - Phase 13D tests — trigger-driven profile creation flow
//
// With Confirm Email enabled, Supabase signup returns a user but NO session —
// the client cannot insert its own profile (RLS requires auth.uid() = id).
// The auth.users trigger `public.handle_new_user` creates the profile from
// signup user metadata instead. These tests pin the new architecture.

// Schema trigger-section assertions run against SchemaFixture.sql (the
// byte-identical snapshot of supabase/schema.sql — regenerated via
// scripts/regenerate-schema-fixture.sh).
@Suite("Phase 13D — auth-user profile trigger (schema)")
struct Phase13DSchemaTests {

    /// Comment-stripped, whitespace-flattened fixture — assertions match
    /// content, not formatting (same normalization as SchemaHardeningTests).
    private let sql: String = {
        let lines = SchemaFixture.sql.components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("--") }
        return lines
            .joined(separator: " ")
            .split(whereSeparator: { $0 == " " || $0 == "\r" || $0 == "\n" || $0 == "\t" })
            .joined(separator: " ")
    }()

    /// Extracts the full plpgsql block of a function (inner semicolons make
    /// statement() unusable for functions).
    private func function(named marker: String) -> String {
        guard let start = sql.range(of: marker) else { return "" }
        guard let end = sql.range(of: "end; $$;", range: start.upperBound..<sql.endIndex) else {
            return String(sql[start.lowerBound...])
        }
        return String(sql[start.lowerBound..<end.upperBound])
    }

    @Test func handleNewUserFunctionExistsAndIsTrusted() {
        let fn = function(named: "create or replace function public.handle_new_user()")
        #expect(fn != "")
        // Trusted database logic: SECURITY DEFINER so the insert bypasses the
        // (unchanged) own-row RLS — no client session is required.
        #expect(fn.contains("security definer"))
        #expect(fn.contains("set search_path = public"))
    }

    @Test func triggerRunsOnAuthUsersInsert() {
        #expect(sql.contains("drop trigger if exists on_auth_user_created on auth.users"))
        #expect(sql.contains("after insert on auth.users"))
        #expect(sql.contains("execute function public.handle_new_user()"))
    }

    @Test func profileCreatedFromMetadataIdentityColumnsOnly() {
        let fn = function(named: "create or replace function public.handle_new_user()")
        // new.id + the three metadata values — nothing else.
        #expect(fn.contains("raw_user_meta_data->>'username'"))
        #expect(fn.contains("raw_user_meta_data->>'first_name'"))
        #expect(fn.contains("raw_user_meta_data->>'last_name'"))
        #expect(fn.contains("insert into public.profiles (id, username, first_name, last_name)"))
        // Never passwords or sensitive data — no password/password_hash/auth
        // secret is read anywhere in the function.
        #expect(!fn.lowercased().contains("password"))
        #expect(!fn.contains("encrypted_password"))
    }

    @Test func triggerCreatesNoCompetitiveStats() {
        // Stats keep their table defaults (zero) — the trigger never touches
        // them (server-authoritative, sections 1 + 3).
        let fn = function(named: "create or replace function public.handle_new_user()")
        #expect(!fn.contains("global_rating"))
        #expect(!fn.contains("career_wins"))
        #expect(!fn.contains("championships"))
        #expect(sql.contains("global_rating int not null default 0"))
    }

    @Test func profileCreationIsIdempotent() {
        let fn = function(named: "create or replace function public.handle_new_user()")
        #expect(fn.contains("on conflict (id) do nothing"))
    }

    @Test func usernameConflictsRaiseReadableMarkerErrors() {
        let fn = function(named: "create or replace function public.handle_new_user()")
        // Uniqueness violation → recognizable USERNAME_TAKEN marker.
        #expect(fn.contains("when unique_violation then"))
        #expect(fn.contains("raise exception 'USERNAME_TAKEN'"))
        // Server-side username rule mirrors the client validator.
        #expect(fn.contains("'^[A-Za-z0-9_]{3,20}$'"))
        #expect(fn.contains("USERNAME_INVALID"))
    }

    @Test func usernameAvailabilityProbeIsAnonCallableBooleanOnly() {
        let fn = function(named: "create or replace function public.is_username_available(requested text)")
        #expect(fn.contains("security definer"))
        #expect(fn.contains("returns boolean"))
        #expect(fn.contains("lower(username_normalized) = lower(btrim(requested))"))
        #expect(sql.contains("grant execute on function public.is_username_available(text) to anon, authenticated"))
    }

    @Test func existingRlsAndStatGuardsRemainUnchanged() {
        // The trigger additions never weaken the hardened surfaces.
        #expect(sql.contains("alter table public.profiles enable row level security"))
        #expect(sql.contains("using (auth.uid() = id)"))
        #expect(sql.contains("revoke all on public.profiles from anon"))
        #expect(sql.contains("revoke all on public.public_profiles from anon"))
        #expect(!sql.contains("or true"))
        #expect(function(named: "create or replace function public.guard_competitive_stats_update()") != "")
        #expect(function(named: "create or replace function public.guard_competitive_stats_insert()") != "")
        #expect(sql.contains("revoke all on function public.is_username_available(text) from public"))
    }
}

// Swift-side flow tests for the new signup architecture.
@MainActor
@Suite("Phase 13D — signup metadata & client-side flow")
struct Phase13DFlowTests {

    private func makeService(
        onAuthenticated: ((UUID) async -> Void)? = nil
    ) -> (AuthService, MockAuthClient, MockProfileRepository) {
        let authClient = MockAuthClient()
        let profiles = MockProfileRepository()
        let name = "phase13d.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        let service = AuthService(
            authClient: authClient,
            profileRepository: profiles,
            defaults: defaults,
            onAuthenticated: onAuthenticated
        )
        return (service, authClient, profiles)
    }

    private func makeDraft() -> SignUpDraft {
        SignUpDraft(
            firstName: "Julius", lastName: "Hudson", username: "GridironKing",
            email: "julius@example.com", password: "tackle99box", confirmPassword: "tackle99box"
        )
    }

    // 3 — signup carries the identity metadata for the trigger.
    @Test func signupMetadataCarriesUsernameFirstAndLastName() async {
        let (service, authClient, _) = makeService()
        await service.restoreSession()

        _ = await service.createAccount(makeDraft())

        #expect(authClient.signedUpIdentities.count == 1)
        let identity = authClient.signedUpIdentities[0]
        #expect(identity.username == "GridironKing")
        #expect(identity.firstName == "Julius")
        #expect(identity.lastName == "Hudson")
    }

    // 1 + 2 — confirmation-pending signup is SUCCESS with zero client writes.
    @Test func nilSessionSignupIsSuccessWithoutClientProfileInsert() async {
        var revenueCatCalls: [UUID] = []
        let (service, authClient, profiles) = makeService(onAuthenticated: { uuid in
            revenueCatCalls.append(uuid)
        })
        await service.restoreSession()
        let userID = UUID()
        authClient.signUpResult = .success(AuthSignUpOutcome(userID: userID, didCreateSession: false))

        let submitted = await service.createAccount(makeDraft())

        // SUCCESS — never converted into a generic failure.
        #expect(submitted)
        #expect(service.didSendConfirmationEmail)
        #expect(service.lastUserMessage?.contains("CONFIRM") == true)
        // The client must NOT attempt the initial profile insert (no session).
        #expect(profiles.writeCount == 0)
        #expect(profiles.probedUsernames == ["GridironKing"])
        // No authenticated session → no RevenueCat identity migration.
        #expect(revenueCatCalls.isEmpty)
        #expect(service.state == .guest)
    }

    // With a session (confirmation disabled): trigger-created profile is
    // fetched — no duplicate insert on top of the trigger's work.
    @Test func immediateSessionSignupFetchesTriggerProfileWithoutDuplicateWrite() async {
        var revenueCatCalls: [UUID] = []
        let (service, authClient, profiles) = makeService(onAuthenticated: { uuid in
            revenueCatCalls.append(uuid)
        })
        await service.restoreSession()
        let userID = UUID()
        let triggerCreated = UserProfile(
            authUserID: userID, username: "GridironKing", firstName: "Julius", lastName: "Hudson"
        )
        profiles.stored[userID] = triggerCreated // as if the trigger ran
        authClient.signUpResult = .success(AuthSignUpOutcome(userID: userID, didCreateSession: true))

        let submitted = await service.createAccount(makeDraft())

        #expect(submitted)
        #expect(profiles.writeCount == 0) // trigger owns creation — no client insert
        #expect(service.state == .authenticated(triggerCreated))
        // RevenueCat identifies exactly once, with the stable Supabase UUID.
        #expect(revenueCatCalls == [userID])
    }

    // 10 — fallback: trigger row unexpectedly missing → recovery, not a crash.
    @Test func missingTriggerRowFallsBackToRecoveryInsert() async {
        let (service, authClient, profiles) = makeService()
        await service.restoreSession()
        let userID = UUID()
        authClient.signUpResult = .success(AuthSignUpOutcome(userID: userID, didCreateSession: true))
        // stored is empty — as if the trigger did not run (e.g. schema not yet applied).

        let submitted = await service.createAccount(makeDraft())

        #expect(submitted)
        #expect(profiles.writeCount == 1) // single idempotent recovery write
        #expect(profiles.stored[userID]?.username == "GridironKing")
        if case .authenticated = service.state {} else {
            Issue.record("Expected authenticated state after recovery insert")
        }
    }

    // 7 — username conflict (trigger marker / GoTrue wrap) reads as taken.
    @Test func usernameConflictProducesReadableTakenMessage() {
        let conflict = NSError(
            domain: "GoTrue", code: 500,
            userInfo: [NSLocalizedDescriptionKey: "Database error saving new user"]
        )
        #expect(AuthErrorMapper.failure(for: conflict) == .usernameTaken)
        #expect(AuthErrorMapper.failure(for: conflict).userMessage.contains("TAKEN"))
        let marker = NSError(
            domain: "trigger", code: 1,
            userInfo: [NSLocalizedDescriptionKey: "USERNAME_TAKEN"]
        )
        #expect(AuthErrorMapper.failure(for: marker) == .usernameTaken)
    }

    // 8 — 429 reads as a wait message, screen never permanently locked.
    @Test func rateLimitProducesReadableWaitMessage() {
        let limited = NSError(
            domain: "GoTrue", code: 429,
            userInfo: [NSLocalizedDescriptionKey: "Over request rate limit"]
        )
        let failure = AuthErrorMapper.failure(for: limited)
        #expect(failure == .rateLimited)
        #expect(failure.userMessage.contains("wait a few minutes"))
        // PostgREST failure category (profile SQL, not auth).
        #expect(AuthFailure.profileCreationFailed.userMessage.contains("player file"))
    }

    // Pre-flight probe failure never blocks signup.
    @Test func usernameProbeFailureDoesNotBlockSignup() async {
        let (service, authClient, profiles) = makeService()
        await service.restoreSession()
        profiles.usernameProbeError = URLError(.notConnectedToInternet)
        authClient.signUpResult = .success(AuthSignUpOutcome(userID: UUID(), didCreateSession: false))

        let submitted = await service.createAccount(makeDraft())

        #expect(submitted) // signup still went through
        #expect(profiles.writeCount == 0)
    }

    // Taken-username pre-flight surfaces the readable message before auth.
    @Test func takenUsernamePreflightSurfacesReadableMessage() async {
        let (service, authClient, profiles) = makeService()
        await service.restoreSession()
        profiles.usernameAvailable = false

        let submitted = await service.createAccount(makeDraft())

        #expect(!submitted)
        #expect(authClient.signedUpEmails.isEmpty) // auth never consumed
        #expect(service.lastUserMessage?.contains("TAKEN") == true)
    }
}

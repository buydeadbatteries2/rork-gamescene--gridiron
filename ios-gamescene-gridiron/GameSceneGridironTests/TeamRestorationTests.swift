import Foundation
import Testing
@testable import GameSceneGridiron

@MainActor
@Suite("TeamRestorationTests")
struct TeamRestorationTests {
    let defaults = UserDefaults(suiteName: "team-restore-\(UUID())")!
    let userID = UUID()
    var auth: AuthSessionState { .authenticated(UserProfile(authUserID: userID, username: "PlayerOne", firstName: "Test", lastName: "Player")) }
    func team(_ name: String = "Wolves") -> GameTeam {
        GameTeam(state: "Virginia", teamName: name, logoID: "wolf", primaryColorHex: 0x112233, secondaryColorHex: 0xFFEEDD, isUserTeam: true)
    }
    private func coordinator(_ repo: TeamRepositoryStub, _ store: TeamStore) -> TeamSyncCoordinator {
        TeamSyncCoordinator(repository: repo, store: store, tutorial: TutorialManager(defaults: defaults), defaults: defaults)
    }

    @Test func freshGuestNeedsOnboardingWithoutCloudCalls() async {
        let repo = TeamRepositoryStub(), store = TeamStore(defaults: defaults)
        let sync = coordinator(repo, store)
        #expect(sync.phase == .loading)
        await sync.resolve(.restoring)
        #expect(sync.phase == .loading)
        await sync.resolve(.guest)
        #expect(sync.phase == .local)
        #expect(!store.hasTeam)
        #expect(!TutorialManager(defaults: defaults).hasCompletedOnboarding)
        #expect(repo.fetchCount == 0)
    }
    @Test func returningSignInRestoresAllIdentityFields() async {
        let repo = TeamRepositoryStub(), store = TeamStore(defaults: defaults)
        repo.remote = team()
        let sync = coordinator(repo, store)
        await sync.resolve(auth)
        #expect(sync.phase == .ready)
        #expect(store.userTeam == repo.remote)
        #expect(store.ownerID == userID)
        #expect(TeamStore(defaults: defaults).userTeam == repo.remote)
        let tutorial = TutorialManager(defaults: defaults)
        #expect(tutorial.hasCompletedOnboarding)
        #expect(!tutorial.hasCompletedTutorial)
        #expect(!tutorial.hasCompletedFirstGameAssist)
    }
    @Test func restoredSessionWithEmptyInstallSkipsCreation() async {
        let repo = TeamRepositoryStub(), store = TeamStore(defaults: defaults)
        repo.remote = team()
        let sync = coordinator(repo, store)
        await sync.resolve(.restoring)
        #expect(!store.hasTeam)
        await sync.resolve(auth)
        #expect(store.hasTeam)
        #expect(sync.phase == .ready)
        #expect(repo.insertCount == 0)
    }
    @Test func remoteAlwaysWinsOverGuest() async {
        let repo = TeamRepositoryStub(), store = TeamStore(defaults: defaults)
        let guest = team("Guest")
        store.save(guest)
        repo.remote = team("Server")
        let sync = coordinator(repo, store)
        await sync.resolve(auth)
        #expect(store.userTeam == repo.remote)
        #expect(repo.insertCount == 0)
        #expect(repo.updateCount == 0)
        #expect(SaveStore.load(GameTeam.self, key: TeamStore.storageKey + ".backup." + guest.id.uuidString, defaults: defaults) == guest)
    }
    @Test func migrationRequiresConfirmationAndRunsOnce() async {
        let repo = TeamRepositoryStub(), store = TeamStore(defaults: defaults)
        let guest = team()
        store.save(guest)
        let sync = coordinator(repo, store)
        await sync.resolve(auth)
        #expect(sync.phase == .migration)
        #expect(repo.insertCount == 0)
        await sync.migrateLocalTeam()
        await sync.migrateLocalTeam()
        await sync.resolve(auth)
        #expect(repo.insertCount == 1)
        #expect(store.userTeam == guest)
        #expect(store.ownerID == userID)
    }
    @Test func concurrentRemoteWinnerIsNeverOverwritten() async {
        let repo = TeamRepositoryStub(), store = TeamStore(defaults: defaults)
        store.save(team("Guest"))
        let sync = coordinator(repo, store)
        await sync.resolve(auth)
        repo.remote = team("Concurrent server team")
        await sync.migrateLocalTeam()
        #expect(store.userTeam == repo.remote)
        #expect(repo.updateCount == 0)
    }
    @Test func teamCreatedOnAnotherDeviceWinsCreationRace() async {
        let repo = TeamRepositoryStub(), store = TeamStore(defaults: defaults)
        let sync = coordinator(repo, store)
        await sync.resolve(auth)
        #expect(!store.hasTeam)
        let remote = team("Other device")
        repo.remote = remote
        store.save(team("Local draft"))
        await sync.retryPendingSave()
        #expect(store.userTeam == remote)
        #expect(!sync.hasPendingSave)
        #expect(repo.updateCount == 0)
    }
    @Test func offlineFailurePreservesSoloData() async {
        let repo = TeamRepositoryStub(), store = TeamStore(defaults: defaults)
        let local = team()
        store.save(local)
        repo.fail = true
        let sync = coordinator(repo, store)
        await sync.resolve(auth)
        #expect(sync.phase == .failure)
        #expect(store.userTeam == local)
        sync.useLocalOffline()
        #expect(sync.phase == .local)
        #expect(store.userTeam == local)
        #expect(repo.insertCount == 0)
    }
    @Test func signOutRetainsOwnedLocalCache() async {
        let repo = TeamRepositoryStub(), store = TeamStore(defaults: defaults)
        repo.remote = team()
        let sync = coordinator(repo, store)
        await sync.resolve(auth)
        let saved = store.userTeam
        await sync.resolve(.guest)
        #expect(sync.phase == .local)
        #expect(store.userTeam == saved)
        #expect(store.ownerID == userID)
        #expect(TeamStore(defaults: defaults).userTeam == saved)
    }
    @Test func otherAccountCannotAdoptRetainedTeam() async {
        let repo = TeamRepositoryStub(), store = TeamStore(defaults: defaults)
        store.hydrate(team(), owner: UUID())
        let sync = coordinator(repo, store)
        await sync.resolve(auth)
        #expect(sync.phase == .ready)
        #expect(!store.hasTeam)
        #expect(store.ownerID == userID)
        #expect(repo.insertCount == 0)
    }
    @Test func lateResponseAfterSignOutDoesNotApply() async {
        let repo = TeamRepositoryStub(), store = TeamStore(defaults: defaults)
        repo.remote = team()
        let sync = coordinator(repo, store)
        repo.duringFetch = { await sync.resolve(.guest) }
        await sync.resolve(auth)
        #expect(sync.phase == .local)
        #expect(!store.hasTeam)
    }
    @Test func failedEditRemainsDurableAndRetries() async {
        let repo = TeamRepositoryStub(), store = TeamStore(defaults: defaults)
        let original = team()
        repo.remote = original
        let sync = coordinator(repo, store)
        await sync.resolve(auth)
        repo.fail = true
        let edited = GameTeam(id: original.id, state: original.state, teamName: "Edited", logoID: original.logoID,
                              primaryColorHex: original.primaryColorHex, secondaryColorHex: original.secondaryColorHex, isUserTeam: true)
        store.save(edited)
        await sync.retryPendingSave()
        #expect(sync.hasPendingSave)
        #expect(SaveStore.load(GameTeam.self, key: "gamescene.gridiron.pendingTeam." + userID.uuidString, defaults: defaults) == edited)
        repo.fail = false
        await sync.retryPendingSave()
        #expect(!sync.hasPendingSave)
        #expect(repo.remote == edited)
        #expect(store.userTeam == edited)
    }
    @Test func switchingTeamsRestoresLocalRosterAndSeason() {
        let a = team("A"), b = team("B")
        let roster = RosterManager(defaults: defaults)
        roster.ensureRoster(for: a)
        let originalRoster = roster.franchise
        let season = SeasonManager(defaults: defaults)
        season.startNewSeason(userTeam: a)
        let originalSeason = season.season
        defaults.set(Data([1, 2, 3]), forKey: ActiveInvestigationStore.storageKey)
        season.activateTeam(b.id, previousTeamID: a.id)
        roster.ensureRoster(for: b)
        #expect(season.season == nil)
        #expect(defaults.data(forKey: ActiveInvestigationStore.storageKey) == nil)
        season.activateTeam(a.id, previousTeamID: b.id)
        roster.ensureRoster(for: a)
        #expect(season.season == originalSeason)
        #expect(roster.franchise?.allPlayers.map(\.id) == originalRoster?.allPlayers.map(\.id))
        #expect(defaults.data(forKey: ActiveInvestigationStore.storageKey) == Data([1, 2, 3]))
    }
    @Test func authSessionRestorationAndSignOutUseSameTeamPath() async {
        let client = MockAuthClient(), profiles = MockProfileRepository()
        client.restoredSessionUserID = userID
        profiles.stored[userID] = UserProfile(authUserID: userID, username: "PlayerOne", firstName: "Test", lastName: "Player")
        let service = AuthService(authClient: client, profileRepository: profiles, defaults: defaults)
        let repo = TeamRepositoryStub(), store = TeamStore(defaults: defaults)
        repo.remote = team()
        let sync = coordinator(repo, store)
        await sync.resolve(service.state)
        #expect(sync.phase == .loading)
        await service.restoreSession()
        await sync.resolve(service.state)
        #expect(store.userTeam == repo.remote)
        #expect(sync.phase == .ready)
        await service.signOut()
        await sync.resolve(service.state)
        #expect(sync.phase == .local)
        #expect(store.userTeam == repo.remote)
        #expect(client.signOutCount == 1)
    }
    @Test func lateAccountAResponseCannotReplaceAccountB() async {
        let repo = TeamRepositoryStub(), store = TeamStore(defaults: defaults)
        let aTeam = team("A"), bTeam = team("B")
        let bID = UUID()
        let bAuth = AuthSessionState.authenticated(UserProfile(authUserID: bID, username: "PlayerTwo", firstName: "Other", lastName: "Player"))
        let sync = coordinator(repo, store)
        repo.remote = aTeam
        repo.duringFetch = {
            repo.remote = bTeam
            await sync.resolve(bAuth)
            repo.remote = aTeam
        }
        await sync.resolve(auth)
        #expect(store.userTeam == bTeam)
        #expect(store.ownerID == bID)
        #expect(sync.resolvedState == bAuth)
    }
    @Test func offlineEditsRemainOwnedAfterServerFirstRestore() async {
        let repo = TeamRepositoryStub(), store = TeamStore(defaults: defaults)
        let original = team()
        repo.remote = original
        let sync = coordinator(repo, store)
        await sync.resolve(auth)
        await sync.resolve(.guest)
        let edited = GameTeam(id: original.id, state: original.state, teamName: "Offline edit", logoID: original.logoID,
                              primaryColorHex: original.primaryColorHex, secondaryColorHex: original.secondaryColorHex, isUserTeam: true)
        store.save(edited)
        #expect(repo.updateCount == 0)
        await sync.resolve(auth)
        #expect(store.userTeam == original)
        #expect(sync.hasPendingSave)
        await sync.retryPendingSave()
        #expect(repo.remote == edited)
    }
    @Test func schemaLocksOwnerAndIdentity() {
        let sql = SchemaFixture.sql
        #expect(sql.contains("user_id uuid primary key references auth.users(id) on delete cascade"))
        #expect(sql.contains("alter table public.user_teams enable row level security"))
        #expect(sql.contains("revoke all on public.user_teams from public, anon, authenticated"))
        #expect(sql.contains("using (auth.uid() = user_id) with check (auth.uid() = user_id)"))
        #expect(sql.contains("grant update (state, team_name, logo_id, primary_color, secondary_color)\n    on public.user_teams"))
    }
}

@MainActor
private final class TeamRepositoryStub: UserTeamRepository {
    var remote: GameTeam?
    var fail = false
    var fetchCount = 0, insertCount = 0, updateCount = 0
    var duringFetch: (() async -> Void)?
    func fetch(userID: UUID) async throws -> GameTeam? {
        fetchCount += 1
        if let duringFetch { self.duringFetch = nil; await duringFetch() }
        if fail { throw URLError(.notConnectedToInternet) }
        return remote
    }
    func createIfAbsent(userID: UUID, team: GameTeam) async throws -> GameTeam {
        insertCount += 1
        if fail { throw URLError(.notConnectedToInternet) }
        if remote == nil { remote = team }
        return remote!
    }
    func update(userID: UUID, team: GameTeam) async throws {
        updateCount += 1
        if fail { throw URLError(.notConnectedToInternet) }
        remote = team
    }
}

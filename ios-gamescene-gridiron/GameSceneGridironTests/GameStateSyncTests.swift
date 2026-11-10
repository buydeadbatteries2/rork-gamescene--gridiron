import Foundation
import Testing
@testable import GameSceneGridiron

@MainActor @Suite("GameStateSyncTests") struct GameStateSyncTests {
    let defaults = UserDefaults(suiteName: "progress-tests-" + UUID().uuidString)!
    let owner = UUID()
    let team = GameTeam(state: "Virginia", teamName: "Wolves", logoID: "wolf", primaryColorHex: 123, secondaryColorHex: 456, isUserTeam: true)

    @Test func winRosterWalletAndPreferencesSurviveFreshInstall() async throws {
        let seasons = SeasonManager(defaults: defaults)
        seasons.startNewSeason(userTeam: team)
        seasons.recordUserResult(isWin: true, userScore: 3, opponentScore: 1, wentToOT: false)
        let roster = RosterManager(defaults: defaults)
        roster.ensureRoster(for: team)
        let wallet = PlayerWallet(defaults: defaults)
        wallet.grantStoreGameBalls(25, transactionID: "purchase-1")
        wallet.addHints(2)
        defaults.set(false, forKey: "accessibility.largerClueText")
        let snapshot = GameStateSnapshot.capture(teamID: team.id, defaults: defaults)
        try snapshot.validate()
        let repo = ProgressRepositoryStub()
        let source = GameStateSync(repository: repo, defaults: defaults)
        let uploaded = try await source.prepare(owner: owner, team: team, candidate: snapshot)
        source.install(uploaded)
        let fresh = UserDefaults(suiteName: "fresh-progress-" + UUID().uuidString)!
        let freshWallet = PlayerWallet(defaults: fresh)
        let freshSeasons = SeasonManager(defaults: fresh)
        let freshRoster = RosterManager(defaults: fresh)
        let target = GameStateSync(repository: repo, defaults: fresh, hydrate: {
            freshWallet.reloadCloudState(); freshSeasons.reloadCloudState(); freshRoster.reloadCloudState()
        })
        let restored = try await target.prepare(owner: owner, team: team, candidate: nil)
        target.install(restored)
        #expect(freshSeasons.season == seasons.season)
        #expect(freshSeasons.season?.currentWeek == 2)
        #expect(freshSeasons.season?.userStanding?.totalWins == 1)
        #expect(freshRoster.franchise == roster.franchise)
        #expect(freshRoster.franchise?.teamID == team.id)
        #expect(freshWallet.gameBalls == wallet.gameBalls)
        #expect(freshWallet.hints == wallet.hints)
        #expect(!freshWallet.grantStoreGameBalls(25, transactionID: "purchase-1"))
        #expect(!TutorialManager(defaults: fresh).isLargerClueTextEnabled)
        #expect(repo.creates == 1)
    }

    @Test func pendingNetworkFailureSurvivesCoordinatorRestart() async throws {
        let repo = ProgressRepositoryStub()
        let sync = GameStateSync(repository: repo, defaults: defaults)
        sync.install(try await sync.prepare(owner: owner, team: team, candidate: nil))
        PlayerWallet(defaults: defaults).grantStoreGameBalls(25, transactionID: "local-win")
        sync.checkpoint()
        repo.fail = true
        await sync.retry()
        #expect(sync.hasPendingSave)
        #expect(PlayerWallet(defaults: defaults).gameBalls == 25)
        repo.fail = false
        let restarted = GameStateSync(repository: repo, defaults: defaults)
        let row = try await restarted.prepare(owner: owner, team: team, candidate: GameStateSnapshot.capture(teamID: team.id, defaults: defaults))
        restarted.install(row)
        #expect(PlayerWallet(defaults: defaults).gameBalls == 25)
        #expect(row.revision == 2)
        #expect(!restarted.hasPendingSave)
    }

    @Test func emptyOrUnrelatedGuestCannotOverwriteCloud() async throws {
        let repo = ProgressRepositoryStub()
        let sync = GameStateSync(repository: repo, defaults: defaults)
        PlayerWallet(defaults: defaults).grantStoreGameBalls(150, transactionID: "saved")
        _ = try await sync.prepare(owner: owner, team: team, candidate: GameStateSnapshot.capture(teamID: team.id, defaults: defaults))
        let empty = GameStateSnapshot(teamID: team.id)
        let row = try await sync.prepare(owner: owner, team: team, candidate: empty)
        sync.install(row)
        #expect(PlayerWallet(defaults: defaults).gameBalls == 150)
        #expect(repo.updates == 0)
        #expect(sync.candidate(owner: UUID(), localTeam: team, localOwner: nil) == nil)
    }

    @Test func fetchFailureDoesNotEraseLocalProgress() async {
        let repo = ProgressRepositoryStub(); repo.fail = true
        let sync = GameStateSync(repository: repo, defaults: defaults)
        PlayerWallet(defaults: defaults).addHints(7)
        let before = GameStateSnapshot.capture(teamID: team.id, defaults: defaults)
        do { _ = try await sync.prepare(owner: owner, team: team, candidate: before); Issue.record("Should fail") } catch {}
        #expect(GameStateSnapshot.capture(teamID: team.id, defaults: defaults) == before)
    }

    @Test func staleDeviceCannotOverwriteNewerCloud() async throws {
        let repo = ProgressRepositoryStub()
        let sync = GameStateSync(repository: repo, defaults: defaults)
        sync.install(try await sync.prepare(owner: owner, team: team, candidate: nil))
        let other = UserDefaults(suiteName: "other-device-" + UUID().uuidString)!
        PlayerWallet(defaults: other).grantStoreGameBalls(150, transactionID: "other")
        _ = try await repo.update(userID: owner, snapshot: GameStateSnapshot.capture(teamID: team.id, defaults: other), revision: 1)
        PlayerWallet(defaults: defaults).grantStoreGameBalls(25, transactionID: "stale")
        await sync.retry()
        #expect(sync.conflict)
        #expect(PlayerWallet(defaults: defaults).gameBalls == 25)
        sync.begin()
        sync.install(try await sync.prepare(owner: owner, team: team, candidate: GameStateSnapshot.capture(teamID: team.id, defaults: defaults)))
        #expect(PlayerWallet(defaults: defaults).gameBalls == 150)
        #expect(defaults.dictionaryRepresentation().keys.contains { $0.contains(".conflict.") })
    }

    @Test func allowlistExcludesCredentialsAndCompetitiveQueues() throws {
        defaults.set("secret", forKey: "auth.token")
        defaults.set(Data([1, 2]), forKey: "gamescene.gridiron.competitiveQueue.v2")
        let snapshot = GameStateSnapshot.capture(teamID: team.id, defaults: defaults)
        try snapshot.validate()
        #expect(snapshot.blobs.isEmpty)
        #expect(snapshot.strings.isEmpty)
        #expect(TutorialManager(defaults: defaults).isLargerClueTextEnabled)
    }

    @Test func wrongTeamAndUnsupportedSchemaAreRejected() {
        let roster = RosterManager(defaults: defaults); roster.ensureRoster(for: team)
        let wrong = GameStateSnapshot.capture(teamID: UUID(), defaults: defaults)
        #expect(throws: GameStateError.self) { try wrong.validate() }
        var future = GameStateSnapshot(teamID: team.id); future.schemaVersion = 999
        #expect(throws: GameStateError.self) { try future.validate() }
    }

    @Test func offlinePlayAdvancesAnAlreadyPendingSave() async throws {
        let repo = ProgressRepositoryStub()
        let sync = GameStateSync(repository: repo, defaults: defaults)
        sync.install(try await sync.prepare(owner: owner, team: team, candidate: nil))
        let wallet = PlayerWallet(defaults: defaults)
        wallet.grantStoreGameBalls(25, transactionID: "before-signout")
        sync.checkpoint(); sync.begin()
        wallet.grantStoreGameBalls(25, transactionID: "while-offline")
        let candidate = GameStateSnapshot.capture(teamID: team.id, defaults: defaults)
        sync.install(try await sync.prepare(owner: owner, team: team, candidate: candidate))
        #expect(PlayerWallet(defaults: defaults).gameBalls == 50)
    }

    @Test func teamGateWaitsForProgressAndHydratesBeforeReady() async throws {
        let teamRepo = TeamRepositoryStub(); teamRepo.remote = team
        let repo = ProgressRepositoryStub()
        PlayerWallet(defaults: defaults).grantStoreGameBalls(25, transactionID: "cloud")
        _ = try await repo.createIfAbsent(userID: owner, snapshot: GameStateSnapshot.capture(teamID: team.id, defaults: defaults))
        defaults.removeObject(forKey: PlayerWallet.storageKey)
        let wallet = PlayerWallet(defaults: defaults)
        let progress = GameStateSync(repository: repo, defaults: defaults, hydrate: { wallet.reloadCloudState() })
        let store = TeamStore(defaults: defaults)
        let sync = TeamSyncCoordinator(repository: teamRepo, store: store, tutorial: TutorialManager(defaults: defaults), defaults: defaults, progress: progress)
        repo.duringFetch = { #expect(sync.phase == .loading); #expect(!store.hasTeam) }
        let auth = AuthSessionState.authenticated(UserProfile(authUserID: owner, username: "PlayerOne", firstName: "Test", lastName: "Player"))
        await sync.resolve(auth)
        #expect(sync.phase == .ready)
        #expect(wallet.gameBalls == 25)
        #expect(store.userTeam == team)
    }

    @Test func failedProgressFetchNeverActivatesIncomingTeam() async {
        let teamRepo = TeamRepositoryStub(); teamRepo.remote = team
        let repo = ProgressRepositoryStub(); repo.fail = true
        let store = TeamStore(defaults: defaults)
        PlayerWallet(defaults: defaults).addHints(5)
        let before = GameStateSnapshot.capture(teamID: team.id, defaults: defaults)
        let progress = GameStateSync(repository: repo, defaults: defaults)
        let sync = TeamSyncCoordinator(repository: teamRepo, store: store, tutorial: TutorialManager(defaults: defaults), defaults: defaults, progress: progress)
        await sync.resolve(.authenticated(UserProfile(authUserID: owner, username: "PlayerOne", firstName: "Test", lastName: "Player")))
        #expect(sync.phase == .failure)
        #expect(!store.hasTeam)
        #expect(GameStateSnapshot.capture(teamID: team.id, defaults: defaults) == before)
    }

    @Test func lateProgressResponseAfterSignOutIsIgnored() async {
        let teamRepo = TeamRepositoryStub(); teamRepo.remote = team
        let repo = ProgressRepositoryStub()
        let store = TeamStore(defaults: defaults)
        let progress = GameStateSync(repository: repo, defaults: defaults)
        let sync = TeamSyncCoordinator(repository: teamRepo, store: store, tutorial: TutorialManager(defaults: defaults), defaults: defaults, progress: progress)
        repo.duringFetch = { await sync.resolve(.guest) }
        await sync.resolve(.authenticated(UserProfile(authUserID: owner, username: "PlayerOne", firstName: "Test", lastName: "Player")))
        #expect(sync.phase == .local)
        #expect(!store.hasTeam)
        #expect(repo.creates == 0)
    }

    @Test func activeInvestigationRestoresWithoutCopyingCompetitiveIdentity() throws {
        let record = ActiveMatchRecord(seasonNumber: 1, week: 2, isPlayoff: false, isChampionship: false,
                                       matchID: UUID(), match: GameMatch(), competitive: .legacyResume())
        ActiveInvestigationStore.save(record, defaults: defaults)
        let clock = InvestigationSnapshot(matchKey: "match-quarter", caseID: "case-test", isTimed: true,
                                           remaining: 12, timeoutsRemaining: 1, lives: 2, placedPlayerIDs: ["one"], usedHintIDs: ["hint"], rejectionCount: 1)
        SaveStore.save(clock, key: GameViewModel.clockSnapshotKey, defaults: defaults)
        let local = GameStateSnapshot.capture(teamID: team.id, defaults: defaults)
        let cloud = local.soloCopy()
        cloud.install(into: defaults)
        #expect(ActiveInvestigationStore.load(defaults: defaults)?.competitive == nil)
        #expect(ActiveInvestigationStore.load(defaults: defaults)?.matchID == record.matchID)
        #expect(SaveStore.load(InvestigationSnapshot.self, key: GameViewModel.clockSnapshotKey, defaults: defaults) == clock)
        cloud.retainingLocalAssignment(from: local).install(into: defaults)
        #expect(ActiveInvestigationStore.load(defaults: defaults)?.competitive == record.competitive)
    }

    @Test func catalogFingerprintsAreUnchangedByCopyCleanup() {
        for item in CaseLibrary.all {
            if let entry = CompetitiveCaseCatalog.entries[item.id] {
                #expect(CompetitiveCaseCatalog.fingerprint(of: item) == entry.fingerprint)
            }
        }
    }

    @Test func allProductionCopyIsFreeOfInternalSuffixes() {
        for item in CaseLibrary.all {
            for clue in item.clues { #expect(!clue.text.contains("Case file:")) }
            for hint in item.hints { #expect(!hint.text.contains(" file.)")) }
        }
    }
}

@MainActor final class ProgressRepositoryStub: GameStateRepository {
    var row: CloudGameState?
    var fail = false
    var creates = 0
    var duringFetch: (() async -> Void)?
    var updates = 0
    func fetch(userID: UUID) async throws -> CloudGameState? {
        let action = duringFetch; duringFetch = nil
        await action?()
        if fail { throw URLError(.notConnectedToInternet) }
        return row
    }
    func createIfAbsent(userID: UUID, snapshot: GameStateSnapshot) async throws -> CloudGameState {
        if let row { return row }
        creates += 1
        let value = CloudGameState(user_id: userID, team_id: snapshot.teamID, schema_version: 1, revision: 1, snapshot: snapshot, updated_at: "2026-11-10T00:00:00Z")
        row = value; return value
    }
    func update(userID: UUID, snapshot: GameStateSnapshot, revision: Int) async throws -> CloudGameState {
        if fail { throw URLError(.notConnectedToInternet) }
        guard row?.revision == revision else { throw GameStateError.conflict }
        updates += 1
        let value = CloudGameState(user_id: userID, team_id: snapshot.teamID, schema_version: 1, revision: revision + 1, snapshot: snapshot, updated_at: "2026-11-10T00:01:00Z")
        row = value; return value
    }
}

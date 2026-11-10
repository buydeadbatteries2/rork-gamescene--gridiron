import Foundation
import Observation

@MainActor
@Observable
final class TeamSyncCoordinator {
    enum Phase: Equatable { case loading, local, ready, migration, failure }
    static let shared = TeamSyncCoordinator(
        repository: SupabaseClientProvider.shared.supabase.map { SupabaseUserTeamRepository(client: $0) },
        store: .shared, tutorial: .shared, defaults: .standard, progress: .shared,
        activate: { team, previousID in
            SeasonManager.shared.activateTeam(team?.id, previousTeamID: previousID)
            if let team { RosterManager.shared.ensureRoster(for: team) }
        })

    private(set) var lastSyncError: String?

    private func recordSyncError(_ error: Error) {
        lastSyncError = TeamSyncDiagnostic.describe(error)
        #if DEBUG
        print("team_sync_fetch_failed \(lastSyncError ?? "unknown")")
        #endif
    }

    private(set) var phase: Phase = .loading
    private(set) var resolvedState: AuthSessionState?
    private(set) var hasPendingSave = false
    private(set) var isSaving = false
    private let repository: (any UserTeamRepository)?
    private let store: TeamStore
    private let tutorial: TutorialManager
    private let defaults: UserDefaults
    private let activate: (GameTeam?, UUID?) -> Void
    private let progress: GameStateSync?
    private var accountID: UUID?
    private var remoteTeamID: UUID?
    private var generation = UUID()
    private var writeRevision = 0

    init(repository: (any UserTeamRepository)?, store: TeamStore, tutorial: TutorialManager,
         defaults: UserDefaults, progress: GameStateSync? = nil, activate: @escaping (GameTeam?, UUID?) -> Void = { _, _ in }) {
        self.repository = repository; self.store = store; self.tutorial = tutorial
        self.defaults = defaults; self.activate = activate; self.progress = progress
        store.onLocalSave = { [weak self] in self?.localSave() }
    }

    static func userID(_ state: AuthSessionState) -> UUID? {
        switch state {
        case .authenticated(let profile), .needsProfileRecovery(let profile): return profile.authUserID
        default: return nil
        }
    }
    private func pendingKey(_ id: UUID) -> String { "gamescene.gridiron.pendingTeam." + id.uuidString }
    private func valid(_ token: UUID) -> Bool { generation == token && !Task.isCancelled }

    func resolve(_ auth: AuthSessionState) async {
        progress?.begin()
        lastSyncError = nil
        generation = UUID()
        let token = generation
        resolvedState = auth
        accountID = Self.userID(auth)
        remoteTeamID = nil
        isSaving = false; hasPendingSave = false
        guard auth != .restoring else { phase = .loading; return }
        guard let id = accountID else { phase = .local; return }
        phase = .loading
        guard let repository else {
            lastSyncError = "configuration: Supabase client unavailable"
            phase = .failure
            return
        }
        do {
            let remote = try await repository.fetch(userID: id)
            guard valid(token) else { return }
            if let remote {
                let candidate = progress?.candidate(owner: id, localTeam: store.userTeam, localOwner: store.ownerID)
                let state = try await progress?.prepare(owner: id, team: remote, candidate: candidate)
                guard valid(token) else { return }
                progress?.archiveLocal()
                apply(remote, owner: id)
                if let state { progress?.install(state) }
                activate(remote, remote.id)
                remoteTeamID = remote.id
                tutorial.skipSetupForRestoredTeam()
                phase = .ready
                hasPendingSave = SaveStore.load(GameTeam.self, key: pendingKey(id), defaults: defaults) != nil
            } else if store.hasTeam && (store.ownerID == nil || store.ownerID == id) {
                phase = .migration
            } else {
                // An account's retained local team is never adopted by another account.
                progress?.prepareNewAccount(owner: id)
                apply(nil, owner: id)
                phase = .ready
            }
        } catch {
            guard valid(token) else { return }
            recordSyncError(error)
            phase = .failure // Network failure is NOT an empty account.
        }
    }

    private func apply(_ team: GameTeam?, owner: UUID) {
        let previousID = store.userTeam?.id
        activate(team, previousID)
        store.hydrate(team, owner: owner)
    }

    func migrateLocalTeam() async {
        guard phase == .migration, let id = accountID, let team = store.userTeam,
              store.ownerID == nil || store.ownerID == id, let repository else { return }
        let token = generation
        phase = .loading
        do {
            let winner = try await repository.createIfAbsent(userID: id, team: team)
            guard valid(token) else { return }
            let candidate = progress?.candidate(owner: id, localTeam: team, localOwner: store.ownerID, explicitlyLinked: true)
            let state = try await progress?.prepare(owner: id, team: winner, candidate: candidate)
            guard valid(token) else { return }
            progress?.archiveLocal()
            apply(winner, owner: id)
            if let state { progress?.install(state) }
            activate(winner, winner.id)
            remoteTeamID = winner.id
            tutorial.skipSetupForRestoredTeam()
            phase = .ready
        } catch {
            guard valid(token) else { return }
            phase = .failure
        }
    }

    func createNewInstead() {
        guard phase == .migration, let id = accountID else { return }
        progress?.prepareNewAccount(owner: id)
        apply(nil, owner: id)
        phase = .ready
    }

    /// Explicit offline escape; ownership and every local solo save remain intact.
    func useLocalOffline() {
        progress?.begin()
        generation = UUID()
        accountID = nil
        phase = .local
        isSaving = false
    }

    private func localSave() {
        guard let owner = store.ownerID, let team = store.userTeam else { return }
        // Offline/signed-out edits stay with their original owner, never a new account.
        SaveStore.save(team, key: pendingKey(owner), defaults: defaults)
        guard phase == .ready, accountID == owner else { return }
        writeRevision += 1
        hasPendingSave = true
        Task { await retryPendingSave() }
    }

    /// Serialized writes; a failed save stays durable until an explicit retry succeeds.
    func retryPendingSave() async {
        guard !isSaving, phase == .ready, let id = accountID, let repository else { return }
        let token = generation
        isSaving = true
        defer { if generation == token { isSaving = false } }
        while let pending = SaveStore.load(GameTeam.self, key: pendingKey(id), defaults: defaults) {
            let revision = writeRevision
            do {
                if remoteTeamID == nil {
                    phase = .loading
                    let winner = try await repository.createIfAbsent(userID: id, team: pending)
                    guard valid(token) else { return }
                    let candidate = progress?.candidate(owner: id, localTeam: store.userTeam, localOwner: store.ownerID)
                    let state = try await progress?.prepare(owner: id, team: winner, candidate: candidate)
                    guard valid(token) else { return }
                    progress?.archiveLocal()
                    apply(winner, owner: id)
                    if let state { progress?.install(state) }
                    activate(winner, winner.id)
                    phase = .ready
                    remoteTeamID = winner.id
                    if winner.id != pending.id {
                        // Preserve the displaced draft, but never retry it over the winner.
                        SaveStore.save(pending, key: pendingKey(id) + ".superseded", defaults: defaults)
                        apply(winner, owner: id)
                        tutorial.skipSetupForRestoredTeam()
                        defaults.removeObject(forKey: pendingKey(id))
                        hasPendingSave = false
                        return
                    } else if revision == writeRevision {
                        apply(winner, owner: id)
                    }
                } else {
                    // A pending edit can never replace a different server identity.
                    guard remoteTeamID == pending.id else { hasPendingSave = true; return }
                    try await repository.update(userID: id, team: pending)
                    guard valid(token) else { return }
                    if revision == writeRevision { apply(pending, owner: id) }
                }
                guard valid(token) else { return }
                if revision == writeRevision {
                    defaults.removeObject(forKey: pendingKey(id))
                    hasPendingSave = false
                    return
                }
            } catch {
                if valid(token), phase == .loading { recordSyncError(error); phase = .failure }
                return
            }
        }
    }
}

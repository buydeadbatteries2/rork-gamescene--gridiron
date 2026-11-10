import Foundation
import Observation

@MainActor @Observable final class GameStateSync {
    static let shared = GameStateSync(repository: SupabaseClientProvider.shared.supabase.map { SupabaseGameStateRepository(client: $0) }, defaults: .standard, hydrate: {
        PlayerWallet.shared.reloadCloudState()
        RosterManager.shared.reloadCloudState()
        SeasonManager.shared.reloadCloudState()
        AchievementManager.shared.reloadCloudState()
        LegacyStore.shared.reloadCloudState()
        TutorialManager.shared.reloadCloudState()
        DifficultyManager.shared.reloadCloudState()
        AudioManager.shared.reloadCloudState()
    })
    nonisolated struct Pending: Codable, Sendable {
        let snapshot: GameStateSnapshot
        let revision: Int
    }
    static let ownerKey = "gamescene.gridiron.progressOwner"
    private let repository: (any GameStateRepository)?
    private let defaults: UserDefaults
    private let hydrate: () -> Void
    private var generation = UUID()
    private var activeUser: UUID?
    private var teamID: UUID?
    private var revision = 0
    private var baseline: GameStateSnapshot?
    private(set) var hasPendingSave = false
    private(set) var isSaving = false
    private(set) var conflict = false
    private(set) var lastError: String?
    init(repository: (any GameStateRepository)?, defaults: UserDefaults, hydrate: @escaping () -> Void = {}) {
        self.repository = repository; self.defaults = defaults; self.hydrate = hydrate
    }
    private func key(_ owner: UUID) -> String { "gamescene.gridiron.progressPending." + owner.uuidString }
    private func cacheKey(_ owner: UUID) -> String { "gamescene.gridiron.progressBase." + owner.uuidString }

    /// Called before any team hydration; ownership cannot be inferred from a newly fetched team.
    func begin() {
        checkpoint()
        generation = UUID(); activeUser = nil; teamID = nil; baseline = nil
        isSaving = false; hasPendingSave = false; conflict = false; lastError = nil
    }
    func candidate(owner: UUID, localTeam: GameTeam?, localOwner: UUID?, explicitlyLinked: Bool = false) -> GameStateSnapshot? {
        guard let localTeam else { return nil }
        let progressOwner = defaults.string(forKey: Self.ownerKey).flatMap(UUID.init(uuidString:))
        guard progressOwner == owner || (progressOwner == nil && (localOwner == owner || explicitlyLinked)) else { return nil }
        return GameStateSnapshot.capture(teamID: localTeam.id, defaults: defaults)
    }

    /// Read/validate first. Failure leaves all local managers and storage untouched.
    func prepare(owner: UUID, team: GameTeam, candidate: GameStateSnapshot?) async throws -> CloudGameState {
        guard let repository else { throw GameStateError.unavailable }
        let token = generation
        var row = try await repository.fetch(userID: owner)
        guard token == generation, !Task.isCancelled else { throw CancellationError() }
        if row == nil {
            let initial = candidate?.teamID == team.id ? candidate! : GameStateSnapshot(teamID: team.id)
            try initial.validate()
            row = try await repository.createIfAbsent(userID: owner, snapshot: initial.soloCopy())
        }
        guard var winner = row, token == generation, !Task.isCancelled else { throw CancellationError() }
        guard winner.user_id == owner, winner.team_id == team.id, winner.schema_version == 1,
              winner.snapshot.teamID == team.id else { throw GameStateError.invalidSnapshot }
        try winner.snapshot.validate()
        // Reconstruct uncheckpointed offline changes against the last acknowledged base.
        if let candidate, candidate.teamID == team.id,
           let base = SaveStore.load(Pending.self, key: cacheKey(owner), defaults: defaults),
           candidate != base.snapshot {
            let queued = SaveStore.load(Pending.self, key: key(owner), defaults: defaults)
            // Signed-out/offline play can advance beyond an already queued upload.
            if queued?.snapshot != candidate {
                SaveStore.save(Pending(snapshot: candidate, revision: queued?.revision ?? base.revision), key: key(owner), defaults: defaults)
            }
        }
        if let pending = SaveStore.load(Pending.self, key: key(owner), defaults: defaults), pending.snapshot.teamID == team.id {
            try pending.snapshot.validate()
            if pending.revision == winner.revision {
                winner = try await repository.update(userID: owner, snapshot: pending.snapshot.soloCopy(), revision: winner.revision)
            } else if pending.snapshot.soloCopy() != winner.snapshot {
                // The server wins a stale-device conflict, but the full losing save is recoverable locally.
                SaveStore.save(pending, key: key(owner) + ".conflict." + UUID().uuidString, defaults: defaults)
            }
        }
        guard token == generation, !Task.isCancelled else { throw CancellationError() }
        try winner.snapshot.validate()
        return CloudGameState(user_id: winner.user_id, team_id: winner.team_id, schema_version: winner.schema_version,
                              revision: winner.revision, snapshot: winner.snapshot.retainingLocalAssignment(from: candidate), updated_at: winner.updated_at)
    }

    func archiveLocal() {
        // Archive displaced guest/account progress before replacing any allowlisted key.
        if let previous = SaveStore.load(GameTeam.self, key: TeamStore.storageKey, defaults: defaults) {
            let backup = GameStateSnapshot.capture(teamID: previous.id, defaults: defaults)
            SaveStore.save(backup, key: "gamescene.gridiron.progressBackup." + UUID().uuidString, defaults: defaults)
        }
    }

    func install(_ row: CloudGameState) {
        activeUser = nil; baseline = nil
        row.snapshot.install(into: defaults)
        defaults.set(row.user_id.uuidString, forKey: Self.ownerKey)
        activeUser = row.user_id; teamID = row.team_id; revision = row.revision
        hydrate()
        if defaults === UserDefaults.standard, let team = TeamStore.shared.userTeam {
            RosterManager.shared.ensureCloudRoster(for: team)
        }
        baseline = GameStateSnapshot.capture(teamID: row.team_id, defaults: defaults)
        SaveStore.save(Pending(snapshot: baseline!, revision: revision), key: cacheKey(row.user_id), defaults: defaults)
        defaults.removeObject(forKey: key(row.user_id))
        hasPendingSave = false; conflict = false; lastError = nil
    }

    /// A new account without a team must not inherit another user's global wallet/achievements.
    func prepareNewAccount(owner: UUID) {
        if let previous = SaveStore.load(GameTeam.self, key: TeamStore.storageKey, defaults: defaults) {
            SaveStore.save(GameStateSnapshot.capture(teamID: previous.id, defaults: defaults), key: "gamescene.gridiron.progressBackup." + UUID().uuidString, defaults: defaults)
        }
        GameStateSnapshot(teamID: UUID()).install(into: defaults)
        defaults.set(owner.uuidString, forKey: Self.ownerKey)
        hydrate()
    }

    /// Local persistence is always first. No network operation is needed to queue a save.
    func checkpoint() {
        guard let owner = activeUser, let teamID, let baseline,
              defaults.string(forKey: Self.ownerKey) == owner.uuidString else { return }
        let snapshot = GameStateSnapshot.capture(teamID: teamID, defaults: defaults)
        guard snapshot != baseline else { return }
        do { try snapshot.validate() } catch { lastError = "Local save could not be validated"; return }
        SaveStore.save(Pending(snapshot: snapshot, revision: revision), key: key(owner), defaults: defaults)
        self.baseline = snapshot
        hasPendingSave = true
    }

    func retry() async {
        checkpoint()
        guard !isSaving, !conflict, let owner = activeUser, let repository,
              let pending = SaveStore.load(Pending.self, key: key(owner), defaults: defaults) else { return }
        let token = generation
        isSaving = true
        defer { if generation == token { isSaving = false } }
        do {
            let row = try await repository.update(userID: owner, snapshot: pending.snapshot.soloCopy(), revision: pending.revision)
            guard generation == token, !Task.isCancelled else { return }
            revision = row.revision
            SaveStore.save(Pending(snapshot: pending.snapshot, revision: revision), key: cacheKey(owner), defaults: defaults)
            if let latest = SaveStore.load(Pending.self, key: key(owner), defaults: defaults), latest.snapshot != pending.snapshot {
                SaveStore.save(Pending(snapshot: latest.snapshot, revision: revision), key: key(owner), defaults: defaults)
            } else {
                defaults.removeObject(forKey: key(owner)); hasPendingSave = false
            }
            lastError = nil
        } catch {
            guard generation == token else { return }
            if case GameStateError.conflict = error { conflict = true }
            lastError = conflict ? "A newer cloud save exists. Reconnect to restore it; this device's save will be archived." : "Progress is saved on this device. Cloud upload will retry."
            hasPendingSave = true
        }
    }
}

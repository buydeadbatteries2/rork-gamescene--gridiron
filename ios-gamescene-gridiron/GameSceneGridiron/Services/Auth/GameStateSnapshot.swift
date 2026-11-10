import Foundation

/// Deliberate allowlist, never a dump of UserDefaults or authentication storage.
nonisolated struct GameStateSnapshot: Codable, Equatable, Sendable {
    var schemaVersion = 1
    let teamID: UUID
    var blobs: [String: Data] = [:]
    var flags: [String: Bool] = [:]
    var numbers: [String: Double] = [:]
    var strings: [String: String] = [:]
    var tooltips: [String] = []

    static let blobKeys = ["season", "franchise", "economy", "achievements", "legacy", "activeMatch", "investigation"].map { "gamescene.gridiron." + $0 }
    static let flagKeys = ["tutorial.onboardingComplete", "tutorial.completed", "tutorial.firstGameAssistDone", "accessibility.hapticsEnabled", "accessibility.reduceMotion", "accessibility.largerClueText", "accessibility.highContrastClues", "audio.musicEnabled", "audio.soundEffectsEnabled", "gamescene.gridiron.hofClockExplained"]
    static let numberKeys = ["gamescene.gridiron.seasonCancellationCount", "gamescene.gridiron.cancelledSeasonNumber", "audio.musicVolume", "audio.effectVolume"]
    static let stringKeys = ["gamescene.gridiron.difficulty"]
    static let tooltipKey = "tutorial.completedTooltips"
    static let allKeys = blobKeys + flagKeys + numberKeys + stringKeys + [tooltipKey]

    @MainActor static func capture(teamID: UUID, defaults: UserDefaults) -> Self {
        var value = Self(teamID: teamID)
        for key in blobKeys { value.blobs[key] = defaults.data(forKey: key) }
        for key in flagKeys { value.flags[key] = defaults.object(forKey: key) as? Bool }
        for key in numberKeys { value.numbers[key] = (defaults.object(forKey: key) as? NSNumber)?.doubleValue }
        for key in stringKeys { value.strings[key] = defaults.string(forKey: key) }
        value.tooltips = defaults.stringArray(forKey: tooltipKey) ?? []
        return value
    }

    /// Validate in an isolated suite before touching the user's live save.
    @MainActor func validate() throws {
        guard schemaVersion == 1,
              Set(blobs.keys).isSubset(of: Set(Self.blobKeys)),
              Set(flags.keys).isSubset(of: Set(Self.flagKeys)),
              Set(numbers.keys).isSubset(of: Set(Self.numberKeys)),
              Set(strings.keys).isSubset(of: Set(Self.stringKeys)),
              numbers.values.allSatisfy({ $0.isFinite && $0 >= 0 }) else { throw GameStateError.invalidSnapshot }
        for data in blobs.values {
            if let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let version = object["version"] as? Int, version > SaveStore.currentSchemaVersion {
                throw GameStateError.invalidSnapshot
            }
        }
        let name = "cloud-validation-" + UUID().uuidString
        let scratch = UserDefaults(suiteName: name)!
        defer { scratch.removePersistentDomain(forName: name) }
        install(into: scratch)
        func valid<T: Decodable>(_ type: T.Type, _ suffix: String) -> Bool {
            let key = "gamescene.gridiron." + suffix
            return blobs[key] == nil || SaveStore.load(type, key: key, defaults: scratch) != nil
        }
        guard valid(Season.self, "season"), valid(Franchise.self, "franchise"),
              valid(ActiveMatchRecord.self, "activeMatch"), valid(InvestigationSnapshot.self, "investigation"),
              PlayerWallet.validateCloudState(scratch), AchievementManager.validateCloudState(scratch),
              LegacyStore.validateCloudState(scratch) else { throw GameStateError.invalidSnapshot }
        if let season = SaveStore.load(Season.self, key: "gamescene.gridiron.season", defaults: scratch), season.userTeamID != teamID { throw GameStateError.invalidSnapshot }
        if let roster = SaveStore.load(Franchise.self, key: "gamescene.gridiron.franchise", defaults: scratch), roster.teamID != teamID { throw GameStateError.invalidSnapshot }
    }

    @MainActor func install(into defaults: UserDefaults) {
        for key in Self.allKeys { defaults.removeObject(forKey: key) }
        for (key, value) in blobs { defaults.set(value, forKey: key) }
        for (key, value) in flags { defaults.set(value, forKey: key) }
        for (key, value) in numbers { defaults.set(value, forKey: key) }
        for (key, value) in strings { defaults.set(value, forKey: key) }
        defaults.set(tooltips, forKey: Self.tooltipKey)
    }

    /// Same-device resume may retain its existing competitive assignment, never import one from cloud.
    @MainActor func retainingLocalAssignment(from local: Self?) -> Self {
        guard let local, local.teamID == teamID,
              local.blobs["gamescene.gridiron.investigation"] == blobs["gamescene.gridiron.investigation"] else { return self }
        let name = "cloud-local-assignment-" + UUID().uuidString
        let scratch = UserDefaults(suiteName: name)!
        defer { scratch.removePersistentDomain(forName: name) }
        local.install(into: scratch)
        guard let original = ActiveInvestigationStore.load(defaults: scratch) else { return self }
        install(into: scratch)
        guard let remote = ActiveInvestigationStore.load(defaults: scratch) else { return self }
        var solo = original; solo.competitive = nil
        guard solo == remote else { return self }
        var result = self
        result.blobs[ActiveInvestigationStore.storageKey] = local.blobs[ActiveInvestigationStore.storageKey]
        return result
    }

    /// Competitive assignments/queues are server-owned and never restored as submissions.
    @MainActor func soloCopy() -> Self {
        var copy = self
        let name = "cloud-sanitize-" + UUID().uuidString
        let scratch = UserDefaults(suiteName: name)!
        defer { scratch.removePersistentDomain(forName: name) }
        install(into: scratch)
        if var record = ActiveInvestigationStore.load(defaults: scratch) {
            record.competitive = nil
            ActiveInvestigationStore.save(record, defaults: scratch)
            copy.blobs[ActiveInvestigationStore.storageKey] = scratch.data(forKey: ActiveInvestigationStore.storageKey)
        }
        return copy
    }
}

nonisolated enum GameStateError: Error { case invalidSnapshot, conflict, unavailable }

nonisolated struct CloudGameState: Codable, Sendable {
    let user_id: UUID
    let team_id: UUID
    let schema_version: Int
    let revision: Int
    let snapshot: GameStateSnapshot
    let updated_at: String
}

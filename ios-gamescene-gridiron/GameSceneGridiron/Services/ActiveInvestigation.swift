import Foundation

// MARK: - Active investigation record
//
// One persisted record for the match currently in progress, so leaving the
// app (or the game) mid-investigation resumes the SAME investigation on
// return — never a fresh puzzle. Phase 11.6 anti-exploit contract: a game is
// played from its current state; quarters already decided are never replayed.
//
// Future competitive (versus/faction) games will reuse this record shape with
// a server-authoritative assignment id — a competitive investigation stays
// one-time and non-restartable.

nonisolated struct ActiveMatchRecord: Codable, Hashable, Sendable {
    /// 0 for a standalone quick game.
    var seasonNumber: Int
    /// 1–10 regular season; 11+ postseason.
    var week: Int
    var isPlayoff: Bool
    var isChampionship: Bool
    /// Stable match identity — deterministic for season games, so the
    /// quarter's saved investigation snapshot always re-keys correctly.
    var matchID: UUID
    /// The match state as of the last completed quarter (or a fresh game).
    var match: GameMatch
    /// Phase 14: the game's competitive identity (unique match ID, start
    /// time, per-case results so far). nil on records saved before ranked
    /// play existed — such a resumed game is played normally but is never
    /// ranked. Optional so older saves keep decoding.
    var competitive: CompetitiveMatchState? = nil
}

nonisolated enum ActiveInvestigationStore {
    static let storageKey = "gamescene.gridiron.activeMatch"

    static func save(_ record: ActiveMatchRecord, defaults: UserDefaults = .standard) {
        SaveStore.save(record, key: storageKey, defaults: defaults)
    }

    static func load(defaults: UserDefaults = .standard) -> ActiveMatchRecord? {
        SaveStore.load(ActiveMatchRecord.self, key: storageKey, defaults: defaults)
    }

    static func clear(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: storageKey)
    }

    /// True when the saved record belongs to this exact game context — the
    /// only situation in which reopening resumes the investigation.
    static func matches(_ record: ActiveMatchRecord, seasonNumber: Int, week: Int, isPlayoff: Bool, isChampionship: Bool) -> Bool {
        record.seasonNumber == seasonNumber
            && record.week == week
            && record.isPlayoff == isPlayoff
            && record.isChampionship == isChampionship
    }
}

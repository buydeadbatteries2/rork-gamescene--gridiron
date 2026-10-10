import Foundation
import Observation

// MARK: - Legacy store

/// Single source of truth for everything that must outlive seasons: the
/// championship trophy case, the season archive, win streaks, the best
/// regular-season record and the career case counter. Persistence is one
/// UserDefaults JSON blob under its own key; starting a new season never
/// touches any of it.
///
/// Historical snapshots are deliberate: `ChampionshipTrophy` and
/// `SeasonArchiveEntry` freeze team name, logo, colors, record and difficulty
/// at the moment the season ended. Later franchise re-branding never rewrites
/// them.
@MainActor
@Observable
final class LegacyStore {
    static let shared = LegacyStore()

    static let storageKey = "gamescene.gridiron.legacy"

    private struct PersistedState: Codable {
        var trophies: [ChampionshipTrophy] = []
        var archive: [SeasonArchiveEntry] = []
        var currentWinStreak = 0
        var longestWinStreak = 0
        var bestRecordWins = 0
        var bestRecordLosses = 0
        var hasBestRecord = false
        var totalCasesSolved = 0
    }

    private let defaults: UserDefaults
    private var state: PersistedState

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        state = SaveStore.load(PersistedState.self, key: Self.storageKey, defaults: defaults) ?? PersistedState()
    }

    // MARK: Queries

    var trophies: [ChampionshipTrophy] { state.trophies }
    var archive: [SeasonArchiveEntry] { state.archive.sorted { $0.seasonNumber > $1.seasonNumber } }
    var currentWinStreak: Int { state.currentWinStreak }
    var longestWinStreak: Int { state.longestWinStreak }
    var totalCasesSolved: Int { state.totalCasesSolved }
    var championshipsWon: Int { state.trophies.count }

    /// The season number of the most recent title, if any.
    var lastTitleSeasonNumber: Int? { state.trophies.last?.seasonNumber }

    /// Trophy for a specific season, if one exists.
    func trophy(forSeason seasonNumber: Int) -> ChampionshipTrophy? {
        state.trophies.first { $0.seasonNumber == seasonNumber }
    }

    func archiveEntry(forSeason seasonNumber: Int) -> SeasonArchiveEntry? {
        state.archive.first { $0.seasonNumber == seasonNumber }
    }

    var isUndefeatedSeasonOnRecord: Bool { state.archive.contains(where: \.isUndefeated) }

    /// Hall of Famer championship trophies — a trophy-room milestone.
    var hallOfFamerTrophies: [ChampionshipTrophy] {
        state.trophies.filter { $0.difficulty == DifficultyLevel.hallOfFamer.title }
    }

    var bestRecordLine: String? {
        guard state.hasBestRecord else { return nil }
        return "\(state.bestRecordWins)–\(state.bestRecordLosses)"
    }

    /// Builds the full presentation-ready legacy summary from the roster's
    /// dynasty history, the roster itself and this store's counters.
    func franchiseLegacy(history: FranchiseHistory, players: [FranchisePlayer]) -> FranchiseLegacy {
        var mostPOG: LegacyLeader?
        for player in players {
            let count = player.seasonStats.value(for: .playerOfTheGame) + player.careerStats.value(for: .playerOfTheGame)
            if count > 0, count > (mostPOG?.count ?? 0) {
                mostPOG = LegacyLeader(name: player.displayName, count: count)
            }
        }
        return FranchiseLegacy(
            seasonsPlayed: history.seasonsPlayed,
            totalWins: history.wins,
            totalLosses: history.losses,
            playoffAppearances: history.playoffAppearances,
            championshipAppearances: history.championshipAppearances,
            championshipsWon: history.championshipsWon,
            bestRecordLine: bestRecordLine,
            currentWinStreak: state.currentWinStreak,
            longestWinStreak: state.longestWinStreak,
            totalCasesSolved: state.totalCasesSolved,
            mostPlayerOfTheGame: mostPOG
        )
    }

    // MARK: Events

    /// One solved quarter in a real game (training never calls this).
    func recordQuarterSolved() {
        state.totalCasesSolved += 1
        persist()
    }

    /// One finished, recorded game. OT wins count as wins; any loss resets
    /// the current streak to zero.
    func recordGameResult(isWin: Bool) {
        if isWin {
            state.currentWinStreak += 1
            state.longestWinStreak = max(state.longestWinStreak, state.currentWinStreak)
        } else {
            state.currentWinStreak = 0
        }
        persist()
    }

    /// Remembers the best regular-season record. Strictly improves only:
    /// more wins first, then fewer losses.
    func recordBestRegularSeason(wins: Int, losses: Int) {
        let improves: Bool
        if !state.hasBestRecord {
            improves = true
        } else if wins != state.bestRecordWins {
            improves = wins > state.bestRecordWins
        } else {
            improves = losses < state.bestRecordLosses
        }
        guard improves else { return }
        state.hasBestRecord = true
        state.bestRecordWins = wins
        state.bestRecordLosses = losses
        persist()
    }

    /// Archives one completed season exactly once (re-entry for the same
    /// season number is a no-op), and files the championship trophy when the
    /// season ended with a title. Returns true when something was recorded.
    @discardableResult
    func completeSeason(_ entry: SeasonArchiveEntry, trophy: ChampionshipTrophy?) -> Bool {
        guard !state.archive.contains(where: { $0.seasonNumber == entry.seasonNumber }) else { return false }
        state.archive.append(entry)
        if let trophy, trophy.seasonNumber == entry.seasonNumber, !state.trophies.contains(where: { $0.seasonNumber == trophy.seasonNumber }) {
            state.trophies.append(trophy)
        }
        recordBestRegularSeason(wins: entry.wins, losses: entry.losses)
        persist()
        return true
    }

    // MARK: Persistence

    private func persist() {
        SaveStore.save(state, key: Self.storageKey, defaults: defaults)
    }
}

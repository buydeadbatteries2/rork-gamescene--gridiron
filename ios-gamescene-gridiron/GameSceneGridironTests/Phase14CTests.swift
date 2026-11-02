import Foundation
import Testing

@testable import GameSceneGridiron

/// Phase 14C — the RANKED entry is UI only: it reuses the 14B services and
/// never changes ranked logic. These tests pin the entry-state resolution the
/// Home tile and the Ranked screen both share.
@Suite("Phase 14C — ranked entry")
struct Phase14CTests {

    private static let profile = UserProfile(authUserID: UUID(), username: "GridironKing", firstName: "Julius", lastName: "Hudson")
    private static let now = Date(timeIntervalSince1970: 1_790_000_000)

    private static func defaults() -> UserDefaults {
        let name = "phase14c-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func guestsSeeTheAccountGate() {
        #expect(RankedEntryState.resolve(state: .guest, hasTeam: true, nextGameNumber: 3, difficulty: .pro) == .needsAccount)
        #expect(RankedEntryState.resolve(state: .restoring, hasTeam: true, nextGameNumber: 3, difficulty: .pro) == .needsAccount)
        #expect(RankedEntryState.resolve(state: .needsProfileRecovery(Self.profile), hasTeam: true, nextGameNumber: 3, difficulty: .pro) == .needsAccount)
    }

    @Test func signedInWithoutFranchiseIsSentToCreateTheTeam() {
        #expect(RankedEntryState.resolve(state: .authenticated(Self.profile), hasTeam: false, nextGameNumber: nil, difficulty: nil) == .needsFranchise)
    }

    @Test func activeSeasonShowsContinueWithGameAndDifficulty() {
        #expect(RankedEntryState.resolve(state: .authenticated(Self.profile), hasTeam: true, nextGameNumber: 5, difficulty: .hallOfFamer)
            == .active(gameNumber: 5, difficulty: .hallOfFamer))
        #expect(RankedEntryState.resolve(state: .authenticated(Self.profile), hasTeam: true, nextGameNumber: 12, difficulty: .allPro)
            == .active(gameNumber: 12, difficulty: .allPro))
    }

    @Test func completedSeasonOffersAStart() {
        // A finished ranked run has no next game — the entry falls back to
        // START RANKED SEASON.
        #expect(RankedEntryState.resolve(state: .authenticated(Self.profile), hasTeam: true, nextGameNumber: nil, difficulty: .pro) == .readyToStart)
        #expect(RankedEntryState.resolve(state: .authenticated(Self.profile), hasTeam: true, nextGameNumber: nil, difficulty: nil) == .readyToStart)
    }

    @Test func progressCountsOnlyPlayedGames() {
        // "Game X" is the NEXT playable game: the first game without a
        // result. A prefetched (unplayed) assignment never advances it.
        #expect(RankedEntryState.progressLabel(1) == "GAME 1 OF 12")
        #expect(RankedEntryState.completedGames(1) == 0)
        #expect(RankedEntryState.progressLabel(10) == "GAME 10 OF 12")
        #expect(RankedEntryState.completedGames(10) == 9)
        #expect(RankedEntryState.progressLabel(11) == "SEMIFINAL · GAME 11 OF 12")
        #expect(RankedEntryState.completedGames(11) == 10)
        #expect(RankedEntryState.progressLabel(12) == "CHAMPIONSHIP · GAME 12 OF 12")
        #expect(RankedEntryState.completedGames(12) == 11)
    }

    @MainActor
    @Test func snapshotTracksConsumedGamesOnly() {
        // Production evidence shape: server season at pro, games 1–4 issued,
        // only game 1 consumed — the display must say PRO and GAME 2 OF 12.
        let owner = P14BHarnessIDs.owner
        let season = P14BServer.season
        var store = RankedAssignmentStore()
        for game in 1...4 {
            store.upsert(P14BServer.wire(season: season, game: game, difficulty: "pro").assignment(owner: owner)!)
        }
        // Prefetching alone never advances progress…
        #expect(store.snapshot?.difficulty == "pro")
        #expect(store.snapshot?.consumedGameNumber == 0)
        // …only consuming game 1 does.
        store.consume(matchID: store.assignments.first { $0.gameNumber == 1 }!.matchID)
        #expect(store.snapshot?.consumedGameNumber == 1)
        // A new server season replaces the snapshot wholesale.
        store.upsert(P14BServer.wire(season: UUID(), game: 1, difficulty: "hall_of_famer").assignment(owner: owner)!)
        #expect(store.snapshot?.consumedGameNumber == 0)
    }

    @MainActor
    @Test func rankedScreenReadsServerStateNotTheLocalSeason() async {
        let h = AssignmentHarness(context: RankedSeasonContext(seasonNumber: 1, rankedSeasonID: nil, nextGameNumber: 1, difficulty: .pro))
        await h.service.refresh()
        // Three games prefetched, none consumed → next playable is game 1.
        #expect(h.service.store.assignments.count == 3)
        #expect(h.service.rankedDisplayState?.difficulty == .pro)
        #expect(h.service.rankedDisplayState?.nextGameNumber == 1)
        // Only game 1 consumed → the screen shows GAME 2 OF 12 at PRO,
        // even though games 2–3 stay prefetched.
        let gameOne = h.service.store.assignments.first { $0.gameNumber == 1 }!
        h.service.consume(matchID: gameOne.matchID)
        #expect(h.service.rankedDisplayState?.nextGameNumber == 2)
        #expect(h.service.rankedDisplayState?.difficulty == .pro)
    }

    @MainActor
    @Test func staleLegacyStoreMigratesToServerTruth() throws {
        // Production shape: a pre-snapshot build persisted assignments 2–4
        // (game 1 consumed and removed) with no season snapshot. On load it
        // must migrate to PRO / GAME 2 — never fall back to the stale local
        // season (HALL OF FAMER / GAME 7).
        let owner = P14BHarnessIDs.owner
        let season = P14BServer.season
        var legacy = RankedAssignmentStore()
        for game in 2...4 {
            legacy.upsert(P14BServer.wire(season: season, game: game, difficulty: "pro").assignment(owner: owner)!)
        }
        // Strip the snapshot to reproduce the legacy on-disk shape.
        var raw = try JSONSerialization.jsonObject(with: CompetitiveResultPayload.encoder().encode(legacy)) as! [String: Any]
        raw.removeValue(forKey: "snapshot")
        let defaults = Self.defaults()
        defaults.set(try JSONSerialization.data(withJSONObject: raw), forKey: RankedAssignmentStore.key)

        let migrated = RankedAssignmentStore.load(defaults: defaults)
        #expect(migrated.snapshot?.seasonID == season)
        #expect(migrated.snapshot?.difficulty == "pro")
        #expect(migrated.snapshot?.consumedGameNumber == 1)   // game 1 consumed
        let service = RankedAssignmentService(
            defaults: defaults, fetcher: nil,
            currentUserID: { owner },
            seasonContext: { nil }, adoptSeasonID: { _, _ in }
        )
        #expect(service.rankedDisplayState?.difficulty == .pro)
        #expect(service.rankedDisplayState?.nextGameNumber == 2)
    }

    @MainActor
    @Test func serverAlreadyRecordedAnswerWins() async {
        // The server says game 2 is already recorded — its consumption truth
        // advances the displayed progress (server state beats local).
        let fetcher = MockAssignmentFetcher()
        fetcher.script(2, .rejected(reason: "game_already_recorded"))
        let h = AssignmentHarness(context: RankedSeasonContext(seasonNumber: 1, rankedSeasonID: P14BServer.season, nextGameNumber: 2, difficulty: .pro), fetcher: fetcher)
        await h.service.refresh()
        #expect(h.service.rankedDisplayState?.difficulty == .pro)
        #expect(h.service.rankedDisplayState?.nextGameNumber == 3)
    }

    @MainActor
    @Test func refreshKeepsServerTruthAssignmentsWhenLocalRunsAhead() {
        // Local season says next is 7 while the server season is only at
        // game 2 — a refresh must NOT destroy the server's assignments 2–4
        // (the stale-local prune floor never goes past the server's next).
        let owner = P14BHarnessIDs.owner
        var store = RankedAssignmentStore()
        for game in 2...4 {
            store.upsert(P14BServer.wire(season: P14BServer.season, game: game, difficulty: "pro").assignment(owner: owner)!)
        }
        store.consume(matchID: store.assignments.first { $0.gameNumber == 2 }!.matchID)
        // prune at the local (stale) game number would keep nothing.
        store.prune(owner: owner, seasonID: P14BServer.season, minGameNumber: 1, now: Self.now)
        #expect(store.assignments.map(\.gameNumber) == [3, 4])
        #expect(store.snapshot?.consumedGameNumber == 2)
    }
}

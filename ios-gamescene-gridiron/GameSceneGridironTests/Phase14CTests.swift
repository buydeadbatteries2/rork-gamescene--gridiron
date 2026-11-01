import Foundation
import Testing

@testable import GameSceneGridiron

/// Phase 14C — the RANKED entry is UI only: it reuses the 14B services and
/// never changes ranked logic. These tests pin the entry-state resolution the
/// Home tile and the Ranked screen both share.
@Suite("Phase 14C — ranked entry")
struct Phase14CTests {

    private static let profile = UserProfile(authUserID: UUID(), username: "GridironKing", firstName: "Julius", lastName: "Hudson")

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
}

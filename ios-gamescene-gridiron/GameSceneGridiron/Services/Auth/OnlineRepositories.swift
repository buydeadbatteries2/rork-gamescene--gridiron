import Foundation

// MARK: - Online repository protocols
//
// The abstractions every future online screen depends on. SwiftUI and view
// models NEVER talk to Supabase directly — conformances live in the service
// layer. No competition features are implemented yet; these protocols define
// the seams now so the screens can be built against mocks/tests first.

// MARK: Profile

/// Creates/reads the GameScene profile record. `ensureProfile` must be
/// idempotent (keyed by the Supabase Auth UUID) so a failed signup step can be
/// retried without ever creating a duplicate account or profile. Conformances
/// read the signed-in user's private row from `public.profiles`; other users'
/// profiles are only ever read through the `public.public_profiles` view.
protocol ProfileRepository: Sendable {
    func fetchProfile(userID: UUID) async throws -> UserProfile?
    func ensureProfile(_ profile: UserProfile) async throws
}

// MARK: Leaderboards (future)
//
// Reads other players through `public.public_profiles` — the safe public
// surface (username, football display name, competitive stats only). Never
// the private `public.profiles` table.

nonisolated struct LeaderboardEntry: Sendable, Equatable {
    let authUserID: UUID
    let username: String
    let footballDisplayName: String
    let rating: Int
}

protocol LeaderboardRepository: Sendable {
    func topPlayers(limit: Int) async throws -> [LeaderboardEntry]
    func rating(for userID: UUID) async throws -> Int?
}

// MARK: Competitive seasons (future)

protocol CompetitiveSeasonRepository: Sendable {
    func currentSeason() async throws -> CompetitiveSeason?
    func join(seasonID: UUID) async throws
    func assignments(seasonID: UUID, for userID: UUID) async throws -> [CompetitiveGameAssignment]
    /// Submits a server-authoritative result for a server-assigned case.
    func submit(result: CompetitiveGameResult) async throws
}

// MARK: Factions (future)
//
// Member lists join `public.public_profiles` for identity display; private
// profile data (real names) is never read for other users.

protocol FactionRepository: Sendable {
    func factions() async throws -> [Faction]
    func create(name: String) async throws -> Faction
    func join(factionID: UUID) async throws
    func members(of factionID: UUID) async throws -> [FactionMember]
    /// Claim one lineup seat for the running faction season.
    func claimRosterSlot(_ slot: FactionSeasonRosterSlot) async throws
}

// MARK: Faction battles (future)

protocol FactionBattleRepository: Sendable {
    func battles(seasonID: UUID) async throws -> [FactionBattle]
    func roster(battleID: UUID, factionID: UUID) async throws -> FactionBattleRoster
    func submitRoster(_ roster: FactionBattleRoster) async throws
    func dailyProgress(factionID: UUID, day: Date) async throws -> [FactionDailyProgress]
}

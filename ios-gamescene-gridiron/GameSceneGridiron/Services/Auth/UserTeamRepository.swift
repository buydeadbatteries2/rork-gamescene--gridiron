import Foundation
import Supabase

@MainActor
protocol UserTeamRepository {
    func fetch(userID: UUID) async throws -> GameTeam?
    /// Insert-only: a concurrent/existing account team always wins.
    func createIfAbsent(userID: UUID, team: GameTeam) async throws -> GameTeam
    func update(userID: UUID, team: GameTeam) async throws
}

@MainActor
struct SupabaseUserTeamRepository: UserTeamRepository {
    let client: SupabaseClient
    nonisolated struct Row: Codable, Sendable {
        let user_id: UUID
        let team_id: UUID
        let state: String
        let team_name: String
        let logo_id: String
        let primary_color: UInt32
        let secondary_color: UInt32
        init(userID: UUID, team: GameTeam) {
            user_id = userID; team_id = team.id; state = team.state
            team_name = team.teamName; logo_id = team.logoID
            primary_color = team.primaryColorHex; secondary_color = team.secondaryColorHex
        }
        var team: GameTeam {
            GameTeam(id: team_id, state: state, teamName: team_name, logoID: logo_id,
                     primaryColorHex: primary_color, secondaryColorHex: secondary_color, isUserTeam: true)
        }
    }
    func fetch(userID: UUID) async throws -> GameTeam? {
        let rows: [Row] = try await client.from("user_teams").select().eq("user_id", value: userID.uuidString).limit(1).execute().value
        return rows.first?.team
    }
    func createIfAbsent(userID: UUID, team: GameTeam) async throws -> GameTeam {
        try await client.from("user_teams").upsert(Row(userID: userID, team: team), onConflict: "user_id", ignoreDuplicates: true).execute()
        guard let saved = try await fetch(userID: userID) else { throw URLError(.badServerResponse) }
        return saved
    }
    nonisolated struct EditableFields: Encodable, Sendable {
        let state: String
        let team_name: String
        let logo_id: String
        let primary_color: UInt32
        let secondary_color: UInt32
        init(_ team: GameTeam) {
            state = team.state; team_name = team.teamName; logo_id = team.logoID
            primary_color = team.primaryColorHex; secondary_color = team.secondaryColorHex
        }
    }
    func update(userID: UUID, team: GameTeam) async throws {
        // Never update another identity, even if the account's team changed remotely.
        let rows: [Row] = try await client.from("user_teams").update(EditableFields(team))
            .eq("user_id", value: userID.uuidString).eq("team_id", value: team.id.uuidString).select().execute().value
        guard rows.count == 1 else { throw URLError(.badServerResponse) }
    }
}

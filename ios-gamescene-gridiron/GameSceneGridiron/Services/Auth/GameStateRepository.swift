import Foundation
import Supabase

@MainActor protocol GameStateRepository {
    func fetch(userID: UUID) async throws -> CloudGameState?
    func createIfAbsent(userID: UUID, snapshot: GameStateSnapshot) async throws -> CloudGameState
    func update(userID: UUID, snapshot: GameStateSnapshot, revision: Int) async throws -> CloudGameState
}

@MainActor struct SupabaseGameStateRepository: GameStateRepository {
    let client: SupabaseClient
    nonisolated struct Insert: Encodable, Sendable {
        let user_id: UUID
        let team_id: UUID
        let schema_version = 1
        let snapshot: GameStateSnapshot
    }
    nonisolated struct Update: Encodable, Sendable {
        let snapshot: GameStateSnapshot
        let schema_version = 1
    }
    func fetch(userID: UUID) async throws -> CloudGameState? {
        let rows: [CloudGameState] = try await client.from("user_game_state").select()
            .eq("user_id", value: userID.uuidString).limit(1).execute().value
        return rows.first
    }
    func createIfAbsent(userID: UUID, snapshot: GameStateSnapshot) async throws -> CloudGameState {
        try await client.from("user_game_state").upsert(Insert(user_id: userID, team_id: snapshot.teamID, snapshot: snapshot), onConflict: "user_id", ignoreDuplicates: true).execute()
        guard let row = try await fetch(userID: userID) else { throw GameStateError.unavailable }
        return row
    }
    func update(userID: UUID, snapshot: GameStateSnapshot, revision: Int) async throws -> CloudGameState {
        let rows: [CloudGameState] = try await client.from("user_game_state").update(Update(snapshot: snapshot))
            .eq("user_id", value: userID.uuidString).eq("team_id", value: snapshot.teamID.uuidString)
            .eq("revision", value: revision).select().execute().value
        guard let row = rows.first else { throw GameStateError.conflict }
        return row
    }
}

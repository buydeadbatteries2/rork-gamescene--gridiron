import Foundation
import Testing
@testable import GameSceneGridiron

@MainActor
struct TeamSyncDiagnosticTests {
    @Test func classifiesLiveSchemaError() {
        #expect(TeamSyncDiagnostic.databaseCode("PGRST205") == "table/schema cache: PGRST205")
        #expect(TeamSyncDiagnostic.databaseCode("42501").contains("permission"))
        #expect(TeamSyncDiagnostic.databaseCode("PGRST301").contains("JWT"))
        #expect(TeamSyncDiagnostic.databaseCode("42703").contains("column/type"))
    }
    @Test func excludesSensitiveErrorDetails() {
        let error = NSError(domain: "private@example.com", code: 1, userInfo: [NSLocalizedDescriptionKey: "Bearer secret-token"])
        #expect(TeamSyncDiagnostic.describe(error) == "other: unclassified error (details redacted)")
        #expect(TeamSyncDiagnostic.databaseCode("private@example.com") == "other database error: unknown code")
        #expect(TeamSyncDiagnostic.describe(URLError(.notConnectedToInternet)) == "network: URL error -1009")
    }
    @Test func decodesPostgresNumericColorsAndEmptyRows() throws {
        let json = """
        [{"user_id":"00000000-0000-0000-0000-000000000001","team_id":"00000000-0000-0000-0000-000000000002","state":"Virginia","team_name":"Wolves","logo_id":"wolf","primary_color":1122867,"secondary_color":16777215}]
        """
        let rows = try JSONDecoder().decode([SupabaseUserTeamRepository.Row].self, from: Data(json.utf8))
        #expect(rows.first?.primary_color == 0x112233)
        #expect(rows.first?.secondary_color == 0xFFFFFF)
        #expect(try JSONDecoder().decode([SupabaseUserTeamRepository.Row].self, from: Data("[]".utf8)).isEmpty)
    }
    @Test func decodingFailureIsDistinctFromDatabaseFailure() {
        do {
            _ = try JSONDecoder().decode([SupabaseUserTeamRepository.Row].self, from: Data("[{}]".utf8))
            Issue.record("Expected missing-field decoding failure")
        } catch {
            #expect(TeamSyncDiagnostic.describe(error) == "decoding: PostgREST JSON does not match Row")
        }
    }
}

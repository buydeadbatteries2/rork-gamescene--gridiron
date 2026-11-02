import Foundation
import Supabase

// MARK: - Phase 15A — Versus backend interface (no UI)
//
// Thin client over the server-authoritative Versus backend:
//   * find-versus-match   (Edge Function) — body = difficulty ONLY,
//   * submit-versus-result (Edge Function) — raw per-case facts only,
//   * my_versus_matches / my_versus_history / versus_public_record
//     (authenticated SECURITY DEFINER RPCs; user = auth.uid()).
// The client never names an opponent, a match to join, a case or a score.
// Classification follows the competitive submitter: 401/408/429/5xx are
// retryable, any other 4xx is a final rejection.

protocol VersusBackend: Sendable {
    func findMatch(difficulty: String) async -> VersusFindResult
    func submit(_ payload: VersusResultPayload) async -> VersusSubmitResult
    func myOpenMatches() async throws -> [VersusMatch]
    func myHistory(limit: Int, offset: Int) async throws -> [VersusHistoryEntry]
    func publicRecord(userID: UUID) async throws -> VersusCareerRecord?
}

enum VersusWire {
    struct FindBody: Encodable, Sendable {
        let difficulty: String
    }

    struct FindResponse: Decodable, Sendable {
        let status: String
        let match: VersusMatch?
    }

    struct RejectedBody: Decodable, Sendable {
        let reason: String?
    }

    /// Maps a decoded find-versus-match 200 body.
    static func findResult(from response: FindResponse) -> VersusFindResult {
        guard let match = response.match else { return .retryable(category: "unexpected_response") }
        switch response.status {
        case "matched": return .matched(match)
        case "waiting": return .waiting(match)
        default: return .retryable(category: "unexpected_response")
        }
    }

    static func findResult(statusCode: Int, reason: String?) -> VersusFindResult {
        switch SupabaseCompetitiveSubmitter.classify(statusCode: statusCode, reason: reason) {
        case .rejected(let reason): return .rejected(reason: reason)
        case .retryable(let category): return .retryable(category: category)
        case .verified: return .retryable(category: "unexpected_response")
        }
    }

    static func submitResult(statusCode: Int, reason: String?) -> VersusSubmitResult {
        if statusCode == 410, reason == "versus_match_expired" { return .expired }
        switch SupabaseCompetitiveSubmitter.classify(statusCode: statusCode, reason: reason) {
        case .rejected(let reason): return .rejected(reason: reason)
        case .retryable(let category): return .retryable(category: category)
        case .verified: return .retryable(category: "unexpected_response")
        }
    }

    static func submitResult(from receipt: VersusSubmitReceipt) -> VersusSubmitResult {
        receipt.status == "verified" ? .verified(receipt) : .retryable(category: "unexpected_response")
    }
}

struct SupabaseVersusBackend: VersusBackend {
    static let findFunction = "find-versus-match"
    static let submitFunction = "submit-versus-result"
    static let historyPageLimit = 50
    let client: SupabaseClient

    private struct HistoryParams: Encodable, Sendable {
        let p_limit: Int
        let p_offset: Int
    }

    private struct RecordParams: Encodable, Sendable {
        let p_user_id: UUID
    }

    func findMatch(difficulty: String) async -> VersusFindResult {
        guard let body = try? JSONEncoder().encode(VersusWire.FindBody(difficulty: difficulty)) else {
            return .rejected(reason: "encoding_failed")
        }
        do {
            let response: VersusWire.FindResponse = try await client.functions.invoke(
                Self.findFunction,
                options: FunctionInvokeOptions(headers: ["Content-Type": "application/json"], body: body)
            )
            return VersusWire.findResult(from: response)
        } catch let FunctionsError.httpError(code, data) {
            let reason = (try? JSONDecoder().decode(VersusWire.RejectedBody.self, from: data))?.reason
            return VersusWire.findResult(statusCode: code, reason: reason)
        } catch {
            return .retryable(category: "network")
        }
    }

    func submit(_ payload: VersusResultPayload) async -> VersusSubmitResult {
        guard let body = try? JSONEncoder().encode(payload) else { return .rejected(reason: "encoding_failed") }
        do {
            let receipt: VersusSubmitReceipt = try await client.functions.invoke(
                Self.submitFunction,
                options: FunctionInvokeOptions(headers: ["Content-Type": "application/json"], body: body)
            )
            return VersusWire.submitResult(from: receipt)
        } catch let FunctionsError.httpError(code, data) {
            let reason = (try? JSONDecoder().decode(VersusWire.RejectedBody.self, from: data))?.reason
            return VersusWire.submitResult(statusCode: code, reason: reason)
        } catch {
            return .retryable(category: "network")
        }
    }

    func myOpenMatches() async throws -> [VersusMatch] {
        let response = try await client.rpc("my_versus_matches").execute()
        return try JSONDecoder().decode([VersusMatch].self, from: response.data)
    }

    func myHistory(limit: Int, offset: Int) async throws -> [VersusHistoryEntry] {
        let response = try await client.rpc("my_versus_history", params: HistoryParams(
            p_limit: min(max(limit, 1), Self.historyPageLimit),
            p_offset: max(offset, 0)
        )).execute()
        return try JSONDecoder().decode([VersusHistoryEntry].self, from: response.data)
    }

    func publicRecord(userID: UUID) async throws -> VersusCareerRecord? {
        let response = try await client.rpc("versus_public_record", params: RecordParams(p_user_id: userID)).execute()
        return try JSONDecoder().decode([VersusCareerRecord].self, from: response.data).first
    }
}

/// App-facing entry point (no UI yet). Adds local pre-flight checks on top of
/// the backend; every decision still belongs to the server.
@MainActor
final class VersusService {
    private let backend: any VersusBackend
    private let gameVersion: String
    private let now: () -> Date

    init(backend: any VersusBackend, gameVersion: String, now: @escaping () -> Date = Date.init) {
        self.backend = backend
        self.gameVersion = gameVersion
        self.now = now
    }

    func findMatch(difficulty: DifficultyLevel) async -> VersusFindResult {
        await backend.findMatch(difficulty: difficulty.serverValue)
    }

    func submit(match: VersusMatch, startedAt: Date, caseResults: [CompetitiveCaseResult]) async -> VersusSubmitResult {
        guard match.playerState.needsMyPlay || match.playerState == .opponentPending || match.playerState == .submitted else {
            return .rejected(reason: "versus_match_closed")
        }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let completed = max(now(), startedAt.addingTimeInterval(0.001))
        let payload = VersusResultPayload(
            matchID: match.matchID,
            startedAt: formatter.string(from: startedAt),
            completedAt: formatter.string(from: completed),
            caseResults: caseResults,
            gameVersion: gameVersion,
            versusProtocol: VersusRules.protocolVersion
        )
        if let reason = payload.localRejection(for: match) { return .rejected(reason: reason) }
        return await backend.submit(payload)
    }

    func openMatches() async throws -> [VersusMatch] { try await backend.myOpenMatches() }
    func history(limit: Int = 20, offset: Int = 0) async throws -> [VersusHistoryEntry] {
        try await backend.myHistory(limit: limit, offset: offset)
    }
    func record(for userID: UUID) async throws -> VersusCareerRecord? { try await backend.publicRecord(userID: userID) }
}

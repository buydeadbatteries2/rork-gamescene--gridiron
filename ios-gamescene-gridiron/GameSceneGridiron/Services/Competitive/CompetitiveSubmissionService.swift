import Foundation
import Observation
import Supabase

// MARK: - Submitter seam

/// Sends one payload to the `submit-ranked-result` Edge Function. The JWT
/// comes from the signed-in Supabase session; the iOS app never holds a
/// service-role key. 426 (client_outdated) / 410 (assignment_expired) are
/// final rejections like every other non-transient 4xx.
protocol CompetitiveResultSubmitting: Sendable {
    func submit(_ payload: CompetitiveResultPayload) async -> CompetitiveSubmitResponse
}

struct SupabaseCompetitiveSubmitter: CompetitiveResultSubmitting {
    static let functionName = "submit-ranked-result"
    let client: SupabaseClient

    private struct VerifiedBody: Decodable {
        let status: String
        let finalScore: Int?
        let duplicate: Bool?
        enum CodingKeys: String, CodingKey {
            case status
            case finalScore = "final_score"
            case duplicate
        }
    }

    private struct RejectedBody: Decodable {
        let status: String?
        let reason: String?
    }

    func submit(_ payload: CompetitiveResultPayload) async -> CompetitiveSubmitResponse {
        guard let body = try? CompetitiveResultPayload.encoder().encode(payload) else {
            return .rejected(reason: "encoding_failed")
        }
        do {
            let result: VerifiedBody = try await client.functions.invoke(
                Self.functionName,
                options: FunctionInvokeOptions(headers: ["Content-Type": "application/json"], body: body)
            )
            guard result.status == "verified", let score = result.finalScore else {
                return .retryable(category: "unexpected_response")
            }
            return .verified(finalScore: score, duplicate: result.duplicate ?? false)
        } catch let FunctionsError.httpError(code, data) {
            let reason = (try? JSONDecoder().decode(RejectedBody.self, from: data))?.reason
            return Self.classify(statusCode: code, reason: reason)
        } catch {
            return .retryable(category: "network")
        }
    }

    /// 401/408/429/5xx are transient; every other 4xx is a final rejection.
    static func classify(statusCode: Int, reason: String?) -> CompetitiveSubmitResponse {
        switch statusCode {
        case 401: return .retryable(category: "unauthorized")
        case 408: return .retryable(category: "timeout")
        case 429: return .retryable(category: "rate_limited")
        case 500...: return .retryable(category: "server_\(statusCode)")
        case 400..<500: return .rejected(reason: reason ?? "rejected_\(statusCode)")
        default: return .retryable(category: "http_\(statusCode)")
        }
    }
}

// MARK: - Service

/// Owns the durable queue and flushes it for the signed-in account. Flushes
/// run on enqueue, when the app becomes active, and right after sign-in.
@MainActor
@Observable
final class CompetitiveSubmissionService {
    static let shared = CompetitiveSubmissionService()

    private(set) var queue: CompetitiveSubmissionQueue
    private(set) var isFlushing = false
    /// DEBUG-only diagnostic: why the most recent finished game was not ranked.
    private(set) var lastIneligibleReason: CompetitiveIneligibility?

    private let defaults: UserDefaults
    private let submitter: (any CompetitiveResultSubmitting)?
    private let currentUserID: @MainActor () -> UUID?
    private let now: () -> Date
    /// Server verified a match — ranked progress may advance (phase 14C:
    /// wires the submission flush to the ranked assignment store).
    private let onVerified: @MainActor (UUID) -> Void

    var isRepositoryConnected: Bool { submitter != nil }

    /// Production instance.
    convenience init() {
        let provider = SupabaseClientProvider.shared
        let submitter: (any CompetitiveResultSubmitting)? = provider.isConfigured
            ? provider.supabase.map { SupabaseCompetitiveSubmitter(client: $0) }
            : nil
        self.init(
            defaults: .standard,
            submitter: submitter,
            currentUserID: {
                if case .authenticated(let profile) = AuthService.shared.state { return profile.authUserID }
                return nil
            },
            onVerified: { RankedAssignmentService.shared.markVerified(matchID: $0) }
        )
    }

    /// Injectable instance (tests).
    init(
        defaults: UserDefaults,
        submitter: (any CompetitiveResultSubmitting)?,
        currentUserID: @escaping @MainActor () -> UUID?,
        now: @escaping () -> Date = Date.init,
        onVerified: @escaping @MainActor (UUID) -> Void = { _ in }
    ) {
        self.defaults = defaults
        self.submitter = submitter
        self.currentUserID = currentUserID
        self.now = now
        self.onVerified = onVerified
        var loaded = CompetitiveSubmissionStore.load(defaults: defaults)
        loaded.recoverInterruptedAttempts()
        queue = loaded
        CompetitiveSubmissionStore.save(loaded, defaults: defaults)
    }

    /// Entry point from a finished game. Ineligible games are only noted
    /// (DEBUG diagnostics) — the local result is never affected.
    /// `owner` is the signed-in account that played the game (the payload
    /// itself carries no user id — the server uses the JWT).
    func handle(_ outcome: CompetitivePayloadBuilder.Outcome, owner: UUID?) {
        switch outcome {
        case .ineligible(let reason):
            lastIneligibleReason = reason
        case .eligible(let payload):
            guard let owner else {
                lastIneligibleReason = .guestPlayer
                return
            }
            lastIneligibleReason = nil
            enqueue(payload, owner: owner)
            Task { await flush() }
        }
    }

    /// Durably records the game (no-op for an already-queued match ID).
    func enqueue(_ payload: CompetitiveResultPayload, owner: UUID) {
        guard queue.enqueue(payload, owner: owner, now: now()) else { return }
        persist()
    }

    /// Submits every due item owned by the signed-in account, one at a time.
    func flush() async {
        guard !isFlushing, let submitter, let owner = currentUserID() else { return }
        isFlushing = true
        defer { isFlushing = false }
        for item in queue.dueItems(for: owner, now: now()) {
            queue.markSubmitting(item.id)
            persist()
            let response = await submitter.submit(item.payload)
            queue.apply(response, to: item.id, now: now())
            persist()
            if case .verified = response {
                LeaderboardCache.shared.invalidate()
                onVerified(item.payload.matchID)
            }
            // Offline / throttled: stop this pass; backoff schedules the next.
            if case .retryable = response { break }
        }
    }

    private func persist() {
        CompetitiveSubmissionStore.save(queue, defaults: defaults)
    }
}

import Foundation

// MARK: - Phase 14 — durable ranked-submission queue
//
// Every eligible finished season game becomes ONE queue item keyed by its
// competitive match ID. The item survives backgrounding, termination and
// relaunch; retries always resend the same match ID (the server is
// idempotent on it), so a game can never be counted twice. A server
// rejection is final and never retried — and never touches the local
// season outcome.

nonisolated enum CompetitiveSubmissionState: String, Codable, Hashable, Sendable {
    case pending
    case submitting
    case verified
    case rejected

    var isFinished: Bool { self == .verified || self == .rejected }
}

nonisolated struct PendingCompetitiveSubmission: Codable, Hashable, Sendable, Identifiable {
    let payload: CompetitiveResultPayload
    /// The account that played the game — only that account may submit it.
    let ownerUserID: UUID
    var state: CompetitiveSubmissionState
    var attempts: Int
    var nextAttemptAt: Date
    /// DEBUG-safe category only (e.g. "network", "case_version_mismatch").
    var lastErrorCategory: String?
    /// Server-computed score once verified (display only).
    var finalScore: Int?
    let enqueuedAt: Date
    var resolvedAt: Date?

    var id: UUID { payload.matchID }
}

/// The server's answer to one submission attempt.
nonisolated enum CompetitiveSubmitResponse: Equatable, Sendable {
    /// Recorded (or already recorded — duplicate match ID).
    case verified(finalScore: Int, duplicate: Bool)
    /// Permanently invalid — never retried.
    case rejected(reason: String)
    /// Offline / 401 / 429 / 5xx — retried with bounded backoff.
    case retryable(category: String)
}

/// Pure queue logic — no I/O, fully testable.
nonisolated struct CompetitiveSubmissionQueue: Codable, Hashable, Sendable {
    private(set) var items: [PendingCompetitiveSubmission] = []

    static let baseBackoff: TimeInterval = 30
    static let maxBackoff: TimeInterval = 6 * 60 * 60
    static let finishedHistoryLimit = 20

    /// min(30s · 2^attempts, 6h).
    static func backoff(afterAttempts attempts: Int) -> TimeInterval {
        let exponent = Double(min(max(attempts, 0), 20))
        return min(baseBackoff * pow(2, exponent), maxBackoff)
    }

    var pendingCount: Int { items.filter { !$0.state.isFinished }.count }
    var lastFinished: PendingCompetitiveSubmission? {
        items.filter(\.state.isFinished).max { ($0.resolvedAt ?? .distantPast) < ($1.resolvedAt ?? .distantPast) }
    }
    var latest: PendingCompetitiveSubmission? { items.max { $0.enqueuedAt < $1.enqueuedAt } }

    func item(matchID: UUID) -> PendingCompetitiveSubmission? { items.first { $0.id == matchID } }

    /// Adds a game exactly once. A second enqueue of the same match ID is a
    /// no-op (returns false) — never a duplicate submission.
    @discardableResult
    mutating func enqueue(_ payload: CompetitiveResultPayload, owner: UUID, now: Date) -> Bool {
        guard item(matchID: payload.matchID) == nil else { return false }
        items.append(PendingCompetitiveSubmission(
            payload: payload, ownerUserID: owner, state: .pending, attempts: 0,
            nextAttemptAt: now, lastErrorCategory: nil, finalScore: nil,
            enqueuedAt: now, resolvedAt: nil
        ))
        return true
    }

    /// After a relaunch an in-flight attempt is unknown: back to pending
    /// (resending the same match ID is safe — the server is idempotent).
    mutating func recoverInterruptedAttempts() {
        for index in items.indices where items[index].state == .submitting {
            items[index].state = .pending
        }
    }

    /// Items the given account may submit now, oldest first.
    func dueItems(for owner: UUID, now: Date) -> [PendingCompetitiveSubmission] {
        items
            .filter { $0.state == .pending && $0.ownerUserID == owner && $0.nextAttemptAt <= now }
            .sorted { $0.enqueuedAt < $1.enqueuedAt }
    }

    mutating func markSubmitting(_ matchID: UUID) {
        guard let index = items.firstIndex(where: { $0.id == matchID }),
              items[index].state == .pending else { return }
        items[index].state = .submitting
    }

    mutating func apply(_ response: CompetitiveSubmitResponse, to matchID: UUID, now: Date) {
        guard let index = items.firstIndex(where: { $0.id == matchID }),
              !items[index].state.isFinished else { return }
        switch response {
        case .verified(let score, _):
            items[index].state = .verified
            items[index].finalScore = score
            items[index].lastErrorCategory = nil
            items[index].resolvedAt = now
        case .rejected(let reason):
            items[index].state = .rejected
            items[index].lastErrorCategory = Self.safeCategory(reason)
            items[index].resolvedAt = now
        case .retryable(let category):
            items[index].attempts += 1
            items[index].state = .pending
            items[index].lastErrorCategory = Self.safeCategory(category)
            items[index].nextAttemptAt = now.addingTimeInterval(Self.backoff(afterAttempts: items[index].attempts - 1))
        }
        pruneFinished()
    }

    /// Keeps the most recent finished items only (pending ones are never dropped).
    mutating func pruneFinished() {
        let finished = items.filter(\.state.isFinished)
            .sorted { ($0.resolvedAt ?? .distantPast) > ($1.resolvedAt ?? .distantPast) }
        guard finished.count > Self.finishedHistoryLimit else { return }
        let drop = Set(finished.dropFirst(Self.finishedHistoryLimit).map(\.id))
        items.removeAll { drop.contains($0.id) }
    }

    /// Reduces any server/transport text to a short lowercase token so
    /// nothing private (tokens, payload fragments) is ever stored or shown.
    static func safeCategory(_ raw: String) -> String {
        let allowed = Set("abcdefghijklmnopqrstuvwxyz0123456789_")
        let token = String(raw.lowercased().map { allowed.contains($0) ? $0 : "_" }.prefix(48))
        return token.isEmpty ? "unknown" : token
    }
}

// MARK: Persistence

nonisolated enum CompetitiveSubmissionStore {
    static let key = "gamescene.gridiron.competitiveQueue"

    static func load(defaults: UserDefaults = .standard) -> CompetitiveSubmissionQueue {
        guard let data = defaults.data(forKey: key),
              let queue = try? CompetitiveResultPayload.decoder().decode(CompetitiveSubmissionQueue.self, from: data) else {
            return CompetitiveSubmissionQueue()
        }
        return queue
    }

    static func save(_ queue: CompetitiveSubmissionQueue, defaults: UserDefaults = .standard) {
        guard let data = try? CompetitiveResultPayload.encoder().encode(queue) else { return }
        defaults.set(data, forKey: key)
    }
}

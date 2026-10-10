import Foundation
import Observation

// MARK: - Local balance telemetry
//
// Phase 9 development metrics: wrong placements, hints used and quarter
// failures per case, plus the difficulty in play. This is a LOCAL debugging
// aid for game-balance review — nothing is ever uploaded, and it never
// influences gameplay, rewards or progression.

@MainActor
@Observable
final class BalanceTelemetry {
    static let shared = BalanceTelemetry()

    static let storageKey = "dev.balanceTelemetry"

    struct CaseRecord: Codable, Hashable, Sendable {
        var wrongPlacements = 0
        var hintsUsed = 0
        var quarterFailures = 0
    }

    struct Snapshot: Codable, Sendable, Equatable {
        var cases: [String: CaseRecord] = [:]
        /// caseID → difficulty level title the case was played at.
        var difficulty: [String: String] = [:]
    }

    private let defaults: UserDefaults
    private(set) var snapshot: Snapshot

    /// Test-injectable: pass an isolated defaults suite for hermetic tests.
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode(Snapshot.self, from: data) {
            snapshot = decoded
        } else {
            snapshot = Snapshot()
        }
    }

    func recordWrongPlacement(caseID: String) {
        snapshot.cases[caseID, default: CaseRecord()].wrongPlacements += 1
        persist()
    }

    func recordHintUsed(caseID: String) {
        snapshot.cases[caseID, default: CaseRecord()].hintsUsed += 1
        persist()
    }

    func recordQuarterFailure(caseID: String, difficulty: String) {
        var record = snapshot.cases[caseID] ?? CaseRecord()
        record.quarterFailures += 1
        snapshot.cases[caseID] = record
        snapshot.difficulty[caseID] = difficulty
        persist()
    }

    /// Dev-menu action: wipes the local metrics (never user progress).
    func clear() {
        snapshot = Snapshot()
        defaults.removeObject(forKey: Self.storageKey)
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(snapshot) {
            defaults.set(data, forKey: Self.storageKey)
        }
    }
}

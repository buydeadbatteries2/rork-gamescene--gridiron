import Foundation

/// Outcome of one quarter within the larger game. Losing a quarter never ends the match.
nonisolated enum QuarterOutcome: String, Hashable, Sendable {
    case solved
    case failed

    var symbol: String {
        switch self {
        case .solved: "checkmark"
        case .failed: "xmark"
        }
    }
}

/// Everything the match remembers about one finished quarter (including overtime).
nonisolated struct QuarterRecord: Hashable, Sendable, Identifiable {
    /// 0-based index; 4 = overtime.
    let id: Int
    let label: String
    let isOvertime: Bool
    let outcome: QuarterOutcome
    let correctPlacements: Int
    let wrongPlacements: Int
    let livesLost: Int
    let hintsUsed: Int
}

/// Final verdict of the whole game, decided by solved investigation situations —
/// never by simulated football points.
nonisolated enum MatchResult: Hashable, Sendable {
    case victory
    case victoryOT
    case defeat
    case defeatOT

    var heading: String {
        switch self {
        case .victory: "CASE CLOSED — VICTORY"
        case .victoryOT: "CASE CLOSED — OT VICTORY"
        case .defeat: "CASE UNSOLVED — DEFEAT"
        case .defeatOT: "CASE UNSOLVED — OT DEFEAT"
        }
    }

    var isWin: Bool {
        switch self {
        case .victory, .victoryOT: true
        case .defeat, .defeatOT: false
        }
    }
}

/// Match-level state for one full game: quarter results, running statistics and
/// the final verdict. Individual puzzle state stays inside `GameViewModel`.
nonisolated struct GameMatch: Hashable, Sendable {
    static let regulationQuarters = 4
    /// Quarters the player must solve to win in regulation.
    static let quartersToWin = 3

    private(set) var quarterRecords: [QuarterRecord] = []
    private(set) var overtimeRecord: QuarterRecord?
    private(set) var totalCorrectPlacements = 0
    private(set) var totalWrongPlacements = 0
    private(set) var totalLivesLost = 0
    private(set) var totalHintsUsed = 0

    /// Index of the quarter about to be played: 0...3 in regulation, 4 in overtime.
    var currentQuarterIndex: Int { quarterRecords.count }

    var isOvertime: Bool { currentQuarterIndex >= Self.regulationQuarters }

    /// True once regulation ends 2–2 and the fifth puzzle is required.
    var needsOvertime: Bool {
        quarterRecords.count == Self.regulationQuarters && quartersSolved == 2
    }

    var quartersSolved: Int {
        quarterRecords.filter { $0.outcome == .solved }.count
    }

    var quartersFailed: Int {
        quarterRecords.filter { $0.outcome == .failed }.count
    }

    var isComplete: Bool {
        if quarterRecords.count < Self.regulationQuarters { return false }
        if needsOvertime { return overtimeRecord != nil }
        return true
    }

    var result: MatchResult? {
        guard isComplete else { return nil }
        if overtimeRecord != nil {
            return overtimeRecord?.outcome == .solved ? .victoryOT : .defeatOT
        }
        return quartersSolved >= Self.quartersToWin ? .victory : .defeat
    }

    /// Score line for the result screen, e.g. "3–1" or "3–2 OT".
    var scoreLine: String? {
        guard isComplete else { return nil }
        let otSolved = overtimeRecord?.outcome == .solved
        let solved = quartersSolved + (otSolved ? 1 : 0)
        let failed = quartersFailed + (overtimeRecord != nil && !otSolved ? 1 : 0)
        return overtimeRecord == nil ? "\(solved)–\(failed)" : "\(solved)–\(failed) OT"
    }

    var currentLabel: String {
        isOvertime ? "OT" : "Q\(currentQuarterIndex + 1)"
    }

    // MARK: Mutations

    /// Records a finished quarter and any overtime equivalent, accumulating stats.
    mutating func recordQuarter(
        index: Int,
        label: String,
        isOvertime: Bool,
        outcome: QuarterOutcome,
        correctPlacements: Int,
        wrongPlacements: Int,
        livesLost: Int,
        hintsUsed: Int
    ) {
        let record = QuarterRecord(
            id: index,
            label: label,
            isOvertime: isOvertime,
            outcome: outcome,
            correctPlacements: correctPlacements,
            wrongPlacements: wrongPlacements,
            livesLost: livesLost,
            hintsUsed: hintsUsed
        )
        if isOvertime {
            overtimeRecord = record
        } else {
            quarterRecords.append(record)
        }
        totalCorrectPlacements += correctPlacements
        totalWrongPlacements += wrongPlacements
        totalLivesLost += livesLost
        totalHintsUsed += hintsUsed
    }

    /// Fresh state for a new game.
    static func fresh() -> GameMatch {
        GameMatch()
    }
}

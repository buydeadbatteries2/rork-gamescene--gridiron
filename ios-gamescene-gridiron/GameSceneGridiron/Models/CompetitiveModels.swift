import Foundation

// MARK: - Phase 14 — competitive (ranked) results
//
// The client NEVER computes or sends an authoritative score. A finished,
// eligible season game produces a `CompetitiveResultPayload` — the raw facts
// of the game (which case versions were played, what was placed where,
// hints, wrong placements, timestamps). The `submit-ranked-result` Edge
// Function re-validates every fact against the private server catalog,
// derives the user from the JWT, computes the score from the single server
// scoring config, and only then records the result and career stats.

// MARK: Catalog entry (generated data lives in Data/CompetitiveCaseCatalog.swift)

nonisolated struct CompetitiveCatalogEntry: Hashable, Sendable {
    let version: Int
    let fingerprint: String
    let tier: DifficultyLevel
    let difficultyScore: Int
    let isCompetitiveEligible: Bool
}

nonisolated extension CompetitiveCaseCatalog {
    /// The canonical content list the export script fingerprints — keep it
    /// byte-identical to `fingerprint_values` in
    /// scripts/export_competitive_catalog.py.
    static func fingerprintValues(of puzzleCase: QuarterCase) -> [String] {
        var values = [
            "gridiron-competitive-case-v1", puzzleCase.id,
            "band:\(puzzleCase.band)", "seed:\(puzzleCase.rosterSeed)",
            "tier:\(puzzleCase.tier?.rawValue ?? "none")",
            "eligible:\(puzzleCase.isCompetitiveEligible ? 1 : 0)",
        ]
        values += puzzleCase.missing.map { "m:\($0.key):\($0.position.rawValue)" }
        values += puzzleCase.slots.map { "s:\($0.key)" }
        values += puzzleCase.solution.map { "x:\($0.playerKey):\($0.slotKey):\($0.profile.rawValue)" }
        values += ["clues:\(puzzleCase.clues.count)", "hints:\(puzzleCase.hints.count)"]
        return values
    }

    /// FNV-1a 64 fingerprint (same algorithm as the export script).
    static func fingerprint(of puzzleCase: QuarterCase) -> String {
        let hash = SeededGenerator.hash(fingerprintValues(of: puzzleCase))
        let hex = String(hash, radix: 16)
        return String(repeating: "0", count: max(0, 16 - hex.count)) + hex
    }

    /// The catalog version for a library case — nil when the case is not in
    /// the competitive catalog (training case, unknown id) or when the local
    /// content no longer matches the exported fingerprint (a stale export can
    /// never submit a result the server would mis-validate).
    static func competitiveVersion(forCaseID caseID: String) -> Int? {
        guard let entry = entries[caseID], entry.isCompetitiveEligible,
              let puzzleCase = CaseLibrary.caseByID(caseID),
              puzzleCase.isCompetitiveEligible,
              fingerprint(of: puzzleCase) == entry.fingerprint else { return nil }
        return entry.version
    }
}

// MARK: Server wire values

nonisolated extension DifficultyLevel {
    /// The server's difficulty enum value (`ranked_game_results.difficulty`).
    var serverValue: String {
        switch self {
        case .rookie: "rookie"
        case .pro: "pro"
        case .allPro: "all_pro"
        case .hallOfFamer: "hall_of_famer"
        }
    }

    init?(serverValue: String) {
        guard let match = DifficultyLevel.allCases.first(where: { $0.serverValue == serverValue }) else { return nil }
        self = match
    }
}

// MARK: Per-case results

/// One correct placement, keyed by the case file's own player/slot keys
/// (runtime ids carry the "<caseID>-" / "<caseID>-s-" prefixes, stripped here).
nonisolated struct CompetitivePlacement: Codable, Hashable, Sendable {
    let playerKey: String
    let slotKey: String
    let profile: String

    enum CodingKeys: String, CodingKey {
        case playerKey = "player_key"
        case slotKey = "slot_key"
        case profile
    }

    /// Strips the runtime id prefixes back to case-file keys.
    static func from(_ placed: PlacedPlayer, caseID: String) -> CompetitivePlacement {
        let playerPrefix = "\(caseID)-"
        let slotPrefix = "\(caseID)-s-"
        let player = placed.player.id.hasPrefix(playerPrefix) ? String(placed.player.id.dropFirst(playerPrefix.count)) : placed.player.id
        let slot = placed.slot.id.hasPrefix(slotPrefix) ? String(placed.slot.id.dropFirst(slotPrefix.count)) : placed.slot.id
        return CompetitivePlacement(playerKey: player, slotKey: slot, profile: placed.profile.rawValue)
    }
}

nonisolated struct CompetitiveCaseResult: Codable, Hashable, Sendable {
    let caseID: String
    /// nil when the case is not in the competitive catalog — the game is
    /// then ineligible and never submitted.
    let caseVersion: Int?
    /// 0–3 regulation, 4 = overtime.
    let quarterIndex: Int
    let outcome: QuarterOutcome
    let hintsUsed: Int
    let wrongPlacements: Int
    /// Deterministic order (sorted by player key).
    let placements: [CompetitivePlacement]

    enum CodingKeys: String, CodingKey {
        case caseID = "case_id"
        case caseVersion = "case_version"
        case quarterIndex = "quarter_index"
        case outcome
        case hintsUsed = "hints_used"
        case wrongPlacements = "wrong_placements"
        case placements
    }
}

// MARK: Match-level competitive state (persisted with the active match)

/// Lives on `ActiveMatchRecord` so the competitive identity survives
/// backgrounding, termination and relaunch. The match ID is generated ONCE
/// when a real season game starts and never regenerated for that game.
nonisolated struct CompetitiveMatchState: Codable, Hashable, Sendable {
    let competitiveMatchID: UUID
    let startedAt: Date
    var caseResults: [CompetitiveCaseResult]
    /// Set when something makes the game ineligible (legacy resume record,
    /// unknown case version…). An ineligible game is never submitted; its
    /// local outcome is unaffected.
    var ineligibleReason: CompetitiveIneligibility?

    static func fresh(now: Date = Date()) -> CompetitiveMatchState {
        CompetitiveMatchState(competitiveMatchID: UUID(), startedAt: now, caseResults: [], ineligibleReason: nil)
    }

    /// A resumed game whose saved record predates competitive tracking: it
    /// keeps playing normally but can never be ranked.
    static func legacyResume(now: Date = Date()) -> CompetitiveMatchState {
        CompetitiveMatchState(competitiveMatchID: UUID(), startedAt: now, caseResults: [], ineligibleReason: .recoveredWithoutCompetitiveIdentity)
    }
}

nonisolated enum CompetitiveIneligibility: String, Codable, Hashable, Sendable {
    case notASeasonGame
    case recoveredWithoutCompetitiveIdentity
    case unknownCaseVersion
    case difficultyMismatch
    case incompleteGame
    case inconsistentCaseResults
    case guestPlayer
    case invalidGameNumber
}

// MARK: Payload

nonisolated struct CompetitiveResultPayload: Codable, Hashable, Sendable {
    let matchID: UUID
    /// Informational only — the server derives the user from the JWT and
    /// rejects a mismatch. Never an authority.
    let userID: UUID
    let seasonID: UUID?
    /// 1–10 regular season, 11 semifinal, 12 championship.
    let gameNumber: Int
    /// Server enum value (rookie / pro / all_pro / hall_of_famer).
    let difficulty: String
    let startedAt: Date
    let completedAt: Date
    let regulationQuartersSolved: Int
    let regulationQuartersLost: Int
    let gameWon: Bool
    let overtimePlayed: Bool
    let overtimeWon: Bool
    let wrongPlacements: Int
    let hintsUsed: Int
    let caseResults: [CompetitiveCaseResult]
    let gameVersion: String

    enum CodingKeys: String, CodingKey {
        case matchID = "match_id"
        case userID = "user_id"
        case seasonID = "season_id"
        case gameNumber = "game_number"
        case difficulty
        case startedAt = "started_at"
        case completedAt = "completed_at"
        case regulationQuartersSolved = "regulation_quarters_solved"
        case regulationQuartersLost = "regulation_quarters_lost"
        case gameWon = "game_won"
        case overtimePlayed = "overtime_played"
        case overtimeWon = "overtime_won"
        case wrongPlacements = "wrong_placements"
        case hintsUsed = "hints_used"
        case caseResults = "case_results"
        case gameVersion = "game_version"
    }

    static var currentGameVersion: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "0"
        let build = info?["CFBundleVersion"] as? String ?? "0"
        return "ios-\(short)(\(build))"
    }

    static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

// MARK: Eligibility + payload building (pure)

nonisolated enum CompetitivePayloadBuilder {
    nonisolated enum Outcome: Equatable, Sendable {
        case eligible(CompetitiveResultPayload)
        case ineligible(CompetitiveIneligibility)
    }

    /// Builds the submission for a finished game, or the reason it can never
    /// count. Pure — every input is explicit.
    /// - Parameters:
    ///   - userID: the authenticated user at completion; nil = guest.
    ///   - seasonDifficulty: the difficulty the season is locked to.
    static func build(
        state: CompetitiveMatchState?,
        match: GameMatch,
        seasonNumber: Int,
        gameNumber: Int,
        activeDifficulty: DifficultyLevel,
        seasonDifficulty: DifficultyLevel?,
        seasonID: UUID?,
        userID: UUID?,
        completedAt: Date,
        gameVersion: String = CompetitiveResultPayload.currentGameVersion
    ) -> Outcome {
        guard seasonNumber > 0, let state else { return .ineligible(.notASeasonGame) }
        if let reason = state.ineligibleReason { return .ineligible(reason) }
        guard let userID else { return .ineligible(.guestPlayer) }
        guard (1...12).contains(gameNumber) else { return .ineligible(.invalidGameNumber) }
        guard let seasonDifficulty, seasonDifficulty == activeDifficulty else { return .ineligible(.difficultyMismatch) }
        guard match.isComplete, let result = match.result else { return .ineligible(.incompleteGame) }

        let regulation = state.caseResults.filter { $0.quarterIndex < GameMatch.regulationQuarters }
        let overtime = state.caseResults.filter { $0.quarterIndex == GameMatch.regulationQuarters }
        let overtimePlayed = match.overtimeRecord != nil
        guard Set(regulation.map(\.quarterIndex)) == Set(0..<GameMatch.regulationQuarters),
              regulation.count == GameMatch.regulationQuarters,
              overtime.count == (overtimePlayed ? 1 : 0),
              Set(state.caseResults.map(\.caseID)).count == state.caseResults.count else {
            return .ineligible(.inconsistentCaseResults)
        }
        // Per-case outcomes must agree with the match record.
        for record in match.quarterRecords {
            guard let caseResult = regulation.first(where: { $0.quarterIndex == record.id }),
                  caseResult.outcome == record.outcome else { return .ineligible(.inconsistentCaseResults) }
        }
        if let ot = match.overtimeRecord, overtime.first?.outcome != ot.outcome {
            return .ineligible(.inconsistentCaseResults)
        }
        guard state.caseResults.allSatisfy({ $0.caseVersion != nil }) else { return .ineligible(.unknownCaseVersion) }

        let ordered = state.caseResults.sorted { $0.quarterIndex < $1.quarterIndex }
        let solved = regulation.filter { $0.outcome == .solved }.count
        return .eligible(CompetitiveResultPayload(
            matchID: state.competitiveMatchID,
            userID: userID,
            seasonID: seasonID,
            gameNumber: gameNumber,
            difficulty: activeDifficulty.serverValue,
            startedAt: state.startedAt,
            completedAt: completedAt,
            regulationQuartersSolved: solved,
            regulationQuartersLost: GameMatch.regulationQuarters - solved,
            gameWon: result.isWin,
            overtimePlayed: overtimePlayed,
            overtimeWon: overtime.first?.outcome == .solved,
            wrongPlacements: ordered.reduce(0) { $0 + $1.wrongPlacements },
            hintsUsed: ordered.reduce(0) { $0 + $1.hintsUsed },
            caseResults: ordered,
            gameVersion: gameVersion
        ))
    }
}

import Foundation
import Testing
@testable import GameSceneGridiron

// MARK: - Phase 14 tests — server-verified global leaderboards
//
// The client never computes an authoritative score. These suites pin:
//  * the exported competitive catalog against the live CaseLibrary,
//  * that every legitimately solved case at every difficulty/week passes the
//    server's solution check (Swift mirror of validateCaseAgainstSolution),
//  * the eligibility gate + payload shape (no score field ever sent),
//  * the single SQL scoring config / formula (oracle from the spec),
//  * schema + Edge Function security properties (fixtures),
//  * the durable submission queue and its flush service,
//  * the leaderboard view model (pagination, pinned rank, offline, cache,
//    search) and display formatting.

// MARK: Shared helpers

private enum P14 {
    /// caseID → difficulty → set of "player|slot|profile".
    static let fixtureSolutions: [String: [String: Set<String>]] = {
        var map: [String: [String: Set<String>]] = [:]
        for line in CompetitiveCatalogFixture.solutions.split(separator: "\n") {
            let parts = line.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
            guard parts.count == 3 else { continue }
            let placements = parts[2].split(separator: ",").map { item -> String in
                item.split(separator: ":").joined(separator: "|")
            }
            map[parts[0], default: [:]][parts[1]] = Set(placements)
        }
        return map
    }()

    /// Mirror of the Edge Function's `trimAllowed`.
    static func serverTrimAllowed(_ level: DifficultyLevel, gameNumber: Int) -> Bool {
        level == .rookie || (level == .pro && gameNumber <= 3)
    }

    /// Mirror of the Edge Function's `validateCaseAgainstSolution`.
    static func serverAccepts(placements: [String], solved: Bool, solution: Set<String>, canTrim: Bool) -> Bool {
        guard !solution.isEmpty else { return false }
        guard placements.allSatisfy({ solution.contains($0) }) else { return false }
        if solved {
            return placements.count == solution.count
                || (canTrim && solution.count > 4 && placements.count == solution.count - 1)
        }
        return placements.count <= solution.count - 1
    }

    static func normalizedSQL(_ raw: String) -> String {
        raw.components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("--") }
            .joined(separator: " ")
            .split(whereSeparator: { $0 == " " || $0 == "\r" || $0 == "\n" || $0 == "\t" })
            .joined(separator: " ")
    }

    static let sql = normalizedSQL(SchemaFixture.sql)

    static func function(named marker: String) -> String {
        guard let start = sql.range(of: marker) else { return "" }
        guard let end = sql.range(of: "end; $$;", range: start.upperBound..<sql.endIndex) else {
            return String(sql[start.lowerBound...])
        }
        return String(sql[start.lowerBound..<end.upperBound])
    }

    static func sqlFunction(named marker: String) -> String {
        guard let start = sql.range(of: marker) else { return "" }
        guard let end = sql.range(of: "$$;", range: start.upperBound..<sql.endIndex) else {
            return String(sql[start.lowerBound...])
        }
        return String(sql[start.lowerBound..<end.upperBound])
    }

    static let caseIDs: [String] = Array(CompetitiveCaseCatalog.entries.keys.sorted().prefix(5))

    static let start = Date(timeIntervalSince1970: 1_790_000_000)
    static let end = Date(timeIntervalSince1970: 1_790_000_900)

    static func caseResult(_ index: Int, _ outcome: QuarterOutcome, hints: Int = 0, wrong: Int = 0, version: Int? = 1) -> CompetitiveCaseResult {
        CompetitiveCaseResult(
            caseID: caseIDs[index], caseVersion: version, quarterIndex: index, outcome: outcome,
            hintsUsed: hints, wrongPlacements: wrong,
            placements: [CompetitivePlacement(playerKey: "rb", slotKey: "rb-right", profile: "veteran")]
        )
    }

    /// A finished match + matching competitive state.
    static func game(_ outcomes: [QuarterOutcome], overtime: QuarterOutcome? = nil, hints: Int = 0, wrong: Int = 0) -> (GameMatch, CompetitiveMatchState) {
        var match = GameMatch.fresh()
        var results: [CompetitiveCaseResult] = []
        for (index, outcome) in outcomes.enumerated() {
            let h = index == 0 ? hints : 0
            let w = index == 0 ? wrong : 0
            match.recordQuarter(index: index, label: "Q\(index + 1)", isOvertime: false, outcome: outcome,
                                correctPlacements: 4, wrongPlacements: w, livesLost: 0, hintsUsed: h)
            results.append(caseResult(index, outcome, hints: h, wrong: w))
        }
        if let overtime {
            match.recordQuarter(index: 4, label: "OT", isOvertime: true, outcome: overtime,
                                correctPlacements: 4, wrongPlacements: 0, livesLost: 0, hintsUsed: 0)
            results.append(caseResult(4, overtime))
        }
        let state = CompetitiveMatchState(competitiveMatchID: UUID(), startedAt: start, caseResults: results, ineligibleReason: nil)
        return (match, state)
    }

    static func build(
        _ state: CompetitiveMatchState?, _ match: GameMatch,
        seasonNumber: Int = 1, gameNumber: Int = 5,
        active: DifficultyLevel = .pro, locked: DifficultyLevel? = .pro,
        user: UUID? = UUID()
    ) -> CompetitivePayloadBuilder.Outcome {
        CompetitivePayloadBuilder.build(
            state: state, match: match, seasonNumber: seasonNumber, gameNumber: gameNumber,
            activeDifficulty: active, seasonDifficulty: locked, seasonID: UUID(),
            userID: user, completedAt: end, gameVersion: "ios-test(1)"
        )
    }

    static func payload(matchID: UUID = UUID(), user: UUID) -> CompetitiveResultPayload {
        CompetitiveResultPayload(
            matchID: matchID, userID: user, seasonID: UUID(), gameNumber: 4, difficulty: "pro",
            startedAt: start, completedAt: end, regulationQuartersSolved: 3, regulationQuartersLost: 1,
            gameWon: true, overtimePlayed: false, overtimeWon: false, wrongPlacements: 0, hintsUsed: 0,
            caseResults: [], gameVersion: "ios-test(1)"
        )
    }

    static func entry(rank: Int, user: UUID = UUID(), score: Double = 100, provisional: Bool = false, difficulty: String = "pro") -> LeaderboardEntry {
        LeaderboardEntry(
            rank: rank, userID: user, username: "det_\(rank)", footballDisplayName: "Detective \(rank)",
            score: score, gamesCounted: 3, totalGames: 3, averageScore: score / 3, wins: 2,
            quartersSolved: 9, hintsUsed: 1, wrongPlacements: 2, topDifficulty: difficulty,
            isProvisional: provisional, firstReachedAt: start
        )
    }

    static func defaults() -> UserDefaults {
        let name = "phase14-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }
}

// MARK: - Catalog

@MainActor
@Suite("Phase 14 — competitive catalog")
struct Phase14CatalogTests {

    @Test func catalogCoversEveryLibraryCaseAndNothingElse() {
        #expect(CompetitiveCaseCatalog.caseCount == 150)
        #expect(CompetitiveCaseCatalog.entries.count == 150)
        #expect(Set(CompetitiveCaseCatalog.entries.keys) == Set(CaseLibrary.all.map(\.id)))
        #expect(CompetitiveCatalogFixture.catalogFingerprint == CompetitiveCaseCatalog.catalogFingerprint)
        #expect(Set(P14.fixtureSolutions.keys) == Set(CaseLibrary.all.map(\.id)))
    }

    @Test func fingerprintsMatchLiveCaseContent() {
        var stale: [String] = []
        for puzzleCase in CaseLibrary.all {
            if CompetitiveCaseCatalog.fingerprint(of: puzzleCase) != CompetitiveCaseCatalog.entries[puzzleCase.id]?.fingerprint {
                stale.append(puzzleCase.id)
            }
        }
        #expect(stale.isEmpty, "Re-run scripts/export_competitive_catalog.py — stale: \(stale.prefix(5))")
    }

    @Test func everyLibraryCaseHasACompetitiveVersion() {
        for puzzleCase in CaseLibrary.all {
            #expect(CompetitiveCaseCatalog.competitiveVersion(forCaseID: puzzleCase.id) != nil, "\(puzzleCase.id)")
        }
    }

    @Test func trainingAndUnknownCasesNeverCount() {
        #expect(CompetitiveCaseCatalog.competitiveVersion(forCaseID: TrainingCase.authored.id) == nil)
        #expect(CompetitiveCaseCatalog.competitiveVersion(forCaseID: "case_does_not_exist") == nil)
    }

    @Test func fixtureHasAllFourDifficultiesPerCase() {
        for (caseID, byDifficulty) in P14.fixtureSolutions {
            #expect(Set(byDifficulty.keys) == Set(DifficultyLevel.allCases.map(\.serverValue)), "\(caseID)")
        }
    }

    @Test func difficultyServerValuesRoundTrip() {
        for level in DifficultyLevel.allCases {
            #expect(DifficultyLevel(serverValue: level.serverValue) == level)
        }
        #expect(DifficultyLevel(serverValue: "legend") == nil)
    }

    /// Client trimming must never exceed what the server tolerates.
    @Test func clientTrimOnlyWhereServerAllowsIt() {
        for level in DifficultyLevel.allCases {
            for week in 1...12 {
                let target = DifficultyResolver.target(selected: level, stage: .forWeek(week))
                if target.maxMissingPlayers < Int.max {
                    #expect(P14.serverTrimAllowed(level, gameNumber: week), "\(level) week \(week) trims but server forbids")
                }
            }
        }
    }

    /// Every case, solved legitimately at every difficulty and every week,
    /// passes the server's per-case solution check.
    @Test func legitimatelySolvedCasesPassServerValidation() {
        var failures: [String] = []
        for level in DifficultyLevel.allCases {
            // The adapted solution depends only on the level's profile pool
            // and the missing-player cap — group weeks by the cap.
            var weeksByCap: [Int: [Int]] = [:]
            for week in 1...12 {
                let cap = DifficultyResolver.target(selected: level, stage: .forWeek(week)).maxMissingPlayers
                weeksByCap[cap, default: []].append(week)
            }
            for (_, weeks) in weeksByCap {
                let target = DifficultyResolver.target(selected: level, stage: .forWeek(weeks[0]))
                for puzzleCase in CaseLibrary.all {
                    let adapted = CaseDifficultyAdapter.adapt(puzzleCase, to: target)
                    let placements = adapted.solution.map { "\($0.playerKey)|\($0.slotKey)|\($0.profile.rawValue)" }
                    guard let truth = P14.fixtureSolutions[puzzleCase.id]?[level.serverValue] else {
                        failures.append("\(puzzleCase.id)/\(level.serverValue): missing solution")
                        continue
                    }
                    for week in weeks where !P14.serverAccepts(
                        placements: placements, solved: true, solution: truth,
                        canTrim: P14.serverTrimAllowed(level, gameNumber: week)
                    ) {
                        failures.append("\(puzzleCase.id)/\(level.serverValue)/w\(week)")
                    }
                }
            }
        }
        #expect(failures.isEmpty, "Rejected legit solves (\(failures.count)): \(failures.prefix(6))")
    }

    @Test func serverRejectsWrongOrIncompleteSolves() {
        let truth: Set<String> = ["a|1|fast", "b|2|veteran", "c|3|rookie", "d|4|powerful", "e|5|veteran"]
        // A placement that is not part of the solution.
        #expect(!P14.serverAccepts(placements: ["a|1|fast", "b|2|veteran", "c|3|rookie", "d|4|powerful", "e|5|fast"], solved: true, solution: truth, canTrim: false))
        // Solved with one missing — only when trimming is allowed.
        let four = ["a|1|fast", "b|2|veteran", "c|3|rookie", "d|4|powerful"]
        #expect(!P14.serverAccepts(placements: four, solved: true, solution: truth, canTrim: false))
        #expect(P14.serverAccepts(placements: four, solved: true, solution: truth, canTrim: true))
        // A failed case can never carry the complete solution.
        #expect(!P14.serverAccepts(placements: Array(truth), solved: false, solution: truth, canTrim: true))
    }

    @Test func placementsStripRuntimePrefixesAndSortDeterministically() {
        let placement = CompetitivePlacement(playerKey: "wr", slotKey: "wr-left", profile: "fast")
        let data = try? JSONEncoder().encode(placement)
        let json = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
        #expect(json.contains("\"player_key\""))
        #expect(json.contains("\"slot_key\""))
    }
}

// MARK: - Eligibility + payload

@MainActor
@Suite("Phase 14 — eligibility and payload")
struct Phase14PayloadTests {

    @Test func cleanWinIsEligibleWithExactSummary() throws {
        let (match, state) = P14.game([.solved, .solved, .solved, .failed], hints: 2, wrong: 1)
        guard case .eligible(let payload) = P14.build(state, match) else {
            Issue.record("expected eligible"); return
        }
        #expect(payload.matchID == state.competitiveMatchID)
        #expect(payload.regulationQuartersSolved == 3)
        #expect(payload.regulationQuartersLost == 1)
        #expect(payload.gameWon)
        #expect(!payload.overtimePlayed)
        #expect(payload.hintsUsed == 2)
        #expect(payload.wrongPlacements == 1)
        #expect(payload.difficulty == "pro")
        #expect(payload.caseResults.map(\.quarterIndex) == [0, 1, 2, 3])
    }

    @Test func overtimeWinIsReported() {
        let (match, state) = P14.game([.solved, .failed, .solved, .failed], overtime: .solved)
        guard case .eligible(let payload) = P14.build(state, match) else {
            Issue.record("expected eligible"); return
        }
        #expect(payload.overtimePlayed)
        #expect(payload.overtimeWon)
        #expect(payload.gameWon)
        #expect(payload.caseResults.count == 5)
    }

    @Test func guestsNeverSubmit() {
        let (match, state) = P14.game([.solved, .solved, .solved, .solved])
        #expect(P14.build(state, match, user: nil) == .ineligible(.guestPlayer))
    }

    @Test func standaloneOrMissingStateIsNotASeasonGame() {
        let (match, state) = P14.game([.solved, .solved, .solved, .solved])
        #expect(P14.build(state, match, seasonNumber: 0) == .ineligible(.notASeasonGame))
        #expect(P14.build(nil, match) == .ineligible(.notASeasonGame))
    }

    @Test func recoveredLegacyGameIsIneligible() {
        let (match, _) = P14.game([.solved, .solved, .solved, .solved])
        #expect(P14.build(.legacyResume(), match) == .ineligible(.recoveredWithoutCompetitiveIdentity))
    }

    @Test func difficultyMustMatchSeasonLock() {
        let (match, state) = P14.game([.solved, .solved, .solved, .solved])
        #expect(P14.build(state, match, active: .hallOfFamer, locked: .pro) == .ineligible(.difficultyMismatch))
        #expect(P14.build(state, match, locked: nil) == .ineligible(.difficultyMismatch))
    }

    @Test func incompleteGameIsIneligible() {
        let (match, state) = P14.game([.solved, .solved, .failed])
        #expect(P14.build(state, match) == .ineligible(.incompleteGame))
    }

    @Test func invalidGameNumberIsIneligible() {
        let (match, state) = P14.game([.solved, .solved, .solved, .solved])
        #expect(P14.build(state, match, gameNumber: 13) == .ineligible(.invalidGameNumber))
        #expect(P14.build(state, match, gameNumber: 0) == .ineligible(.invalidGameNumber))
    }

    @Test func caseResultsMustAgreeWithTheMatch() {
        let (match, state) = P14.game([.solved, .solved, .solved, .failed])
        var tampered = state
        tampered.caseResults[3] = P14.caseResult(3, .solved)
        #expect(P14.build(tampered, match) == .ineligible(.inconsistentCaseResults))

        var missing = state
        missing.caseResults.removeLast()
        #expect(P14.build(missing, match) == .ineligible(.inconsistentCaseResults))
    }

    @Test func unknownCaseVersionIsIneligible() {
        let (match, state) = P14.game([.solved, .solved, .solved, .failed])
        var unknown = state
        unknown.caseResults[1] = P14.caseResult(1, .solved, version: nil)
        #expect(P14.build(unknown, match) == .ineligible(.unknownCaseVersion))
    }

    @Test func markedIneligibleStateStaysIneligible() {
        let (match, state) = P14.game([.solved, .solved, .solved, .solved])
        var flagged = state
        flagged.ineligibleReason = .unknownCaseVersion
        #expect(P14.build(flagged, match) == .ineligible(.unknownCaseVersion))
    }

    /// The wire format carries raw facts only — never a score.
    @Test func payloadNeverContainsAScore() throws {
        let (match, state) = P14.game([.solved, .solved, .solved, .solved])
        guard case .eligible(let payload) = P14.build(state, match) else {
            Issue.record("expected eligible"); return
        }
        let data = try CompetitiveResultPayload.encoder().encode(payload)
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let keys = Set(object.keys)
        #expect(keys == [
            "match_id", "user_id", "season_id", "game_number", "difficulty", "started_at", "completed_at",
            "regulation_quarters_solved", "regulation_quarters_lost", "game_won", "overtime_played",
            "overtime_won", "wrong_placements", "hints_used", "case_results", "game_version",
        ])
        #expect(!keys.contains { $0.contains("score") || $0.contains("multiplier") || $0.contains("rating") })
        let decoded = try CompetitiveResultPayload.decoder().decode(CompetitiveResultPayload.self, from: data)
        #expect(decoded == payload)
    }

    @Test func matchIDIsStableAcrossPersistence() throws {
        let state = CompetitiveMatchState.fresh(now: P14.start)
        let data = try CompetitiveResultPayload.encoder().encode(state)
        let restored = try CompetitiveResultPayload.decoder().decode(CompetitiveMatchState.self, from: data)
        #expect(restored.competitiveMatchID == state.competitiveMatchID)
    }
}

// MARK: - Scoring (single SQL config)

@MainActor
@Suite("Phase 14 — server scoring config")
struct Phase14ScoringTests {

    struct Config {
        let quarter, win, overtimeWin, perfect, noHints, noWrong: Int
        /// Hundredths.
        let multipliers: [String: Int]
        let weeklyBest, allTimeBest, provisionalMin: Int
    }

    /// Parsed from the ONE insert in schema.sql — the only place values live.
    static func parsedConfig() throws -> Config {
        let sql = P14.sql
        let marker = ") values (1, "
        let start = try #require(sql.range(of: marker))
        let close = try #require(sql.range(of: ")", range: start.upperBound..<sql.endIndex))
        let values = ("1, " + sql[start.upperBound..<close.lowerBound])
            .split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        // 15 scoring/board values + 4 Phase 14A trust-window values (30, 20, 168, 300).
        try #require(values.count == 19)
        #expect(Array(values[15...]) == ["30", "20", "168", "300"])
        func int(_ i: Int) -> Int { Int(values[i]) ?? -1 }
        func hundredths(_ i: Int) -> Int { Int(((Double(values[i]) ?? -1) * 100).rounded()) }
        return Config(
            quarter: int(1), win: int(2), overtimeWin: int(3), perfect: int(4), noHints: int(5), noWrong: int(6),
            multipliers: ["rookie": hundredths(7), "pro": hundredths(8), "all_pro": hundredths(9), "hall_of_famer": hundredths(10)],
            weeklyBest: int(11), allTimeBest: int(12), provisionalMin: int(13)
        )
    }

    /// Oracle of record_verified_ranked_result's formula (numeric round,
    /// half away from zero — scores are never negative).
    static func score(_ c: Config, solved: Int, won: Bool, otWon: Bool, hints: Int, wrong: Int, difficulty: String) -> Int {
        let base = solved * c.quarter + (won ? c.win : 0) + (otWon ? c.overtimeWin : 0)
            + (solved == 4 ? c.perfect : 0) + (hints == 0 ? c.noHints : 0) + (wrong == 0 ? c.noWrong : 0)
        return (base * (c.multipliers[difficulty] ?? 0) + 50) / 100
    }

    @Test func configMatchesTheSpec() throws {
        let c = try Self.parsedConfig()
        #expect(c.quarter == 10 && c.win == 10 && c.overtimeWin == 5 && c.perfect == 5)
        #expect(c.noHints == 3 && c.noWrong == 3)
        #expect(c.multipliers == ["rookie": 100, "pro": 125, "all_pro": 150, "hall_of_famer": 200])
        #expect(c.weeklyBest == 10 && c.allTimeBest == 25 && c.provisionalMin == 5)
    }

    @Test func workedExamples() throws {
        let c = try Self.parsedConfig()
        // Perfect, clean Hall of Famer: (40+10+5+3+3) × 2.00
        #expect(Self.score(c, solved: 4, won: true, otWon: false, hints: 0, wrong: 0, difficulty: "hall_of_famer") == 122)
        // Rookie 3–1 with a hint and a wrong placement: (30+10) × 1.00
        #expect(Self.score(c, solved: 3, won: true, otWon: false, hints: 1, wrong: 1, difficulty: "rookie") == 40)
        // Pro 2–2 OT win, clean: (20+10+5+3+3) × 1.25 = 51.25 → 51
        #expect(Self.score(c, solved: 2, won: true, otWon: true, hints: 0, wrong: 0, difficulty: "pro") == 51)
        // All-Pro 1–3 loss with hints, no wrong: (10+3) × 1.5 = 19.5 → 20
        #expect(Self.score(c, solved: 1, won: false, otWon: false, hints: 2, wrong: 0, difficulty: "all_pro") == 20)
        // Hints only cost the +3 clean bonus.
        let clean = Self.score(c, solved: 3, won: true, otWon: false, hints: 0, wrong: 0, difficulty: "pro")
        let hinted = Self.score(c, solved: 3, won: true, otWon: false, hints: 5, wrong: 0, difficulty: "pro")
        #expect(clean - hinted == 4) // 57.5 → 58 vs 53.75 → 54
    }

    @Test func formulaLivesOnlyInTheDatabaseFunction() {
        let body = P14.function(named: "create or replace function public.record_verified_ranked_result(")
        #expect(body.contains("p_regulation_quarters_solved * cfg.quarter_solved_points"))
        #expect(body.contains("when p_game_won then cfg.game_win_points"))
        #expect(body.contains("when p_overtime_won then cfg.overtime_win_points"))
        #expect(body.contains("when p_regulation_quarters_solved = 4 then cfg.perfect_regulation_points"))
        #expect(body.contains("when p_hints_used = 0 then cfg.no_hints_points"))
        #expect(body.contains("when p_wrong_placements = 0 then cfg.no_wrong_placements_points"))
        #expect(body.contains("round(v_base::numeric * v_mult)::int"))
        // The Edge Function never holds scoring constants.
        let edge = EdgeFunctionFixture.submitRankedResult
        #expect(!edge.contains("quarter_solved_points"))
        #expect(!edge.contains("multiplier"))
    }

    @Test func leaderboardAggregationRules() {
        let rows = P14.sqlFunction(named: "create or replace function public.ranked_leaderboard_rows(")
        #expect(rows.contains("date_trunc('week', now() at time zone 'utc')"))
        #expect(rows.contains("when p_board = 'weekly' then cfg.weekly_best_games else cfg.alltime_best_games"))
        #expect(rows.contains("when p_board = 'weekly' then a.total_score else a.average_score"))
        #expect(rows.contains("a.total_games < cfg.provisional_min_games"))
        #expect(rows.contains("order by s.is_provisional asc, s.score desc, s.average_score desc, s.wins desc, s.quarters_solved desc, s.hints_used asc, s.wrong_placements asc"))
        #expect(rows.contains("rank() over"))
        #expect(rows.contains("join public.public_profiles pp"))
        #expect(!rows.contains("email"))
    }
}

// MARK: - Schema + Edge Function security

@MainActor
@Suite("Phase 14 — server security (fixtures)")
struct Phase14SecurityTests {

    @Test func privateTablesAreLockedDown() {
        let sql = P14.sql
        #expect(sql.contains("alter table public.competitive_cases enable row level security;"))
        #expect(sql.contains("revoke all on public.competitive_cases from anon, authenticated;"))
        #expect(sql.contains("revoke all on public.ranked_scoring_config from anon, authenticated;"))
        #expect(sql.contains("revoke all on public.ranked_submission_attempts from anon, authenticated;"))
        #expect(!sql.contains("on public.competitive_cases for select"))
    }

    @Test func clientsCannotWriteRankedResults() {
        let sql = P14.sql
        #expect(sql.contains("alter table public.ranked_game_results enable row level security;"))
        #expect(sql.contains("revoke insert, update, delete on public.ranked_game_results from authenticated;"))
        #expect(sql.contains("using (auth.uid() = user_id)"))
        #expect(!sql.contains("on public.ranked_game_results for insert"))
        #expect(!sql.contains("on public.ranked_game_results for update"))
        #expect(sql.contains("constraint ranked_game_results_match_id_key unique (match_id)"))
    }

    @Test func onlyServiceRoleRecordsResults() {
        let sig = "public.record_verified_ranked_result(uuid, uuid, uuid, int, text, int, boolean, boolean, boolean, int, int, jsonb, timestamptz, timestamptz, text)"
        #expect(P14.sql.contains("revoke all on function \(sig) from public, anon, authenticated;"))
        #expect(P14.sql.contains("grant execute on function \(sig) to service_role;"))
        #expect(!P14.sql.contains("grant execute on function \(sig) to authenticated"))
        #expect(P14.sql.contains("revoke all on function public.ranked_leaderboard_rows(text, text) from public, anon, authenticated;"))
    }

    @Test func recordFunctionIsIdempotentAndNeverTouchesChampionships() {
        let body = P14.function(named: "create or replace function public.record_verified_ranked_result(")
        #expect(body.contains("return query select existing.id, existing.final_score, true, existing.leaderboard_at, existing.leaderboard_at_source;"))
        #expect(body.contains("raise exception 'MATCH_ID_CONFLICT'"))
        #expect(body.contains("raise exception 'SEASON_DIFFICULTY_MISMATCH'"))
        #expect(body.contains("when unique_violation then"))
        #expect(!body.contains("championships"))
        #expect(!body.contains("or true"))
    }

    @Test func readFunctionsRequireAuthAndCapPages() {
        let board = P14.function(named: "create or replace function public.ranked_leaderboard(")
        #expect(board.contains("if auth.uid() is null then raise exception 'AUTH_REQUIRED';"))
        #expect(board.contains("least(greatest(coalesce(p_limit, 50), 1), 50)"))
        let mine = P14.function(named: "create or replace function public.my_ranked_standing(")
        #expect(mine.contains("where lr.user_id = auth.uid()"))
        #expect(P14.sql.contains("revoke all on function public.ranked_leaderboard(text, text, int, int) from public, anon;"))
        #expect(P14.sql.contains("grant execute on function public.ranked_leaderboard(text, text, int, int) to authenticated;"))
    }

    @Test func edgeFunctionDerivesUserFromJWT() {
        let edge = EdgeFunctionFixture.submitRankedResult
        #expect(edge.contains("admin.auth.getUser(token)"))
        #expect(edge.contains("p_user_id: userID"))
        #expect(edge.contains("return reject(\"user_mismatch\", 403);"))
        #expect(edge.contains("reason: \"unauthorized\""))
        #expect(edge.contains("reason: \"rate_limited\""))
    }

    @Test func edgeFunctionNeverReadsAClientScore() {
        let edge = EdgeFunctionFixture.submitRankedResult
        for forbidden in ["payload.final_score", "payload.score", "p.final_score", "p.score", "body.score", "base_score"] {
            #expect(!edge.contains(forbidden), "\(forbidden)")
        }
        #expect(!edge.contains("p_final_score"))
    }

    @Test func edgeFunctionIsIdempotentByMatchID() {
        let edge = EdgeFunctionFixture.submitRankedResult
        #expect(edge.contains(".eq(\"match_id\", payload.match_id)"))
        #expect(edge.contains("duplicate: true"))
        #expect(edge.contains("return reject(\"match_id_conflict\", 409);"))
    }

    @Test func edgeFunctionValidatesAgainstPrivateCatalog() {
        let edge = EdgeFunctionFixture.submitRankedResult
        #expect(edge.contains("require(entry.case_version === result.case_version, \"case_version_mismatch\");"))
        #expect(edge.contains("entry.active === true && entry.competitive_eligible === true"))
        #expect(edge.contains("return difficulty === \"rookie\" || (difficulty === \"pro\" && gameNumber <= 3);"))
        #expect(edge.contains("require(p.game_won === (solved >= 3 || overtimeWon), \"summary_mismatch\");"))
        #expect(!edge.contains("SUPABASE_ANON_KEY"))
    }

    @Test func submitterClassifiesResponses() {
        #expect(SupabaseCompetitiveSubmitter.classify(statusCode: 401, reason: nil) == .retryable(category: "unauthorized"))
        #expect(SupabaseCompetitiveSubmitter.classify(statusCode: 429, reason: "rate_limited") == .retryable(category: "rate_limited"))
        #expect(SupabaseCompetitiveSubmitter.classify(statusCode: 503, reason: nil) == .retryable(category: "server_503"))
        #expect(SupabaseCompetitiveSubmitter.classify(statusCode: 422, reason: "placement_mismatch") == .rejected(reason: "placement_mismatch"))
        #expect(SupabaseCompetitiveSubmitter.classify(statusCode: 409, reason: "duplicate_season_game") == .rejected(reason: "duplicate_season_game"))
    }
}

// MARK: - Durable queue

@MainActor
@Suite("Phase 14 — submission queue")
struct Phase14QueueTests {

    @Test func enqueueIsIdempotentPerMatchID() {
        var queue = CompetitiveSubmissionQueue()
        let user = UUID()
        let payload = P14.payload(user: user)
        let first = queue.enqueue(payload, owner: user, now: P14.start)
        let second = queue.enqueue(payload, owner: user, now: P14.start)
        #expect(first)
        #expect(!second)
        #expect(queue.items.count == 1)
        #expect(queue.pendingCount == 1)
    }

    @Test func backoffIsExponentialAndCapped() {
        #expect(CompetitiveSubmissionQueue.backoff(afterAttempts: 0) == 30)
        #expect(CompetitiveSubmissionQueue.backoff(afterAttempts: 1) == 60)
        #expect(CompetitiveSubmissionQueue.backoff(afterAttempts: 3) == 240)
        #expect(CompetitiveSubmissionQueue.backoff(afterAttempts: 40) == 6 * 60 * 60)
    }

    @Test func retryableSchedulesNextAttempt() {
        var queue = CompetitiveSubmissionQueue()
        let user = UUID()
        let payload = P14.payload(user: user)
        queue.enqueue(payload, owner: user, now: P14.start)
        queue.markSubmitting(payload.matchID)
        queue.apply(.retryable(category: "network"), to: payload.matchID, now: P14.start)
        let item = queue.item(matchID: payload.matchID)
        #expect(item?.state == .pending)
        #expect(item?.attempts == 1)
        #expect(item?.nextAttemptAt == P14.start.addingTimeInterval(30))
        #expect(queue.dueItems(for: user, now: P14.start).isEmpty)
        #expect(queue.dueItems(for: user, now: P14.start.addingTimeInterval(31)).count == 1)
    }

    @Test func rejectionIsFinal() {
        var queue = CompetitiveSubmissionQueue()
        let user = UUID()
        let payload = P14.payload(user: user)
        queue.enqueue(payload, owner: user, now: P14.start)
        queue.apply(.rejected(reason: "placement_mismatch"), to: payload.matchID, now: P14.start)
        queue.apply(.verified(finalScore: 99, duplicate: false), to: payload.matchID, now: P14.start)
        #expect(queue.item(matchID: payload.matchID)?.state == .rejected)
        #expect(queue.item(matchID: payload.matchID)?.finalScore == nil)
        #expect(queue.dueItems(for: user, now: .distantFuture).isEmpty)
    }

    @Test func onlyTheOwnerMaySubmit() {
        var queue = CompetitiveSubmissionQueue()
        let owner = UUID()
        queue.enqueue(P14.payload(user: owner), owner: owner, now: P14.start)
        #expect(queue.dueItems(for: UUID(), now: P14.start).isEmpty)
        #expect(queue.dueItems(for: owner, now: P14.start).count == 1)
    }

    @Test func safeCategoryStripsAnythingPrivate() {
        #expect(CompetitiveSubmissionQueue.safeCategory("Bearer eyJ.abc/def") == "bearer_eyj_abc_def")
        #expect(CompetitiveSubmissionQueue.safeCategory("") == "unknown")
        #expect(CompetitiveSubmissionQueue.safeCategory(String(repeating: "a", count: 200)).count == 48)
    }

    @Test func finishedHistoryIsPrunedButPendingKept() {
        var queue = CompetitiveSubmissionQueue()
        let user = UUID()
        let pending = P14.payload(user: user)
        queue.enqueue(pending, owner: user, now: P14.start)
        for i in 0..<30 {
            let p = P14.payload(user: user)
            queue.enqueue(p, owner: user, now: P14.start)
            queue.apply(.verified(finalScore: i, duplicate: false), to: p.matchID, now: P14.start.addingTimeInterval(Double(i)))
        }
        #expect(queue.items.filter(\.state.isFinished).count == CompetitiveSubmissionQueue.finishedHistoryLimit)
        #expect(queue.item(matchID: pending.matchID)?.state == .pending)
    }

    @Test func queueSurvivesRelaunchAndRecoversInFlightAttempts() {
        let defaults = P14.defaults()
        var queue = CompetitiveSubmissionQueue()
        let user = UUID()
        let payload = P14.payload(user: user)
        queue.enqueue(payload, owner: user, now: P14.start)
        queue.markSubmitting(payload.matchID)
        CompetitiveSubmissionStore.save(queue, defaults: defaults)

        var relaunched = CompetitiveSubmissionStore.load(defaults: defaults)
        #expect(relaunched.item(matchID: payload.matchID)?.state == .submitting)
        relaunched.recoverInterruptedAttempts()
        #expect(relaunched.item(matchID: payload.matchID)?.state == .pending)
        #expect(relaunched.item(matchID: payload.matchID)?.payload == payload)
    }
}

// MARK: - Submission service

@MainActor
final class MockCompetitiveSubmitter: CompetitiveResultSubmitting {
    var responses: [CompetitiveSubmitResponse] = []
    private(set) var submitted: [UUID] = []

    func submit(_ payload: CompetitiveResultPayload) async -> CompetitiveSubmitResponse {
        submitted.append(payload.matchID)
        return responses.isEmpty ? .verified(finalScore: 50, duplicate: false) : responses.removeFirst()
    }
}

@MainActor
@Suite("Phase 14 — submission service")
struct Phase14ServiceTests {

    @Test func verifiedSubmissionIsPersisted() async {
        let defaults = P14.defaults()
        let user = UUID()
        let submitter = MockCompetitiveSubmitter()
        submitter.responses = [.verified(finalScore: 77, duplicate: false)]
        let service = CompetitiveSubmissionService(defaults: defaults, submitter: submitter, currentUserID: { user }, now: { P14.start })
        let payload = P14.payload(user: user)
        service.enqueue(payload)
        await service.flush()
        #expect(submitter.submitted == [payload.matchID])
        #expect(service.queue.item(matchID: payload.matchID)?.state == .verified)
        #expect(service.queue.item(matchID: payload.matchID)?.finalScore == 77)

        let relaunched = CompetitiveSubmissionService(defaults: defaults, submitter: submitter, currentUserID: { user }, now: { P14.start })
        #expect(relaunched.queue.item(matchID: payload.matchID)?.state == .verified)
        await relaunched.flush()
        #expect(submitter.submitted.count == 1) // never resubmitted
    }

    @Test func retryableStopsThePassAndSurvivesRelaunch() async {
        let defaults = P14.defaults()
        let user = UUID()
        let submitter = MockCompetitiveSubmitter()
        submitter.responses = [.retryable(category: "network")]
        var clock = P14.start
        let service = CompetitiveSubmissionService(defaults: defaults, submitter: submitter, currentUserID: { user }, now: { clock })
        let first = P14.payload(user: user)
        service.enqueue(first)
        clock = clock.addingTimeInterval(1)
        service.enqueue(P14.payload(user: user))
        await service.flush()
        #expect(submitter.submitted == [first.matchID])
        #expect(service.queue.pendingCount == 2)

        // Relaunch after the backoff: both go through.
        clock = clock.addingTimeInterval(120)
        let relaunched = CompetitiveSubmissionService(defaults: defaults, submitter: submitter, currentUserID: { user }, now: { clock })
        #expect(relaunched.queue.pendingCount == 2)
        await relaunched.flush()
        #expect(relaunched.queue.pendingCount == 0)
        #expect(submitter.submitted.count == 3)
    }

    @Test func otherAccountsAndGuestsNeverFlush() async {
        let submitter = MockCompetitiveSubmitter()
        let owner = UUID()
        let other = CompetitiveSubmissionService(defaults: P14.defaults(), submitter: submitter, currentUserID: { UUID() }, now: { P14.start })
        other.enqueue(P14.payload(user: owner))
        await other.flush()
        let guest = CompetitiveSubmissionService(defaults: P14.defaults(), submitter: submitter, currentUserID: { nil }, now: { P14.start })
        guest.enqueue(P14.payload(user: owner))
        await guest.flush()
        #expect(submitter.submitted.isEmpty)
    }

    @Test func noRepositoryKeepsItemsQueued() async {
        let user = UUID()
        let service = CompetitiveSubmissionService(defaults: P14.defaults(), submitter: nil, currentUserID: { user }, now: { P14.start })
        #expect(!service.isRepositoryConnected)
        service.enqueue(P14.payload(user: user))
        await service.flush()
        #expect(service.queue.pendingCount == 1)
    }

    @Test func ineligibleOutcomeIsOnlyNoted() {
        let service = CompetitiveSubmissionService(defaults: P14.defaults(), submitter: MockCompetitiveSubmitter(), currentUserID: { UUID() }, now: { P14.start })
        service.handle(.ineligible(.guestPlayer))
        #expect(service.lastIneligibleReason == .guestPlayer)
        #expect(service.queue.items.isEmpty)
    }

    @Test func rejectionNeverRetries() async {
        let user = UUID()
        let submitter = MockCompetitiveSubmitter()
        submitter.responses = [.rejected(reason: "placement_mismatch")]
        let service = CompetitiveSubmissionService(defaults: P14.defaults(), submitter: submitter, currentUserID: { user }, now: { P14.start })
        let payload = P14.payload(user: user)
        service.enqueue(payload)
        await service.flush()
        await service.flush()
        #expect(submitter.submitted.count == 1)
        #expect(service.queue.item(matchID: payload.matchID)?.state == .rejected)
    }
}

// MARK: - Leaderboard view model

@MainActor
final class MockLeaderboardRepository: LeaderboardRepository {
    var all: [LeaderboardEntry] = []
    var mine: LeaderboardEntry?
    var error: Error?
    var players: [PublicPlayerFile] = []
    private(set) var pageCalls = 0
    private(set) var searchQueries: [String] = []

    func page(board: LeaderboardBoard, difficulty: LeaderboardDifficultyFilter, limit: Int, offset: Int) async throws -> [LeaderboardEntry] {
        pageCalls += 1
        if let error { throw error }
        guard offset < all.count else { return [] }
        return Array(all[offset..<min(all.count, offset + limit)])
    }

    func myStanding(board: LeaderboardBoard, difficulty: LeaderboardDifficultyFilter) async throws -> LeaderboardEntry? {
        if let error { throw error }
        return mine
    }

    func searchPlayers(query: String, limit: Int) async throws -> [PublicPlayerFile] {
        searchQueries.append(query)
        if let error { throw error }
        return players
    }

    func playerFile(userID: UUID) async throws -> PublicPlayerFile? {
        players.first { $0.id == userID }
    }
}

@MainActor
@Suite("Phase 14 — leaderboard view model")
struct Phase14LeaderboardViewModelTests {

    private func makeModel(_ repo: MockLeaderboardRepository?, user: UUID? = nil) -> LeaderboardViewModel {
        LeaderboardViewModel(repository: repo, currentUserID: user, cache: LeaderboardCache(), pageSize: 50, searchDebounce: .milliseconds(5))
    }

    @Test func paginatesInPagesOfFifty() async {
        let repo = MockLeaderboardRepository()
        repo.all = (1...120).map { P14.entry(rank: $0) }
        let model = makeModel(repo)
        await model.load()
        #expect(model.state == .loaded)
        #expect(model.entries.count == 50)
        #expect(model.canLoadMore)
        await model.loadMoreIfNeeded(current: model.entries[10]) // not the last row
        #expect(model.entries.count == 50)
        await model.loadMoreIfNeeded(current: model.entries.last!)
        #expect(model.entries.count == 100)
        await model.loadMoreIfNeeded(current: model.entries.last!)
        #expect(model.entries.count == 120)
        #expect(!model.canLoadMore)
        #expect(model.entries.map(\.rank) == Array(1...120))
    }

    @Test func pinnedRankOnlyWhenOffscreen() async {
        let me = UUID()
        let repo = MockLeaderboardRepository()
        repo.all = (1...10).map { P14.entry(rank: $0) }
        repo.mine = P14.entry(rank: 412, user: me)
        let model = makeModel(repo, user: me)
        await model.load()
        #expect(model.pinnedStanding?.rank == 412)

        let visible = MockLeaderboardRepository()
        let mine = P14.entry(rank: 3, user: me)
        visible.all = [P14.entry(rank: 1), P14.entry(rank: 2), mine]
        visible.mine = mine
        let model2 = makeModel(visible, user: me)
        await model2.load()
        #expect(model2.pinnedStanding == nil)
        #expect(model2.isCurrentUser(mine))
        #expect(!model2.isCurrentUser(visible.all[0]))
    }

    @Test func offlineAndUnavailableStates() async {
        let offline = MockLeaderboardRepository()
        offline.error = URLError(.notConnectedToInternet)
        let model = makeModel(offline)
        await model.load()
        #expect(model.state == .offline)
        #expect(model.entries.isEmpty)

        struct Boom: Error {}
        let broken = MockLeaderboardRepository()
        broken.error = Boom()
        let model2 = makeModel(broken)
        await model2.load()
        #expect(model2.state == .unavailable)

        let model3 = makeModel(nil)
        await model3.load()
        #expect(model3.state == .unavailable)
    }

    @Test func emptyBoard() async {
        let model = makeModel(MockLeaderboardRepository())
        await model.load()
        #expect(model.state == .empty)
    }

    @Test func cacheAvoidsRefetchUntilForced() async {
        let repo = MockLeaderboardRepository()
        repo.all = [P14.entry(rank: 1)]
        let cache = LeaderboardCache()
        let model = LeaderboardViewModel(repository: repo, currentUserID: nil, cache: cache, pageSize: 50)
        await model.load()
        await model.load()
        #expect(repo.pageCalls == 1)
        await model.refresh()
        #expect(repo.pageCalls == 2)
        cache.invalidate()
        await model.load()
        #expect(repo.pageCalls == 3)
    }

    @Test func cacheExpiresAfterSixtySeconds() {
        let cache = LeaderboardCache()
        let key = LeaderboardCache.Key(board: .weekly, difficulty: .all)
        let fetched = Date(timeIntervalSince1970: 1_000)
        cache.store(.init(entries: [], mine: nil, canLoadMore: false, fetchedAt: fetched), for: key)
        #expect(cache.snapshot(for: key, now: fetched.addingTimeInterval(59)) != nil)
        #expect(cache.snapshot(for: key, now: fetched.addingTimeInterval(61)) == nil)
    }

    @Test func searchIsDebouncedAndValidated() async throws {
        let repo = MockLeaderboardRepository()
        repo.players = [PublicPlayerFile(id: UUID(), username: "gridiron_ace", footballDisplayName: "Ace", globalRating: 88, careerGamesPlayed: 10, careerWins: 7, championships: 0)]
        let model = makeModel(repo)
        model.searchText = "a"
        model.searchText = "a b!"
        try await Task.sleep(for: .milliseconds(60))
        #expect(repo.searchQueries.isEmpty)

        model.searchText = "Gr"
        model.searchText = "Grid"
        try await Task.sleep(for: .milliseconds(150))
        #expect(repo.searchQueries == ["grid"])
        #expect(model.searchResults.count == 1)
        #expect(!model.isSearching)
    }
}

// MARK: - Formatting + models

@MainActor
@Suite("Phase 14 — leaderboard formatting")
struct Phase14FormattingTests {

    @Test func weeklyAndAllTimeScores() {
        #expect(LeaderboardFormat.score(P14.entry(rank: 1, score: 412), board: .weekly) == "412")
        #expect(LeaderboardFormat.score(P14.entry(rank: 1, score: 92.44), board: .allTime) == "92.4")
        #expect(LeaderboardFormat.score(P14.entry(rank: 1, score: 92.4, provisional: true), board: .allTime) == "92.4 — PROVISIONAL")
    }

    @Test func difficultyBadges() {
        #expect(LeaderboardFormat.difficultyBadge("rookie") == "RK")
        #expect(LeaderboardFormat.difficultyBadge("pro") == "PRO")
        #expect(LeaderboardFormat.difficultyBadge("all_pro") == "AP")
        #expect(LeaderboardFormat.difficultyBadge("hall_of_famer") == "HOF")
        #expect(LeaderboardFormat.difficultyBadge("??") == "—")
    }

    @Test func podiumForTopThreeOnly() {
        #expect(P14.entry(rank: 1).podium == .gold)
        #expect(P14.entry(rank: 2).podium == .silver)
        #expect(P14.entry(rank: 3).podium == .bronze)
        #expect(P14.entry(rank: 4).podium == nil)
    }

    @Test func boardAndFilterWireValues() {
        #expect(LeaderboardBoard.allTime.rawValue == "alltime")
        #expect(LeaderboardDifficultyFilter.allCases.map(\.rawValue) == ["all", "rookie", "pro", "all_pro", "hall_of_famer"])
        #expect(LeaderboardDifficultyFilter.hallOfFamer.difficulty == .hallOfFamer)
        #expect(LeaderboardDifficultyFilter.all.difficulty == nil)
    }

    @Test func searchNormalization() {
        #expect(PlayerSearchQuery.normalized("  Ace_99 ") == "ace_99")
        #expect(PlayerSearchQuery.normalized("a") == nil)
        #expect(PlayerSearchQuery.normalized(String(repeating: "a", count: 21)) == nil)
        #expect(PlayerSearchQuery.normalized("bad name") == nil)
        #expect(PlayerSearchQuery.normalized("x'; drop") == nil)
    }

    @Test func decodesServerRowsWithAndWithoutFractionalSeconds() throws {
        let json = """
        [{"rank":1,"user_id":"\(UUID().uuidString)","username":"ace","football_display_name":"Ace","score":412,
          "games_counted":10,"total_games":14,"average_score":41.2,"wins":9,"quarters_solved":35,"hints_used":2,
          "wrong_placements":4,"top_difficulty":"hall_of_famer","is_provisional":false,"first_reached_at":"2026-10-20T12:30:01.123456+00:00"},
         {"rank":2,"user_id":"\(UUID().uuidString)","username":"bee","football_display_name":"Bee","score":400.5,
          "games_counted":3,"total_games":3,"average_score":133.5,"wins":3,"quarters_solved":12,"hints_used":0,
          "wrong_placements":0,"top_difficulty":"pro","is_provisional":true,"first_reached_at":"2026-10-20T12:30:01+00:00"}]
        """
        let rows = try LeaderboardDecoding.decoder().decode([LeaderboardEntry].self, from: Data(json.utf8))
        #expect(rows.count == 2)
        #expect(rows[0].topDifficultyLevel == .hallOfFamer)
        #expect(rows[1].isProvisional)
        #expect(rows[0].firstReachedAt != nil && rows[1].firstReachedAt != nil)
    }

    @Test func publicPlayerFileHasNoPrivateFields() throws {
        let file = PublicPlayerFile(id: UUID(), username: "ace", footballDisplayName: "Ace", globalRating: 90, careerGamesPlayed: 3, careerWins: 2, championships: 0)
        let data = try JSONEncoder().encode(file)
        let keys = Set(try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any]).keys)
        #expect(!keys.contains { $0.contains("email") || $0.contains("real") || $0.contains("first_name") || $0.contains("last_name") })
    }
}

import Foundation
import Testing
@testable import GameSceneGridiron

// MARK: - Phase 15A — asynchronous 1-v-1 Versus foundation
//
//  * schema pins (fixture): tables, RLS, privileges, constraints, locks,
//    snapshot, tiebreak order, lazy expiry, no purchased advantage, privacy,
//    Ranked untouched,
//  * Edge Function pins (fixture): JWT-only, difficulty-only, no score,
//    410 expiry, rate-limit order,
//  * Swift models: wire decoding, rules, local pre-flight,
//  * VersusService with a mock backend + response classification.
//
// The behavioral database scenarios (real Postgres in PGlite) live in
// scripts/verify-versus-sql.mjs; the Edge handlers run in
// scripts/verify-versus-edge.mjs.

private enum P15A {
    static let sql = SchemaFixture.sql
    static let normalized: String = sql
        .components(separatedBy: "\n")
        .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("--") }
        .joined(separator: "\n")
        .lowercased()
        .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)

    /// The Versus section only (section 8).
    static let versus: String = {
        guard let start = sql.range(of: "-- 8. PHASE 15A"),
              let end = sql.range(of: "-- Future tables (Phase 13A defines the shape", range: start.upperBound..<sql.endIndex) else { return "" }
        return String(sql[start.lowerBound..<end.lowerBound])
    }()
    static let versusNormalized: String = versus
        .components(separatedBy: "\n")
        .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("--") }
        .joined(separator: "\n")
        .lowercased()
        .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)

    /// Text of one function definition in the Versus section.
    static func function(_ name: String) -> String {
        guard let start = versusNormalized.range(of: "create or replace function public.\(name)(") else { return "" }
        let rest = versusNormalized[start.upperBound...]
        guard let end = rest.range(of: "create or replace function public.") else { return String(rest) }
        return String(rest[..<end.lowerBound])
    }

    static let find = VersusEdgeFunctionFixture.findVersusMatch
    static let submit = VersusEdgeFunctionFixture.submitVersusResult

    static let matchJSON = """
    {"match_id":"6f2b6c1e-1111-2222-3333-444444444444","status":"active","player_state":"opponent_pending",
     "role":"player_a","difficulty":"all_pro","case_ids":["a","b","c","d","e"],"case_versions":[1,1,2,1,1],
     "catalog_fingerprint":"a30cb39044dc193b","content_source":"bundled_dev_fallback",
     "created_at":"2026-11-02T10:00:00.123Z","matched_at":"2026-11-02T10:05:00Z","expires_at":"2026-11-03T10:05:00.000Z",
     "completed_at":null,"opponent_user_id":"7a7a7a7a-1111-2222-3333-444444444444","opponent_username":"ben_qb",
     "opponent_display_name":"B. Hidden","my_submitted":true,"my_final_score":69,"my_cases_solved":4,
     "opponent_submitted":false,"opponent_final_score":null,"opponent_cases_solved":null,"outcome":null,
     "is_forfeit":false,"resolution":null,"reused":true}
    """

    static func match(state: VersusPlayerState = .active, caseIDs: [String] = ["a", "b", "c", "d", "e"]) -> VersusMatch {
        VersusMatch(
            matchID: UUID(), status: .active, playerState: state, role: "player_b", difficulty: "pro",
            caseIDs: caseIDs, caseVersions: [1, 1, 1, 1, 1], catalogFingerprint: "fp", contentSource: .bundledDevFallback,
            createdAt: "2026-11-02T10:00:00Z", matchedAt: nil, expiresAt: "2026-11-03T10:00:00Z", completedAt: nil,
            opponentUserID: nil, opponentUsername: nil, opponentDisplayName: nil, mySubmitted: false,
            myFinalScore: nil, myCasesSolved: nil, opponentSubmitted: false, opponentFinalScore: nil,
            opponentCasesSolved: nil, outcome: nil, isForfeit: false, resolution: nil, reused: nil
        )
    }

    static func caseResult(_ index: Int, id: String? = nil, version: Int = 1, hints: Int = 0) -> CompetitiveCaseResult {
        CompetitiveCaseResult(
            caseID: id ?? ["a", "b", "c", "d", "e"][index], caseVersion: version, quarterIndex: index,
            outcome: .solved, hintsUsed: hints, wrongPlacements: 0,
            placements: [CompetitivePlacement(playerKey: "p1", slotKey: "s1", profile: "veteran")]
        )
    }
}

final class MockVersusBackend: VersusBackend, @unchecked Sendable {
    var findCalls: [String] = []
    var submitted: [VersusResultPayload] = []
    var findResult: VersusFindResult = .retryable(category: "network")
    var submitResult: VersusSubmitResult = .retryable(category: "network")

    func findMatch(difficulty: String) async -> VersusFindResult {
        findCalls.append(difficulty)
        return findResult
    }
    func submit(_ payload: VersusResultPayload) async -> VersusSubmitResult {
        submitted.append(payload)
        return submitResult
    }
    func myOpenMatches() async throws -> [VersusMatch] { [] }
    func myHistory(limit: Int, offset: Int) async throws -> [VersusHistoryEntry] { [] }
    func publicRecord(userID: UUID) async throws -> VersusCareerRecord? { nil }
}

// MARK: Schema

@Suite("Phase 15A — Versus schema")
struct Phase15ASchemaTests {
    @Test func versusSectionExistsBeforeFutureTables() {
        #expect(!P15A.versus.isEmpty)
        #expect(P15A.versus.contains("create table if not exists public.versus_matches"))
    }

    @Test func everyVersusTableHasRLSAndNoClientPrivileges() {
        for table in ["versus_config", "versus_matches", "versus_match_solutions", "versus_match_results",
                      "versus_career_stats", "versus_rate_limits"] {
            #expect(P15A.versusNormalized.contains("alter table public.\(table) enable row level security"), "\(table) RLS")
            #expect(P15A.versusNormalized.contains("revoke all on public.\(table) from anon, authenticated"), "\(table) revoke")
        }
        for table in ["versus_matches", "versus_match_solutions", "versus_match_results", "versus_career_stats"] {
            #expect(P15A.versusNormalized.contains("alter table public.\(table) force row level security"), "\(table) force")
        }
        #expect(!P15A.versusNormalized.contains("grant select on public.versus"))
        #expect(!P15A.versusNormalized.contains("create policy"))
    }

    @Test func everySecurityDefinerPinsSearchPath() {
        let definers = P15A.versusNormalized.components(separatedBy: "security definer").count - 1
        let pinned = P15A.versusNormalized.components(separatedBy: "security definer set search_path = ''").count - 1
        #expect(definers == 10)
        #expect(definers == pinned)
        // Whole-file invariant shared with Phase 14B.
        #expect(P15A.normalized.components(separatedBy: "security definer").count
                == P15A.normalized.components(separatedBy: "security definer set search_path = ''").count)
    }

    @Test func writersAreServiceRoleOnly() {
        for signature in ["versus_find_match(uuid, text)",
                          "versus_record_result(uuid, uuid, jsonb, timestamptz, timestamptz, text, int)",
                          "consume_versus_rate_limit(uuid, text)", "versus_expire_due(uuid)", "versus_player_rows(uuid)"] {
            #expect(P15A.versusNormalized.contains("revoke all on function public.\(signature) from public, anon, authenticated"), "\(signature)")
            #expect(P15A.versusNormalized.contains("grant execute on function public.\(signature) to service_role"), "\(signature)")
        }
        #expect(P15A.versusNormalized.contains("revoke all on function public.versus_bump_stats(uuid, int, int, int, int, int) from public, anon, authenticated"))
        #expect(P15A.versusNormalized.contains("revoke all on function public.versus_resolve_locked(uuid) from public, anon, authenticated"))
    }

    @Test func readsAreAuthenticatedOnlyAndUseAuthUID() {
        for fn in ["my_versus_matches()", "my_versus_history(int, int)", "versus_public_record(uuid)"] {
            #expect(P15A.versusNormalized.contains("revoke all on function public.\(fn) from public, anon"), "\(fn)")
            #expect(P15A.versusNormalized.contains("grant execute on function public.\(fn) to authenticated"), "\(fn)")
        }
        #expect(P15A.function("my_versus_matches").contains("auth.uid()"))
        #expect(P15A.function("my_versus_history").contains("auth.uid()"))
        #expect(P15A.function("versus_public_record").contains("raise exception 'auth_required'"))
        #expect(P15A.function("my_versus_history").contains("least(greatest(coalesce(p_limit, 20), 1), 50)"))
    }

    @Test func selfMatchAndDuplicateWaitingAreImpossible() {
        #expect(P15A.versusNormalized.contains("constraint versus_matches_no_self_match check (player_b_id is null or player_b_id <> player_a_id)"))
        #expect(P15A.versusNormalized.contains("create unique index if not exists versus_matches_one_waiting_per_user on public.versus_matches (player_a_id) where status = 'waiting_for_opponent'"))
        let find = P15A.function("versus_find_match")
        #expect(find.contains("m.player_a_id <> p_user_id"))
        #expect(find.contains("and m.difficulty = p_difficulty"))
    }

    @Test func matchmakingIsSerializedAndConcurrencySafe() {
        let find = P15A.function("versus_find_match")
        guard let userLock = find.range(of: "pg_advisory_xact_lock(hashtextextended('versus:user:'"),
              let queueLock = find.range(of: "pg_advisory_xact_lock(hashtextextended('versus:queue:'") else {
            Issue.record("advisory locks missing"); return
        }
        #expect(userLock.lowerBound < queueLock.lowerBound, "fixed lock order: user then queue")
        #expect(find.contains("for update skip locked"))
        #expect(find.contains("order by m.created_at asc, m.match_id asc"))
        // No duplicate active pairing.
        #expect(find.contains("x.status = 'active'"))
        // Retry / double tap returns the same match.
        #expect(find.contains("return query select v.*, true from public.versus_player_rows(p_user_id) v"))
        #expect(find.contains("raise exception 'versus_already_waiting'"))
        #expect(find.contains("raise exception 'versus_match_in_progress'"))
    }

    @Test func snapshotIsPrivateAndPrefersServerContent() {
        let find = P15A.function("versus_find_match")
        #expect(find.contains("insert into public.versus_match_solutions (match_id, expected_solutions)"))
        #expect(find.contains("foreach v_dist in array array['server_assigned', 'client_bundled']"))
        #expect(find.contains("cfg.allow_bundled_fallback"))
        #expect(find.contains("'bundled_dev_fallback'"))
        // random() is evaluated once per band (never per row inside WHERE).
        #expect(find.contains("v_pick := floor(v_mode * (v_n - v_w) / 3.0)::int + floor(random() * v_w)::int"))
        #expect(find.contains("where o.idx = v_pick"))
        // The player-facing row builder never touches solutions.
        #expect(!P15A.function("versus_player_rows").contains("versus_match_solutions"))
        #expect(!P15A.function("versus_player_rows").contains("expected_solutions"))
    }

    @Test func resultsVerifiedAgainstSnapshotAndRecordedOnce() {
        let record = P15A.function("versus_record_result")
        for code in ["versus_not_a_member", "versus_match_closed", "case_mismatch", "case_version_mismatch",
                     "placement_mismatch", "solved_case_incomplete", "failed_case_complete", "overtime_mismatch",
                     "versus_hints_not_allowed", "client_outdated"] {
            #expect(record.contains("raise exception '\(code)'"), "\(code)")
        }
        #expect(record.contains("from public.versus_matches m where m.match_id = p_match_id for update"))
        #expect(record.contains("when unique_violation then"))
        #expect(record.contains("'duplicate'::text"))
        #expect(record.contains("'expired'::text"))
        #expect(P15A.versusNormalized.contains("constraint versus_match_results_once unique (match_id, user_id)"))
        // Score is server-derived from versus_config.
        #expect(record.contains("v_solved * cfg.quarter_solved_points"))
    }

    @Test func tiebreakOrderAndExpiryRules() {
        let resolve = P15A.function("versus_resolve_locked")
        guard let score = resolve.range(of: "v_res := 'score'"),
              let cases = resolve.range(of: "v_res := 'cases_solved'"),
              let quarters = resolve.range(of: "v_res := 'regulation_quarters'"),
              let tie = resolve.range(of: "v_res := 'tie'") else {
            Issue.record("tiebreak steps missing"); return
        }
        #expect(score.lowerBound < cases.lowerBound && cases.lowerBound < quarters.lowerBound && quarters.lowerBound < tie.lowerBound)
        #expect(!resolve.contains("elapsed"), "elapsed time is not a 15A tiebreaker")
        #expect(resolve.contains("resolution = 'expired_no_opponent'"))
        #expect(resolve.contains("resolution = 'forfeit'"))
        #expect(resolve.contains("resolution = 'expired_unplayed'"))
        #expect(resolve.contains("perform public.versus_bump_stats(v_winner, 1, 0, 0, 1, 0)"))
        #expect(P15A.function("versus_expire_due").contains("for update skip locked"))
    }

    @Test func noPurchasedAdvantage() {
        #expect(P15A.versusNormalized.contains("check (purchasable_hints_allowed = false)"))
        #expect(!VersusRules.purchasableHintsEnabled)
    }

    @Test func publicExposureNeverIncludesPrivateNames() {
        for fn in ["versus_player_rows", "versus_public_record", "my_versus_history", "my_versus_matches"] {
            let body = P15A.function(fn)
            #expect(!body.contains("first_name") && !body.contains("last_name") && !body.contains("email"), "\(fn)")
        }
        #expect(P15A.function("versus_player_rows").contains("left join public.public_profiles opp"))
        #expect(P15A.function("versus_player_rows").contains("case when m.status = 'completed' then theirs.final_score end"))
    }

    @Test func rankedIsUntouchedByVersus() {
        // Versus never writes Ranked tables or the profile career counters.
        for forbidden in ["insert into public.ranked_", "update public.ranked_", "update public.profiles",
                          "ranked_scoring_config", "consume_ranked_rate_limit"] {
            #expect(!P15A.versusNormalized.contains(forbidden), "\(forbidden)")
        }
        #expect(!P15A.versus.contains("or true"))
        #expect(!P15A.normalized.contains("or true"))
    }
}

// MARK: Edge Functions

@Suite("Phase 15A — Versus Edge Functions")
struct Phase15AEdgeTests {
    @Test func findUsesJWTAndDifficultyOnly() {
        #expect(P15A.find.contains("admin.auth.getUser(token)"))
        #expect(P15A.find.contains(#"const ALLOWED_KEYS = new Set(["difficulty"]);"#))
        #expect(P15A.find.contains(#"ensure(ALLOWED_KEYS.has(key), "unexpected_field")"#))
        #expect(P15A.find.contains("p_user_id: userID,\n    p_difficulty: request.difficulty,"))
        #expect(!P15A.find.contains("body.user_id") && !P15A.find.contains("opponent_id:"))
    }

    @Test func findRateLimitsBeforeMatchmaking() {
        guard let limit = P15A.find.range(of: #"admin.rpc("consume_versus_rate_limit""#),
              let match = P15A.find.range(of: #"admin.rpc("versus_find_match""#) else {
            Issue.record("rpc calls missing"); return
        }
        #expect(limit.lowerBound < match.lowerBound)
        #expect(P15A.find.contains(#"p_bucket: "find""#))
    }

    @Test func findHidesOpponentNumbersAndSolutions() {
        #expect(P15A.find.contains("opponent_final_score: completed ? (row.opponent_final_score ?? null) : null"))
        #expect(!P15A.find.contains("solution_variant:"))
        #expect(!P15A.find.contains("expected_solutions"))
    }

    @Test func submitSendsNoScoreAndMapsExpiry() {
        #expect(P15A.submit.contains("admin.auth.getUser(token)"))
        #expect(P15A.submit.contains(#""unexpected_field""#))
        #expect(!P15A.submit.contains("p_final_score"))
        #expect(P15A.submit.contains(#"if (row.outcome === "expired") return reject("versus_match_expired", 410);"#))
        #expect(P15A.submit.contains(#"ensure(c.hints_used === 0, "versus_hints_not_allowed");"#))
        #expect(P15A.submit.contains(#"p_bucket: "submit""#))
        #expect(P15A.submit.contains("sanitizedVersusCaseResults(payload.case_results)"))
    }

    @Test func rankedEdgeFunctionsUnchangedPins() {
        #expect(EdgeFunctionFixture.startRankedMatch.contains("issue_ranked_match_assignment"))
        #expect(EdgeFunctionFixture.submitRankedResult.contains("record_verified_ranked_result"))
        #expect(!EdgeFunctionFixture.startRankedMatch.contains("versus"))
        #expect(!EdgeFunctionFixture.submitRankedResult.contains("versus"))
    }
}

// MARK: Models + service

@Suite("Phase 15A — Versus models and service")
@MainActor
struct Phase15AServiceTests {
    @Test func decodesMatchWire() throws {
        let match = try JSONDecoder().decode(VersusMatch.self, from: Data(P15A.matchJSON.utf8))
        #expect(match.status == .active)
        #expect(match.playerState == .opponentPending)
        #expect(match.contentSource == .bundledDevFallback)
        #expect(match.difficultyLevel == .allPro)
        #expect(match.caseVersions == [1, 1, 2, 1, 1])
        #expect(match.opponentFinalScore == nil)
        #expect(match.reused == true)
        #expect(match.expiresAtDate != nil)
        #expect(!match.playerState.needsMyPlay)
    }

    @Test func decodesHistoryAndRecord() throws {
        let history = """
        [{"match_id":"6f2b6c1e-1111-2222-3333-444444444444","difficulty":"pro","completed_at":"2026-11-02T11:00:00Z",
          "opponent_user_id":null,"opponent_username":"ava_qb","opponent_display_name":"A. Secret",
          "my_final_score":69,"opponent_final_score":0,"outcome":"win","is_forfeit":false,"resolution":"score"}]
        """
        let entries = try JSONDecoder().decode([VersusHistoryEntry].self, from: Data(history.utf8))
        #expect(entries.first?.outcome == .win && entries.first?.resolution == .score)
        let record = """
        [{"user_id":"7a7a7a7a-1111-2222-3333-444444444444","username":"ben_qb","football_display_name":"B. Hidden",
          "versus_games_played":3,"versus_wins":2,"versus_losses":1,"versus_ties":0,"versus_forfeit_wins":1,"versus_forfeit_losses":0}]
        """
        let records = try JSONDecoder().decode([VersusCareerRecord].self, from: Data(record.utf8))
        #expect(records.first?.wins == 2 && records.first?.forfeitWins == 1)
    }

    @Test func allServerEnumsDecode() throws {
        for raw in ["score", "cases_solved", "regulation_quarters", "tie", "forfeit", "expired_unplayed", "expired_no_opponent", "cancelled"] {
            #expect(VersusResolution(rawValue: raw) != nil, "\(raw)")
        }
        for raw in ["waiting_for_opponent", "submitted", "active", "opponent_pending", "completed", "expired", "cancelled"] {
            #expect(VersusPlayerState(rawValue: raw) != nil, "\(raw)")
        }
    }

    @Test func payloadEncodesNoIdentityOrScore() throws {
        let payload = VersusResultPayload(
            matchID: UUID(), startedAt: "2026-11-02T10:00:00.000Z", completedAt: "2026-11-02T10:10:00.000Z",
            caseResults: (0..<4).map { P15A.caseResult($0) }, gameVersion: "ios 1.0", versusProtocol: 1
        )
        let object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(payload)) as? [String: Any]
        #expect(Set(object?.keys.map { $0 } ?? []) == ["match_id", "started_at", "completed_at", "case_results", "game_version", "versus_protocol"])
    }

    @Test func findSendsDifficultyServerValueOnly() async {
        let backend = MockVersusBackend()
        let waiting = P15A.match(state: .waitingForOpponent)
        backend.findResult = .waiting(waiting)
        let service = VersusService(backend: backend, gameVersion: "ios 1.0")
        let result = await service.findMatch(difficulty: .hallOfFamer)
        #expect(backend.findCalls == ["hall_of_famer"])
        #expect(result == .waiting(waiting))
    }

    @Test func submitPreflightRejectsHintsAndWrongCases() async {
        let backend = MockVersusBackend()
        let service = VersusService(backend: backend, gameVersion: "ios 1.0")
        let match = P15A.match()
        let hinted = await service.submit(match: match, startedAt: Date(), caseResults: [P15A.caseResult(0, hints: 1)] + (1..<4).map { P15A.caseResult($0) })
        #expect(hinted == .rejected(reason: "versus_hints_not_allowed"))
        let swapped = await service.submit(match: match, startedAt: Date(), caseResults: [P15A.caseResult(0, id: "zzz")] + (1..<4).map { P15A.caseResult($0) })
        #expect(swapped == .rejected(reason: "case_mismatch"))
        let version = await service.submit(match: match, startedAt: Date(), caseResults: [P15A.caseResult(0, version: 9)] + (1..<4).map { P15A.caseResult($0) })
        #expect(version == .rejected(reason: "case_version_mismatch"))
        #expect(backend.submitted.isEmpty)
    }

    @Test func submitForwardsValidResult() async {
        let backend = MockVersusBackend()
        backend.submitResult = .expired
        let service = VersusService(backend: backend, gameVersion: "ios 1.0", now: { Date(timeIntervalSince1970: 1_800_000_000) })
        let result = await service.submit(match: P15A.match(), startedAt: Date(timeIntervalSince1970: 1_799_999_000),
                                          caseResults: (0..<4).map { P15A.caseResult($0) })
        #expect(result == .expired)
        #expect(backend.submitted.count == 1)
        #expect(backend.submitted.first?.versusProtocol == VersusRules.protocolVersion)
    }

    @Test func submitRefusesClosedMatch() async {
        let backend = MockVersusBackend()
        let service = VersusService(backend: backend, gameVersion: "ios 1.0")
        let result = await service.submit(match: P15A.match(state: .completed), startedAt: Date(), caseResults: [])
        #expect(result == .rejected(reason: "versus_match_closed"))
        #expect(backend.submitted.isEmpty)
    }

    @Test func classification() {
        #expect(VersusWire.findResult(statusCode: 409, reason: "versus_match_in_progress") == .rejected(reason: "versus_match_in_progress"))
        #expect(VersusWire.findResult(statusCode: 401, reason: "unauthorized") == .retryable(category: "unauthorized"))
        #expect(VersusWire.findResult(statusCode: 429, reason: nil) == .retryable(category: "rate_limited"))
        #expect(VersusWire.findResult(statusCode: 503, reason: "versus_catalog_unavailable") == .retryable(category: "server_503"))
        #expect(VersusWire.submitResult(statusCode: 410, reason: "versus_match_expired") == .expired)
        #expect(VersusWire.submitResult(statusCode: 403, reason: "versus_not_a_member") == .rejected(reason: "versus_not_a_member"))
        let waiting = P15A.match(state: .waitingForOpponent)
        #expect(VersusWire.findResult(from: .init(status: "waiting", match: waiting)) == .waiting(waiting))
        #expect(VersusWire.findResult(from: .init(status: "matched", match: waiting)) == .matched(waiting))
        #expect(VersusWire.findResult(from: .init(status: "matched", match: nil)) == .retryable(category: "unexpected_response"))
    }
}

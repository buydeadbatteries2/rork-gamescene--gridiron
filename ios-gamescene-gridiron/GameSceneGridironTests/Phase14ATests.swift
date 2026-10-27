import CryptoKit
import Foundation
import Testing
@testable import GameSceneGridiron

// MARK: - Phase 14A — leaderboard deployment blockers
//
//  * every competitive-eligible case carries the calibrated, content-derived
//    difficulty score (no placeholder / default / guessed values),
//  * the generated catalog matches the live library and its checksum is the
//    one public.competitive_catalog_checksum() verifies on paste,
//  * solutions stay private, weekly bucketing is server-validated and the
//    future Versus distribution path is reserved (schema + edge fixtures).

private enum P14A {
    static func normalizedSQL(_ raw: String) -> String {
        raw.components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("--") }
            .joined(separator: " ")
            .split(whereSeparator: { $0 == " " || $0 == "\r" || $0 == "\n" || $0 == "\t" })
            .joined(separator: " ")
    }

    static let sql = normalizedSQL(SchemaFixture.sql)
    static let edge = EdgeFunctionFixture.submitRankedResult

    static func section(from marker: String, to endMarker: String) -> String {
        guard let start = sql.range(of: marker),
              let end = sql.range(of: endMarker, range: start.upperBound..<sql.endIndex) else { return "" }
        return String(sql[start.lowerBound..<end.upperBound])
    }

    static let serverDifficulty: [DifficultyLevel: String] = [
        .rookie: "rookie", .pro: "pro", .allPro: "all_pro", .hallOfFamer: "hall_of_famer",
    ]

    static func md5(_ text: String) -> String {
        Insecure.MD5.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    /// Canonical catalog lines, split into fields.
    static let lines: [[String]] = CompetitiveCatalogFixture.canonicalLines
        .split(separator: "\n").map { $0.split(separator: "|", omittingEmptySubsequences: false).map(String.init) }

    static let eligible: [QuarterCase] = CaseLibrary.all.filter(\.isCompetitiveEligible)
}

// MARK: Calibrated difficulty scores

@MainActor
struct Phase14ACalibrationTests {
    @Test func libraryHas150UniqueEligibleCases() {
        #expect(CaseLibrary.all.count == 150)
        #expect(Set(CaseLibrary.all.map(\.id)).count == 150)
        #expect(P14A.eligible.count == 150)
        #expect(CaseLibrary.all.allSatisfy { $0.metadata != nil })
    }

    @Test func everyScoreEqualsTheCalibrationModel() {
        for c in P14A.eligible {
            guard let meta = c.metadata else { Issue.record("\(c.id) has no metadata"); continue }
            let expected = CaseDifficultyCalibration.score(of: c, tier: meta.tier)
            #expect(meta.difficultyScore == expected, "\(c.id): authored \(meta.difficultyScore) ≠ calibrated \(expected)")
        }
    }

    @Test func everyScoreIsNonZeroAndInsideItsTierBand() {
        for c in P14A.eligible {
            guard let meta = c.metadata, let band = CaseDifficultyCalibration.sanityBand[meta.tier] else {
                Issue.record("\(c.id) missing tier band"); continue
            }
            #expect(meta.difficultyScore >= 1 && meta.difficultyScore <= 100)
            #expect(band.contains(meta.difficultyScore), "\(c.id) \(meta.difficultyScore) outside \(band)")
        }
    }

    @Test func tierCountsAndOrderingMatchTheCurve() {
        let byTier = Dictionary(grouping: P14A.eligible) { $0.metadata!.tier }
        #expect(byTier[.rookie]?.count == 30)
        #expect(byTier[.pro]?.count == 40)
        #expect(byTier[.allPro]?.count == 40)
        #expect(byTier[.hallOfFamer]?.count == 40)
        func mean(_ t: DifficultyLevel) -> Double {
            let s = byTier[t]!.map { Double($0.metadata!.difficultyScore) }
            return s.reduce(0, +) / Double(s.count)
        }
        #expect(mean(.rookie) < mean(.pro))
        #expect(mean(.pro) < mean(.allPro))
        #expect(mean(.allPro) < mean(.hallOfFamer))
    }

    @Test func scoresVaryWithContentNotJustTier() {
        // Not an enum lookup: every tier spreads across several values.
        let byTier = Dictionary(grouping: P14A.eligible) { $0.metadata!.tier }
        for (tier, cases) in byTier {
            #expect(Set(cases.map { $0.metadata!.difficultyScore }).count >= 3, "\(tier) collapsed to a constant")
        }
    }

    @Test func moreContentNeverScoresLower() {
        // Same tier, strictly heavier content on every axis → never a lower score.
        let base = CaseDifficultyCalibration.Features(missing: 4, decoys: 4, evidence: 4, clueComplexity: 0.55,
                                                      hardShare: 0.1, chainedShare: 0, negativeShare: 0,
                                                      relationalShare: 0.1, distinctProfiles: 2)
        let heavy = CaseDifficultyCalibration.Features(missing: 6, decoys: 7, evidence: 6, clueComplexity: 0.7,
                                                       hardShare: 0.5, chainedShare: 0.25, negativeShare: 0.25,
                                                       relationalShare: 0.5, distinctProfiles: 4)
        for tier in DifficultyLevel.allCases {
            #expect(CaseDifficultyCalibration.contentComplexity(heavy, tier: tier)
                    > CaseDifficultyCalibration.contentComplexity(base, tier: tier))
        }
        #expect(CaseDifficultyCalibration.timerPressure(heavy, tier: .hallOfFamer) == 1)
        #expect(CaseDifficultyCalibration.timerPressure(heavy, tier: .allPro) == 0)
    }

    @Test func trainingCaseIsNeverCompetitive() {
        #expect(TrainingCase.authored.isCompetitiveEligible == false)
        #expect(CompetitiveCaseCatalog.entries[TrainingCase.authored.id] == nil)
    }
}

// MARK: Catalog + checksum

@MainActor
struct Phase14ACatalogTests {
    @Test func catalogEntriesMatchLiveMetadata() {
        #expect(CompetitiveCaseCatalog.caseCount == 150)
        #expect(CompetitiveCaseCatalog.entries.count == 150)
        for c in P14A.eligible {
            guard let entry = CompetitiveCaseCatalog.entries[c.id], let meta = c.metadata else {
                Issue.record("\(c.id) missing from catalog"); continue
            }
            #expect(entry.tier == meta.tier)
            #expect(entry.difficultyScore == meta.difficultyScore)
            #expect(entry.isCompetitiveEligible == meta.isCompetitiveEligible)
            #expect(entry.difficultyScore > 0)
        }
    }

    @Test func checksumRecomputesFromCanonicalLines() {
        let text = CompetitiveCatalogFixture.canonicalLines
        let sorted = text.split(separator: "\n").map(String.init).sorted { Array($0.utf8).lexicographicallyPrecedes(Array($1.utf8)) }
        #expect(sorted.joined(separator: "\n") == text, "fixture lines must be in byte order")
        #expect(P14A.md5(text) == CompetitiveCaseCatalog.catalogChecksum)
    }

    @Test func canonicalLinesMatchLibraryAndCatalog() {
        #expect(P14A.lines.count == 150)
        var seen = Set<String>()
        for f in P14A.lines {
            #expect(f.count == 11)
            guard f.count == 11, let c = CaseLibrary.caseByID(f[0]), let meta = c.metadata,
                  let entry = CompetitiveCaseCatalog.entries[f[0]] else {
                Issue.record("unknown catalog line \(f.first ?? "")"); continue
            }
            seen.insert(f[0])
            #expect(f[1] == String(entry.version))
            #expect(f[2] == P14A.serverDifficulty[meta.tier])
            #expect(f[3] == String(meta.difficultyScore))
            #expect(f[4] == String(c.band))
            #expect(f[5] == String(c.solution.count))
            #expect(f[6] == "true")
            #expect(f[7] == "true")
            #expect(f[8] == "client_bundled")
            #expect(f[9] == entry.fingerprint)
            #expect(f[10].count == 32)
        }
        #expect(seen.count == 150)
    }

    @Test func solutionsNeverShipInTheAppCatalog() {
        // The app-side catalog has no solution field; solutions live only in
        // the private server table (and the test-only fixture).
        let entry = CompetitiveCaseCatalog.entries.values.first!
        let labels = Mirror(reflecting: entry).children.compactMap(\.label)
        #expect(Set(labels) == ["version", "fingerprint", "tier", "difficultyScore", "isCompetitiveEligible"])
    }
}

// MARK: Schema + Edge Function (fixtures)

@MainActor
struct Phase14AServerTests {
    @Test func competitiveCasesArePrivateAndScored() {
        let sql = P14A.sql
        #expect(sql.contains("alter table public.competitive_cases force row level security;"))
        #expect(sql.contains("revoke all on public.competitive_cases from public;"))
        #expect(sql.contains("revoke all on public.competitive_cases from anon, authenticated;"))
        #expect(!sql.contains("on public.competitive_cases for select"))
        #expect(sql.contains("check (distribution in ('client_bundled', 'server_assigned'))"))
        #expect(!sql.contains("difficulty_score int not null default"))
    }

    @Test func checksumFunctionIsServiceOnly() {
        let sql = P14A.sql
        #expect(sql.contains("create or replace function public.competitive_catalog_checksum()"))
        #expect(sql.contains("revoke all on function public.competitive_catalog_checksum() from public, anon, authenticated;"))
        #expect(sql.contains("grant execute on function public.competitive_catalog_checksum() to service_role;"))
        #expect(sql.contains("md5(c.solutions::text)"))
        #expect(sql.contains("revoke all on public.competitive_catalog_meta from anon, authenticated;"))
    }

    @Test func catalogPasteAbortsOnDrift() {
        let catalog = CompetitiveCaseCatalog.catalogChecksum
        #expect(catalog.count == 32)
        // The SQL fixture holds schema.sql only; the catalog SQL's drift guard
        // is proven by scripts/verify-supabase-sql.mjs. Here we pin that the
        // schema exposes the function the guard calls.
        #expect(P14A.sql.contains("public.competitive_catalog_checksum()"))
    }

    @Test func weeklyBoardUsesValidatedLeaderboardTime() {
        let sql = P14A.sql
        #expect(sql.contains("r.leaderboard_at >= (select w.ts from week_start w)"))
        #expect(sql.contains("r.leaderboard_at < (select w.ts from week_start w) + interval '7 days'"))
        #expect(sql.contains("check (leaderboard_at_source in ('completed_at', 'received_at'))")
                || sql.contains("leaderboard_at_source in ('completed_at', 'received_at')"))
        let body = P14A.section(from: "create or replace function public.record_verified_ranked_result(", to: "end; $$;")
        #expect(body.contains("p_started_at < p_completed_at"))
        #expect(body.contains("p_completed_at <= v_received + make_interval(secs => cfg.max_clock_skew_seconds)"))
        #expect(body.contains("p_started_at >= v_received - make_interval(days => cfg.max_offline_age_days)"))
        #expect(body.contains("make_interval(secs => cfg.min_game_duration_seconds)"))
        #expect(body.contains("make_interval(hours => cfg.max_trusted_game_hours)"))
        #expect(body.contains("p_started_at < p.created_at - make_interval(secs => cfg.max_clock_skew_seconds)"))
        #expect(body.contains("v_board_at := least(p_completed_at, v_received);"))
        #expect(body.contains("v_board_at := v_received;"))
    }

    @Test func trustWindowConfigMatchesEdgeConstants() {
        let sql = P14A.sql
        #expect(sql.contains("max_offline_age_days int not null default 30"))
        #expect(sql.contains("min_game_duration_seconds int not null default 20"))
        #expect(sql.contains("max_trusted_game_hours int not null default 168"))
        #expect(sql.contains("max_clock_skew_seconds int not null default 300"))
        let edge = P14A.edge
        #expect(edge.contains("const MAX_GAME_AGE_MS = 30 * 24 * 60 * 60 * 1000;"))
        #expect(edge.contains("const MIN_GAME_DURATION_MS = 20 * 1000;"))
        #expect(edge.contains("const MAX_FUTURE_SKEW_MS = 5 * 60 * 1000;"))
    }

    @Test func scoringStaysServerSideAtSpecValues() {
        let sql = P14A.sql
        let edge = P14A.edge
        for forbidden in ["quarter_solved_points", "multiplier", "p_final_score", "base_score", "1.25", "2.00"] {
            #expect(!edge.contains(forbidden), "edge must not hold scoring: \(forbidden)")
        }
        #expect(sql.contains("10, 10, 5, 5, 3, 3, 1.00, 1.25, 1.50, 2.00"))
    }

    @Test func edgeRequiresBundledDistributionAndNeverLeaksSolutions() {
        let edge = P14A.edge
        #expect(edge.contains("const SOLO_DISTRIBUTION = \"client_bundled\";"))
        #expect(edge.contains("require(entry.distribution === SOLO_DISTRIBUTION, \"case_not_eligible\");"))
        #expect(edge.contains("leaderboard_at"))
        #expect(!edge.contains("solutions: entry"))
        #expect(!edge.contains("SUPABASE_ANON_KEY"))
    }

    @Test func clientNeverHoldsServiceRoleSecrets() {
        // The app only knows the public anon key; the service key lives in the
        // Edge Function environment.
        #expect(!Config.allValues.keys.contains { $0.uppercased().contains("SERVICE_ROLE") })
        #expect(!Config.allValues.values.contains { $0.lowercased().contains("service_role") })
    }
}

#!/usr/bin/env python3
"""
Phase 14 — deterministic competitive case catalog export.

Parses the 150-case library (GameSceneGridiron/Data/CasePack1..12.swift, in
CaseLibrary.all order) and emits the server's private solution catalog plus
the client/test artifacts that pin it:

  supabase/competitive_catalog.sql                    paste into Supabase AFTER schema.sql
  supabase/competitive_case_versions.json             version state (committed)
  GameSceneGridiron/Data/CompetitiveCaseCatalog.swift client case versions + fingerprints
  GameSceneGridironTests/CompetitiveCatalogFixture.swift  per-difficulty solutions (tests)

Case versioning: every case carries a content fingerprint (FNV-1a 64 over a
canonical string list — byte-for-byte the same algorithm as Swift's
`SeededGenerator.hash`). When a case's fingerprint changes, its version is
bumped (state lives in competitive_case_versions.json). The Swift test
`Phase14CatalogTests` recomputes fingerprints from the live CaseLibrary and
fails when the app's case content drifts from this export.

Per-difficulty solutions = the authored solution with every profile remapped
into the difficulty's profile pool (exact port of ProfilePoolAdapter.remap).
Rookie (and Pro games 1–3) may additionally trim one missing player; the
Edge Function accepts exactly that, and the Swift tests prove every adapted
case satisfies the server's acceptance rule.

Deterministic: no randomness, stable ordering. Re-run after any case edit:
  python3 scripts/export_competitive_catalog.py
"""

import hashlib, json, os, re, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import case_difficulty_features as cdf  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
APP = os.path.join(ROOT, "ios-gamescene-gridiron")
DATA = os.path.join(APP, "GameSceneGridiron", "Data")
TESTS = os.path.join(APP, "GameSceneGridironTests")
SUPABASE = os.path.join(ROOT, "supabase")
VERSIONS_PATH = os.path.join(SUPABASE, "competitive_case_versions.json")

SERVER_DIFFICULTY = {"rookie": "rookie", "pro": "pro", "allPro": "all_pro", "hallOfFamer": "hall_of_famer"}
POOLS = {
    "rookie": ["rookie", "veteran"],
    "pro": ["rookie", "veteran", "fast", "powerful"],
    "allPro": ["rookie", "veteran", "fast", "powerful", "overrated"],
    "hallOfFamer": ["rookie", "veteran", "fast", "powerful", "overrated"],
}
DIFFICULTY_ORDER = ["rookie", "pro", "allPro", "hallOfFamer"]
SANITY_BANDS = {"rookie": (10, 35), "pro": (30, 55), "allPro": (50, 75), "hallOfFamer": (70, 100)}
# Solo leaderboard cases ship inside the app binary. Future Versus/Faction
# cases will be 'server_assigned' (content never bundled) and are refused by
# the solo submission path.
DISTRIBUTION = "client_bundled"


def jsonb_text(value):
    """Postgres jsonb::text rendering: object keys ordered by (length, bytes),
    ', ' and ': ' separators. Lets the server recompute the catalog checksum
    from the stored jsonb (competitive_catalog_checksum())."""
    if isinstance(value, dict):
        keys = sorted(value.keys(), key=lambda k: (len(k.encode("utf-8")), k.encode("utf-8")))
        return "{" + ", ".join(json.dumps(k) + ": " + jsonb_text(value[k]) for k in keys) + "}"
    if isinstance(value, list):
        return "[" + ", ".join(jsonb_text(v) for v in value) + "]"
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, str):
        assert all(32 <= ord(ch) < 127 and ch not in '"\\' for ch in value), value
        return json.dumps(value)
    return str(value)


def md5(text):
    return hashlib.md5(text.encode("utf-8")).hexdigest()


def canonical_line(c):
    """One active catalog row — byte-identical to the line built by
    public.competitive_catalog_checksum() and by Phase14ACatalogTests."""
    return "|".join([
        c["id"], str(c["version"]), SERVER_DIFFICULTY[c["tier"]], str(c["score"]),
        str(c["band"]), str(len(c["solution"])), "true", "true" if c["eligible"] else "false",
        DISTRIBUTION, c["fingerprint"], md5(jsonb_text(solutions_for(c))),
    ])


def catalog_checksum(cases):
    lines = sorted((canonical_line(c) for c in cases), key=lambda l: l.encode("utf-8"))
    return md5("\n".join(lines))


def fnv1a(values):
    h = 0xCBF29CE484222325
    mask = 0xFFFFFFFFFFFFFFFF
    for v in values:
        for b in v.encode("utf-8"):
            h ^= b
            h = (h * 0x100000001B3) & mask
        h ^= 0x1F
        h = (h * 0x100000001B3) & mask
    return h


def remap(profile, pool):
    """Exact port of ProfilePoolAdapter.remap."""
    if profile in pool:
        return profile
    if profile in ("fast", "overrated"):
        return "rookie" if "rookie" in pool else (pool[0] if pool else "veteran")
    if profile == "powerful":
        return "veteran" if "veteran" in pool else (pool[0] if pool else "rookie")
    return "veteran" if "veteran" in pool else (pool[0] if pool else "rookie")


def parse_cases():
    """Shared parser (scripts/case_difficulty_features.py). Phase 14A: every
    case must carry an EXPLICIT authored score equal to the calibration
    model — no derived, default or placeholder score can reach the server."""
    cases = cdf.parse_library()
    problems = []
    for c in cases:
        expected = cdf.calibrated_score(c)
        if c["score"] == 0:
            problems.append(f"{c['id']}: no authored difficultyScore")
        elif c["score"] != expected:
            problems.append(f"{c['id']}: difficultyScore {c['score']} != calibrated {expected}")
        lo, hi = SANITY_BANDS[c["tier"]]
        if not lo <= c["score"] <= hi:
            problems.append(f"{c['id']}: {c['tier']} score {c['score']} outside {lo}-{hi}")
    if problems:
        sys.exit("run scripts/calibrate_case_difficulty.py first:\n  " + "\n  ".join(problems[:20]))
    return cases


def fingerprint_values(c):
    values = [
        "gridiron-competitive-case-v1", c["id"],
        f"band:{c['band']}", f"seed:{c['seed']}",
        f"tier:{c['tier']}", f"eligible:{1 if c['eligible'] else 0}",
    ]
    values += [f"m:{k}:{p.upper()}" for k, p in c["missing"]]
    values += [f"s:{k}" for k in c["slots"]]
    values += [f"x:{p}:{s}:{prof}" for p, s, prof in c["solution"]]
    values += [f"clues:{c['clue_count']}", f"hints:{c['hint_count']}"]
    return values


def solutions_for(c):
    out = {}
    for d in DIFFICULTY_ORDER:
        pool = POOLS[d]
        out[SERVER_DIFFICULTY[d]] = [
            {"player_key": p, "slot_key": s, "profile": remap(prof, pool)} for p, s, prof in c["solution"]
        ]
    return out


def sql_str(s):
    return "'" + s.replace("'", "''") + "'"


def main():
    cases = parse_cases()
    if len(cases) != 150:
        sys.exit(f"expected 150 cases, parsed {len(cases)}")
    ids = [c["id"] for c in cases]
    if len(set(ids)) != len(ids):
        sys.exit("duplicate case ids")

    state = {}
    if os.path.exists(VERSIONS_PATH):
        state = json.load(open(VERSIONS_PATH))
    new_state = {}
    for c in cases:
        fp = "%016x" % fnv1a(fingerprint_values(c))
        prev = state.get(c["id"])
        if prev is None:
            version = 1
        elif prev["fingerprint"] != fp:
            version = prev["version"] + 1
        else:
            version = prev["version"]
        c["fingerprint"] = fp
        c["version"] = version
        new_state[c["id"]] = {"version": version, "fingerprint": fp}
    catalog_fp = "%016x" % fnv1a([f"{c['id']}@{c['version']}:{c['fingerprint']}" for c in cases])
    checksum = catalog_checksum(cases)

    os.makedirs(SUPABASE, exist_ok=True)
    with open(VERSIONS_PATH, "w") as f:
        json.dump(new_state, f, indent=2, sort_keys=True)
        f.write("\n")

    # ---------------------------------------------------------------- SQL
    rows = []
    for c in cases:
        sol = json.dumps(solutions_for(c), separators=(",", ":"), sort_keys=True)
        rows.append(
            f"    ({sql_str(c['id'])}, {c['version']}, {sql_str(SERVER_DIFFICULTY[c['tier']])}, {c['score']}, "
            f"{c['band']}, {len(c['solution'])}, true, {'true' if c['eligible'] else 'false'}, "
            f"{sql_str(DISTRIBUTION)}, {sql_str(c['fingerprint'])}, {sql_str(sol)}::jsonb)"
        )
    sql = [
        "-- GENERATED by scripts/export_competitive_catalog.py — DO NOT EDIT BY HAND.",
        "-- GameScene: Gridiron — Phase 14 competitive case catalog (PRIVATE).",
        f"-- {len(cases)} cases · catalog fingerprint {catalog_fp} · checksum (md5) {checksum}",
        f"-- difficulty_score: calibrated (CaseDifficultyCalibration) — "
        + ", ".join(f"{SERVER_DIFFICULTY[t]} {min(x['score'] for x in cases if x['tier'] == t)}-{max(x['score'] for x in cases if x['tier'] == t)}" for t in DIFFICULTY_ORDER),
        "-- Paste into the Supabase SQL editor AFTER supabase/schema.sql. Idempotent:",
        "-- re-running upserts every case; edited cases arrive with a bumped",
        "-- case_version. Solutions are readable ONLY by the service role (the",
        "-- submit-ranked-result Edge Function) — anon/authenticated have no access.",
        "-- The whole file runs as ONE transaction: the final checksum check rolls",
        "-- everything back if the stored catalog differs from this export.",
        "begin;",
        "",
        "insert into public.competitive_cases",
        "    (case_id, case_version, difficulty, difficulty_score, band, missing_count, active, competitive_eligible, distribution, fingerprint, solutions)",
        "values",
        ",\n".join(rows),
        "on conflict (case_id) do update set",
        "    case_version         = excluded.case_version,",
        "    difficulty           = excluded.difficulty,",
        "    difficulty_score     = excluded.difficulty_score,",
        "    band                 = excluded.band,",
        "    missing_count        = excluded.missing_count,",
        "    active               = excluded.active,",
        "    competitive_eligible = excluded.competitive_eligible,",
        "    distribution         = excluded.distribution,",
        "    fingerprint          = excluded.fingerprint,",
        "    solutions            = excluded.solutions,",
        "    updated_at           = now();",
        "",
        "-- Cases removed from the library are retired, never deleted (history keeps",
        "-- its references).",
        "update public.competitive_cases set active = false, updated_at = now()",
        "where case_id not in (" + ", ".join(sql_str(i) for i in ids) + ");",
        "",
        "-- Drift detection: the expected checksum is recorded, then recomputed",
        "-- from the stored rows. Any mismatch aborts (and rolls back) the paste.",
        "insert into public.competitive_catalog_meta (id, case_count, catalog_fingerprint, expected_checksum)",
        f"values (1, {len(cases)}, {sql_str(catalog_fp)}, {sql_str(checksum)})",
        "on conflict (id) do update set",
        "    case_count          = excluded.case_count,",
        "    catalog_fingerprint = excluded.catalog_fingerprint,",
        "    expected_checksum   = excluded.expected_checksum,",
        "    updated_at          = now();",
        "",
        "do $$",
        "declare",
        "    v_actual text := public.competitive_catalog_checksum();",
        "begin",
        f"    if v_actual is distinct from {sql_str(checksum)} then",
        f"        raise exception 'COMPETITIVE_CATALOG_DRIFT: expected {checksum}, stored %', v_actual;",
        "    end if;",
        "end;",
        "$$;",
        "",
        "commit;",
        "",
    ]
    open(os.path.join(SUPABASE, "competitive_catalog.sql"), "w").write("\n".join(sql))

    # ---------------------------------------------------------------- Swift (app)
    lines = [
        "import Foundation",
        "",
        "// GENERATED by scripts/export_competitive_catalog.py — DO NOT EDIT BY HAND.",
        "//",
        "// The competitive catalog's public half: per-case version + content",
        "// fingerprint (no solutions). Every ranked submission names the case",
        "// version it was played at; the server rejects versions it does not hold.",
        "// Phase14CatalogTests recompute the fingerprints from the live",
        "// CaseLibrary, so any case edit without a re-export fails the tests.",
        "nonisolated enum CompetitiveCaseCatalog {",
        f"    static let catalogFingerprint = \"{catalog_fp}\"",
        "    /// md5 over the canonical active-row lines — equals",
        "    /// public.competitive_catalog_checksum() on a correctly pasted server.",
        f"    static let catalogChecksum = \"{checksum}\"",
        f"    static let caseCount = {len(cases)}",
        "",
        "    static let entries: [String: CompetitiveCatalogEntry] = [",
    ]
    for c in cases:
        lines.append(
            f"        \"{c['id']}\": CompetitiveCatalogEntry(version: {c['version']}, fingerprint: \"{c['fingerprint']}\", "
            f"tier: .{c['tier']}, difficultyScore: {c['score']}, isCompetitiveEligible: {'true' if c['eligible'] else 'false'}),"
        )
    lines += ["    ]", "}", ""]
    open(os.path.join(DATA, "CompetitiveCaseCatalog.swift"), "w").write("\n".join(lines))

    # ---------------------------------------------------------------- Swift (tests)
    sol_lines = []
    for c in cases:
        for d, entries in solutions_for(c).items():
            sol_lines.append(f"{c['id']}|{d}|" + ",".join(f"{e['player_key']}:{e['slot_key']}:{e['profile']}" for e in entries))
    test = [
        "import Foundation",
        "",
        "// GENERATED by scripts/export_competitive_catalog.py — DO NOT EDIT BY HAND.",
        "//",
        "// The server catalog's per-difficulty solutions, exactly as exported into",
        "// supabase/competitive_catalog.sql (the test runner only receives the app",
        "// folder). One line per case × difficulty:",
        "//   case_id|difficulty|player:slot:profile,player:slot:profile,...",
        "enum CompetitiveCatalogFixture {",
        f"    static let catalogFingerprint = \"{catalog_fp}\"",
        "    /// Canonical active-row lines hashed by public.competitive_catalog_checksum():",
        "    /// id|version|difficulty|score|band|missing|active|eligible|distribution|fingerprint|md5(solutions jsonb)",
        "    static let canonicalLines = #\"\"\"",
        *sorted((canonical_line(c) for c in cases), key=lambda l: l.encode("utf-8")),
        "\"\"\"#",
        "    static let solutions = #\"\"\"",
        *sol_lines,
        "\"\"\"#",
        "}",
        "",
    ]
    open(os.path.join(TESTS, "CompetitiveCatalogFixture.swift"), "w").write("\n".join(test))

    print(f"exported {len(cases)} cases, catalog {catalog_fp}, checksum {checksum}")


if __name__ == "__main__":
    main()

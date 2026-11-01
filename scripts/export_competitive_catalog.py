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

Phase 14B — per-VARIANT solutions. `solutions` holds the EXACT solution the
client's deterministic CaseDifficultyAdapter produces for each of the five
solution variants (scripts/case_adapter_port.py: rookie, pro_early, pro,
all_pro, hall_of_famer). The server snapshots one variant per quarter into the
ranked match assignment; no arbitrary trimmed subset is accepted.
Phase14BAdapterParityTests run the real Swift adapter against the fixture.

Phase 14B — version history. competitive_case_versions.json keeps every
(version, fingerprint) a case has shipped with. The generator refuses a
fingerprint change without a version bump and any version regression
(verify_transition); the SQL trigger enforces the same on the server.

Phase 14B — retirement and checksum are scoped to distribution
'client_bundled'; future 'server_assigned' rows are never touched here and
get their own checksum row in competitive_catalog_meta.

Deterministic: no randomness, stable ordering. Re-run after any case edit:
  python3 scripts/export_competitive_catalog.py
"""

import hashlib, json, os, re, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import case_difficulty_features as cdf  # noqa: E402
import case_adapter_port as adapter  # noqa: E402

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


_SOLUTION_CACHE = {}


def solutions_for(c):
    """Exact adapted solution per variant (authored order)."""
    if c["id"] not in _SOLUTION_CACHE:
        _SOLUTION_CACHE[c["id"]] = {
            v: [{"player_key": p, "slot_key": s, "profile": prof} for p, s, prof in sol]
            for v, sol in adapter.variant_solutions(c).items()
        }
    return _SOLUTION_CACHE[c["id"]]


# ------------------------------------------------------------ version history
class ManifestError(Exception):
    pass


def normalize_entry(entry):
    """Accept the pre-14B {version, fingerprint} shape (history = current)."""
    hist = entry.get("history") or [{"version": entry["version"], "fingerprint": entry["fingerprint"]}]
    return {"version": entry["version"], "fingerprint": entry["fingerprint"],
            "history": [{"version": h["version"], "fingerprint": h["fingerprint"]} for h in hist]}


def verify_manifest(state):
    """Every entry: history strictly increasing in version, one fingerprint per
    version, current == last history entry."""
    for cid, raw in state.items():
        e = normalize_entry(raw)
        hist = e["history"]
        if not hist:
            raise ManifestError(f"{cid}: empty history")
        for a, b in zip(hist, hist[1:]):
            if b["version"] <= a["version"]:
                raise ManifestError(f"CASE_VERSION_REGRESSION: {cid} history {a['version']} -> {b['version']}")
        if hist[-1]["version"] != e["version"] or hist[-1]["fingerprint"] != e["fingerprint"]:
            raise ManifestError(f"{cid}: current version/fingerprint is not the last history entry")
        if e["version"] < 1:
            raise ManifestError(f"{cid}: version < 1")
    return True


def verify_transition(old_state, new_state):
    """Generator-side rule mirrored by the SQL trigger: a case's version never
    goes down and a changed fingerprint always comes with a higher version."""
    for cid, new_raw in new_state.items():
        if cid not in old_state:
            continue
        old, new = normalize_entry(old_state[cid]), normalize_entry(new_raw)
        if new["version"] < old["version"]:
            raise ManifestError(f"CASE_VERSION_REGRESSION: {cid} {old['version']} -> {new['version']}")
        if new["fingerprint"] != old["fingerprint"] and new["version"] == old["version"]:
            raise ManifestError(f"CASE_FINGERPRINT_CHANGED_WITHOUT_VERSION_BUMP: {cid} v{new['version']}")
        known = {h["version"]: h["fingerprint"] for h in old["history"]}
        for h in new["history"]:
            if h["version"] in known and known[h["version"]] != h["fingerprint"]:
                raise ManifestError(f"CASE_FINGERPRINT_CHANGED_WITHOUT_VERSION_BUMP: {cid} v{h['version']}")
    return True


def compute_versions(fingerprints, old_state):
    """fingerprints: {case_id: fp}. Pure: returns the new manifest. A changed
    fingerprint gets max(history)+1 — even when reverting to older content."""
    verify_manifest(old_state)
    new_state = {}
    for cid, fp in fingerprints.items():
        prev = old_state.get(cid)
        if prev is None:
            new_state[cid] = {"version": 1, "fingerprint": fp, "history": [{"version": 1, "fingerprint": fp}]}
            continue
        prev = normalize_entry(prev)
        if prev["fingerprint"] == fp:
            new_state[cid] = prev
        else:
            v = max(h["version"] for h in prev["history"]) + 1
            new_state[cid] = {"version": v, "fingerprint": fp,
                              "history": prev["history"] + [{"version": v, "fingerprint": fp}]}
    # Retired cases keep their history (a re-added case continues its numbering).
    for cid, prev in old_state.items():
        if cid not in new_state:
            new_state[cid] = dict(normalize_entry(prev), retired=True)
    verify_manifest(new_state)
    verify_transition(old_state, new_state)
    return new_state


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
    fps = {c["id"]: "%016x" % fnv1a(fingerprint_values(c)) for c in cases}
    try:
        new_state = compute_versions(fps, state)
    except ManifestError as e:
        sys.exit(f"competitive_case_versions.json: {e}")
    for c in cases:
        c["fingerprint"] = fps[c["id"]]
        c["version"] = new_state[c["id"]]["version"]
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
        "-- case_version (the version-history trigger rejects a changed fingerprint",
        "-- without a bump and any version regression). Solutions are readable ONLY",
        "-- by the service role — anon/authenticated have no access. They are NOT",
        "-- secret: the same cases ship inside the app binary.",
        "-- solutions: { variant: [ {player_key, slot_key, profile}, ... ] } for",
        "-- variants rookie, pro_early, pro, all_pro, hall_of_famer — the exact",
        "-- output of the client's CaseDifficultyAdapter (case_adapter_port.py).",
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
        "-- Client-bundled cases removed from the library are retired, never deleted",
        "-- (history keeps its references). Scoped to distribution = 'client_bundled':",
        "-- server_assigned rows (future Versus/Faction) are never touched here.",
        "update public.competitive_cases set active = false, updated_at = now()",
        "where distribution = 'client_bundled'",
        "  and case_id not in (" + ", ".join(sql_str(i) for i in ids) + ");",
        "",
        "-- Drift detection: the expected checksum is recorded, then recomputed",
        "-- from the stored rows. Any mismatch aborts (and rolls back) the paste.",
        "-- One meta row per distribution; this file owns only 'client_bundled'.",
        "insert into public.competitive_catalog_meta (distribution, case_count, catalog_fingerprint, expected_checksum)",
        f"values ({sql_str(DISTRIBUTION)}, {len(cases)}, {sql_str(catalog_fp)}, {sql_str(checksum)})",
        "on conflict (distribution) do update set",
        "    case_count          = excluded.case_count,",
        "    catalog_fingerprint = excluded.catalog_fingerprint,",
        "    expected_checksum   = excluded.expected_checksum,",
        "    updated_at          = now();",
        "",
        "do $$",
        "declare",
        f"    v_actual text := public.competitive_catalog_checksum({sql_str(DISTRIBUTION)});",
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
        "// The server catalog's per-VARIANT adapted solutions, exactly as exported",
        "// into supabase/competitive_catalog.sql (the test runner only receives the",
        "// app folder). One line per case × variant, authored order:",
        "//   case_id|variant|player:slot:profile,player:slot:profile,...",
        "// variants: rookie, pro_early, pro, all_pro, hall_of_famer",
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

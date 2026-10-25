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

import json, os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
APP = os.path.join(ROOT, "ios-gamescene-gridiron")
DATA = os.path.join(APP, "GameSceneGridiron", "Data")
TESTS = os.path.join(APP, "GameSceneGridironTests")
SUPABASE = os.path.join(ROOT, "supabase")
VERSIONS_PATH = os.path.join(SUPABASE, "competitive_case_versions.json")

# Derived difficulty scores for packs 1–6 (cases authored before explicit
# scores existed). CaseLibrary.makeCase derives them from
# CaseDifficultyProfile(rating * 100); captured once from the Swift runtime
# and pinned by Phase14CatalogTests (any drift fails the test).
DERIVED_SCORES = {
}

SERVER_DIFFICULTY = {"rookie": "rookie", "pro": "pro", "allPro": "all_pro", "hallOfFamer": "hall_of_famer"}
POOLS = {
    "rookie": ["rookie", "veteran"],
    "pro": ["rookie", "veteran", "fast", "powerful"],
    "allPro": ["rookie", "veteran", "fast", "powerful", "overrated"],
    "hallOfFamer": ["rookie", "veteran", "fast", "powerful", "overrated"],
}
DIFFICULTY_ORDER = ["rookie", "pro", "allPro", "hallOfFamer"]


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


def band_tier(band):
    return "pro" if band in (1, 2) else ("allPro" if band == 3 else "hallOfFamer")


def block_between(text, start, end):
    i = text.index(start) + len(start)
    j = text.index(end, i)
    return text[i:j]


def parse_cases():
    cases = []
    for n in range(1, 13):
        text = open(os.path.join(DATA, f"CasePack{n}.swift")).read()
        for block in text.split("CaseLibrary.makeCase(")[1:]:
            cid = re.search(r'id: "([^"]+)"', block).group(1)
            seed = int(re.search(r'seed: (\d+)', block).group(1))
            band = int(re.search(r'band: (\d+)', block).group(1))
            missing = re.findall(r'\(key: "([^"]+)", position: \.(\w+)\)', block_between(block, "missing: [", "evidence: ["))
            slots = re.findall(r'\(key: "([^"]+)", x:', block_between(block, "slots: [", "clues: ["))
            clues = re.findall(r'\(player: "[^"]+", family:', block)
            hints = re.findall(r'\(player: "[^"]+", text:', block)
            solution = re.findall(r'\(player: "([^"]+)", slot: "([^"]+)", profile: \.(\w+)\)', block)
            tail = block[block.index("solution: ["):]
            tier_m = re.search(r'tier: \.(\w+)', tail)
            score_m = re.search(r'difficultyScore: (\d+)', tail)
            elig_m = re.search(r'isCompetitiveEligible: (true|false)', tail)
            tier = tier_m.group(1) if tier_m else band_tier(band)
            if score_m:
                score = int(score_m.group(1))
                score_source = "authored"
            else:
                score = DERIVED_SCORES.get(cid, 0)
                score_source = "derived"
            eligible = (elig_m.group(1) == "true") if elig_m else True
            assert missing and slots and solution, cid
            cases.append(dict(
                id=cid, seed=seed, band=band, missing=missing, slots=slots,
                clue_count=len(clues), hint_count=len(hints), solution=solution,
                tier=tier, score=min(100, max(1, score)) if score else 0,
                score_source=score_source, eligible=eligible,
            ))
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
    missing_scores = [c["id"] for c in cases if c["score"] == 0]

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
            f"{sql_str(c['fingerprint'])}, {sql_str(sol)}::jsonb)"
        )
    sql = [
        "-- GENERATED by scripts/export_competitive_catalog.py — DO NOT EDIT BY HAND.",
        "-- GameScene: Gridiron — Phase 14 competitive case catalog (PRIVATE).",
        f"-- {len(cases)} cases · catalog fingerprint {catalog_fp}",
        "-- Paste into the Supabase SQL editor AFTER supabase/schema.sql. Idempotent:",
        "-- re-running upserts every case; edited cases arrive with a bumped",
        "-- case_version. Solutions are readable ONLY by the service role (the",
        "-- submit-ranked-result Edge Function) — anon/authenticated have no access.",
        "insert into public.competitive_cases",
        "    (case_id, case_version, difficulty, difficulty_score, band, missing_count, active, competitive_eligible, fingerprint, solutions)",
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
        "    fingerprint          = excluded.fingerprint,",
        "    solutions            = excluded.solutions,",
        "    updated_at           = now();",
        "",
        "-- Cases removed from the library are retired, never deleted (history keeps",
        "-- its references).",
        "update public.competitive_cases set active = false, updated_at = now()",
        "where case_id not in (" + ", ".join(sql_str(i) for i in ids) + ");",
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
        "    static let solutions = #\"\"\"",
        *sol_lines,
        "\"\"\"#",
        "}",
        "",
    ]
    open(os.path.join(TESTS, "CompetitiveCatalogFixture.swift"), "w").write("\n".join(test))

    print(f"exported {len(cases)} cases, catalog {catalog_fp}")
    if missing_scores:
        print(f"WARNING: {len(missing_scores)} derived scores not yet captured: run Phase14CatalogTests to capture them")


if __name__ == "__main__":
    main()

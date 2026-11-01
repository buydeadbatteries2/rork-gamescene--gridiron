#!/usr/bin/env python3
"""
Phase 14B: exact Python port of the solution-changing parts of
`CaseDifficultyAdapter` (GameSceneGridiron/Services/CaseDifficultyAdapter.swift)
and `CaseSolver.isUnique` (GameSceneGridiron/Models/QuarterCase.swift).

Only two adapter steps can change a case's SOLUTION:
  1. adaptProfiles      remaps profiles onto the SELECTED level's pool
  2. trimMissingPlayers drops one missing player when maxMissingPlayers < count
     and the solver still proves uniqueness
trimDecoys / addDecoys only touch decoy slots (never solution slots) and
reorderClues / rewriteHints are presentation. So the adapted solution for a
case depends only on (profile pool, maxMissingPlayers), and the
DifficultyResolver collapses every (selected level, game number) pair onto one
of five VARIANTS:

  rookie         rookie pool  + trim to 4   (every rookie game, any stage)
  pro_early      pro pool     + trim to 4   (pro games 1-3: rating 0.85 -> rookie tier)
  pro            pro pool,      no trim     (pro games 4-12)
  all_pro        full pool,     no trim     (full pool == profile adaptation no-op)
  hall_of_famer  full pool,     no trim

The server stores one solution per variant (competitive_cases.solutions) and
the SQL function `ranked_solution_variant(difficulty, game_number)` picks the
one the client's adapter produces. The Swift test `Phase14BAdapterParityTests`
runs the real adapter for every case x variant and compares it with
`CompetitiveCatalogFixture` lines generated from this port.
"""

import math

PROFILES_ALL = ["rookie", "veteran", "fast", "powerful", "overrated"]  # PlayerProfile.allCases
POOLS = {
    "rookie": ["rookie", "veteran"],
    "pro": ["rookie", "veteran", "fast", "powerful"],
    "allPro": PROFILES_ALL,
    "hallOfFamer": PROFILES_ALL,
}
INT_MAX = 1 << 62

# variant -> (selected level whose pool applies, maxMissingPlayers)
VARIANTS = {
    "rookie": ("rookie", 4),
    "pro_early": ("pro", 4),
    "pro": ("pro", INT_MAX),
    "all_pro": ("allPro", INT_MAX),
    "hall_of_famer": ("hallOfFamer", INT_MAX),
}
VARIANT_ORDER = ["rookie", "pro_early", "pro", "all_pro", "hall_of_famer"]

# Mirrors DifficultyLevel.baseRating / SeasonStage.difficultyOffset.
BASE_RATING = {"rookie": 0.4, "pro": 1.4, "allPro": 2.4, "hallOfFamer": 3.1}


def stage_offset(week):
    if week <= 3:
        return -0.55
    if week <= 6:
        return 0.0
    if week <= 8:
        return 0.35
    if week <= 10:
        return 0.6
    if week == 11:
        return 0.75
    return 0.9


def variant_for(level, week):
    """Port of DifficultyResolver.target -> (pool, maxMissing) -> variant."""
    rating = min(3.5, max(0.0, BASE_RATING[level] + stage_offset(week)))
    max_missing = 4 if rating < 1.0 else INT_MAX
    if level == "rookie":
        max_missing = min(max_missing, 4)
    for name, (pl, mm) in VARIANTS.items():
        if pl == level and mm == max_missing:
            return name
        if level == "pro" and pl == "pro" and mm == max_missing:
            return name
    raise AssertionError((level, week, max_missing))


def remap(profile, pool):
    if profile in pool:
        return profile
    if profile in ("fast", "overrated"):
        return "rookie" if "rookie" in pool else (pool[0] if pool else "veteran")
    if profile == "powerful":
        return "veteran" if "veteran" in pool else (pool[0] if pool else "rookie")
    return "veteran" if "veteran" in pool else (pool[0] if pool else "rookie")


def other(pool, profile):
    for p in pool:
        if p != profile:
            return p
    return profile


def referenced_players(con):
    k = con[0]
    if k in ("yAbove", "yBelow", "sameSideOfBall", "oppositeSideOfBall"):
        return [con[1], con[2]]
    return [con[1]]


def referenced_profiles(clues):
    return {c[2] for clue in clues for c in clue["full"] if c[0] in ("profileIs", "profileIsNot")}


def make_case(c):
    """Working copy with only the fields the solver/adapter need."""
    return dict(
        id=c["id"],
        missing=[k for k, _ in c["missing"]],
        evidence={k: (x, y) for k, x, y in c["evidence_xy"]},
        slots={k: (x, y) for k, x, y in c["slots_xy"]},
        clues=[dict(player=cl["player"], full=list(cl["full"])) for cl in c["clues"]],
        solution=[tuple(s) for s in c["solution"]],
    )


def adapt_profiles(case, pool):
    if set(pool) == set(PROFILES_ALL):
        return case
    new_for = {p: remap(prof, pool) for p, _, prof in case["solution"]}
    solution = [(p, s, new_for.get(p, prof)) for p, s, prof in case["solution"]]
    universe = {"fast", "powerful", "veteran"} | referenced_profiles(case["clues"])
    out_of_pool = sorted(universe - set(pool))  # order irrelevant: conjunctive
    added = set()
    clues = []
    for clue in case["clues"]:
        extra = [("profileIsNot", clue["player"], p) for p in out_of_pool] if clue["player"] in case["missing"] else []
        if clue["player"] in added:
            extra = []
        elif extra:
            added.add(clue["player"])
        mapped = []
        for con in clue["full"]:
            if con[0] == "profileIs" and con[1] in new_for:
                mapped.append(("profileIs", con[1], new_for[con[1]]))
            elif con[0] == "profileIsNot" and con[1] in new_for:
                m = remap(con[2], pool)
                mapped.append(("profileIsNot", con[1], m if m != new_for[con[1]] else other(pool, new_for[con[1]])))
            else:
                mapped.append(con)
        clues.append(dict(player=clue["player"], full=mapped + extra))
    return dict(case, clues=clues, solution=solution)


def dist(a, b):
    return math.sqrt((a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2)


def satisfied(con, assignment, variants, evidence):
    k = con[0]
    if k == "nearEvidence":
        p, e = assignment.get(con[1]), evidence.get(con[2])
        return p is not None and e is not None and dist(p, e) <= con[3]
    if k == "nearestToEvidence":
        p, e = assignment.get(con[1]), evidence.get(con[2])
        if p is None or e is None:
            return False
        return all(key == con[1] or dist(p, e) < dist(q, e) for key, q in assignment.items())
    if k == "farthestFromEvidence":
        p, e = assignment.get(con[1]), evidence.get(con[2])
        if p is None or e is None:
            return False
        return all(key == con[1] or dist(p, e) > dist(q, e) for key, q in assignment.items())
    if k == "depthBand":
        p = assignment.get(con[1])
        return p is not None and con[2] <= p[1] <= con[3]
    if k == "xBand":
        p = assignment.get(con[1])
        return p is not None and con[2] <= p[0] <= con[3]
    if k in ("yAbove", "yBelow", "sameSideOfBall", "oppositeSideOfBall"):
        pa, pb = assignment.get(con[1]), assignment.get(con[2])
        if pa is None or pb is None:
            return False
        if k == "yAbove":
            return pa[1] <= pb[1] - con[3]
        if k == "yBelow":
            return pa[1] >= pb[1] + con[3]
        if k == "sameSideOfBall":
            return (pa[0] < 0.5) == (pb[0] < 0.5)
        return (pa[0] < 0.5) != (pb[0] < 0.5)
    if k == "profileIs":
        return variants.get(con[1]) == con[2]
    if k == "profileIsNot":
        chosen = variants.get(con[1])
        return chosen is None or chosen != con[2]
    raise ValueError(k)


def is_unique(case):
    """Port of CaseSolver.diagnose(...).isUnique."""
    slots, evidence = case["slots"], case["evidence"]
    players = case["missing"]
    all_cons = [con for clue in case["clues"] for con in clue["full"]]
    single, multi, prof = {}, [], {}
    for con in all_cons:
        if con[0] in ("profileIs", "profileIsNot"):
            prof.setdefault(con[1], []).append(con)
        elif con[0] in ("nearEvidence", "depthBand", "xBand"):
            single.setdefault(con[1], []).append(con)
        else:
            multi.append(con)
    universe = {"fast", "powerful", "veteran"} | {c[2] for c in all_cons if c[0] in ("profileIs", "profileIsNot")}
    allowed_variants = {}
    for key in players:
        opts = set(universe)
        for con in prof.get(key, []):
            if con[0] == "profileIs":
                opts = {con[2]}
            else:
                opts.discard(con[2])
        allowed_variants[key] = opts
    allowed_slots = {}
    for key in players:
        cons = single.get(key, [])
        allowed_slots[key] = {s for s, pos in slots.items()
                              if all(satisfied(c, {key: pos}, {}, evidence) for c in cons)}
    # Intended-solution checks.
    intended = {p: slots[s] for p, s, _ in case["solution"] if s in slots}
    intended_v = {p: prof_ for p, _, prof_ in case["solution"]}
    if not all(satisfied(c, intended, intended_v, evidence) for c in all_cons):
        return False
    for p, s, prof_ in case["solution"]:
        if prof_ not in allowed_variants.get(p, set()) or s not in allowed_slots.get(p, set()):
            return False
    if not all(len(v) == 1 for v in allowed_variants.values()):
        return False
    # Count valid assignments; only "== 1" matters, so stop at 2.
    keys = sorted(players)
    count = 0

    def assign(i, used, current):
        nonlocal count
        if count >= 2:
            return
        if i == len(keys):
            pos = {k: slots[v] for k, v in current.items()}
            if all(satisfied(c, pos, {}, evidence) for c in multi):
                count += 1
            return
        key = keys[i]
        for s in sorted(allowed_slots[key]):
            if s in used:
                continue
            nxt = dict(current)
            nxt[key] = s
            pos = {k: slots[v] for k, v in nxt.items()}
            checkable = [c for c in multi if all(p in nxt for p in referenced_players(c))]
            if all(satisfied(c, pos, {}, evidence) for c in checkable):
                assign(i + 1, used | {s}, nxt)

    assign(0, frozenset(), {})
    return count == 1


def trim_missing(case, max_missing):
    if len(case["missing"]) <= max_missing:
        return case
    for cand in sorted(case["missing"]):
        kept = [cl for cl in case["clues"] if cl["player"] != cand]
        if any(cand in referenced_players(con) for cl in kept for con in cl["full"]):
            continue
        reduced = dict(
            case,
            missing=[m for m in case["missing"] if m != cand],
            clues=kept,
            solution=[s for s in case["solution"] if s[0] != cand],
        )
        # Evidence filtering (referencedEvidence) never removes evidence a
        # kept constraint uses, so it cannot change the solver's answer.
        if is_unique(reduced):
            return reduced
    return case


def adapted_solution(c, variant):
    pool_level, max_missing = VARIANTS[variant]
    case = make_case(c)
    case = adapt_profiles(case, POOLS[pool_level])
    case = trim_missing(case, max_missing)
    return list(case["solution"])  # authored order (filter only)


def variant_solutions(c):
    return {v: adapted_solution(c, v) for v in VARIANT_ORDER}


if __name__ == "__main__":
    import case_difficulty_features as cdf
    from collections import Counter
    lib = cdf.parse_library()
    trims = Counter()
    for c in lib:
        assert is_unique(make_case(c)), c["id"]
        vs = variant_solutions(c)
        for v in VARIANT_ORDER:
            if len(vs[v]) < len(c["solution"]):
                trims[v] += 1
    print(f"{len(lib)} cases; trimmed per variant: {dict(trims)}")
    for lvl in ("rookie", "pro", "allPro", "hallOfFamer"):
        print(lvl, [variant_for(lvl, w) for w in range(1, 13)])

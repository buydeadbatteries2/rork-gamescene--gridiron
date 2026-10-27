#!/usr/bin/env python3
"""
Phase 14A — shared case parser + difficulty calibration model.

Exact Python port of `CaseDifficultyCalibration` (GameSceneGridiron/Models/
CaseDifficultyCalibration.swift). Both sides compute the calibrated 1–100
difficulty score from the AUTHORED case content; the Swift test
`Phase14ACalibrationTests` recomputes it from the live CaseLibrary and fails
when any case's written `difficultyScore:` disagrees.

Used by:
  scripts/calibrate_case_difficulty.py   writes the score into every case
  scripts/export_competitive_catalog.py  (indirectly, via the written score)
"""

import os, re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(ROOT, "ios-gamescene-gridiron", "GameSceneGridiron", "Data")

PACK_COUNT = 12

# Profile pool size per tier (PlayerProfile.pool(for:)).
POOL_SIZE = {"rookie": 2, "pro": 4, "allPro": 5, "hallOfFamer": 5}

# Calibration constants — MUST match CaseDifficultyCalibration.swift.
BAND_FLOOR = {"rookie": 10, "pro": 30, "allPro": 50, "hallOfFamer": 70}
BAND_SPAN = {"rookie": 25, "pro": 25, "allPro": 25, "hallOfFamer": 30}
CLUE_DIFFICULTY = {"easy": 0.2, "medium": 0.5, "hard": 1.0}
FAMILY_BONUS = {"chainedDeduction": 0.3, "orderDepth": 0.15, "negative": 0.1, "elimination": 0.1}
RELATIONAL_FAMILIES = {"relativePosition", "orderDepth"}
NEGATIVE_FAMILIES = {"negative", "elimination"}
TWO_PLAYER_CONSTRAINTS = {"yAbove", "yBelow", "sameSideOfBall", "oppositeSideOfBall"}


def band_tier(band):
    return "pro" if band in (1, 2) else ("allPro" if band == 3 else "hallOfFamer")


def block_between(text, start, end):
    i = text.index(start) + len(start)
    j = text.index(end, i)
    return text[i:j]


def split_clues(clue_block):
    """Each clue tuple starts with `(player: "x", family:`."""
    starts = [m.start() for m in re.finditer(r'\(player: "[^"]+", family:', clue_block)]
    starts.append(len(clue_block))
    return [clue_block[starts[i]:starts[i + 1]] for i in range(len(starts) - 1)]


def parse_pack(n):
    path = os.path.join(DATA, f"CasePack{n}.swift")
    text = open(path).read()
    cases = []
    for block in text.split("CaseLibrary.makeCase(")[1:]:
        cid = re.search(r'id: "([^"]+)"', block).group(1)
        seed = int(re.search(r'seed: (\d+)', block).group(1))
        band = int(re.search(r'band: (\d+)', block).group(1))
        missing = re.findall(r'\(key: "([^"]+)", position: \.(\w+)\)', block_between(block, "missing: [", "evidence: ["))
        evidence = re.findall(r'\(key: "([^"]+)", kind: \.(\w+)', block_between(block, "evidence: [", "slots: ["))
        slots = re.findall(r'\(key: "([^"]+)", x:', block_between(block, "slots: [", "clues: ["))
        clue_block = block_between(block, "clues: [", "hints: [")
        clues = []
        for raw in split_clues(clue_block):
            fam = re.search(r'family: \.(\w+)', raw).group(1)
            diff = re.search(r'difficulty: \.(\w+)', raw).group(1)
            cons = re.findall(r'\.(\w+)\((?:player|a): ', raw[raw.index("constraints: ["):])
            clues.append(dict(family=fam, difficulty=diff, constraints=cons))
        hints = re.findall(r'\(player: "[^"]+", text:', block_between(block, "hints: [", "solution: ["))
        solution = re.findall(r'\(player: "([^"]+)", slot: "([^"]+)", profile: \.(\w+)\)', block)
        tail = block[block.index("solution: ["):]
        tier_m = re.search(r'tier: \.(\w+)', tail)
        score_m = re.search(r'difficultyScore: (\d+)', tail)
        elig_m = re.search(r'isCompetitiveEligible: (true|false)', tail)
        assert missing and slots and solution and clues, cid
        cases.append(dict(
            id=cid, seed=seed, band=band, missing=missing, evidence=evidence, slots=slots,
            clues=clues, clue_count=len(clues), hint_count=len(hints), solution=solution,
            tier=tier_m.group(1) if tier_m else band_tier(band),
            explicit_tier=bool(tier_m),
            score=int(score_m.group(1)) if score_m else 0,
            eligible=(elig_m.group(1) == "true") if elig_m else True,
        ))
    return cases


def parse_library():
    cases = []
    for n in range(1, PACK_COUNT + 1):
        for c in parse_pack(n):
            c["pack"] = n
            cases.append(c)
    return cases


def clamp01(x):
    return min(1.0, max(0.0, x))


def features(c):
    clues = c["clues"]
    n = max(1, len(clues))
    complexity = 0.0
    hard = chained = negative = relational = 0
    for clue in clues:
        s = CLUE_DIFFICULTY[clue["difficulty"]]
        s = min(1.0, s + FAMILY_BONUS.get(clue["family"], 0.0))
        complexity += s
        if clue["difficulty"] == "hard":
            hard += 1
        if clue["family"] == "chainedDeduction":
            chained += 1
        if clue["family"] in NEGATIVE_FAMILIES or "profileIsNot" in clue["constraints"]:
            negative += 1
        if clue["family"] in RELATIONAL_FAMILIES or any(k in TWO_PLAYER_CONSTRAINTS for k in clue["constraints"]):
            relational += 1
    missing = len(c["missing"])
    decoys = len(c["slots"]) - len(c["solution"])
    return dict(
        missing=missing, decoys=decoys, evidence=len(c["evidence"]),
        clue_complexity=complexity / n, hard_share=hard / n, chained_share=chained / n,
        negative_share=negative / n, relational_share=relational / n,
        distinct_profiles=len({p for _, _, p in c["solution"]}),
    )


def content_complexity(f, tier):
    """0…1 blended authored-content complexity."""
    pool = POOL_SIZE[tier]
    # Normalizers span the library's authoring envelope (4–6 missing, 4–7
    # decoys, 4–6 evidence, clue mix 0.5–0.75), so content differences use
    # the whole tier band. Fixed constants — adding a case never moves
    # another case's score.
    return clamp01(
        0.22 * clamp01((f["missing"] - 4) / 2)
        + 0.14 * clamp01((f["decoys"] - 4) / 3)
        + 0.06 * clamp01((f["evidence"] - 4) / 2)
        + 0.20 * clamp01((f["clue_complexity"] - 0.5) / 0.25)
        + 0.10 * clamp01((f["hard_share"] - 0.1) / 0.4)
        + 0.08 * clamp01(f["chained_share"] / 0.25)
        + 0.07 * clamp01(f["negative_share"] / 0.25)
        + 0.07 * clamp01(f["relational_share"] / 0.5)
        + 0.06 * clamp01((f["distinct_profiles"] - 1) / max(1, pool - 1))
    )


def timer_pressure(f, tier):
    """Hall of Famer only: 40-second clock per placement — more placements
    under the clock, more pressure."""
    if tier != "hallOfFamer":
        return 0.0
    return clamp01((f["missing"] - 4) / 2)


def calibrated_score(c):
    f = features(c)
    tier = c["tier"]
    cc = content_complexity(f, tier)
    if tier == "hallOfFamer":
        blended = 0.8 * cc + 0.2 * timer_pressure(f, tier)
    else:
        blended = cc
    raw = BAND_FLOOR[tier] + BAND_SPAN[tier] * blended
    # Round half away from zero (Swift `.rounded()` semantics).
    return max(1, min(100, int(raw + 0.5)))

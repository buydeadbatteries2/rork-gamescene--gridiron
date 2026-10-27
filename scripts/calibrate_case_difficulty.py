#!/usr/bin/env python3
"""
Phase 14A — writes a calibrated difficulty score into EVERY library case.

For each `CaseLibrary.makeCase(` in CasePack1…12.swift the script computes
the calibrated 1–100 score (scripts/case_difficulty_features.py, an exact
port of CaseDifficultyCalibration.swift) from the case's authored content and
writes an explicit trailer:

    tier: .<tier>, difficultyScore: <score>, isCompetitiveEligible: <bool>

Cases that already carry the trailer are updated in place; cases authored
before metadata existed (packs 1–6) get it appended after `solution:`. The
tier is preserved (packs 1–6 keep their band-derived tier), eligibility is
preserved. After running, re-export the catalog:

    python3 scripts/calibrate_case_difficulty.py
    python3 scripts/export_competitive_catalog.py
    bash scripts/regenerate-schema-fixture.sh
"""

import os, re, sys
from collections import defaultdict

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import case_difficulty_features as cdf  # noqa: E402

TRAILER = re.compile(r'tier: \.(\w+), difficultyScore: (\d+), isCompetitiveEligible: (true|false)')


def rewrite_block(block, case):
    trailer = f"tier: .{case['tier']}, difficultyScore: {cdf.calibrated_score(case)}, isCompetitiveEligible: {'true' if case['eligible'] else 'false'}"
    if TRAILER.search(block):
        return TRAILER.sub(trailer, block, count=1)
    sol = block.index("solution: [")
    close = re.compile(r'\n(\s*)\](\s*)\n(\s*)\)').search(block, sol)
    assert close, case["id"]
    indent = close.group(1)
    replacement = f"\n{indent}],\n{indent}{trailer}\n{close.group(3)})"
    return block[:close.start()] + replacement + block[close.end():]


def main():
    dist = defaultdict(list)
    for n in range(1, cdf.PACK_COUNT + 1):
        path = os.path.join(cdf.DATA, f"CasePack{n}.swift")
        text = open(path).read()
        cases = cdf.parse_pack(n)
        parts = text.split("CaseLibrary.makeCase(")
        assert len(parts) - 1 == len(cases)
        out = [parts[0]]
        for block, case in zip(parts[1:], cases):
            out.append(rewrite_block(block, case))
            dist[case["tier"]].append(cdf.calibrated_score(case))
        new = "CaseLibrary.makeCase(".join(out)
        if new != text:
            open(path, "w").write(new)
    # Verify by re-parsing: every case now carries its calibrated score.
    for c in cdf.parse_library():
        assert c["score"] == cdf.calibrated_score(c), c["id"]
    for tier in ["rookie", "pro", "allPro", "hallOfFamer"]:
        v = dist[tier]
        print(f"{tier:12s} {len(v):3d} cases  min {min(v)}  max {max(v)}  mean {sum(v)/len(v):.1f}")


if __name__ == "__main__":
    main()

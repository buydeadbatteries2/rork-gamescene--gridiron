#!/usr/bin/env python3
"""
Phase 11.6 case library expansion: 53 -> 150 validated cases.

Parses the existing CasePack1..6 files for already-used case ids, titles,
evidence-kind combinations, per-band position mixes and roster seeds, then
authors 97 new cases (seeds 53..149) that are validated IN THIS SCRIPT with a
faithful port of the Swift `CaseSolver` brute-force check before any Swift is
written. Outputs:

  GameSceneGridiron/Data/CaseRosterNames.swift     750 extra roster names (900 total)
  GameSceneGridiron/Data/CasePack7..12.swift       the new cases
  GameSceneGridiron/Data/CaseStatEventsGenerated.swift  stat events for the new cases

Re-runnable: deterministic (fixed RNG seed), skips nothing, rewrites outputs.
"""

import os, re, sys, random, itertools, math

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(ROOT, "ios-gamescene-gridiron", "GameSceneGridiron", "Data")

rng = random.Random(1162026)

# ---------------------------------------------------------------- parsing

def parse_packs():
    cases = []
    for n in range(1, 7):
        path = os.path.join(DATA, f"CasePack{n}.swift")
        text = open(path).read()
        blocks = text.split("CaseLibrary.makeCase(")[1:]
        for block in blocks:
            cid = re.search(r'id: "([^"]+)"', block).group(1)
            band = int(re.search(r'band: (\d+)', block).group(1))
            seed = int(re.search(r'seed: (\d+)', block).group(1))
            title = re.search(r'title: "([^"]+)"', block).group(1)
            heading = re.search(r'heading: "([^"]+)"', block).group(1)
            evs = re.findall(r'kind: \.(\w+)', block)
            missing = re.findall(r'\(key: "(\w+)", position: \.(\w+)\)', block)
            cases.append(dict(id=cid, band=band, seed=seed, title=title,
                              heading=heading, evidence=evs,
                              missing=[m[1] for m in missing]))
    return cases

legacy = parse_packs()
used_ids = {c["id"] for c in legacy}
used_titles = {c["title"] for c in legacy}
used_combos = {tuple(sorted(c["evidence"])) for c in legacy}
used_mixes = {b: {"-".join(sorted(c["missing"])) for c in legacy if c["band"] == b} for b in range(1, 6)}
used_seeds = {c["seed"] for c in legacy}
legacy_names = set()
lib = open(os.path.join(DATA, "CaseLibrary.swift")).read()
pool_block = re.search(r'static let pool: \[String\] = \[(.*?)\]\n', lib, re.S).group(1)
legacy_names = set(re.findall(r'"([^"]+)"', pool_block))
legacy_texts = set()
for n in range(1, 7):
    text = open(os.path.join(DATA, f"CasePack{n}.swift")).read()
    for m in re.findall(r'text: "((?:[^"\\]|\\.)*)"', text):
        legacy_texts.add(re.sub(r'[^a-z0-9 ]', ' ', m.lower()).split()and " ".join(re.sub(r'[^a-z0-9 ]', ' ', m.lower()).split()))

print(f"legacy: {len(legacy)} cases, {len(legacy_names)} names, {len(used_combos)} evidence combos")

# ---------------------------------------------------------------- catalogs

KINDS = [  # (kind, display title)
    ("orangeTowel", "Orange Towel"), ("droppedGlove", "Dropped Glove"),
    ("waterBottle", "Water Bottle"), ("muddyFootprints", "Muddy Footprints"),
    ("looseFootball", "Loose Football"), ("mouthguard", "Mouthguard"),
    ("wristPlaybook", "Wrist Playbook"), ("chinStrap", "Chin Strap"),
    ("brokenHelmetStrap", "Broken Helmet Strap"), ("looseCleat", "Loose Cleat"),
    ("kickingTee", "Kicking Tee"), ("handWarmer", "Hand Warmer"),
    ("shoulderPadStrap", "Shoulder-Pad Strap"), ("kneeBrace", "Knee Brace"),
    ("visorCloth", "Visor Cloth"), ("tapeRoll", "Tape Roll"),
    ("wristband", "Wristband"), ("sportsDrinkCup", "Sports Drink Cup"),
    ("droppedPlayCard", "Dropped Play Card"), ("clipboard", "Clipboard"),
    ("laminatedPlaySheet", "Laminated Play Sheet"), ("headset", "Headset"),
    ("challengeFlag", "Challenge Flag"), ("markerBoard", "Marker Board"),
    ("whistle", "Whistle"), ("equipmentBag", "Equipment Bag"),
    ("orangeCone", "Orange Cone"), ("pylon", "Pylon"),
    ("yardMarker", "Yard Marker"), ("chainMarker", "Chain Marker"),
    ("skidMarks", "Skid Marks"), ("tornTurf", "Torn Turf"),
    ("grassStain", "Grass Stain"), ("cleatMarks", "Cleat Marks"),
    ("divot", "Divot"), ("chalkMark", "Chalk Mark"),
    ("wetPatch", "Wet Patch"), ("draggedFootTrail", "Dragged-Foot Trail"),
]
KIND_TITLE = dict(KINDS)

POSITION_TITLE = {"qb": "quarterback", "rb": "running back", "wr": "receiver",
                  "te": "tight end", "ol": "offensive lineman", "dl": "defensive lineman",
                  "lb": "linebacker", "cb": "cornerback", "ss": "strong safety", "fs": "free safety"}

RELEVANT_STATS = {
    "qb": ["successfulReads", "drivesSecured", "scrambleOpportunities"],
    "rb": ["successfulRuns", "brokenTackles", "keyBlocks"],
    "wr": ["receptions", "bigPlays", "successfulAssignments"],
    "te": ["receptions", "bigPlays", "successfulAssignments"],
    "ol": ["blocks", "protectionWins"],
    "dl": ["tackles", "sacks", "pressures", "stops"],
    "lb": ["tackles", "stops", "coverageWins", "sacks"],
    "cb": ["tackles", "passBreakups", "interceptions", "coverageWins"],
    "ss": ["tackles", "passBreakups", "interceptions", "coverageWins"],
    "fs": ["tackles", "passBreakups", "interceptions", "coverageWins"],
}

# Formation templates: realistic visible formations with candidate anchor
# slots (missing-player placements) and decoy slots. All coordinates obey the
# field grammar used by the legacy packs (x 0.07–0.93, y 0.09–0.84, defense
# drawn at the top, offense at the bottom).
FORMATION_TEMPLATES = [
    dict(name="spread", visible=[
        ("ol", 0.30, 0.565), ("ol", 0.40, 0.565), ("ol", 0.50, 0.565), ("ol", 0.60, 0.565), ("ol", 0.70, 0.565),
        ("qb", 0.50, 0.655), ("wr", 0.075, 0.53), ("wr", 0.28, 0.525),
        ("dl", 0.28, 0.475), ("dl", 0.42, 0.475), ("dl", 0.58, 0.475), ("dl", 0.72, 0.475),
        ("lb", 0.50, 0.36), ("cb", 0.925, 0.435)],
        anchors={"rb": (0.62, 0.70), "te": (0.775, 0.565), "wr": (0.925, 0.53), "cb": (0.075, 0.435), "fs": (0.50, 0.13), "dl": (0.165, 0.465)},
        decoys=[(0.38, 0.70), (0.205, 0.525), (0.66, 0.295), (0.30, 0.17)]),
    dict(name="gun protection", visible=[
        ("ol", 0.30, 0.565), ("ol", 0.40, 0.565), ("ol", 0.50, 0.565), ("ol", 0.70, 0.565),
        ("rb", 0.42, 0.66), ("wr", 0.075, 0.53), ("wr", 0.925, 0.52),
        ("dl", 0.28, 0.475), ("dl", 0.42, 0.475), ("dl", 0.58, 0.475), ("dl", 0.72, 0.475),
        ("lb", 0.50, 0.36), ("fs", 0.50, 0.135)],
        anchors={"qb": (0.50, 0.655), "ol": (0.60, 0.565), "cb": (0.925, 0.435), "ss": (0.34, 0.295), "rb": (0.38, 0.70), "fs": (0.50, 0.115), "wr": (0.205, 0.525), "dl": (0.835, 0.465)},
        decoys=[(0.50, 0.605), (0.66, 0.295), (0.82, 0.155), (0.30, 0.28)]),
    dict(name="singleback", visible=[
        ("ol", 0.30, 0.565), ("ol", 0.40, 0.565), ("ol", 0.50, 0.565), ("ol", 0.60, 0.565), ("ol", 0.70, 0.565),
        ("qb", 0.50, 0.63), ("te", 0.775, 0.565), ("wr", 0.925, 0.52),
        ("dl", 0.28, 0.475), ("dl", 0.42, 0.475), ("dl", 0.58, 0.475), ("dl", 0.72, 0.475),
        ("lb", 0.34, 0.36), ("cb", 0.075, 0.435)],
        anchors={"rb": (0.38, 0.70), "wr": (0.075, 0.53), "lb": (0.66, 0.36), "fs": (0.32, 0.15), "cb": (0.935, 0.415), "dl": (0.80, 0.44)},
        decoys=[(0.62, 0.70), (0.34, 0.365), (0.50, 0.115), (0.205, 0.525)]),
    dict(name="tight edge", visible=[
        ("ol", 0.30, 0.565), ("ol", 0.40, 0.565), ("ol", 0.50, 0.565), ("ol", 0.70, 0.565),
        ("qb", 0.50, 0.63), ("wr", 0.075, 0.53), ("wr", 0.925, 0.52),
        ("dl", 0.28, 0.475), ("dl", 0.42, 0.475), ("dl", 0.58, 0.475), ("dl", 0.72, 0.475),
        ("lb", 0.50, 0.36), ("cb", 0.925, 0.435), ("ss", 0.68, 0.22)],
        anchors={"te": (0.775, 0.565), "ol": (0.60, 0.565), "dl": (0.165, 0.465), "cb": (0.075, 0.435), "fs": (0.30, 0.155), "ss": (0.66, 0.295), "lb": (0.85, 0.36)},
        decoys=[(0.245, 0.565), (0.14, 0.52), (0.835, 0.465), (0.30, 0.28)]),
    dict(name="two-back", visible=[
        ("ol", 0.30, 0.565), ("ol", 0.40, 0.565), ("ol", 0.50, 0.565), ("ol", 0.60, 0.565), ("ol", 0.70, 0.565),
        ("rb", 0.50, 0.72), ("te", 0.775, 0.565), ("wr", 0.075, 0.53),
        ("dl", 0.28, 0.475), ("dl", 0.42, 0.475), ("dl", 0.58, 0.475), ("dl", 0.72, 0.475),
        ("lb", 0.50, 0.36), ("lb", 0.34, 0.36), ("cb", 0.075, 0.435), ("cb", 0.925, 0.435), ("fs", 0.50, 0.135)],
        anchors={"qb": (0.50, 0.655), "rb": (0.62, 0.70), "wr": (0.925, 0.52), "ss": (0.66, 0.295), "fs": (0.50, 0.115), "dl": (0.165, 0.465), "lb": (0.80, 0.36)},
        decoys=[(0.50, 0.605), (0.38, 0.70), (0.80, 0.44), (0.82, 0.155), (0.34, 0.295)]),
    dict(name="trips", visible=[
        ("ol", 0.30, 0.565), ("ol", 0.40, 0.565), ("ol", 0.50, 0.565), ("ol", 0.60, 0.565), ("ol", 0.70, 0.565),
        ("qb", 0.50, 0.655), ("wr", 0.075, 0.53), ("wr", 0.80, 0.525), ("wr", 0.87, 0.545),
        ("dl", 0.28, 0.475), ("dl", 0.42, 0.475), ("dl", 0.58, 0.475), ("dl", 0.72, 0.475),
        ("lb", 0.50, 0.36), ("cb", 0.925, 0.435), ("ss", 0.35, 0.24)],
        anchors={"wr": (0.935, 0.53), "te": (0.245, 0.565), "lb": (0.66, 0.36), "fs": (0.50, 0.135), "cb": (0.075, 0.415), "rb": (0.38, 0.70), "ss": (0.30, 0.30), "dl": (0.165, 0.465)},
        decoys=[(0.14, 0.52), (0.855, 0.48), (0.30, 0.28), (0.30, 0.155)]),
    dict(name="short-yardage", visible=[
        ("ol", 0.30, 0.565), ("ol", 0.40, 0.565), ("ol", 0.50, 0.565), ("ol", 0.60, 0.565),
        ("qb", 0.50, 0.63), ("te", 0.225, 0.565), ("wr", 0.925, 0.52),
        ("dl", 0.28, 0.475), ("dl", 0.42, 0.475), ("dl", 0.58, 0.475),
        ("lb", 0.50, 0.36), ("cb", 0.075, 0.435), ("ss", 0.66, 0.24)],
        anchors={"rb": (0.50, 0.79), "ol": (0.70, 0.565), "dl": (0.72, 0.475), "fs": (0.50, 0.13), "cb": (0.925, 0.435), "wr": (0.14, 0.52), "lb": (0.80, 0.36)},
        decoys=[(0.38, 0.70), (0.83, 0.42), (0.66, 0.295), (0.70, 0.155)]),
    dict(name="bunch", visible=[
        ("ol", 0.30, 0.565), ("ol", 0.40, 0.565), ("ol", 0.50, 0.565), ("ol", 0.60, 0.565), ("ol", 0.70, 0.565),
        ("rb", 0.42, 0.68), ("wr", 0.14, 0.53), ("wr", 0.205, 0.545), ("wr", 0.925, 0.52),
        ("dl", 0.28, 0.475), ("dl", 0.42, 0.475), ("dl", 0.58, 0.475), ("dl", 0.72, 0.475),
        ("lb", 0.50, 0.36), ("cb", 0.075, 0.435), ("fs", 0.50, 0.135)],
        anchors={"qb": (0.50, 0.655), "te": (0.775, 0.565), "wr": (0.27, 0.545), "cb": (0.925, 0.435), "ss": (0.34, 0.295), "rb": (0.62, 0.70), "fs": (0.50, 0.115), "dl": (0.165, 0.465), "lb": (0.80, 0.36)},
        decoys=[(0.50, 0.605), (0.215, 0.575), (0.14, 0.52), (0.80, 0.155)]),
    dict(name="motion", visible=[
        ("ol", 0.30, 0.565), ("ol", 0.40, 0.565), ("ol", 0.50, 0.565), ("ol", 0.60, 0.565), ("ol", 0.70, 0.565),
        ("qb", 0.50, 0.655), ("te", 0.775, 0.565), ("wr", 0.925, 0.52),
        ("dl", 0.28, 0.475), ("dl", 0.42, 0.475), ("dl", 0.58, 0.475),
        ("lb", 0.50, 0.36), ("lb", 0.34, 0.36), ("cb", 0.925, 0.435), ("ss", 0.35, 0.24)],
        anchors={"wr": (0.075, 0.53), "rb": (0.38, 0.70), "dl": (0.165, 0.465), "cb": (0.075, 0.415), "fs": (0.50, 0.13), "te": (0.245, 0.565), "ss": (0.30, 0.30), "lb": (0.80, 0.36)},
        decoys=[(0.62, 0.70), (0.80, 0.44), (0.66, 0.295), (0.70, 0.155)]),
    dict(name="red zone", visible=[
        ("ol", 0.30, 0.565), ("ol", 0.40, 0.565), ("ol", 0.50, 0.565), ("ol", 0.60, 0.565),
        ("qb", 0.50, 0.63), ("rb", 0.50, 0.72), ("wr", 0.075, 0.53),
        ("dl", 0.28, 0.475), ("dl", 0.42, 0.475), ("dl", 0.58, 0.475), ("dl", 0.72, 0.475),
        ("lb", 0.50, 0.36), ("cb", 0.925, 0.435), ("fs", 0.50, 0.135)],
        anchors={"te": (0.775, 0.565), "ol": (0.70, 0.565), "lb": (0.66, 0.36), "ss": (0.32, 0.26), "wr": (0.925, 0.52), "rb": (0.50, 0.79), "fs": (0.50, 0.115), "dl": (0.165, 0.465), "cb": (0.075, 0.435)},
        decoys=[(0.245, 0.565), (0.85, 0.46), (0.78, 0.25), (0.30, 0.155), (0.14, 0.52)]),
    dict(name="empty", visible=[
        ("ol", 0.30, 0.565), ("ol", 0.40, 0.565), ("ol", 0.50, 0.565), ("ol", 0.60, 0.565), ("ol", 0.70, 0.565),
        ("qb", 0.50, 0.63), ("wr", 0.075, 0.53), ("wr", 0.925, 0.52), ("wr", 0.80, 0.525),
        ("dl", 0.28, 0.475), ("dl", 0.42, 0.475), ("dl", 0.58, 0.475), ("dl", 0.72, 0.475),
        ("lb", 0.50, 0.36), ("cb", 0.075, 0.435), ("fs", 0.50, 0.135)],
        anchors={"rb": (0.62, 0.70), "te": (0.775, 0.565), "dl": (0.165, 0.465), "ss": (0.34, 0.295), "wr": (0.205, 0.525), "cb": (0.935, 0.415), "fs": (0.50, 0.115), "lb": (0.66, 0.36)},
        decoys=[(0.38, 0.70), (0.80, 0.44), (0.30, 0.28)]),
    dict(name="goal line", visible=[
        ("ol", 0.30, 0.565), ("ol", 0.40, 0.565), ("ol", 0.50, 0.565), ("ol", 0.60, 0.565), ("ol", 0.70, 0.565),
        ("te", 0.225, 0.565), ("te", 0.775, 0.565), ("qb", 0.50, 0.63), ("rb", 0.50, 0.72),
        ("dl", 0.28, 0.475), ("dl", 0.42, 0.475), ("dl", 0.58, 0.475), ("dl", 0.72, 0.475),
        ("lb", 0.50, 0.36), ("cb", 0.075, 0.435), ("ss", 0.66, 0.24)],
        anchors={"wr": (0.925, 0.52), "rb": (0.50, 0.80), "fs": (0.50, 0.13), "dl": (0.80, 0.465), "cb": (0.075, 0.435), "ss": (0.30, 0.30), "lb": (0.80, 0.36)},
        decoys=[(0.15, 0.575), (0.66, 0.295), (0.30, 0.155), (0.14, 0.52), (0.62, 0.70)]),
    dict(name="field tornado", visible=[
        ("ol", 0.30, 0.565), ("ol", 0.40, 0.565), ("ol", 0.50, 0.565), ("ol", 0.60, 0.565), ("ol", 0.70, 0.565),
        ("qb", 0.50, 0.655), ("te", 0.775, 0.565),
        ("dl", 0.28, 0.475), ("dl", 0.42, 0.475), ("dl", 0.58, 0.475), ("dl", 0.72, 0.475),
        ("lb", 0.50, 0.36), ("cb", 0.075, 0.435), ("cb", 0.925, 0.435)],
        anchors={"rb": (0.38, 0.70), "wr": (0.925, 0.52), "fs": (0.30, 0.15), "ss": (0.66, 0.295), "lb": (0.34, 0.365), "te": (0.855, 0.52), "cb": (0.075, 0.415), "dl": (0.835, 0.465)},
        decoys=[(0.62, 0.70), (0.50, 0.115), (0.80, 0.44), (0.205, 0.525)]),
    dict(name="overload", visible=[
        ("ol", 0.30, 0.565), ("ol", 0.40, 0.565), ("ol", 0.50, 0.565), ("ol", 0.60, 0.565),
        ("qb", 0.50, 0.655), ("rb", 0.62, 0.70), ("wr", 0.925, 0.52), ("te", 0.225, 0.565),
        ("dl", 0.28, 0.475), ("dl", 0.42, 0.475), ("dl", 0.58, 0.475), ("dl", 0.72, 0.475),
        ("lb", 0.50, 0.36), ("fs", 0.50, 0.135), ("cb", 0.075, 0.435)],
        anchors={"wr": (0.075, 0.53), "ol": (0.70, 0.565), "ss": (0.34, 0.295), "dl": (0.835, 0.465), "cb": (0.925, 0.435), "rb": (0.38, 0.72), "fs": (0.50, 0.115), "lb": (0.34, 0.365)},
        decoys=[(0.30, 0.28), (0.80, 0.155), (0.14, 0.52), (0.62, 0.70)]),
]

# Position mixes (the missing set) — used as a fallback pool; primary
# selection enumerates anchor subsets per formation template.
MIXES = [
    ("rb", "wr", "cb", "fs"), ("te", "ol", "dl", "cb"), ("qb", "rb", "lb", "ss"),
    ("wr", "te", "lb", "fs"), ("ol", "dl", "cb", "ss"), ("rb", "ol", "dl", "fs"),
    ("qb", "wr", "cb", "fs"), ("rb", "te", "ss", "fs"), ("wr", "ol", "dl", "lb"),
    ("rb", "te", "dl", "cb"), ("qb", "te", "lb", "fs"), ("wr", "rb", "cb", "ss"),
    ("te", "wr", "dl", "ss"), ("wr", "ol", "dl", "cb"), ("qb", "ol", "cb", "fs"),
    ("rb", "wr", "lb", "fs"), ("dl", "lb", "cb", "wr"), ("qb", "rb", "wr", "ol"),
    ("te", "fs", "ss", "cb"), ("rb", "lb", "cb", "fs"), ("wr", "te", "ol", "ss"),
    ("qb", "rb", "dl", "fs"), ("te", "ol", "lb", "cb"), ("wr", "rb", "dl", "ss"),
    ("rb", "te", "wr", "cb", "fs"), ("qb", "rb", "wr", "te", "ol"), ("ol", "te", "wr", "dl", "fs"),
    ("qb", "rb", "cb", "ss", "fs"), ("wr", "te", "lb", "cb", "fs"), ("rb", "ol", "dl", "lb", "fs"),
    ("qb", "wr", "te", "dl", "cb"), ("rb", "wr", "te", "lb", "ss"), ("qb", "rb", "wr", "cb", "fs"),
    ("te", "ol", "dl", "lb", "cb"), ("qb", "rb", "te", "ss", "fs"), ("wr", "ol", "dl", "cb", "fs"),
    ("rb", "te", "dl", "lb", "ss"), ("qb", "wr", "ol", "cb", "ss"), ("rb", "wr", "dl", "cb", "fs"),
    ("te", "wr", "lb", "ss", "fs"), ("qb", "rb", "ol", "lb", "cb"), ("wr", "rb", "te", "dl", "fs"),
    ("ol", "rb", "cb", "ss", "fs"), ("qb", "te", "wr", "lb", "fs"), ("rb", "wr", "ol", "dl", "ss"),
    ("qb", "rb", "wr1", "wr2", "cb", "fs"), ("te", "ol", "dl", "lb", "cb", "ss"),
    ("rb", "te", "wr", "ol", "fs", "ss"), ("wr1", "wr2", "te", "dl", "cb", "fs"),
    ("qb", "rb", "ol", "lb", "cb", "ss"), ("rb", "wr", "te", "dl", "ss", "fs"),
    ("qb", "rb", "te", "ol", "cb", "fs"), ("ol", "te", "wr1", "wr2", "lb", "fs"),
    ("rb", "wr1", "wr2", "dl", "ss", "fs"), ("qb", "rb", "wr", "te", "dl", "cb"),
]

FIRST = ["Amos", "Bruno", "Cato", "Dov", "Eli", "Finn", "Gus", "Hank", "Ike", "Jae",
         "Kofi", "Lamar", "Miles", "Nico", "Omar", "Pete", "Quincy", "Ray", "Silas", "Tobias",
         "Ulysses", "Vic", "Wade", "Xavi", "Yuri", "Zack", "Andre", "Bail", "Cyrus", "Dev",
         "Emory", "Felix", "Grant", "Hugh", "Ivan", "Jonah", "Kai", "Lev", "Marek", "Nate",
         "Otis", "Paul", "Quinn", "Rocco", "Sam", "Tomas", "Ulric", "Vince", "Wes", "Yusuf"]
LAST = ["Delgado", "Vance", "Brill", "Marsh", "Sandoval", "Corrigan", "Prather", "Ostrander",
        "Munoz", "Parkin", "Adjei", "Ogden", "Okoro", "Peters", "Siddiq", "Lindholm", "Duke",
        "Underhill", "Bartok", "Fenn", "Grantham", "Sorrell", "Kimura", "Tolbert", "Volkov",
        "Mercer", "Kingsley", "Osei", "Dunn", "Okonkwo", "Colton", "Ibarra", "Hollis",
        "Nakamura", "Bezdek", "Redmond", "Brennan", "Aronov", "Dvorak", "Farrow", "Granger",
        "Kimbrough", "Ashby", "Baldini", "Ellery", "Vesely", "Tan", "Barrow", "Calloway",
        "Kane"]

def extra_names(count=750):
    names, seen = [], set(legacy_names)
    combos = [(f, l) for f in FIRST for l in LAST]
    rng.shuffle(combos)
    for f, l in combos:
        full = f"{f} {l}"
        if full not in seen:
            seen.add(full)
            names.append(full)
        if len(names) >= count:
            break
    assert len(names) == count, f"only {len(names)} extra names"
    return names

# ---------------------------------------------------------------- prose banks

TITLE_A = ["Silent", "Crooked", "Blinking", "Buried", "Borrowed", "Restless", "Crooked", "Broken",
           "Quiet", "Hollow", "Stubborn", "Rusted", "Crimson", "Heavy", "Reckless", "Patient",
           "Wandering", "Fading", "Ivory", "Slate", "Iron", "Velvet", "Narrow", "Wilted",
           "Jagged", "Second", "Marble", "Copper", "Sudden", "Willing", "Bitter", "Golden"]
TITLE_B = ["Count", "Audible", "Mirror", "Interval", "Snap", "Cadence", "Bracket", "Bender",
           "Flood", "Wall", "Wing", "Blind", "Signal", "Statue", "Bootleg", "Pinch", "Gate",
           "Trap", "Swing", "Screen", "Stunt", "Loop", "Slant", "Post", "Corner", "Hook",
           "Curl", "Drive", "Dive", "Pitch", "Sweep", "Reverse", "Fountain", "Bounce", "Edge",
           "Margin", "Clock", "Ledger", "Verdict", "Alibi", "Footnote", "Pivot", "Detour",
           "Rally", "Rebate", "Settle", "Draft", "Ledger"]

def make_titles(count):
    titles, seen = [], set(used_titles)
    pairs = [(a, b) for a in TITLE_A for b in TITLE_B]
    rng.shuffle(pairs)
    for a, b in pairs:
        t = f"The {a} {b}"
        if t not in seen:
            seen.add(t)
            titles.append(t)
        if len(titles) >= count:
            break
    assert len(titles) == count, f"only {len(titles)} titles"
    return titles

HEADINGS = ["FILM ROOM", "SIDELINE REPORT", "EVIDENCE LOCKER", "PRENTICE FILES", "MONDAY REVIEW",
            "PRESS GALLERY", "SCOUTING MEMO", "NIGHT SHIFT", "CASE REOPENED", "TURF TRUTH",
            "COUNTING HOUSE", "GRASS LEDGER"]

TIER_PROFILE_CYCLE = {
    "rookie": ["rookie", "veteran"],
    "pro": ["fast", "powerful", "veteran"],
    "allPro": ["fast", "powerful", "veteran", "rookie", "overrated"],
    "hallOfFamer": ["powerful", "rookie", "fast", "overrated", "veteran"],
}

PROFILE_CLAUSES = {
    "rookie": [
        "The call asks for a first-year learner — someone still growing into the job.",
        "This is a job for the young one, still learning what the formation does.",
        "The staff wants the newest jersey here, raw but in the right spot.",
        "A developing player takes this rep — the assignment is simple and the reps are precious.",
    ],
    "veteran": [
        "A seasoned head has seen this look a dozen times and settles without drama.",
        "Years of reads show in the first step — this spot demands the steadiest head.",
        "The staff trusts a decade of discipline here more than any fresh legs.",
        "Poise over promise: this rep belongs to someone who has already lived it.",
    ],
    "fast": [
        "Only instant acceleration wins this spot before the window closes.",
        "Recovery speed is the whole job here — no cushion survives without it.",
        "The first three steps decide this rep, and only a burner owns them.",
        "This is wheels territory — track speed or the play dies at the line.",
    ],
    "powerful": [
        "The point of attack demands an immovable anchor, not a dancer.",
        "Strength over everything — whoever lines up here will not be moved.",
        "A bull rush is coming and the answer is a wall with hands.",
        "This spot gets won with leverage and violence, nothing else.",
    ],
    "overrated": [
        "The name on the roster sheet is bigger than the recent tape.",
        "The headlines have been writing this check; the execution stopped co-signing weeks ago.",
        "Reputation got him the jersey — the last month of film tells the truth.",
        "He talks a good game and the market still believes; the tape has moved on.",
    ],
}

FAMILY_GEOMETRY = {
    "footballResponsibility": "The job description fits exactly one man: the {pos} {side_depth}, right where the {ev} lies.",
    "evidenceRelationship": "Tied to the ground: the {ev} marks where this {pos} worked — {side_depth}.",
    "formationKnowledge": "Formation logic: against this look, the {pos} must take the {side_depth} spot, and the {ev} sits at his feet.",
    "scenario": "The situation points straight at the {ev}: the {pos} belongs {side_depth}.",
    "relativePosition": "Measured against the rest of the formation, the {pos} takes the {side_depth} spot beside the {ev}.",
    "elimination": "Every other candidate is accounted for; the {ev} settles the last one — the {pos}, {side_depth}.",
    "chainedDeduction": "Chain the reads and only one man fits: the {pos} {side_depth}, at the {ev}.",
    "orderDepth": "Depth order settles it: the {pos} {side_depth}, the {ev} dropped at his heel.",
}

def side_depth_phrase(x, y):
    side = "left sideline" if x < 0.3 else ("middle of the field" if x < 0.7 else "right sideline")
    if y < 0.3: depth = "deep downfield"
    elif y < 0.52: depth = "in the second level"
    elif y < 0.66: depth = "just past the line of scrimmage"
    else: depth = "in the backfield"
    return f"{side}, {depth}"

def dist(a, b):
    return math.hypot(a[0] - b[0], a[1] - b[1])

# ---------------------------------------------------------------- solver port

def diagnose(case):
    """Faithful port of CaseSolver.diagnose for the constraint subset used."""
    slots = {s["key"]: (s["x"], s["y"]) for s in case["slots"]}
    evs = {e["key"]: (e["x"], e["y"]) for e in case["evidence"]}
    keys = [p["key"] for p in case["missing"]]

    single, multi, prof = {}, [], {}
    for clue in case["clues"]:
        for c in clue["constraints"]:
            if c[0] == "profileIs" or c[0] == "profileIsNot":
                prof.setdefault(c[1], []).append(c)
            elif c[0] in ("nearEvidence", "depthBand", "xBand"):
                single.setdefault(c[1], []).append(c)
            else:
                multi.append(c)

    referenced = {c[2] for clue in case["clues"] for c in clue["constraints"] if c[0] in ("profileIs", "profileIsNot")}
    universe = {"fast", "powerful", "veteran"} | referenced
    variants = {}
    for key in keys:
        options = set(universe)
        for c in prof.get(key, []):
            if c[0] == "profileIs": options = {c[2]}
            else: options.discard(c[2])
        variants[key] = options

    allowed = {}
    for key in keys:
        cs = single.get(key, [])
        if not cs:
            allowed[key] = set(slots)
        else:
            ok = set()
            for sk, pos in slots.items():
                if all(c_satisfies_single(c, pos, evs) for c in cs):
                    ok.add(sk)
            allowed[key] = ok

    # intended check
    assignment = {e["player"]: slots[e["slot"]] for e in case["solution"]}
    ivars = {e["player"]: e["profile"] for e in case["solution"]}
    violations = []
    for clue in case["clues"]:
        for c in clue["constraints"]:
            if not c_satisfies(c, assignment, ivars, evs):
                violations.append(str(c))
    for e in case["solution"]:
        if e["profile"] not in variants[e["player"]]:
            violations.append(f"profile not allowed for {e['player']}")
        if e["slot"] not in allowed[e["player"]]:
            violations.append(f"slot not allowed for {e['player']}")

    count = 0
    def assign(i, used, current):
        nonlocal count
        if count >= 10000: return
        if i == len(keys):
            full = {k: slots[v] for k, v in current.items()}
            if all(c_satisfies(c, full, {}, evs) for c in multi):
                count += 1
            return
        key = keys[i]
        for sk in sorted(allowed[key]):
            if sk in used: continue
            nxt = dict(current); nxt[key] = sk
            full = {k: slots[v] for k, v in nxt.items()}
            ok = True
            for c in multi:
                refs = c_refs(c)
                if all(r in nxt for r in refs) and not c_satisfies(c, full, {}, evs):
                    ok = False; break
            if ok:
                assign(i + 1, used | {sk}, nxt)
    assign(0, set(), {})
    return count, variants, violations

def c_satisfies_single(c, pos, evs):
    if c[0] == "nearEvidence":
        return dist(pos, evs[c[2]]) <= c[3]
    if c[0] == "depthBand":
        return c[2] <= pos[1] <= c[3]
    if c[0] == "xBand":
        return c[2] <= pos[0] <= c[3]
    return True

def c_refs(c):
    if c[0] in ("profileIs", "profileIsNot", "nearEvidence", "nearestToEvidence",
                "farthestFromEvidence", "depthBand", "xBand"):
        return {c[1]}
    if c[0] in ("sameSideOfBall", "oppositeSideOfBall", "yAbove", "yBelow"):
        return {c[1], c[2]}
    raise ValueError(c)

def c_satisfies(c, assignment, variants, evs):
    if c[0] == "nearEvidence":
        p = assignment.get(c[1]); e = evs.get(c[2])
        return p is not None and e is not None and dist(p, e) <= c[3]
    if c[0] == "depthBand":
        p = assignment.get(c[1]); return p is not None and c[2] <= p[1] <= c[3]
    if c[0] == "xBand":
        p = assignment.get(c[1]); return p is not None and c[2] <= p[0] <= c[3]
    if c[0] == "yAbove":
        pa, pb = assignment.get(c[1]), assignment.get(c[2])
        return pa is not None and pb is not None and pa[1] <= pb[1] - c[3]
    if c[0] == "yBelow":
        pa, pb = assignment.get(c[1]), assignment.get(c[2])
        return pa is not None and pb is not None and pa[1] >= pb[1] + c[3]
    if c[0] == "sameSideOfBall":
        pa, pb = assignment.get(c[1]), assignment.get(c[2])
        return pa is not None and pb is not None and (pa[0] < 0.5) == (pb[0] < 0.5)
    if c[0] == "oppositeSideOfBall":
        pa, pb = assignment.get(c[1]), assignment.get(c[2])
        return pa is not None and pb is not None and (pa[0] < 0.5) != (pb[0] < 0.5)
    if c[0] == "profileIs":
        return variants.get(c[1]) == c[2]
    if c[0] == "profileIsNot":
        chosen = variants.get(c[1])
        return chosen is None or chosen != c[2]
    raise ValueError(c)

# ---------------------------------------------------------------- case builder

EVIDENCE_OFFSETS = [(0.02, 0.015), (-0.025, 0.012), (0.015, -0.02), (0.0, 0.026), (-0.02, -0.015), (0.026, 0.0)]
ROTATIONS = [-12, 8, 24, -30, 45, -6, 18, 36, -18, 60, -42, 12]

def build_case(cid, seed, band, tier, title, index_in_tier):
    # Deterministically pick a (formation, missing-set) pair whose mix is
    # still unused in this band: rotate templates by case index, then walk
    # every 4-6 position subset of the template's anchor map in a stable
    # order until one is free.
    start = (index_in_tier + seed) % len(FORMATION_TEMPLATES)
    chosen = None
    for t_offset in range(len(FORMATION_TEMPLATES)):
        template = FORMATION_TEMPLATES[(start + t_offset) % len(FORMATION_TEMPLATES)]
        anchor_keys = sorted(template["anchors"])
        for size in (4, 5, 6):
            for mix in itertools.combinations(anchor_keys, size):
                key = "-".join(sorted(mix))
                if key in used_mixes[band]:
                    continue
                chosen = (template, mix)
                break
            if chosen:
                break
        if chosen:
            break
    if not chosen:
        raise SystemExit(f"{cid}: no unused mix for band {band}")
    template, mix = chosen
    used_mixes[band].add("-".join(sorted(mix)))

    positions = {}
    for p in mix:
        positions[p] = (p, template["anchors"][p])
    n = len(mix)

    # Slots: solution slots (jittered) + decoys. Anchors are >= 0.09 apart by
    # template; evidence placement (below) keeps every pin unambiguous.
    pts, slots = [], []
    for i, (p, (base, (ax, ay))) in enumerate(positions.items()):
        jx, jy = ax, ay
        for _ in range(9):
            cand = (ax + rng.choice([-1, 0, 1]) * 0.004, ay + rng.choice([-1, 0, 1]) * 0.004)
            if all(dist(cand, q) >= 0.07 for q in pts):
                jx, jy = cand
                break
        side = "left" if jx < 0.3 else ("mid" if jx < 0.7 else "right")
        depth = "deep" if jy < 0.3 else ("mid" if jy < 0.55 else ("line" if jy < 0.66 else "back"))
        pts.append((jx, jy))
        slots.append(dict(key=f"{base}-{side}-{depth}-{i}", x=round(jx, 3), y=round(jy, 3)))

    # Decoys: deterministic lattice (same idea as the adapter's runtime
    # decoys), kept clear of anchors, visible players and existing decoys.
    decoy_budget = 4 if n >= 5 else 5
    decoy_rng = random.Random(hash((cid, seed)) & 0xFFFFFFFF)
    chosen_decoys = []
    y = 0.14
    while y <= 0.82 and len(chosen_decoys) < decoy_budget:
        x = 0.09
        while x <= 0.91 and len(chosen_decoys) < decoy_budget:
            cand = (x + decoy_rng.uniform(-0.02, 0.02), y + decoy_rng.uniform(-0.02, 0.02))
            if all(dist(cand, q) >= 0.09 for q in pts + chosen_decoys) \
               and all(dist(cand, v[1:]) >= 0.075 for v in template["visible"]):
                chosen_decoys.append((round(cand[0], 3), round(cand[1], 3)))
            x += 0.085
        y += 0.085
    assert len(chosen_decoys) >= 3, f"too few decoys in {cid}"
    for i, (dx, dy) in enumerate(chosen_decoys):
        slots.append(dict(key=f"decoy-{chr(97 + i)}", x=dx, y=dy))

    # Evidence: one kind per player, combo unique across the library.
    while True:
        kinds = rng.sample(KINDS, n)
        combo = tuple(sorted(k[0] for k in kinds))
        if combo not in used_combos:
            used_combos.add(combo)
            break
    evidence = []
    ev_key_of = {}
    for i, ((kind, _), (p, (base, _))) in enumerate(zip(kinds, positions.items())):
        sx, sy = slots[i]["x"], slots[i]["y"]
        # Off-axis placement: scan directions and magnitudes for a spot
        # within the 0.08 pin radius of its OWN slot but clear of every
        # other slot (the legacy packs' trick for tight slot pairs).
        placed = None
        for step in range(24):
            ang = step * (2 * math.pi / 24)
            for mul in (0.03, 0.045, 0.06, 0.074):
                cand = (sx + math.cos(ang) * mul, sy + math.sin(ang) * mul)
                if not (0.05 <= cand[0] <= 0.95 and 0.05 <= cand[1] <= 0.88):
                    continue
                if dist(cand, (sx, sy)) > 0.078:
                    continue
                if all(dist(cand, (q["x"], q["y"])) > 0.085
                       for j, q in enumerate(slots) if j != i):
                    placed = cand
                    break
            if placed:
                break
        assert placed, f"no clear evidence spot for {cid}/{p}"
        ev_key = f"ev{i + 1}"
        ev_key_of[p] = ev_key
        evidence.append(dict(key=ev_key, kind=kind,
                             x=round(placed[0], 3), y=round(placed[1], 3),
                             rotation=rng.choice(ROTATIONS)))

    # Profiles: cycle the tier's pool with a per-case offset (no stereotypes).
    cycle = TIER_PROFILE_CYCLE[tier]
    offset = (index_in_tier + seed) % len(cycle)
    profiles = {p: cycle[(i + offset) % len(cycle)] for i, p in enumerate(mix)}

    # Clue difficulty pattern (>=1 easy, >=1 hard) and family rotation (>=4).
    if n == 4: pattern = ["easy", "medium", "medium", "hard"]
    elif n == 5: pattern = ["easy", "medium", "medium", "hard", "hard"] if index_in_tier % 2 == 0 else ["easy", "easy", "medium", "hard", "hard"]
    else: pattern = ["easy", "medium", "medium", "hard", "hard", "medium"] if index_in_tier % 2 == 0 else ["easy", "easy", "medium", "hard", "hard", "hard"]
    family_order = ["scenario", "evidenceRelationship", "footballResponsibility", "relativePosition",
                    "formationKnowledge", "elimination", "chainedDeduction", "orderDepth"]
    fam_start = (index_in_tier + seed) % len(family_order)
    families = [family_order[(fam_start + i) % len(family_order)] for i in range(n)]

    clues, hints, solution = [], [], []
    for i, (p, (base, _)) in enumerate(positions.items()):
        slot = slots[i]
        ev = evidence[i]
        ev_key = ev["key"]
        ev_title = KIND_TITLE[ev["kind"]].lower()
        pos_full = POSITION_TITLE[base]
        sd = side_depth_phrase(slot["x"], slot["y"])
        geo = FAMILY_GEOMETRY[families[i]].format(pos=pos_full, ev=ev_title, side_depth=sd)
        clause = PROFILE_CLAUSES[profiles[p]][(i + seed) % len(PROFILE_CLAUSES[profiles[p]])]
        stamp = f"Case file: {title} — sheet {i + 1}."
        text = f"{geo} {clause} {stamp}"

        constraints = [f"nearEvidence:{p}:{ev_key}:0.08", f"profileIs:{p}:{profiles[p]}"]
        clues.append(dict(player=p, family=families[i], difficulty=pattern[i],
                          text=text, constraints=constraints, evidence=[ev_key]))
        hints.append(dict(player=p,
                          text=f"Focus on the {pos_full} — {sd.replace(', ', ', ')}, by the {ev_title}. (The {title} file.)"))
        solution.append(dict(player=p, slot=slot["key"], profile=profiles[p]))

    # One cross-player relational statement per case (always true of the
    # intended geometry) for elimination flavor.
    if n >= 2:
        a, b = mix[0], mix[1]
        pa, pb = slots[0], slots[1]
        if (pa["x"] < 0.5) == (pb["x"] < 0.5):
            clues[0]["constraints"].append(f"sameSideOfBall:{a}:{b}")
        else:
            clues[0]["constraints"].append(f"oppositeSideOfBall:{a}:{b}")

    # Stat events.
    stats = {}
    for i, (p, (base, _)) in enumerate(positions.items()):
        rel = RELEVANT_STATS[base]
        stats[p] = rel[(i + seed) % len(rel)]

    return dict(id=cid, seed=seed, band=band, tier=tier, title=title,
                formation=template["name"], visible=template["visible"],
                missing=[dict(key=p, position=p.rstrip("12")) for p in mix],
                evidence=evidence, slots=slots, clues=clues, hints=hints,
                solution=solution, stats=stats)

# ---------------------------------------------------------------- swift emit

def swift_constraint(c):
    kind = c[0]
    if kind == "nearEvidence":
        return f'.nearEvidence(player: "{c[1]}", evidence: "{c[2]}", radius: {c[3]})'
    if kind == "profileIs":
        return f'.profileIs(player: "{c[1]}", profile: .{c[2]})'
    if kind == "profileIsNot":
        return f'.profileIsNot(player: "{c[1]}", profile: .{c[2]})'
    if kind == "sameSideOfBall":
        return f'.sameSideOfBall(a: "{c[1]}", b: "{c[2]}")'
    if kind == "oppositeSideOfBall":
        return f'.oppositeSideOfBall(a: "{c[1]}", b: "{c[2]}")'
    raise ValueError(c)

def _unused_legacy(c):
    parts = c.split(":")
    if parts[0] == "nearEvidence":
        return f'.nearEvidence(player: "{parts[1]}", evidence: "{parts[2]}", radius: {parts[3]})'
    if parts[0] == "profileIs":
        return f'.profileIs(player: "{parts[1]}", profile: .{parts[2]})'
    if parts[0] == "profileIsNot":
        return f'.profileIsNot(player: "{parts[1]}", profile: .{parts[2]})'
    if parts[0] == "sameSideOfBall":
        return f'.sameSideOfBall(a: "{parts[1]}", b: "{parts[2]}")'
    if parts[0] == "oppositeSideOfBall":
        return f'.oppositeSideOfBall(a: "{parts[1]}", b: "{parts[2]}")'
    raise ValueError(c)

def swift_case(c):
    lines = []
    lines.append(f'        // {c["title"]} — {c["formation"]} look ({c["tier"]} tier, band {c["band"]})')
    lines.append('        CaseLibrary.makeCase(')
    lines.append(f'            id: "{c["id"]}", seed: {c["seed"]}, band: {c["band"]},')
    lines.append(f'            title: "{c["title"]}",')
    lines.append(f'            heading: "{c["heading"]}",')
    lines.append(f'            body: "{c["body"]}",')
    vis = ", ".join(f'.{p[0]}' for p in [("x",)] )  # placeholder no-op
    lines.append('            visible: Formation.build { b in')
    for (pos, x, y) in c["visible"]:
        lines.append(f'                b.add(.{pos}, {x}, {y})')
    lines.append('            },')
    lines.append('            missing: [')
    for m in c["missing"]:
        lines.append(f'                (key: "{m["key"]}", position: .{m["position"]}),')
    lines.append('            ],')
    lines.append('            evidence: [')
    for e in c["evidence"]:
        lines.append(f'                (key: "{e["key"]}", kind: .{e["kind"]}, x: {e["x"]}, y: {e["y"]}, rotation: {e["rotation"]}),')
    lines.append('            ],')
    lines.append('            slots: [')
    for s in c["slots"]:
        lines.append(f'                (key: "{s["key"]}", x: {s["x"]}, y: {s["y"]}),')
    lines.append('            ],')
    lines.append('            clues: [')
    for clue in c["clues"]:
        cons = ", ".join(swift_constraint(cc) for cc in clue["constraints"])
        lines.append(f'                (player: "{clue["player"]}", family: .{clue["family"]}, difficulty: .{clue["difficulty"]},')
        lines.append(f'                 text: "{clue["text"]}",')
        lines.append(f'                 constraints: [{cons}],')
        lines.append(f'                 evidence: [{", ".join(chr(34) + k + chr(34) for k in clue["evidence"])}]),')
    lines.append('            ],')
    lines.append('            hints: [')
    for h in c["hints"]:
        lines.append(f'                (player: "{h["player"]}", text: "{h["text"]}"),')
    lines.append('            ],')
    lines.append('            solution: [')
    for s in c["solution"]:
        lines.append(f'                (player: "{s["player"]}", slot: "{s["slot"]}", profile: .{s["profile"]}),')
    lines.append('            ],')
    lines.append(f'            tier: .{c["tier"]}, difficultyScore: {c["score"]}, isCompetitiveEligible: {str(c["eligible"]).lower()}')
    lines.append('        ),')
    return "\n".join(lines)

def difficulty_score(c):
    # Same formula as CaseDifficultyProfile (rating 0...1 -> 1...100).
    n_clues = max(1, len(c["clues"]))
    decoys = len(c["slots"]) - len(c["solution"])
    complexity = 0.0
    for clue in c["clues"]:
        s = {"easy": 0.2, "medium": 0.5, "hard": 1.0}[clue["difficulty"]]
        if clue["family"] == "chainedDeduction": s = min(1, s + 0.3)
        if clue["family"] == "orderDepth": s = min(1, s + 0.15)
        if clue["family"] in ("negative", "elimination"): s = min(1, s + 0.1)
        complexity += s
    clue_complexity = complexity / n_clues
    hard_share = sum(1 for cl in c["clues"] if cl["difficulty"] == "hard") / n_clues
    negative_share = 0.0
    norm_missing = min(1, max(0, (len(c["missing"]) - 3) / 3))
    norm_decoys = min(1, decoys / 5)
    norm_ev = min(1, max(0, (len(c["evidence"]) - 3) / 3))
    rating = min(1, max(0, 0.25 * norm_missing + 0.18 * norm_decoys + 0.24 * clue_complexity
                        + 0.13 * hard_share + 0.10 * negative_share + 0.05 * norm_ev + 0.03))
    return min(100, max(1, round(rating * 100)))

# ---------------------------------------------------------------- assemble

def parse_constraint(c):
    parts = c.split(":")
    if parts[0] == "nearEvidence":
        return ("nearEvidence", parts[1], parts[2], float(parts[3]))
    if parts[0] in ("profileIs", "profileIsNot", "sameSideOfBall", "oppositeSideOfBall"):
        return (parts[0], parts[1], parts[2])
    raise ValueError(c)

# Legacy band-to-tier mapping (see CaseLibrary.makeCase): bands 1-2 are Pro
# content (the legacy fast/power/veteran dialect), band 3 All-Pro, bands 4-5
# Hall of Famer — legacy totals: pro 20, allPro 11, hof 22, rookie 0.
tier_plan = [("rookie", 30), ("pro", 20), ("allPro", 29), ("hallOfFamer", 18)]
bodies = {
    "rookie": "A young roster, a {formation} look, and {n} jerseys that never came out of the tunnel.",
    "pro": "The {formation} look on tape, and {n} pieces of it missing.",
    "allPro": "A {formation} look with {n} men unaccounted for — and the answers are not friendly.",
    "hallOfFamer": "The {formation} look, stripped bare: {n} men missing and every read earned.",
}

new_cases = []
seed = 53
for tier, count in tier_plan:
    for i in range(count):
        band = ((seed - 53) % 5) + 1
        cid_num = seed + 7  # deterministic id numbering, no legacy collision
        new_cases.append(dict(_tier=tier, _i=i, _band=band, _seed=seed, _num=cid_num))
        seed += 1

titles = make_titles(97)

final_cases = []
for entry, title in zip(new_cases, titles):
    cid = f"case_{entry['_tier']}_{entry['_num']:03d}"
    # builder picks mix per band-uniqueness; run it
    c = build_case(cid, entry["_seed"], entry["_band"], entry["_tier"], title, entry["_i"])
    for clue in c["clues"]:
        clue["constraints"] = [parse_constraint(x) for x in clue["constraints"]]
    c["heading"] = HEADINGS[entry["_i"] % len(HEADINGS)]
    c["body"] = bodies[entry["_tier"]].format(formation=c["formation"], n=len(c["missing"]))
    c["score"] = difficulty_score(c)
    # Experimental (competitive-ineligible): the heaviest 6-missing shapes.
    c["eligible"] = not (len(c["missing"]) == 6 and c["score"] >= 70)
    final_cases.append(c)

# Validate all cases with the solver port before writing anything.
failures = []
for c in final_cases:
    count, variants, violations = diagnose(c)
    if count != 1 or violations:
        failures.append((c["id"], count, violations[:3]))
    if any(len(v) != 1 for v in variants.values()):
        failures.append((c["id"], "ambiguous profiles", {k: sorted(v) for k, v in variants.items() if len(v) != 1}))
if failures:
    for f in failures[:10]:
        print("FAIL", f)
    sys.exit(f"{len(failures)} case(s) failed validation")

# Per-case solver-unique + per-tier rules already hold by construction; verify tier rules.
for c in final_cases:
    sols = {s["profile"] for s in c["solution"]}
    if c["tier"] == "rookie" and not sols <= {"rookie", "veteran"}:
        sys.exit(f"{c['id']}: rookie tier used {sols}")
    if c["tier"] == "pro" and "overrated" in sols:
        sys.exit(f"{c['id']}: pro tier used overrated")

# ---------------------------------------------------------------- write packs

PACK_SIZES = [17, 17, 16, 16, 16, 15]
packs = [[] for _ in PACK_SIZES]
idx = 0
for pack_id, size in enumerate(PACK_SIZES, start=7):
    packs[pack_id - 7] = final_cases[idx:idx + size]
    idx += size
assert idx == len(final_cases)

for pack_id, cases in enumerate(packs, start=7):
    tier_note = ", ".join(sorted({c["tier"] for c in cases}))
    out = [f'import Foundation\n']
    out.append(f'/// Phase 11.6 expansion — CasePack{pack_id}: {len(cases)} authored, solver-validated')
    out.append(f'/// cases ({tier_note} tiers). Generated by scripts/generate_phase116_cases.py and')
    out.append('/// hand-checkable: every case is pinned by evidence geometry plus explicit')
    out.append('/// profile statements, and the brute-force solver proves a single solution.')
    out.append(f'nonisolated enum CasePack{pack_id} {{\n    static let all: [QuarterCase] = [\n')
    body = "\n\n".join(swift_case(c) for c in cases)
    out.append(body)
    out.append("\n    ]\n}\n")
    open(os.path.join(DATA, f"CasePack{pack_id}.swift"), "w").write("\n".join(out))
    print(f"wrote CasePack{pack_id}.swift ({len(cases)} cases)")

# Roster extension
names = extra_names(750)
lines = ["import Foundation\n"]
lines.append("/// Phase 11.6 roster extension: with 150 cases (seeds 0...149) the stride-6")
lines.append("/// name-window scheme needs 900 collision-free slots — the original 150-name")
lines.append("/// pool plus these 750. Generated by scripts/generate_phase116_cases.py.")
lines.append("nonisolated extension CaseRoster {\n    static let extraNames: [String] = [")
for i in range(0, len(names), 5):
    chunk = ", ".join(f'"{n}"' for n in names[i:i + 5])
    lines.append(f"        {chunk},")
lines.append("    ]\n}")
open(os.path.join(DATA, "CaseRosterNames.swift"), "w").write("\n".join(lines) + "\n")
print(f"wrote CaseRosterNames.swift ({len(names)} names)")

# Stat events for the new cases
lines = ["import Foundation\n"]
lines.append("// Phase 11.6 expansion: authored stat events for the generated cases,")
lines.append("// merged into `CaseStatEvents.table`. Profile never decides the stat — the")
lines.append("// case file does. Generated by scripts/generate_phase116_cases.py.")
lines.append("nonisolated extension CaseStatEvents {\n    static let generatedTable: [String: [String: PlayerStat]] = [")
for c in final_cases:
    entries = ", ".join(f'"{k}": .{v}' for k, v in c["stats"].items())
    lines.append(f'        "{c["id"]}": [{entries}],')
lines.append("    ]\n}")
open(os.path.join(DATA, "CaseStatEventsGenerated.swift"), "w").write("\n".join(lines) + "\n")
print("wrote CaseStatEventsGenerated.swift")

# Summary
from collections import Counter
BAND_TIER = {1: "pro", 2: "pro", 3: "allPro", 4: "hallOfFamer", 5: "hallOfFamer"}
band_counts = Counter(c["band"] for c in final_cases)
tier_counts = Counter(c["tier"] for c in final_cases)
print("new per-band:", dict(sorted(band_counts.items())))
print("new per-tier:", dict(tier_counts))
total_by_band = Counter(c["band"] for c in legacy)
for b in range(1, 6):
    total_by_band[b] += band_counts[b]
print("total per-band:", dict(sorted(total_by_band.items())))
all_tiers = Counter(BAND_TIER[c["band"] if "tier" not in c else c["band"]] if "tier" not in c else c["tier"] for c in legacy)
all_tiers.update(tier_counts)
print("total per-tier:", dict(all_tiers))
print("eligible:", sum(1 for c in final_cases if c["eligible"]), "of", len(final_cases))

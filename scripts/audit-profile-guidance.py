#!/usr/bin/env python3
"""Audit legacy authored prose before the typed ProfileDialect safety layer.

This is a conservative review queue, not the production semantic validator.
The Swift tests validate typed signal IDs and their actual displayed phrases.
Run from any directory. Output includes original text for human review.
"""
import csv
import json
import re
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / 'ios-gamescene-gridiron/GameSceneGridiron/Data'
VOCABULARY = {
    'rookie': ['young', 'first-year', 'newest', 'raw', 'developing', 'learning'],
    'veteran': ['veteran', 'seasoned', 'years', 'seasons', 'decade', 'experience', 'already lived', 'longer than', 'old hand', 'seen this'],
    'fast': ['acceleration', 'recovery speed', 'speed', 'burst', 'quick', 'burner', 'wheels', 'footrace', 'sprint', 'closing pace'],
    'powerful': ['strength', 'power', 'immovable', 'anchor', 'not get moved', 'never gives ground', 'battering ram', 'mass', 'heaviest', 'force'],
    'overrated': ['reputation', 'headlines', 'hype', 'recent tape', 'market still believes', 'blue-chip'],
    'underrated': ['overlooked', 'rarely credited', 'tape is better'],
    'elusive': ['change of direction', 'changes direction', 'slippery', 'makes defenders miss'],
    'reliable': ['dependable', 'assignment-sound', 'consistent', 'every snap'],
    'technical': ['footwork', 'hand placement', 'technique', 'mechanics', 'inside hands'],
}
rows = []
counts = Counter()
for pack in range(1, 13):
    source = (DATA / f'CasePack{pack}.swift').read_text()
    for block in source.split('CaseLibrary.makeCase(')[1:]:
        case_id = re.search(r'id: "([^"]+)"', block)[1]
        solutions = dict((player, profile) for player, profile in re.findall(
            r'\(player: "([^"]+)", slot: "[^"]+", profile: \.(\w+)\)', block))
        clues = block.split('clues: [', 1)[1].split('hints: [', 1)[0]
        for player, text in re.findall(r'\(player: "([^"]+)", family:.*?text: "([^"]+)"', clues, re.S):
            counts[f'CasePack{pack}'] += 1
            profile = solutions[player]
            if not any(word in text.lower() for word in VOCABULARY[profile]):
                rows.append({'case_id': case_id, 'player_key': player, 'profile': profile,
                             'review_reason': 'No unambiguous legacy vocabulary match; now has typed profile signal',
                             'original_clue': text})
output = ROOT / 'scripts/fixtures/profile-guidance-review.csv'
with output.open('w', newline='') as file:
    writer = csv.DictWriter(file, fieldnames=['case_id', 'player_key', 'profile', 'review_reason', 'original_clue'], lineterminator='\n')
    writer.writeheader()
    writer.writerows(rows)
print(json.dumps({'production_clues_enriched': sum(counts.values()), 'per_pack': dict(counts),
                  'legacy_review_flags': len(rows), 'affected_cases': len({r['case_id'] for r in rows}),
                  'review_file': str(output.relative_to(ROOT))}, indent=2))

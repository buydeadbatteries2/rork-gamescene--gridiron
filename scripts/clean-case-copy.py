"""Remove only terminal authoring boilerplate; leave every structural case field intact."""
from pathlib import Path
import re
root = Path(__file__).resolve().parents[1]
clues = hints = 0
for path in sorted((root / 'ios-gamescene-gridiron/GameSceneGridiron/Data').glob('CasePack*.swift')):
    original = path.read_text()
    cleaned, c = re.subn(r' Case file: [^"\n]+ — sheet \d+\.(?=")', '', original)
    cleaned, h = re.subn(r' \(The [^"\n]+ file\.\)(?=")', '', cleaned)
    if cleaned != original:
        path.write_text(cleaned)
        print(f'{path.name}: {c} clues, {h} hints')
    clues += c
    hints += h
print(f'Total: {clues} clues, {hints} hints')

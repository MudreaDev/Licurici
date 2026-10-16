"""Ce portrete pictate (faces2) lipsesc încă. Fețele intră în jocuri doar când setul e complet:
8 copii × 7 emoții la 100% + treptele 20/40/60/80% pentru a0 și b0 (5 emoții) = 96 de imagini.

    py tools/art/check_faces.py
"""
import os

ill = os.path.join(os.path.dirname(__file__), '..', '..', 'packages', 'game_content', 'art', 'illustrations', 'faces2')
ids = ['a0', 'a1', 'a2', 'a3', 'b0', 'b1', 'b2', 'b3']
emotions = ['neutru', 'bucuros', 'trist', 'suparat', 'speriat', 'surprins', 'obosit']
want = [f'{k}_{e}_100' for k in ids for e in emotions]
want += [f'{k}_{e}_{p}' for k in ('a0', 'b0') for e in ('bucuros', 'trist', 'suparat', 'surprins', 'speriat') for p in (20, 40, 60, 80)]
missing = [w for w in want if not os.path.exists(os.path.join(ill, w + '.webp'))]
print(f'{len(want) - len(missing)} / {len(want)} portrete')
for m in missing:
    print('  lipsește', m)
if not missing:
    print('Complet: adaugă `- art/illustrations/faces2/` în packages/game_content/pubspec.yaml (assets).')

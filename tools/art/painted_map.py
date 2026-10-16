"""Scrie apps/child_app/lib/shared/painted_extra.dart: emoji → ilustrația pictată, pentru
obiectele generate în loturile Codex (lista emoji / nume e în mapping.json al lotului).

    py tools/art/painted_map.py mapping.json
"""
import json, os, sys

root = os.path.join(os.path.dirname(__file__), '..', '..')
ill = os.path.join(root, 'packages', 'game_content', 'art', 'illustrations')
mapping = json.load(open(sys.argv[1], encoding='utf-8'))
# Emoji-uri care au deja o ilustrație potrivită (aceeași expresie / același animal).
aliases = {'😭': 'faces/trist', '😀': 'faces/fericit', '🙂': 'faces/fericit', '😋': 'faces/fericit',
           '😰': 'faces/speriat', '🐰': 'objects/rabbit', '📧': 'objects/envelope', '🐕': 'objects/dog', '🐈': 'objects/cat'}
pairs = [(e, 'objects/' + n) for e, n in mapping] + list(aliases.items())
lines = ['// Generat de tools/art/painted_map.py — nu edita de mână.', '',
         '/// Emoji → ilustrația pictată (Codex) pentru obiectele adăugate în loturi; vezi `stimulus_art.dart`.',
         'const paintedExtra = {']
seen = set()
for e, path in pairs:
    if e in seen or not os.path.exists(os.path.join(ill, path + '.webp')):
        continue
    seen.add(e)
    lines.append(f"  '{e}': '{path}',")
lines.append('};')
out = os.path.join(root, 'apps', 'child_app', 'lib', 'shared', 'painted_extra.dart')
open(out, 'w', encoding='utf-8', newline='\n').write('\n'.join(lines) + '\n')
print(len(seen), 'emoji')

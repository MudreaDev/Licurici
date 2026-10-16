"""Scrie lista „Sursă PNG + prompt” (README-<nume>.md) pentru imaginile din lotul Codex.

    py tools/art/codex_readme.py jobs.json out_dir <nume> [prefix...]

Sursa fiecărei imagini se găsește după conținut în ~/.codex/generated_images (așa merge și
când două loturi au rulat în paralel). Doar imaginile al căror nume începe cu un prefix dat.
"""
import glob, hashlib, json, os, sys

jobs = {j['name']: j for j in json.load(open(sys.argv[1], encoding='utf-8'))}
out_dir, name = sys.argv[2], sys.argv[3]
prefixes = tuple(sys.argv[4:]) or ('',)
digest = lambda p: hashlib.sha1(open(p, 'rb').read()).hexdigest()
gen = {}
for p in glob.glob(os.path.expanduser(r'~\.codex\generated_images\*\*.png')) + glob.glob(os.path.expanduser(r'~\.codex\generated_images\*\cells\*.png')):
    gen.setdefault(digest(p), p)
root = os.path.join(os.path.dirname(__file__), '..', '..', 'packages', 'game_content', 'art', 'illustrations')
lines = [f'# Ilustrații — {name}', '']
for f in sorted(glob.glob(os.path.join(out_dir, '*', '*.png'))):
    key = os.path.relpath(f, out_dir).replace(os.sep, '/')[:-4]
    if not key.startswith(prefixes): continue
    # Sursa: imaginea din generated_images (după conținut) sau, dacă a fost generată altfel
    # (ex. salvată direct de Codex), chiar fișierul din out_dir.
    src = gen.get(digest(f)) or os.path.abspath(f)
    job = jobs.get(key) or next((j for j in jobs.values() if key in j.get('cells', [])), None)
    if not src or job is None:
        print('fără sursă', key); continue
    lines += [f'## {key}.webp', '', f'Sursă PNG: `{src}`', '', 'Prompt exact:', '', '> ' + job['prompt'], '']
open(os.path.join(root, f'README-{name}.md'), 'w', encoding='utf-8', newline='\n').write('\n'.join(lines))
print(len(lines) // 8, 'intrări')

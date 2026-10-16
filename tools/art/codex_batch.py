"""Generează ilustrații cu Codex CLI, în paralel, dintr-o listă de lucrări.

    py tools/art/codex_batch.py jobs.json out_dir [--workers 3]
    py tools/art/codex_batch.py jobs.json out_dir --split-only   # doar taie planșele deja salvate

Căile din `refs` / `needs` sunt relative la folderul fișierului jobs.json.

jobs.json: [{"name": "games/turnul", "prompt": "...", "refs": ["ref1.png", ...]}, ...]
O planșă: {"name": "sheets/x", "grid": [rânduri, coloane], "cells": ["objects/a", ...], ...} — imaginea
generată e tăiată în celule (rând cu rând), fiecare decupată la contur și salvată ca out_dir/<celulă>.png
(sursa celulei rămâne lângă planșă, în generated_images/<sesiune>/cells/).
Pentru fiecare lucrare: rulează `codex exec` cu promptul pe stdin și imaginile de stil atașate,
găsește PNG-ul generat în ~/.codex/generated_images/<sesiune>/ și îl copiază în
out_dir/<name>.png. Ce există deja în out_dir se sare (reluare după întrerupere).
Rezultatul (sursa fiecărei imagini) se adaugă în out_dir/results.json.
"""

import glob
import json
import os
import re
import shutil
import subprocess
import sys
import threading
from concurrent.futures import ThreadPoolExecutor


def codex_exe():
    bins = glob.glob(os.path.expanduser(r'~\AppData\Local\OpenAI\Codex\bin\*\codex.exe'))
    if not bins:
        sys.exit('codex.exe nu a fost găsit')
    return max(bins, key=os.path.getmtime)


GEN = os.path.expanduser(r'~\.codex\generated_images')
lock = threading.Lock()
# Codex a spus că s-a atins limita de utilizare: restul lucrărilor nu mai pornesc.
limited = threading.Event()


def split(job, src, out_dir, results):
    """Taie planșa în celule; fiecare celulă e decupată la conturul ei (alfa vizibil)."""
    from PIL import Image
    im = Image.open(src).convert('RGBA')
    rows, cols = job['grid']
    w, h = im.width / cols, im.height / rows
    cell_dir = os.path.join(os.path.dirname(src), 'cells')
    os.makedirs(cell_dir, exist_ok=True)
    for k, name in enumerate(job['cells']):
        r, c = divmod(k, cols)
        cell = im.crop((round(c * w), round(r * h), round((c + 1) * w), round((r + 1) * h)))
        bbox = cell.getchannel('A').point(lambda v: 255 if v > 12 else 0).getbbox()
        if not bbox:
            print('celulă goală', name, flush=True)
            continue
        # o margine mică în jur, ca la imaginile generate una câte una
        pad = round(0.06 * max(bbox[2] - bbox[0], bbox[3] - bbox[1]))
        cell = cell.crop((max(0, bbox[0] - pad), max(0, bbox[1] - pad), min(cell.width, bbox[2] + pad), min(cell.height, bbox[3] + pad)))
        side = max(cell.size)
        sq = Image.new('RGBA', (side, side), (0, 0, 0, 0))
        sq.paste(cell, ((side - cell.width) // 2, (side - cell.height) // 2))
        cell_src = os.path.join(cell_dir, name.replace('/', '__') + '.png')
        sq.save(cell_src)
        target = os.path.join(out_dir, name + '.png')
        os.makedirs(os.path.dirname(target), exist_ok=True)
        sq.save(target)
        results[name] = {'src': cell_src, 'prompt': job['prompt'], 'sheet': src}


def run(job, out_dir, exe, results):
    try:
        _run(job, out_dir, exe, results)
    except Exception:
        import traceback
        print('EROARE', job['name'], traceback.format_exc(), flush=True)


def _run(job, out_dir, exe, results):
    target = os.path.join(out_dir, job['name'] + '.png')
    if job.get('cells'):
        if all(os.path.exists(os.path.join(out_dir, c + '.png')) for c in job['cells']):
            return
    elif os.path.exists(target):
        return
    if limited.is_set():
        return
    # O lucrare care are nevoie de altă imagine (ex. portretul de bază al copilului) așteaptă tura următoare.
    if job.get('needs') and not os.path.exists(job['needs']):
        return
    os.makedirs(os.path.dirname(target), exist_ok=True)
    prompt = 'Generate this image with your image generation tool and tell me the path of the saved PNG. ' + job['prompt']
    args = [exe, 'exec', '--skip-git-repo-check']
    if job.get('refs'):
        args += ['-i', *job['refs']]
    args.append('-')
    for attempt in range(2):
        try:
            p = subprocess.run(args, input=prompt, capture_output=True, text=True, encoding='utf-8', errors='replace', timeout=900)
        except subprocess.TimeoutExpired:
            continue
        out = p.stdout + p.stderr
        # Doar mesajul real de eroare (textul de ajutor al lui Codex poate conține și el „usage limit”).
        if re.search(r"ERROR: You.ve hit your usage limit", out):
            limited.set()
            print('LIMITĂ', job['name'], re.search(r'try again at [^.]*', out).group(0) if 'try again' in out else '', flush=True)
            return
        m = re.search(r'session id:\s*([0-9a-f-]+)', out)
        pngs = glob.glob(os.path.join(GEN, m.group(1), '*.png')) if m else []
        if not pngs:
            pngs = re.findall(r'[A-Z]:\\[^\s`]*generated_images\\[^\s`]*\.png', out)
            pngs = [x for x in pngs if os.path.exists(x)]
        if pngs:
            src = max(pngs, key=os.path.getmtime)
            shutil.copy(src, target)
            with lock:
                if job.get('cells'):
                    split(job, src, out_dir, results)
                results[job['name']] = {'src': src, 'prompt': job['prompt']}
                json.dump(results, open(os.path.join(out_dir, 'results.json'), 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
            print('ok', job['name'], flush=True)
            return
    print('EȘUAT', job['name'], flush=True)


def main():
    jobs = json.load(open(sys.argv[1], encoding='utf-8'))
    base = os.path.dirname(os.path.abspath(sys.argv[1]))
    for j in jobs:
        j['refs'] = [r if os.path.isabs(r) else os.path.join(base, r) for r in j.get('refs', [])]
        if j.get('needs') and not os.path.isabs(j['needs']):
            j['needs'] = os.path.join(base, j['needs'])
    out_dir = sys.argv[2]
    workers = int(sys.argv[sys.argv.index('--workers') + 1]) if '--workers' in sys.argv else 3
    os.makedirs(out_dir, exist_ok=True)
    rpath = os.path.join(out_dir, 'results.json')
    results = json.load(open(rpath, encoding='utf-8')) if os.path.exists(rpath) else {}
    if '--split-only' in sys.argv:
        # Planșele generate de mână (salvate ca out_dir/sheets/<nume>.png) se taie în celule.
        for j in jobs:
            sheet = os.path.join(out_dir, j['name'] + '.png')
            if j.get('cells') and os.path.exists(sheet):
                split(j, sheet, out_dir, results)
                print('tăiată', j['name'], flush=True)
        json.dump(results, open(rpath, 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
        return
    exe = codex_exe()
    # Câteva ture: lucrările care așteptau o imagine de bază pornesc după ce aceasta există.
    for _ in range(3):
        with ThreadPoolExecutor(workers) as pool:
            for j in jobs:
                pool.submit(run, j, out_dir, exe, results)
        if limited.is_set() or all(os.path.exists(os.path.join(out_dir, c + '.png')) for j in jobs for c in (j.get('cells') or [j['name']])):
            break


if __name__ == '__main__':
    main()

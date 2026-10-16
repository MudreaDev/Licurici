"""Generează ilustrații cu Codex CLI, în paralel, dintr-o listă de lucrări.

    py tools/art/codex_batch.py jobs.json out_dir [--workers 3]

jobs.json: [{"name": "games/turnul", "prompt": "...", "refs": ["ref1.png", ...]}, ...]
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


def run(job, out_dir, exe, results):
    target = os.path.join(out_dir, job['name'] + '.png')
    if os.path.exists(target) or limited.is_set():
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
        if 'usage limit' in out:
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
                results[job['name']] = {'src': src, 'prompt': job['prompt']}
                json.dump(results, open(os.path.join(out_dir, 'results.json'), 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
            print('ok', job['name'], flush=True)
            return
    print('EȘUAT', job['name'], flush=True)


def main():
    jobs = json.load(open(sys.argv[1], encoding='utf-8'))
    out_dir = sys.argv[2]
    workers = int(sys.argv[sys.argv.index('--workers') + 1]) if '--workers' in sys.argv else 3
    os.makedirs(out_dir, exist_ok=True)
    rpath = os.path.join(out_dir, 'results.json')
    results = json.load(open(rpath, encoding='utf-8')) if os.path.exists(rpath) else {}
    exe = codex_exe()
    # Câteva ture: lucrările care așteptau o imagine de bază pornesc după ce aceasta există.
    for _ in range(3):
        with ThreadPoolExecutor(workers) as pool:
            for j in jobs:
                pool.submit(run, j, out_dir, exe, results)
        if limited.is_set() or all(os.path.exists(os.path.join(out_dir, j['name'] + '.png')) for j in jobs):
            break


if __name__ == '__main__':
    main()

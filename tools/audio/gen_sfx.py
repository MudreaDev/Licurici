"""Sunetele interfeței Licurici, generate din cod (fără înregistrări, fără licențe).

Toate sunt blânde: atac moale, fără frecvențe ascuțite, volum moderat, sub o secundă.
Nu există sunet de „greșit” (README §15.1: fără sunete de eșec).

    python tools/audio/gen_sfx.py

Scrie WAV mono 22 050 Hz în packages/game_content/audio/sfx/.
"""

import os
import wave

import numpy as np

RATE = 22050
OUT = os.path.join(os.path.dirname(__file__), '..', '..', 'packages', 'game_content', 'audio', 'sfx')


def env(n, attack=0.005, decay=6.0):
    """Anvelopă: atac liniar scurt, apoi stingere exponențială."""
    t = np.arange(n) / RATE
    a = np.clip(t / attack, 0, 1)
    return a * np.exp(-decay * t)


def mallet(freq, dur=0.9, decay=5.0, bright=0.35):
    """Timbru de marimbă/clopoțel: fundamentala + parțiale care se sting mai repede."""
    n = int(dur * RATE)
    t = np.arange(n) / RATE
    tone = np.sin(2 * np.pi * freq * t)
    tone += bright * np.sin(2 * np.pi * freq * 3.93 * t) * np.exp(-14 * t)
    tone += 0.5 * bright * np.sin(2 * np.pi * freq * 2.0 * t) * np.exp(-9 * t)
    return tone * env(n, decay=decay)


def pop(dur=0.09):
    """Atingere: un „pop” moale, glisando scurt în sus."""
    n = int(dur * RATE)
    t = np.arange(n) / RATE
    f = 520 + 380 * (t / dur)
    phase = 2 * np.pi * np.cumsum(f) / RATE
    return np.sin(phase) * env(n, attack=0.003, decay=40)


def mix(*parts):
    """Suprapune fragmente (offset în secunde, semnal)."""
    end = max(int(o * RATE) + len(s) for o, s in parts)
    out = np.zeros(end)
    for o, s in parts:
        i = int(o * RATE)
        out[i:i + len(s)] += s
    return out


def save(name, signal, gain=0.5, pad=True):
    peak = np.max(np.abs(signal)) or 1
    data = (signal / peak * gain * 32767).astype(np.int16)
    # 15 ms de liniște la capăt, ca playerul să nu taie coada (nu și la bucle: s-ar auzi pauza)
    if pad:
        data = np.concatenate([data, np.zeros(int(0.015 * RATE), dtype=np.int16)])
    os.makedirs(OUT, exist_ok=True)
    with wave.open(os.path.join(OUT, name + '.wav'), 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data.tobytes())
    print('ok', name, f'{len(data) / RATE:.2f}s')


def hz(semitones_from_c5):
    return 523.25 * 2 ** (semitones_from_c5 / 12)


# Felinarele: pentatonica do major (do re mi sol la do') — orice ordine sună bine.
PENTA = [0, 2, 4, 7, 9, 12]
for i, s in enumerate(PENTA):
    save(f'note_{i}', mallet(hz(s), dur=0.8), gain=0.55)

save('tap', pop(), gain=0.35)
# Corect: două note care urcă (sol → do'), ca un „da!” vesel.
save('correct', mix((0, mallet(hz(7), 0.5, 7)), (0.09, mallet(hz(12), 0.7, 5))), gain=0.5)
# Stea: sclipire scurtă — arpegiu sus, foarte încet.
save('star', mix(*[(k * 0.05, mallet(hz(12 + s), 0.35, 10, 0.2)) for k, s in enumerate([0, 4, 7, 12])]), gain=0.4)
# Abțibild: „plop” + clinchet.
save('sticker', mix((0, pop(0.12)), (0.07, mallet(hz(16), 0.6, 6, 0.25))), gain=0.45)


def drum(freq, dur=0.45, drop=0.35, noise=0.12):
    """Tobă moale: ton care coboară puțin (corp) + un strop de zgomot la atac (piele)."""
    n = int(dur * RATE)
    t = np.arange(n) / RATE
    f = freq * (1 + drop * np.exp(-30 * t))
    body = np.sin(2 * np.pi * np.cumsum(f) / RATE) * env(n, attack=0.002, decay=9)
    rng = np.random.default_rng(7)
    hit = rng.standard_normal(n) * np.exp(-60 * t) * noise
    return body + hit


# Toba magică: două tobe, una joasă și una mai sus (bongo), blânde.
save('drum_0', drum(150), gain=0.6)
save('drum_1', drum(260, dur=0.35), gain=0.55)


# Acvariul: bula („blup”) — glisando scurt în sus, ca o bulă care urcă.
def bubble(f0=320, f1=980, dur=0.07):
    n = int(dur * RATE)
    t = np.arange(n) / RATE
    f = f0 + (f1 - f0) * (t / dur) ** 0.6
    phase = 2 * np.pi * np.cumsum(f) / RATE
    return np.sin(phase) * env(n, attack=0.002, decay=30)


save('bubble', mix((0.0, bubble()), (0.09, bubble(380, 1150, 0.06) * 0.6)), gain=0.45)


# Apa, în buclă (10 s): zgomot „maro” (jos, moale) care urcă și coboară ca valurile, cu bule
# rare. Capetele se îmbină (fade încrucișat), deci bucla nu „sare”.
def ocean(dur=10.0, seed=7):
    rng = np.random.default_rng(seed)
    n = int(dur * RATE)
    brown = np.cumsum(rng.standard_normal(n + RATE))
    brown -= np.convolve(brown, np.ones(2000) / 2000, mode='same')  # fără derivă lentă
    k = np.ones(18) / 18
    brown = np.convolve(brown, k, mode='same')  # doar frecvențele joase
    t = np.arange(n + RATE) / RATE
    swell = 0.55 + 0.45 * np.sin(2 * np.pi * t / dur * 2) ** 2  # două „valuri” pe buclă
    sig = brown * swell
    for at in rng.uniform(0.3, dur, 9):  # bule rare, foarte încet
        i = int(at * RATE)
        b = bubble(rng.uniform(260, 420), rng.uniform(800, 1200), 0.06) * np.std(sig) * 0.9
        sig[i:i + len(b)] += b
    head, tail = sig[:RATE], sig[n:n + RATE]
    fade = np.linspace(0, 1, RATE)
    loop = sig[:n].copy()
    loop[:RATE] = head * fade + tail * (1 - fade)
    return loop


save('ocean_loop', ocean(), gain=0.3, pad=False)

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


def save(name, signal, gain=0.5):
    peak = np.max(np.abs(signal)) or 1
    data = (signal / peak * gain * 32767).astype(np.int16)
    # 15 ms de liniște la capăt, ca playerul să nu taie coada
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

"""Muzica de fundal Licurici, generată din cod (fără înregistrări, fără licențe).

Muzică liniștită pentru copii (și pentru copiii cu autism): tempo lent (60–72 bpm, aproape de
ritmul inimii în repaus), doar note din gama pentatonică (nicio disonanță), fără tobe, fără
schimbări bruște de volum, atac moale pe fiecare notă, melodie rară cu pauze. Fiecare piesă
începe încet și se încheie pe acordul de bază, care se stinge (fără tăieturi); aplicația le cântă
pe rând, cu câteva secunde de liniște între ele (nu în buclă — MP3-ul n-are bucle fără cusătură).

    python tools/audio/gen_music.py

Scrie MP3 (ffmpeg, 96 kbps stereo) în packages/game_content/audio/music/.
"""

import os
import subprocess
import tempfile
import wave

import numpy as np

RATE = 32000
OUT = os.path.join(os.path.dirname(__file__), '..', '..', 'packages', 'game_content', 'audio', 'music')


def midi_hz(m):
    return 440.0 * 2 ** ((m - 69) / 12)


def adsr(n, attack, release, sustain=1.0):
    """Anvelopă moale: urcare lentă, palier, stingere lentă (fără „clic”)."""
    t = np.arange(n) / RATE
    a = np.clip(t / attack, 0, 1) ** 2
    r = np.clip((n / RATE - t) / release, 0, 1) ** 1.5
    return a * r * sustain


def pad(freq, dur, bright=0.25, detune=0.25):
    """Pad cald: două oscilatoare ușor dezacordate + armonice slabe, anvelopă foarte lentă."""
    n = int(dur * RATE)
    t = np.arange(n) / RATE
    tone = np.zeros(n)
    for d in (-detune, detune):
        f = freq * 2 ** (d / 1200 * 4)
        tone += np.sin(2 * np.pi * f * t)
        tone += bright * 0.5 * np.sin(2 * np.pi * 2 * f * t)
        tone += bright * 0.2 * np.sin(2 * np.pi * 3 * f * t)
    # o respirație lentă a volumului (tremolo de 0,2 Hz)
    tone *= 1 + 0.08 * np.sin(2 * np.pi * 0.2 * t)
    return tone * adsr(n, attack=min(1.6, dur / 3), release=min(2.0, dur / 2))


def bell(freq, dur=2.6, decay=2.2, bright=0.3):
    """Cutie muzicală / clopoțel moale: parțiale care se sting repede, fundamentala rămâne."""
    n = int(dur * RATE)
    t = np.arange(n) / RATE
    tone = np.sin(2 * np.pi * freq * t)
    tone += bright * np.sin(2 * np.pi * freq * 2.0 * t) * np.exp(-5 * t)
    tone += bright * 0.4 * np.sin(2 * np.pi * freq * 3.01 * t) * np.exp(-9 * t)
    env = np.clip(t / 0.012, 0, 1) * np.exp(-decay * t)
    return tone * env


def marimba(freq, dur=1.8):
    n = int(dur * RATE)
    t = np.arange(n) / RATE
    tone = np.sin(2 * np.pi * freq * t) + 0.25 * np.sin(2 * np.pi * freq * 3.93 * t) * np.exp(-12 * t)
    return tone * np.clip(t / 0.008, 0, 1) * np.exp(-3.2 * t)


def flute(freq, dur):
    """Flaut moale: sinus cu vibrato lent și puțin suflu."""
    n = int(dur * RATE)
    t = np.arange(n) / RATE
    vib = 1 + 0.004 * np.sin(2 * np.pi * 4.8 * t) * np.clip(t / 0.6, 0, 1)
    phase = 2 * np.pi * np.cumsum(freq * vib) / RATE
    tone = np.sin(phase) + 0.12 * np.sin(2 * phase)
    rng = np.random.default_rng(int(freq))
    breath = rng.normal(0, 0.02, n)
    return (tone + breath) * adsr(n, attack=0.18, release=min(0.6, dur / 2))


def reverb(x, seconds=2.8, mix=0.35, seed=1):
    """Reverberație moale: convoluție cu zgomot care se stinge exponențial (cameră mare)."""
    rng = np.random.default_rng(seed)
    n = int(seconds * RATE)
    t = np.arange(n) / RATE
    ir = rng.normal(0, 1, n) * np.exp(-3.2 * t / seconds * 2)
    # tăiem înaltele din coadă (mai cald)
    k = np.ones(24) / 24
    ir = np.convolve(ir, k, mode='same')
    ir /= np.sqrt(np.sum(ir ** 2))
    size = len(x) + n
    nfft = 1 << (size - 1).bit_length()
    wet = np.fft.irfft(np.fft.rfft(x, nfft) * np.fft.rfft(ir, nfft), nfft)[:size]
    out = np.zeros(size)
    out[:len(x)] += x * (1 - mix)
    out += wet * mix
    return out


def lowpass(x, cutoff=3500):
    """Filtru simplu de o pol: muzica rămâne caldă, fără sunete ascuțite."""
    a = np.exp(-2 * np.pi * cutoff / RATE)
    y = np.zeros_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc = (1 - a) * x[i] + a * acc
        y[i] = acc
    return y


class Track:
    def __init__(self, seconds):
        self.n = int(seconds * RATE)
        # loc pentru coada notelor de la final; o adunăm peste început (buclă)
        self.buf = np.zeros((2, self.n + int(8 * RATE)))

    def add(self, at, sig, gain=1.0, pan=0.0):
        i = int(at * RATE)
        sig = sig * gain
        left = np.cos((pan + 1) * np.pi / 4)
        right = np.sin((pan + 1) * np.pi / 4)
        end = min(i + len(sig), self.buf.shape[1])
        self.buf[0, i:end] += sig[:end - i] * left
        self.buf[1, i:end] += sig[:end - i] * right

    def render(self, rev=0.35, cutoff=3800):
        out = []
        for ch in range(2):
            x = lowpass(self.buf[ch], cutoff)
            x = reverb(x, mix=rev, seed=ch + 1)
            out.append(x)
        stereo = np.stack(out)
        # începe din liniște (2 s) și se stinge de tot la capăt (ultimele 3 s)
        n = stereo.shape[1]
        t = np.arange(n) / RATE
        stereo *= np.clip(t / 2.0, 0, 1) * np.clip((n / RATE - t) / 3.0, 0, 1)
        # fără liniștea de la coadă (doar ce se aude)
        loud = np.nonzero(np.max(np.abs(stereo), axis=0) > 1e-4)[0]
        stereo = stereo[:, :loud[-1] + 1]
        stereo /= np.max(np.abs(stereo)) or 1
        return stereo * 0.7


def melody(rng, scale, bars, beats_per_bar, chord_tones, rest_prob=0.35):
    """Melodie lină: mai ales pași mici în gamă, des pe notele acordului, cu pauze."""
    notes = []
    idx = len(scale) // 2
    for bar in range(bars):
        tones = chord_tones[bar % len(chord_tones)]
        beat = 0
        while beat < beats_per_bar:
            dur = rng.choice([1, 1, 2, 2, 3]) if beat + 2 <= beats_per_bar else 1
            dur = min(dur, beats_per_bar - beat)
            if rng.random() < rest_prob or (bar % 4 == 3 and beat >= 2):
                beat += dur
                continue
            step = rng.choice([-2, -1, -1, 0, 1, 1, 2])
            idx = int(np.clip(idx + step, 0, len(scale) - 1))
            # pe timpul tare, preferăm o notă a acordului (stabil, previzibil)
            if beat == 0:
                near = min(range(len(scale)), key=lambda j: (scale[j] % 12 not in tones, abs(j - idx)))
                idx = near
            notes.append((bar * beats_per_bar + beat, dur, scale[idx]))
            beat += dur
    return notes


def save(name, stereo):
    os.makedirs(OUT, exist_ok=True)
    data = (stereo.T * 32767).astype(np.int16)
    with tempfile.TemporaryDirectory() as tmp:
        wav = os.path.join(tmp, name + '.wav')
        with wave.open(wav, 'wb') as w:
            w.setnchannels(2)
            w.setsampwidth(2)
            w.setframerate(RATE)
            w.writeframes(data.tobytes())
        mp3 = os.path.join(OUT, name + '.mp3')
        subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', wav, '-codec:a', 'libmp3lame', '-b:a', '96k',
                        '-ar', '32000', mp3], check=True)
    print('ok', name, f'{stereo.shape[1] / RATE:.1f}s', os.path.getsize(mp3) // 1024, 'KB')


def piece(name, *, bpm, key, progression, bars, lead, seed, rev=0.38):
    """O piesă: pad pe acorduri, bas moale, melodie rară pe instrumentul [lead]."""
    beat = 60 / bpm
    beats = 4
    seconds = (bars + 2) * beats * beat
    tr = Track(seconds)
    rng = np.random.default_rng(seed)
    # gama pentatonică majoră pe două octave, de la tonică
    penta = [0, 2, 4, 7, 9]
    scale = [key + 12 + o * 12 + p for o in range(2) for p in penta] + [key + 36]
    chord_pcs = []
    for bar in range(bars):
        root, quality = progression[bar % len(progression)]
        third = 3 if quality == 'm' else 4
        chord = [root, root + third, root + 7, root + (10 if quality == 'm' else 11) if bar % 2 else root + 14]
        chord_pcs.append({c % 12 for c in chord})
        at = bar * beats * beat
        # pad: acordul ținut toată măsura (cu suprapunere ușoară, legato)
        for i, c in enumerate(chord):
            tr.add(at, pad(midi_hz(key - 12 + c), beats * beat + 1.2), gain=0.11, pan=(-0.5 + i / 3))
        # bas: tonica, foarte încet, de două ori pe măsură
        for b in (0, 2):
            tr.add(at + b * beat, pad(midi_hz(key - 24 + root), 2 * beat + 0.6, bright=0.05), gain=0.16)
        # arpegiu discret (harpă) în a doua jumătate a fiecărei măsuri pare
        if bar % 2 == 1:
            for j, c in enumerate(chord[:3]):
                tr.add(at + (2 + j * 0.5) * beat, marimba(midi_hz(key + c)), gain=0.07, pan=0.4 - j * 0.3)
    # încheierea: acordul de bază, ținut două măsuri, cu o notă de clopoțel care se stinge
    end = bars * beats * beat
    for i, c in enumerate([0, 4, 7, 12]):
        tr.add(end, pad(midi_hz(key - 12 + c), 2 * beats * beat), gain=0.11, pan=(-0.5 + i / 3))
    tr.add(end, pad(midi_hz(key - 24), 2 * beats * beat, bright=0.05), gain=0.16)
    tr.add(end, bell(midi_hz(key + 12), dur=5, decay=0.9), gain=0.18, pan=0.15)
    for (b, d, m) in melody(rng, scale, bars, beats, chord_pcs):
        at = b * beat
        if lead == 'bell':
            tr.add(at, bell(midi_hz(m)), gain=0.22, pan=0.15)
        elif lead == 'flute':
            tr.add(at, flute(midi_hz(m), d * beat * 0.95), gain=0.13, pan=-0.1)
        else:
            tr.add(at, marimba(midi_hz(m)), gain=0.2, pan=0.1)
    save(name, tr.render(rev=rev))


if __name__ == '__main__':
    # C major: I – vi – IV – V (acorduri ca grade de la tonică)
    calm = [(0, ''), (9, 'm'), (5, ''), (7, '')]
    # F major: I – iii – IV – I
    waves = [(0, ''), (4, 'm'), (5, ''), (0, '')]
    # G major: I – IV – vi – IV
    garden = [(0, ''), (5, ''), (9, 'm'), (5, '')]
    piece('lumini', bpm=64, key=60, progression=calm, bars=24, lead='bell', seed=7)
    piece('valuri', bpm=58, key=65, progression=waves, bars=20, lead='flute', seed=11, rev=0.45)
    piece('gradina', bpm=70, key=55, progression=garden, bars=28, lead='marimba', seed=5)

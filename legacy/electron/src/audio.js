// Sunete blânde generate în cod (WebAudio). Fără fișiere, fără sunete bruște.
// Respectă setarea „sound". Tonuri moi, volum mic, atac/decădere line — ca să nu
// suprastimuleze auditiv (sensibilitate senzorială frecventă în autism).
import { store } from './store.js';

let ctx = null;
function ac() {
  if (!ctx) {
    try { ctx = new (window.AudioContext || window.webkitAudioContext)(); }
    catch (e) { ctx = null; }
  }
  return ctx;
}

// Același AudioContext e folosit și de muzica de fundal (music.js).
export function getAudioContext() { return ac(); }

function sfxVol() { const v = store.get('sfxVol'); return v == null ? 0.5 : v; }

function tone(freq, start, dur, gainPeak = 0.12, type = 'sine') {
  const a = ac();
  if (!a) return;
  const peak = gainPeak * sfxVol() * 1.6;   // scalat de volumul „Sunete" (mediu = 0.5)
  if (peak <= 0.0002) return;
  const t0 = a.currentTime + start;
  const osc = a.createOscillator();
  const g = a.createGain();
  osc.type = type;
  osc.frequency.value = freq;
  // Plic blând: fără click, urcă și coboară lin.
  g.gain.setValueAtTime(0.0001, t0);
  g.gain.exponentialRampToValueAtTime(peak, t0 + 0.04);
  g.gain.exponentialRampToValueAtTime(0.0001, t0 + dur);
  osc.connect(g).connect(a.destination);
  osc.start(t0);
  osc.stop(t0 + dur + 0.02);
}

function enabled() { return sfxVol() > 0; }

export const sfx = {
  tap() { if (enabled()) tone(440, 0, 0.08, 0.06, 'sine'); },
  good() {                       // două note care urcă — plăcut
    if (!enabled()) return;
    tone(523.25, 0, 0.16, 0.10);       // do
    tone(659.25, 0.12, 0.22, 0.10);    // mi
  },
  gentle() {                     // ton jos, cald — „mai încearcă", fără alarmă
    if (enabled()) tone(392, 0, 0.28, 0.07, 'sine');
  },
  celebrate() {                  // arpegiu scurt și vesel, dar blând
    if (!enabled()) return;
    const notes = [523.25, 659.25, 783.99, 1046.5];
    notes.forEach((f, i) => tone(f, i * 0.12, 0.26, 0.09));
  },
  // O singură notă blândă (pentru jocul de memorie — fiecare pătrat are sunetul lui).
  note(freq) { if (enabled()) tone(freq, 0, 0.34, 0.10, 'sine'); }
};

// Multe browsere pornesc AudioContext „suspended" până la primul click.
export function unlockAudio() {
  const a = ac();
  if (a && a.state === 'suspended') a.resume();
}

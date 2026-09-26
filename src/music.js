// Muzică de fundal — o melodie BUCLATĂ, drăgălașă, tip cutie muzicală (celesta), caldă și
// profesionistă. Generată în cod (WebAudio, 0 fișiere), dar NU aleatorie: o temă fixă,
// plăcută, care se repetă perfect (progresie Do–Sol–la minor–Fa), cu acorduri blânde și
// un bas moale. Planificator „look-ahead" pentru sincronizare curată și buclă fără cusur.
import { getAudioContext } from './audio.js';
import { store } from './store.js';

let master = null, filter = null, started = false, schedTimer = null;
let step = 0, nextTime = 0;

// ---- Tempo & structură ----
const BPM = 96;
const SPB = 60 / BPM;              // secunde pe bătaie (pătrime)
const BEATS_PER_BAR = 4;
const BARS = 8;                    // două fraze (A + B) → buclă de 8 bări, mai puțin repetitivă
const STEPS = BEATS_PER_BAR * BARS; // 32 pătrimi = o buclă

// ---- Note (Hz, temperament egal) ----
// Acorduri pe bară: Do major, Sol major, la minor, Fa major (progresia „veselă").
const CHORDS = [
  [130.81, 164.81, 196.00],  // C: do3 mi3 sol3
  [98.00, 123.47, 146.83],   // G: sol2 si2 re3
  [110.00, 130.81, 164.81],  // Am: la2 do3 mi3
  [87.31, 110.00, 130.81]    // F: fa2 la2 do3
];
const BASS = [65.41, 98.00, 110.00, 87.31];   // do2 sol2 la2 fa2

// Melodie: o pătrime pe bătaie. Fraza A (bările 1-4) + fraza B „răspuns" (5-8, mai sus),
// caldă și cântabilă, se închide lin și reia bucla. 32 de note.
const MELODY = [
  // Fraza A
  329.63, 392.00, 523.25, 392.00,   // C : mi4 sol4 do5 sol4
  293.66, 392.00, 493.88, 392.00,   // G : re4 sol4 si4 sol4
  261.63, 329.63, 440.00, 329.63,   // Am: do4 mi4 la4 mi4
  261.63, 349.23, 440.00, 523.25,   // F : do4 fa4 la4 do5
  // Fraza B (răspuns mai înalt)
  392.00, 523.25, 659.25, 523.25,   // C : sol4 do5 mi5 do5
  392.00, 493.88, 587.33, 493.88,   // G : sol4 si4 re5 si4
  440.00, 329.63, 523.25, 440.00,   // Am: la4 mi4 do5 la4
  349.23, 440.00, 392.00, 329.63    // F : fa4 la4 sol4 mi4 → coboară lin, reia bucla
];

function ensureGraph(a) {
  if (master) return;
  master = a.createGain(); master.gain.value = 0;
  filter = a.createBiquadFilter();
  filter.type = 'lowpass'; filter.frequency.value = 2800; filter.Q.value = 0.3;
  filter.connect(master); master.connect(a.destination);
}

// O „voce" cu plic blând (fără click), panoramare opțională.
function tone(a, freq, time, dur, { type = 'sine', peak = 0.08, attack = 0.02, release = 0.35, pan = 0 } = {}) {
  const o = a.createOscillator(); o.type = type; o.frequency.setValueAtTime(freq, time);
  const g = a.createGain();
  g.gain.setValueAtTime(0.0001, time);
  g.gain.exponentialRampToValueAtTime(peak, time + attack);
  g.gain.exponentialRampToValueAtTime(0.0001, time + dur + release);
  if (a.createStereoPanner && pan) {
    const p = a.createStereoPanner(); p.pan.value = pan;
    o.connect(g).connect(p).connect(filter);
  } else {
    o.connect(g).connect(filter);
  }
  o.start(time); o.stop(time + dur + release + 0.02);
}

// Notă tip cutie muzicală (celesta): triunghi cald + o sclipire fină o octavă mai sus.
function bell(a, freq, time, pan) {
  tone(a, freq, time, SPB * 0.9, { type: 'triangle', peak: 0.10, attack: 0.006, release: 0.5, pan });
  tone(a, freq * 2, time, SPB * 0.5, { type: 'sine', peak: 0.028, attack: 0.006, release: 0.4, pan });
}

function scheduleStep(s, time) {
  const bar = Math.floor(s / BEATS_PER_BAR);
  const beat = s % BEATS_PER_BAR;

  // Începutul barei: acord (pad) lung și foarte blând + bas moale. Progresia (4 acorduri)
  // se repetă în ambele fraze → index pe bar % 4.
  if (beat === 0) {
    const c = bar % 4;
    CHORDS[c].forEach((f, i) =>
      tone(a_ctx, f, time, SPB * BEATS_PER_BAR * 0.98,
        { type: 'sine', peak: 0.03, attack: 0.08, release: 0.6, pan: (i - 1) * 0.25 }));
    tone(a_ctx, BASS[c], time, SPB * BEATS_PER_BAR * 0.9,
      { type: 'sine', peak: 0.06, attack: 0.03, release: 0.5 });
  }

  // Melodia: o notă pe bătaie, cu ușoară panoramare stânga-dreapta.
  const m = MELODY[s];
  if (m) bell(a_ctx, m, time, (beat % 2 === 0 ? -0.18 : 0.18));
}

function musicVol() { const v = store.get('musicVol'); return v == null ? 0.5 : v; }

let a_ctx = null;
function scheduler() {
  const a = a_ctx;
  while (nextTime < a.currentTime + 0.25) {
    if (musicVol() > 0) scheduleStep(step, nextTime);
    nextTime += SPB;
    step = (step + 1) % STEPS;
  }
  schedTimer = setTimeout(scheduler, 25);
}

export function applyMusicVolume() {
  const a = getAudioContext(); if (!a || !master) return;
  master.gain.cancelScheduledValues(a.currentTime);
  master.gain.linearRampToValueAtTime(musicVol() * 0.9, a.currentTime + 1.0);  // mediu(0.5) ≈ 0.45
}

export function startMusic() {
  const a = getAudioContext(); if (!a) return;
  a_ctx = a;
  ensureGraph(a);
  if (!started) { started = true; nextTime = a.currentTime + 0.12; scheduler(); }
  applyMusicVolume();
}

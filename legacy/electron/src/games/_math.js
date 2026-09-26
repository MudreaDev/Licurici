// Ajutoare comune pentru jocurile de matematică (adunare, scădere, înmulțire, împărțire).
import { shuffle, randInt, pick } from '../ui.js';

const NUM_EMOJIS = ['🍎','⭐','🎈','🍓','🐥','🌸','🚗','🍒','🐟','🧸'];

// Variante de răspuns: numărul corect + distractori apropiați, în interval, unici.
// Generăm generos (până la 5); motorul de lecție (engine.js) taie la optionCount()
// după tier, deci un nivel adânc arată mai multe variante = alegere mai grea.
export function numChoices(correct, lo, hi, count = 5) {
  const set = new Set([correct]);
  let guard = 0;
  while (set.size < count && guard++ < 80) {
    const delta = (Math.random() < 0.5 ? -1 : 1) * randInt(1, 3);
    const d = correct + delta;
    if (d >= lo && d <= hi) set.add(d);
  }
  // dacă intervalul e prea mic, completează în sus/jos
  let x = lo;
  while (set.size < count && x <= hi) { set.add(x); x++; }
  return shuffle([...set]);
}

// Rând de obiecte (reprezentare concretă a unui număr).
export function objectsRow(emoji, count, cls = '') {
  return `<span class="objrow ${cls}">` +
    Array.from({ length: count }, () => emoji).join(' ') + '</span>';
}

export function mathEmoji() { return pick(NUM_EMOJIS); }

// Motorul CENTRAL de dificultate. Un singur „tier" numeric conduce toată scalarea:
//  - în Aventură: dat de nivel și NEMĂRGINIT (cu cât mergi mai departe, cu atât mai greu);
//  - în joc liber: pornește de la clasă (grădiniță…clasa 4) + setarea ușor/mediu.
// Din tier derivăm knob-uri folosite de motorul de lecție (engine.js) și de jocuri:
//  - optionCount(): câte variante de răspuns se arată (2 → 5) — mai multe = mai greu;
//  - roundCount(): câte runde are lecția (mai puține la început, mai multe mai adânc);
//  - numeric*(): plafoane pentru mărimea numerelor la matematică.
// Așa fiecare nivel devine o „variantă" distinctă, tot mai grea, fără fișiere noi.
import { store } from './store.js';
import { gradeTier } from './grades.js';

let levelTier = null;

export function setTier(t) { levelTier = t; }
export function clearTier() { levelTier = null; }

// Tier-ul curent (1..∞). În Aventură e dat de nivel; altfel din clasă + dificultate.
export function tier() {
  if (levelTier != null) return levelTier;            // Aventură: nemărginit
  const base = gradeTier();                            // joc liber: 1..5 după clasă
  return store.get('difficulty') === 'mediu' ? base + 1 : base;
}

// Câte variante de răspuns să se afișeze. Crește BLÂND cu dificultatea și rămâne
// prietenos (2 la început → maxim 5). Motorul taie surplusul de variante la acest număr.
export function optionCount() {
  const t = tier();
  return Math.max(2, Math.min(2 + Math.floor(t / 2), 5));   // t1:2 t2:3 t3:3 t4:4 t5:4 t6:5 …
}

// Câți „distractori" (variante greșite) să genereze un joc = optionCount - 1.
export function distractors() { return optionCount() - 1; }

// Câte runde are o lecție: puține la început (blând cu atenția), mai multe mai adânc.
// Motorul taie/limitează la câte runde a construit jocul.
export function roundCount() {
  const t = tier();
  return Math.max(4, Math.min(5 + Math.floor((t - 1) / 2), 8));  // 5 → 8
}

// ---- Plafoane numerice pentru matematică (cresc cu tier-ul, dar spre valori rezonabile
// pentru clasele primare). Cu cât tier mai mare, cu atât numere mai mari / operații mai grele.
export function numMax(cap = 100, growth = 8, startv = 5) {
  return Math.min(startv + tier() * growth, cap);
}

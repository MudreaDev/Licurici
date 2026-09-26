// Helpere pentru construit interfața + citire cu voce.
import { store } from './store.js';
import { sfx } from './audio.js';
import { VOICE } from './audio-ro/manifest.js';
import { fireflySVG } from './mascot.js';

// ---- Creare rapidă de elemente ----
export function el(tag, attrs = {}, ...children) {
  const node = document.createElement(tag);
  for (const [k, v] of Object.entries(attrs)) {
    if (k === 'class') node.className = v;
    else if (k === 'html') node.innerHTML = v;
    else if (k === 'text') node.textContent = v;
    else if (k.startsWith('on') && typeof v === 'function') {
      node.addEventListener(k.slice(2).toLowerCase(), v);
    } else if (v !== null && v !== undefined && v !== false) {
      node.setAttribute(k, v === true ? '' : v);
    }
  }
  for (const c of children.flat()) {
    if (c == null) continue;
    node.appendChild(typeof c === 'string' ? document.createTextNode(c) : c);
  }
  return node;
}

export function clear(node) { while (node.firstChild) node.removeChild(node.firstChild); }

// ---- Citire cu voce: română CURATĂ, offline, din clipuri împachetate ----
// Toate replicile sunt pre-generate cu vocea românească Ioana (vezi tools/gen-voice.mjs)
// și incluse în app. NU depinde de vocile din sistemul utilizatorului.
// O SINGURĂ voce activă la un moment dat. „gen" (generația) invalidează orice clip mai
// vechi — inclusiv unul care TOCMAI pornea (play() e asincron) — ca vocile să NU se
// suprapună niciodată. Fiecare rostire nouă incrementează gen și oprește dur ce era.
let curAudio = null;
let gen = 0;

// Rezervă: voce RO din sistem, DOAR dacă există (altfel tăcere — să nu se audă engleză).
let roVoice = null;
function pickVoice() {
  const voices = window.speechSynthesis ? speechSynthesis.getVoices() : [];
  roVoice = voices.find(v => /ro(-|_)?/i.test(v.lang)) ||
            voices.find(v => /Romanian|Ioana/i.test(v.name)) || null;
}
if (window.speechSynthesis) {
  pickVoice();
  speechSynthesis.onvoiceschanged = pickVoice;
}

// Oprește complet ce se aude acum (clip + sinteză de sistem).
function hardStop() {
  if (curAudio) {
    try { curAudio.pause(); curAudio.onended = null; curAudio.removeAttribute('src'); curAudio.load(); } catch (e) {}
    curAudio = null;
  }
  if (window.speechSynthesis) { try { speechSynthesis.cancel(); } catch (e) {} }
}

function voiceVol() { const v = store.get('voiceVol'); return v == null ? 0.5 : v; }

function playClip(file, onended) {
  const my = ++gen;          // generație nouă → orice clip anterior devine „vechi"
  hardStop();
  try {
    const a = new Audio('audio-ro/' + file);
    a.volume = Math.min(1, voiceVol());
    curAudio = a;
    a.onended = () => { if (my === gen && onended) onended(); };
    const p = a.play();
    if (p && p.then) {
      p.then(() => { if (my !== gen) { try { a.pause(); } catch (e) {} } })  // depășit cât pornea → taie
       .catch(() => { if (my === gen && onended) onended(); });
    }
    return true;
  } catch (e) { return false; }
}

export function speak(text) {
  if (voiceVol() <= 0 || !text) { stopSpeak(); return; }
  const key = String(text).trim();
  const file = VOICE[key];
  if (file) { playClip(file); return; }
  // Rezervă (rar): voce RO din sistem, doar dacă există.
  gen++; hardStop();
  if (window.speechSynthesis && roVoice) {
    try {
      const u = new SpeechSynthesisUtterance(key);
      u.lang = 'ro-RO'; u.voice = roVoice; u.rate = 1.0; u.volume = Math.min(1, voiceVol());
      speechSynthesis.speak(u);
    } catch (e) { /* ignoră */ }
  }
}

// Rostește o listă de cuvinte pe rând, în ordine (ex. ecuație „Cât fac 2 plus 3").
export function speakSeq(words) {
  if (voiceVol() <= 0 || !words || !words.length) { stopSpeak(); return; }
  let i = 0;
  const next = () => {
    if (i >= words.length) return;
    const file = VOICE[String(words[i]).trim()];
    i++;
    if (file) playClip(file, next); else next();
  };
  next();
}

export function stopSpeak() { gen++; hardStop(); }

// ---- Confetti blând (dezactivabil prin „motion") ----
export function celebrate() {
  sfx.celebrate();
  if (!store.get('motion')) return;
  const layer = el('div', { class: 'confetti' });
  const emojis = ['⭐', '🌈', '✨', '🎈', '💚', '🌟'];
  for (let i = 0; i < 22; i++) {
    const s = el('span', { text: emojis[i % emojis.length] });
    s.style.left = Math.random() * 100 + 'vw';
    s.style.animationDelay = (Math.random() * 0.5) + 's';
    s.style.fontSize = (20 + Math.random() * 22) + 'px';
    layer.appendChild(s);
  }
  document.body.appendChild(layer);
  setTimeout(() => layer.remove(), 3000);
}

// ---- Amestecare (Fisher–Yates) ----
export function shuffle(arr) {
  const a = arr.slice();
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}
export function pick(arr) { return arr[Math.floor(Math.random() * arr.length)]; }
export function sample(arr, n) { return shuffle(arr).slice(0, n); }
export function randInt(min, max) { return Math.floor(Math.random() * (max - min + 1)) + min; }

// ---- Ecran de final (reutilizat de jocurile cu interacțiune proprie) ----
export function showFinish(screen, ctx, { stars = 2, message = 'Ai terminat! 🎉', sub = '', gameId = null }) {
  clear(screen);
  if (gameId) store.recordStat(gameId, { stars });
  celebrate();
  speak('Ai terminat! Bravo!');
  const box = el('div', { class: 'finish' });
  box.appendChild(el('div', { class: 'finish-mascot', html: fireflySVG(110, true) }));
  box.appendChild(el('div', { class: 'bigstars', text: '⭐'.repeat(Math.max(1, stars)) }));
  box.appendChild(el('h2', { text: message }));
  if (sub) box.appendChild(el('p', { class: 'lead', text: sub }));
  const row = el('div', { class: 'row' });
  if (ctx.level) {
    if (ctx.onComplete) ctx.onComplete(Math.max(1, stars));
    row.appendChild(el('button', { class: 'btn', onclick: () => ctx.next() }, '➡️ Următorul'));
    row.appendChild(el('button', { class: 'btn ghost', onclick: () => ctx.restart() }, '🔁 Din nou'));
    row.appendChild(el('button', { class: 'btn mint', onclick: () => ctx.goMap() }, '🗺️ Hartă'));
  } else {
    row.appendChild(el('button', { class: 'btn', onclick: () => ctx.restart() }, '🔁 Încă o dată'));
    row.appendChild(el('button', { class: 'btn mint', onclick: () => ctx.goHome() }, '🏠 Alt joc'));
  }
  box.appendChild(row);
  screen.appendChild(box);
}

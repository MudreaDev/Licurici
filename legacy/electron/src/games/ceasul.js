// Joc: Ceasul — citește ora pe un ceas analog (desenat în SVG).
import { runLesson } from '../engine.js';
import { shuffle, sample, randInt } from '../ui.js';
import { store } from '../store.js';

// Desenează un ceas analog frumos pentru ora h (1-12) și minutul m (0 sau 30).
function drawClock(h, m) {
  const cx = 100, cy = 100;
  const hourAng = ((h % 12) + m / 60) * 30;   // grade de la 12
  const minAng = m * 6;
  const hand = (ang, len, w, color) => {
    const r = (ang - 90) * Math.PI / 180;
    const x = cx + len * Math.cos(r), y = cy + len * Math.sin(r);
    return `<line x1="${cx}" y1="${cy}" x2="${x.toFixed(1)}" y2="${y.toFixed(1)}" stroke="${color}" stroke-width="${w}" stroke-linecap="round"/>`;
  };
  let nums = '';
  for (let i = 1; i <= 12; i++) {
    const r = (i * 30 - 90) * Math.PI / 180;
    const x = cx + 76 * Math.cos(r), y = cy + 76 * Math.sin(r);
    nums += `<text x="${x.toFixed(1)}" y="${y.toFixed(1)}" text-anchor="middle" dominant-baseline="central" font-size="18" font-weight="700" fill="#3f5250" font-family="Fredoka, sans-serif">${i}</text>`;
  }
  let ticks = '';
  for (let i = 0; i < 60; i++) {
    const r = (i * 6 - 90) * Math.PI / 180;
    const big = i % 5 === 0;
    const r1 = big ? 88 : 91, r2 = 95;
    ticks += `<line x1="${(cx + r1 * Math.cos(r)).toFixed(1)}" y1="${(cy + r1 * Math.sin(r)).toFixed(1)}" x2="${(cx + r2 * Math.cos(r)).toFixed(1)}" y2="${(cy + r2 * Math.sin(r)).toFixed(1)}" stroke="${big ? '#8aa6a2' : '#cfe0dd'}" stroke-width="${big ? 3 : 1.5}"/>`;
  }
  return `<svg width="220" height="220" viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">
    <circle cx="100" cy="100" r="97" fill="#ffffff" stroke="#5b9bb5" stroke-width="5"/>
    <circle cx="100" cy="100" r="97" fill="none" stroke="#e8f1ef" stroke-width="1"/>
    ${ticks}${nums}
    ${hand(hourAng, 46, 7, '#3f7d96')}
    ${hand(minAng, 66, 4.5, '#5b9bb5')}
    <circle cx="100" cy="100" r="6" fill="#3f5250"/>
  </svg>`;
}

const label = (h, m) => m === 30 ? `ora ${h} și jumătate` : `ora ${h}`;

function buildRounds(n = 6) {
  const half = store.get('difficulty') === 'mediu';
  const rounds = [];
  for (let i = 0; i < n; i++) {
    const h = randInt(1, 12);
    const m = half && i % 2 === 1 ? 30 : 0;
    const correct = label(h, m);
    // distractori: alte ore (întregi), formatate la fel ca răspunsul
    const others = new Set();
    while (others.size < 2) {
      const dh = randInt(1, 12);
      const dm = (half && Math.random() < 0.4) ? 30 : 0;
      const lb = label(dh, dm);
      if (lb !== correct) others.add(lb);
    }
    const opts = shuffle([correct, ...others]);
    rounds.push({
      promptHtml: `<div class="prompt">Cât e ceasul?</div><div class="clock">${drawClock(h, m)}</div>`,
      speak: 'Cât e ceasul?',
      cols: 3,
      hint: `Acul scurt arată ora. Este ${correct}.`,
      choices: opts.map(o => ({ html: o, correct: o === correct }))
    });
  }
  return rounds;
}

export default {
  id: 'ceasul',
  name: 'Ceasul',
  emoji: '🕐',
  desc: 'Citește ora pe ceas',
  badge: 'Timp',
  start(mount, ctx) {
    runLesson(mount, ctx, {
      gameId: 'ceasul',
      title: '🕐 Ceasul',
      instruction: 'Alege cât e ceasul.',
      rounds: buildRounds(6)
    });
  }
};

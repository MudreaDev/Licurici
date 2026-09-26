// Joc: Numărăm — câte obiecte sunt? Alegi numărul potrivit.
import { COUNT_ITEMS } from '../data/content.js';
import { runLesson } from '../engine.js';
import { pick, randInt, shuffle } from '../ui.js';
import { tier } from '../difficulty.js';

function buildRounds(n = 6) {
  const maxN = Math.min(3 + tier() * 2, 20);
  const rounds = [];
  for (let i = 0; i < n; i++) {
    const count = randInt(1, maxN);
    const item = pick(COUNT_ITEMS);
    const row = Array.from({ length: count }, () => item).join(' ');

    // Variante de răspuns: numărul corect + vecini (motorul taie la optionCount după tier)
    const set = new Set([count]);
    let g = 0;
    while (set.size < 5 && g++ < 60) {
      const d = count + (Math.random() < 0.5 ? -1 : 1) * randInt(1, 3);
      if (d >= 1 && d <= maxN) set.add(d);
    }
    const opts = shuffle([...set]);
    rounds.push({
      promptHtml: `<div class="prompt">Câte sunt?</div><div class="hugeemoji" style="font-size:64px;line-height:1.4">${row}</div>`,
      speak: 'Câte obiecte sunt?',
      cols: 3,
      hint: `Numără unul câte unul. Sunt ${count}.`,
      choices: opts.map(o => ({ html: `<span class="big">${o}</span>`, correct: o === count, speak: String(o) }))
    });
  }
  return rounds;
}

export default {
  id: 'numaram',
  name: 'Numărăm',
  emoji: '🔢',
  desc: 'Câte obiecte vezi?',
  badge: 'Numere',
  start(mount, ctx) {
    runLesson(mount, ctx, {
      gameId: 'numaram',
      title: '🔢 Numărăm',
      instruction: 'Numără obiectele și alege numărul.',
      rounds: buildRounds(8)
    });
  }
};

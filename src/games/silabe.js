// Joc: Silabe — câte silabe are cuvântul? (conștiință fonologică, clasa 1-2)
import { WORDS } from '../data/school.js';
import { runLesson } from '../engine.js';
import { pick, shuffle } from '../ui.js';

function buildRounds(n = 6) {
  const rounds = [];
  for (let i = 0; i < n; i++) {
    const word = pick(WORDS);
    const count = word.syl.length;
    const set = new Set([count]);
    while (set.size < 3) { const d = 1 + Math.floor(Math.random() * 4); if (d !== count) set.add(d); }
    const opts = shuffle([...set]);
    rounds.push({
      promptHtml: `<div class="prompt">Câte silabe?</div><div class="hugeemoji">${word.e}</div><div class="colorname">${word.w}</div>`,
      speak: `Câte silabe are cuvântul ${word.w}?`,
      cols: 3,
      hint: `${word.w} are ${count}: ${word.syl.join(' · ')}`,
      choices: opts.map(v => ({ html: `<span class="big">${v}</span>`, correct: v === count }))
    });
  }
  return rounds;
}

export default {
  id: 'silabe', name: 'Silabe', emoji: '🔤', desc: 'Câte silabe are cuvântul', badge: 'Română',
  start(mount, ctx) {
    runLesson(mount, ctx, { gameId: 'silabe', title: '🔤 Silabe', instruction: 'Câte silabe are cuvântul?', rounds: buildRounds(6) });
  }
};

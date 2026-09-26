// Joc: Zeci și unități — valoarea poziției (clasa 1-2).
import { runLesson } from '../engine.js';
import { randInt, shuffle } from '../ui.js';
import { tier } from '../difficulty.js';

function buildRounds(n = 6) {
  const maxT = Math.min(tier(), 9);
  const rounds = [];
  for (let i = 0; i < n; i++) {
    const T = randInt(1, Math.max(2, maxT));
    const U = randInt(0, 9);
    const num = T * 10 + U;
    const tens = '🟦'.repeat(T);
    const units = '🟡'.repeat(U) || '—';
    const set = new Set([num, U * 10 + T]);           // distractor clasic: cifre inversate
    let g = 0;
    while (set.size < 5 && g++ < 60) { const d = num + randInt(-9, 9); if (d >= 1 && d <= 99) set.add(d); }
    const opts = shuffle([...set]).slice(0, 5);
    if (!opts.includes(num)) opts[0] = num;
    rounds.push({
      promptHtml: `<div class="prompt">Ce număr este?</div><div class="mathrow groups">` +
        `<span class="group"><b>Zeci</b><div style="font-size:30px">${tens}</div></span>` +
        `<span class="group"><b>Unități</b><div style="font-size:30px">${units}</div></span></div>`,
      speak: 'Ce număr este?',
      cols: 3,
      hint: `${T} zeci și ${U} unități fac ${num}.`,
      choices: shuffle(opts).map(v => ({ html: `<span class="big">${v}</span>`, correct: v === num }))
    });
  }
  return rounds;
}

export default {
  id: 'zeci', name: 'Zeci și unități', emoji: '🔟', desc: 'Valoarea poziției', badge: 'Matematică',
  start(mount, ctx) {
    runLesson(mount, ctx, { gameId: 'zeci', title: '🔟 Zeci și unități', instruction: 'Ce număr formează?', rounds: buildRounds(8) });
  }
};

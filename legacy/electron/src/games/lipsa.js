// Joc: Numărul lipsă — completează egalitatea (ex. 3 + _ = 7). (clasa 1-3)
import { runLesson } from '../engine.js';
import { randInt, shuffle } from '../ui.js';
import { tier } from '../difficulty.js';

function buildRounds(n = 6) {
  const maxSum = Math.min(6 + tier() * 6, 50);
  const rounds = [];
  for (let i = 0; i < n; i++) {
    const sum = randInt(3, maxSum);
    const a = randInt(1, sum - 1);
    const b = sum - a;
    const blankFirst = Math.random() < 0.5;
    const missing = blankFirst ? a : b;
    const eq = blankFirst
      ? `<span class="q">?</span> + ${b} = ${sum}`
      : `${a} + <span class="q">?</span> = ${sum}`;
    const set = new Set([missing]);
    let g = 0;
    while (set.size < 5 && g++ < 60) { const d = missing + randInt(-4, 4); if (d >= 0 && d <= maxSum) set.add(d); }
    rounds.push({
      promptHtml: `<div class="prompt">Ce număr lipsește?</div><div class="equation">${eq}</div>`,
      speak: 'Ce număr lipsește?',
      cols: 3,
      hint: `Numărul care lipsește este ${missing}.`,
      choices: shuffle([...set]).map(v => ({ html: `<span class="big">${v}</span>`, correct: v === missing }))
    });
  }
  return rounds;
}

export default {
  id: 'lipsa', name: 'Numărul lipsă', emoji: '❓', desc: 'Completează egalitatea', badge: 'Matematică',
  start(mount, ctx) {
    runLesson(mount, ctx, { gameId: 'lipsa', title: '❓ Numărul lipsă', instruction: 'Ce număr lipsește?', rounds: buildRounds(8) });
  }
};

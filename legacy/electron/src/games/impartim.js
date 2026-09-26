// Joc: Împărțim — împărțire ca „împarte în grupe egale" (concret) + ecuație citită.
import { runLesson } from '../engine.js';
import { randInt } from '../ui.js';
import { tier } from '../difficulty.js';
import { numChoices, objectsRow, mathEmoji } from './_math.js';

function buildRounds(n = 6) {
  const t = tier();
  const maxRes = Math.min(3 + t, 12);
  const maxDiv = Math.min(2 + Math.floor(t / 2), 9);
  const rounds = [];
  for (let i = 0; i < n; i++) {
    const res = randInt(1, maxRes);   // câte în fiecare grupă (răspunsul)
    const b = randInt(2, maxDiv);     // în câte grupe
    const a = res * b;                // total
    const emo = mathEmoji();
    // Sprijin vizual (grupe) doar cât totalul e mic (concret → abstract).
    const concrete = a <= 30;
    const groups = Array.from({ length: b }, () =>
      `<span class="group">${objectsRow(emo, res)}</span>`).join(' ');
    rounds.push({
      promptHtml:
        `<div class="prompt">Câte sunt în fiecare grupă?</div>` +
        (concrete ? `<div class="mathrow groups">${groups}</div>` : '') +
        `<div class="equation">${a} ÷ ${b} = <span class="q">?</span></div>`,
      speakSeq: ['Cât fac', String(a), 'împărțit la', String(b)],
      cols: 3,
      hint: `${a} împărțit în ${b} grupe egale fac câte ${res}.`,
      choices: numChoices(res, 1, maxRes).map(v => ({
        html: `<span class="big">${v}</span>`, correct: v === res
      }))
    });
  }
  return rounds;
}

export default {
  id: 'impartim',
  name: 'Împărțim',
  emoji: '➗',
  desc: 'Împarte în grupe egale',
  badge: 'Matematică',
  start(mount, ctx) {
    runLesson(mount, ctx, {
      gameId: 'impartim',
      title: '➗ Împărțim',
      instruction: 'Câte sunt în fiecare grupă?',
      rounds: buildRounds(8)
    });
  }
};

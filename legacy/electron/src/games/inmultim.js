// Joc: Înmulțim — înmulțire ca „grupe egale" (concret) + ecuație citită natural.
import { runLesson } from '../engine.js';
import { randInt } from '../ui.js';
import { tier } from '../difficulty.js';
import { numChoices, objectsRow, mathEmoji } from './_math.js';

function buildRounds(n = 6) {
  const maxF = Math.min(3 + tier(), 12);
  const rounds = [];
  for (let i = 0; i < n; i++) {
    const a = randInt(1, maxF);   // câte în grupă
    const b = randInt(2, maxF);   // câte grupe
    const prod = a * b;
    const emo = mathEmoji();
    // Sprijin vizual (grupe de obiecte) doar cât produsul e mic (concret → abstract).
    const concrete = prod <= 30;
    const groups = Array.from({ length: b }, () =>
      `<span class="group">${objectsRow(emo, a)}</span>`).join(' ');
    rounds.push({
      promptHtml:
        `<div class="prompt">Câte sunt în total?</div>` +
        (concrete ? `<div class="mathrow groups">${groups}</div>` : '') +
        `<div class="equation">${a} × ${b} = <span class="q">?</span></div>`,
      speakSeq: ['Cât fac', String(a), 'ori', String(b)],
      cols: 3,
      hint: `${b} grupe a câte ${a} fac ${prod}.`,
      choices: numChoices(prod, 1, maxF * maxF).map(v => ({
        html: `<span class="big">${v}</span>`, correct: v === prod
      }))
    });
  }
  return rounds;
}

export default {
  id: 'inmultim',
  name: 'Înmulțim',
  emoji: '✖️',
  desc: 'Grupe egale',
  badge: 'Matematică',
  start(mount, ctx) {
    runLesson(mount, ctx, {
      gameId: 'inmultim',
      title: '✖️ Înmulțim',
      instruction: 'Câte sunt în total?',
      rounds: buildRounds(8)
    });
  }
};

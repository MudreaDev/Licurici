// Joc: Scădem — scădere cu sprijin vizual (obiecte tăiate) + ecuație citită natural.
import { runLesson } from '../engine.js';
import { randInt } from '../ui.js';
import { tier } from '../difficulty.js';
import { numChoices, objectsRow, mathEmoji } from './_math.js';

function buildRounds(n = 6) {
  const maxA = Math.min(6 + tier() * 6, 100);
  const rounds = [];
  for (let i = 0; i < n; i++) {
    const a = randInt(2, maxA);
    const b = randInt(1, a - 1);
    const res = a - b;
    const emo = mathEmoji();
    // Sprijin vizual (obiecte tăiate) doar cât numerele sunt mici (concret → abstract).
    const concrete = a <= 20;
    const kept = objectsRow(emo, a - b);
    const taken = objectsRow(emo, b, 'taken');
    rounds.push({
      promptHtml:
        `<div class="prompt">Câte rămân?</div>` +
        (concrete ? `<div class="mathrow">${kept} ${taken}</div>` : '') +
        `<div class="equation">${a} − ${b} = <span class="q">?</span></div>`,
      speakSeq: ['Cât fac', String(a), 'minus', String(b)],
      cols: 3,
      hint: `Iei ${b}. Rămân ${res}.`,
      choices: numChoices(res, 0, maxA).map(v => ({
        html: `<span class="big">${v}</span>`, correct: v === res
      }))
    });
  }
  return rounds;
}

export default {
  id: 'scadem',
  name: 'Scădem',
  emoji: '➖',
  desc: 'Învață să scazi',
  badge: 'Matematică',
  start(mount, ctx) {
    runLesson(mount, ctx, {
      gameId: 'scadem',
      title: '➖ Scădem',
      instruction: 'Câte rămân?',
      rounds: buildRounds(8)
    });
  }
};

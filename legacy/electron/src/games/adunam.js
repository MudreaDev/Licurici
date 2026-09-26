// Joc: Adunăm — adunare cu sprijin vizual (obiecte) + ecuație citită natural.
import { runLesson } from '../engine.js';
import { randInt } from '../ui.js';
import { tier } from '../difficulty.js';
import { numChoices, objectsRow, mathEmoji } from './_math.js';

function buildRounds(n = 6) {
  const t = tier();
  const maxTerm = Math.min(3 + t * 3, 50);
  const maxSum = Math.min(6 + t * 8, 100);
  const rounds = [];
  for (let i = 0; i < n; i++) {
    const a = randInt(1, maxTerm);
    const b = randInt(1, Math.min(maxTerm, maxSum - a));
    const sum = a + b;
    const emo = mathEmoji();
    // Sprijin vizual (obiecte) doar cât numerele sunt mici; mai adânc → doar ecuația
    // (trecere firească de la concret la abstract).
    const concrete = sum <= 20;
    rounds.push({
      promptHtml:
        `<div class="prompt">Cât fac?</div>` +
        (concrete ? `<div class="mathrow">${objectsRow(emo, a)} <span class="op">+</span> ${objectsRow(emo, b)}</div>` : '') +
        `<div class="equation">${a} + ${b} = <span class="q">?</span></div>`,
      speakSeq: ['Cât fac', String(a), 'plus', String(b)],
      cols: 3,
      hint: `Numără toate obiectele: sunt ${sum}.`,
      choices: numChoices(sum, 1, maxSum).map(v => ({
        html: `<span class="big">${v}</span>`, correct: v === sum
      }))
    });
  }
  return rounds;
}

export default {
  id: 'adunam',
  name: 'Adunăm',
  emoji: '➕',
  desc: 'Învață să aduni',
  badge: 'Matematică',
  start(mount, ctx) {
    runLesson(mount, ctx, {
      gameId: 'adunam',
      title: '➕ Adunăm',
      instruction: 'Câte sunt în total?',
      rounds: buildRounds(8)
    });
  }
};

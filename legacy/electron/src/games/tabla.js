// Joc: Tabla înmulțirii — exercițiu rapid (clasa 2-4). Ecuația e citită natural.
import { runLesson } from '../engine.js';
import { randInt, shuffle } from '../ui.js';
import { tier } from '../difficulty.js';
import { numChoices } from './_math.js';

function buildRounds(n = 6) {
  const maxF = Math.min(2 + tier(), 12);
  const rounds = [];
  for (let i = 0; i < n; i++) {
    const a = randInt(2, maxF);
    const b = randInt(2, maxF);
    const prod = a * b;
    rounds.push({
      promptHtml: `<div class="prompt">Cât fac?</div><div class="equation big-eq">${a} × ${b} = <span class="q">?</span></div>`,
      speakSeq: ['Cât fac', String(a), 'ori', String(b)],
      cols: 3,
      hint: `${a} × ${b} = ${prod}`,
      choices: numChoices(prod, 1, maxF * maxF).map(v => ({ html: `<span class="big">${v}</span>`, correct: v === prod }))
    });
  }
  return rounds;
}

export default {
  id: 'tabla', name: 'Tabla înmulțirii', emoji: '✖️', desc: 'Exercițiu rapid', badge: 'Matematică',
  start(mount, ctx) {
    runLesson(mount, ctx, { gameId: 'tabla', title: '✖️ Tabla înmulțirii', instruction: 'Cât fac?', rounds: buildRounds(8) });
  }
};

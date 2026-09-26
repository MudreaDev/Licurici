// Joc: Simboluri naționale — recunoaște simbolul (Istorie).
import { SYMBOLS } from '../data/istorie.js';
import { runLesson } from '../engine.js';
import { pick, sample, shuffle } from '../ui.js';

function buildRounds(n = 6) {
  const rounds = [];
  for (let i = 0; i < n; i++) {
    const target = pick(SYMBOLS);
    const others = sample(SYMBOLS.filter(s => s.name !== target.name), 4);
    const opts = shuffle([target, ...others]);
    rounds.push({
      promptHtml: `<div class="prompt">Ce simbol național este?</div><div class="hugeemoji">${target.e}</div>`,
      speak: 'Ce simbol național este?',
      cols: 3,
      hint: `Acesta este ${target.name}.`,
      choices: opts.map(o => ({ html: o.name, correct: o.name === target.name }))
    });
  }
  return rounds;
}

export default {
  id: 'simboluri', name: 'Simboluri', emoji: '🏛️', desc: 'Simbolurile țării', badge: 'Istorie',
  start(mount, ctx) {
    runLesson(mount, ctx, { gameId: 'simboluri', title: '🏛️ Simboluri naționale', instruction: 'Ce simbol național este?', rounds: buildRounds(6) });
  }
};

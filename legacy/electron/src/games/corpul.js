// Joc: Corpul — recunoaște părțile corpului (Științe / cunoașterea de sine).
import { BODY } from '../data/school.js';
import { runLesson } from '../engine.js';
import { pick, sample, shuffle } from '../ui.js';

function buildRounds(n = 6) {
  const rounds = [];
  for (let i = 0; i < n; i++) {
    const target = pick(BODY);
    const others = sample(BODY.filter(b => b.name !== target.name), 4);
    const opts = shuffle([target, ...others]);
    rounds.push({
      promptHtml: `<div class="prompt">Ce parte a corpului este?</div><div class="hugeemoji">${target.e}</div>`,
      speak: 'Ce parte a corpului este?',
      cols: 3,
      hint: `Aceasta este: ${target.name}.`,
      choices: opts.map(o => ({ html: o.name, correct: o.name === target.name }))
    });
  }
  return rounds;
}

export default {
  id: 'corpul', name: 'Corpul', emoji: '🧍', desc: 'Părțile corpului', badge: 'Științe',
  start(mount, ctx) {
    runLesson(mount, ctx, { gameId: 'corpul', title: '🧍 Corpul', instruction: 'Ce parte a corpului este?', rounds: buildRounds(6) });
  }
};

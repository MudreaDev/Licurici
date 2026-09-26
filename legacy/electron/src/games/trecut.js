// Joc: Trecut și prezent — care obiect e din trecut? (Istorie / trecut vs prezent)
import { PAST_PRESENT } from '../data/istorie.js';
import { runLesson } from '../engine.js';
import { pick, shuffle } from '../ui.js';

function buildRounds(n = 6) {
  const rounds = [];
  for (let i = 0; i < n; i++) {
    const pair = pick(PAST_PRESENT);
    const opts = shuffle([
      { e: pair.old.e, w: pair.old.w, old: true },
      { e: pair.neu.e, w: pair.neu.w, old: false }
    ]);
    rounds.push({
      promptHtml: `<div class="prompt">Care e din trecut?</div><div class="scene">Unul e vechi, unul e nou.</div>`,
      speak: 'Care e din trecut?',
      cols: 2,
      hint: `${pair.old.w} este din trecut; ${pair.neu.w} este de acum.`,
      choices: opts.map(o => ({ html: `<span class="big">${o.e}</span><span>${o.w}</span>`, correct: o.old }))
    });
  }
  return rounds;
}

export default {
  id: 'trecut', name: 'Trecut și prezent', emoji: '⏳', desc: 'Vechi sau nou?', badge: 'Istorie',
  start(mount, ctx) {
    runLesson(mount, ctx, { gameId: 'trecut', title: '⏳ Trecut și prezent', instruction: 'Care obiect e din trecut?', rounds: buildRounds(6) });
  }
};

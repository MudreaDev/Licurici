// Joc: Opuse — alege cuvântul cu sens opus (mare↔mic, zi↔noapte…).
import { OPPOSITES } from '../data/content.js';
import { runLesson } from '../engine.js';
import { shuffle, sample, pick } from '../ui.js';

// Toate cuvintele (pentru distractori)
const ALL = OPPOSITES.flatMap(p => [p.a, p.b]);

function buildRounds(n = 6) {
  const rounds = [];
  for (let i = 0; i < n; i++) {
    const pair = pick(OPPOSITES);
    const showA = Math.random() < 0.5;
    const shown = showA ? pair.a : pair.b;
    const answer = showA ? pair.b : pair.a;
    const distract = sample(ALL.filter(w => w.w !== shown.w && w.w !== answer.w), 4);
    const opts = shuffle([answer, ...distract]);
    rounds.push({
      promptHtml: `<div class="prompt">Care e opusul?</div><div class="hugeemoji">${shown.e}</div><div class="colorname">${shown.w}</div>`,
      speak: 'Care e opusul?',
      cols: 3,
      hint: `Opusul lui „${shown.w}" este „${answer.w}".`,
      choices: opts.map(o => ({ html: `<span class="big">${o.e}</span><span>${o.w}</span>`, correct: o.w === answer.w }))
    });
  }
  return rounds;
}

export default {
  id: 'opuse',
  name: 'Opuse',
  emoji: '↔️',
  desc: 'Găsește opusul',
  badge: 'Cuvinte',
  start(mount, ctx) {
    runLesson(mount, ctx, {
      gameId: 'opuse',
      title: '↔️ Opuse',
      instruction: 'Alege cuvântul cu sens opus.',
      rounds: buildRounds(6)
    });
  }
};

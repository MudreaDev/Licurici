// Joc: Singular și plural — cum spui la mai multe? (clasa 2-4).
import { PLURALS, ALL_PLURALS } from '../data/romana.js';
import { runLesson } from '../engine.js';
import { pick, sample, shuffle } from '../ui.js';

function buildRounds(n = 6) {
  const rounds = [];
  for (let i = 0; i < n; i++) {
    const item = pick(PLURALS);
    const distract = sample(ALL_PLURALS.filter(p => p !== item.pl), 4);
    const opts = shuffle([item.pl, ...distract]);
    rounds.push({
      promptHtml:
        `<div class="prompt">Cum spui la mai multe?</div>` +
        `<div class="hugeemoji" style="font-size:64px">${item.e}</div>` +
        `<div class="scene" style="font-size:30px">o/un <b>${item.sg}</b> → mai multe…</div>`,
      speak: 'Cum spui la mai multe?',
      hint: `Mai multe: ${item.pl}.`,
      choices: opts.map(o => ({ html: `<span style="font-weight:800">${o}</span>`, correct: o === item.pl }))
    });
  }
  return rounds;
}

export default {
  id: 'plural',
  name: 'Singular și plural',
  emoji: '🧒',
  desc: 'Cum spui la mai multe?',
  badge: 'Română',
  start(mount, ctx) {
    runLesson(mount, ctx, {
      gameId: 'plural',
      title: '🧒 Singular și plural',
      instruction: 'Cum spui la mai multe?',
      rounds: buildRounds(6)
    });
  }
};

// Joc: Citește cuvântul — vezi cuvântul scris, alegi imaginea potrivită (citire).
import { WORDS } from '../data/school.js';
import { runLesson } from '../engine.js';
import { pick, sample, shuffle } from '../ui.js';

function buildRounds(n = 6) {
  const rounds = [];
  for (let i = 0; i < n; i++) {
    const target = pick(WORDS);
    const others = sample(WORDS.filter(w => w.w !== target.w), 4);
    const opts = shuffle([target, ...others]);
    rounds.push({
      promptHtml: `<div class="prompt">Citește și alege imaginea:</div><div class="colorname">${target.w}</div>`,
      speak: target.w,
      cols: 3,
      hint: `„${target.w}" este ${target.e}`,
      choices: opts.map(o => ({ html: `<span class="big">${o.e}</span>`, correct: o.w === target.w }))
    });
  }
  return rounds;
}

export default {
  id: 'cuvinte', name: 'Citește', emoji: '📕', desc: 'Citește cuvântul și alege imaginea', badge: 'Română',
  start(mount, ctx) {
    runLesson(mount, ctx, { gameId: 'cuvinte', title: '📕 Citește cuvântul', instruction: 'Citește cuvântul și alege imaginea.', rounds: buildRounds(6) });
  }
};

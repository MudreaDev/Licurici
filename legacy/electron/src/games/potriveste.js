// Joc: Potrivește — găsește obiectul la fel (potrivire, atenție vizuală).
// Joc fundamental, cu încărcare mică — bun ca început.
import { MATCH_ITEMS } from '../data/content.js';
import { runLesson } from '../engine.js';
import { pick, sample, shuffle } from '../ui.js';

function buildRounds(n = 6) {
  const nOpts = 4;  // generăm generos; motorul (engine.js) taie la optionCount() după tier
  const rounds = [];
  for (let i = 0; i < n; i++) {
    const target = pick(MATCH_ITEMS);
    const distract = sample(MATCH_ITEMS.filter(t => t !== target), nOpts);
    const opts = shuffle([target, ...distract]);
    rounds.push({
      promptHtml: `<div class="prompt">Găsește la fel:</div><div class="hugeemoji">${target}</div>`,
      speak: 'Găsește obiectul la fel.',
      cols: nOpts + 1 >= 3 ? 3 : 2,
      hint: 'Caută pe cel care arată exact la fel.',
      choices: opts.map(o => ({ html: `<span class="big">${o}</span>`, correct: o === target, speak: '' }))
    });
  }
  return rounds;
}

export default {
  id: 'potriveste',
  name: 'Potrivește',
  emoji: '🧩',
  desc: 'Găsește obiectul la fel',
  badge: 'Atenție',
  start(mount, ctx) {
    runLesson(mount, ctx, {
      gameId: 'potriveste',
      title: '🧩 Potrivește',
      instruction: 'Găsește obiectul care e la fel.',
      rounds: buildRounds(6)
    });
  }
};

// Joc: Ce fel de cuvânt? — recunoaște substantiv / verb / adjectiv (clasa 3-4).
import { WORD_KINDS } from '../data/romana.js';
import { runLesson } from '../engine.js';
import { pick, shuffle } from '../ui.js';

function buildRounds(n = 6) {
  const rounds = [];
  for (let i = 0; i < n; i++) {
    const cat = pick(WORD_KINDS);
    const word = pick(cat.words);
    rounds.push({
      promptHtml:
        `<div class="prompt">Ce fel de cuvânt este?</div>` +
        (word.e ? `<div class="hugeemoji" style="font-size:64px">${word.e}</div>` : '') +
        `<div class="scene" style="font-size:36px;font-weight:800">${word.w}</div>`,
      speak: 'Ce fel de cuvânt este?',
      hint: `„${word.w}" este ${cat.label.toLowerCase()}.`,
      // ordinea variază (nu e mereu pe același loc)
      choices: shuffle(WORD_KINDS).map(k => ({ html: k.label, correct: k.kind === cat.kind }))
    });
  }
  return rounds;
}

export default {
  id: 'gramatica',
  name: 'Ce fel de cuvânt?',
  emoji: '✍️',
  desc: 'Substantiv, verb sau adjectiv',
  badge: 'Română',
  start(mount, ctx) {
    runLesson(mount, ctx, {
      gameId: 'gramatica',
      title: '✍️ Ce fel de cuvânt?',
      instruction: 'Substantiv, verb sau adjectiv?',
      rounds: buildRounds(6)
    });
  }
};

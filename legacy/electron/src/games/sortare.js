// Joc: Sortare — în ce grupă intră obiectul? (formarea conceptelor / categorii)
import { CATEGORIES } from '../data/content.js';
import { runLesson } from '../engine.js';
import { pick, sample, shuffle } from '../ui.js';

function buildRounds(n = 6) {
  const rounds = [];
  for (let i = 0; i < n; i++) {
    const target = pick(CATEGORIES);
    const item = pick(target.items);
    const others = sample(CATEGORIES.filter(c => c.name !== target.name), 4);
    const opts = shuffle([target, ...others]);
    rounds.push({
      promptHtml: `<div class="prompt">În ce grupă intră?</div><div class="hugeemoji">${item}</div>`,
      speak: 'În ce grupă intră acest obiect?',
      cols: 3,
      hint: `Acesta face parte din grupa „${target.name}".`,
      choices: opts.map(o => ({
        html: `<span class="big">${o.emoji}</span><span>${o.name}</span>`,
        correct: o.name === target.name, speak: o.name
      }))
    });
  }
  return rounds;
}

export default {
  id: 'sortare',
  name: 'Sortare',
  emoji: '🗂️',
  desc: 'Pune obiectul în grupa potrivită',
  badge: 'Concepte',
  start(mount, ctx) {
    runLesson(mount, ctx, {
      gameId: 'sortare',
      title: '🗂️ Sortare',
      instruction: 'Alege grupa în care intră obiectul.',
      rounds: buildRounds(6)
    });
  }
};

// Joc: Unde trăiește? — potrivește animalul cu mediul lui (Științe / mediu).
import { HABITATS } from '../data/school.js';
import { runLesson } from '../engine.js';
import { pick, sample, shuffle } from '../ui.js';

function buildRounds(n = 6) {
  const rounds = [];
  for (let i = 0; i < n; i++) {
    const home = pick(HABITATS);
    const animal = pick(home.animals);
    const others = sample(HABITATS.filter(h => h.name !== home.name), 4);
    const opts = shuffle([home, ...others]);
    rounds.push({
      promptHtml: `<div class="prompt">Unde trăiește?</div><div class="hugeemoji">${animal}</div>`,
      speak: 'Unde trăiește?',
      cols: 3,
      hint: `Acest animal trăiește: ${home.name}.`,
      choices: opts.map(o => ({ html: `<span class="big">${o.emoji}</span><span>${o.name}</span>`, correct: o.name === home.name }))
    });
  }
  return rounds;
}

export default {
  id: 'habitate', name: 'Unde trăiește?', emoji: '🦁', desc: 'Animalul și mediul lui', badge: 'Științe',
  start(mount, ctx) {
    runLesson(mount, ctx, { gameId: 'habitate', title: '🦁 Unde trăiește?', instruction: 'Unde trăiește animalul?', rounds: buildRounds(6) });
  }
};

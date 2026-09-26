// Joc: Personalități — cine a fost? (Istorie, clasele 3-4)
import { PEOPLE, PEOPLE_NAMES } from '../data/istorie.js';
import { runLesson } from '../engine.js';
import { pick, sample, shuffle } from '../ui.js';

function buildRounds(n = 5) {
  const chosen = sample(PEOPLE, Math.min(n, PEOPLE.length));
  return chosen.map(p => {
    const distract = sample(PEOPLE_NAMES.filter(x => x !== p.a), 4);
    const opts = shuffle([p.a, ...distract]);
    return {
      promptHtml: `<div class="prompt">🏛️ Cine a fost?</div><div class="scene">${p.q}</div>`,
      speak: p.q,
      cols: 1,
      hint: `Răspunsul este ${p.a}.`,
      choices: opts.map(name => ({ html: name, correct: name === p.a }))
    };
  });
}

export default {
  id: 'personalitati', name: 'Personalități', emoji: '👑', desc: 'Oameni mari din istorie', badge: 'Istorie',
  start(mount, ctx) {
    runLesson(mount, ctx, { gameId: 'personalitati', title: '👑 Personalități', instruction: 'Cine a fost?', rounds: buildRounds(5) });
  }
};

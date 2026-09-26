// Joc: Engleză — auzi cuvântul în engleză (voce englezească), vezi imaginea și alegi
// cuvântul scris corect. Ascultare + citire de bază (engleză ca materie).
import { ENGLISH, ENGLISH_WORDS } from '../data/school.js';
import { runLesson } from '../engine.js';
import { pick, sample, shuffle } from '../ui.js';

function buildRounds(n = 6) {
  const rounds = [];
  for (let i = 0; i < n; i++) {
    const cat = pick(ENGLISH);
    const target = pick(cat.items);
    const distract = sample(ENGLISH_WORDS.filter(w => w !== target.en), 4);
    const opts = shuffle([target.en, ...distract]);
    rounds.push({
      promptHtml: `<div class="prompt">Cum se spune în engleză?</div><div class="hugeemoji">${target.e}</div><div class="scene">${target.ro}</div>`,
      speak: target.en,                 // se rostește în engleză (clip cu voce englezească)
      cols: 3,
      hint: `„${target.ro}" în engleză este „${target.en}".`,
      choices: opts.map(w => ({ html: w, correct: w === target.en }))
    });
  }
  return rounds;
}

export default {
  id: 'engleza', name: 'Engleză', emoji: '🌐', desc: 'Cuvinte în engleză', badge: 'English',
  start(mount, ctx) {
    runLesson(mount, ctx, { gameId: 'engleza', title: '🌐 Engleză', instruction: 'Ascultă și alege cuvântul englezesc.', rounds: buildRounds(6) });
  }
};

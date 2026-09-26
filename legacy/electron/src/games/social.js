// Joc: Situații sociale — ce e potrivit să faci.
// Scenariu scurt și literal → alegi reacția potrivită. Explicația devine indiciu blând.
import { SOCIAL } from '../data/content.js';
import { runLesson } from '../engine.js';
import { shuffle, sample } from '../ui.js';

function buildRounds(n = 6) {
  const scenarios = sample(SOCIAL, Math.min(n, SOCIAL.length));
  return scenarios.map(s => {
    const opts = shuffle(s.options);
    return {
      promptHtml: `<div class="prompt">🤝 Ce faci?</div><div class="scene">${s.q}</div>`,
      speak: s.q,
      cols: 1,
      hint: s.explain,
      choices: opts.map(o => ({ html: o.t, correct: !!o.good, speak: o.t }))
    };
  });
}

export default {
  id: 'social',
  name: 'Situații',
  emoji: '🤝',
  desc: 'Ce e potrivit să faci cu ceilalți',
  badge: 'Social',
  start(mount, ctx) {
    runLesson(mount, ctx, {
      gameId: 'social',
      title: '🤝 Situații sociale',
      instruction: 'Alege ce e cel mai potrivit să faci.',
      rounds: buildRounds(6)
    });
  }
};

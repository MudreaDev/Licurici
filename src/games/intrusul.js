// Joc: Găsește intrusul — care obiect NU se potrivește cu celelalte (categorii).
import { CATEGORIES } from '../data/content.js';
import { runLesson } from '../engine.js';
import { shuffle, sample, pick } from '../ui.js';
import { tier } from '../difficulty.js';

function buildRounds(n = 6) {
  const rounds = [];
  // Mai adânc = mai multe obiecte „la fel" printre care se ascunde intrusul (scanare mai grea).
  const same = Math.min(2 + tier(), 5);
  for (let i = 0; i < n; i++) {
    const cat = pick(CATEGORIES);
    const other = pick(CATEGORIES.filter(c => c.name !== cat.name));
    const group = sample(cat.items, same);
    const intruder = pick(other.items.filter(x => !group.includes(x)));
    const opts = shuffle([...group.map(x => ({ e: x, bad: false })), { e: intruder, bad: true }]);
    rounds.push({
      promptHtml: `<div class="prompt">Care nu se potrivește?</div><div class="scene">Toate sunt la fel, unul e intrus.</div>`,
      speak: 'Care nu se potrivește?',
      fixedChoices: true,   // intrusul are formatul lui (mai multe „la fel" + 1 intrus)
      hint: `Celelalte sunt din grupa „${cat.name}". Intrusul este ${intruder}.`,
      choices: opts.map(o => ({ html: `<span class="big">${o.e}</span>`, correct: o.bad }))
    });
  }
  return rounds;
}

export default {
  id: 'intrusul',
  name: 'Intrusul',
  emoji: '🔎',
  desc: 'Găsește ce nu se potrivește',
  badge: 'Logică',
  start(mount, ctx) {
    runLesson(mount, ctx, {
      gameId: 'intrusul',
      title: '🔎 Găsește intrusul',
      instruction: 'Alege obiectul care nu se potrivește.',
      rounds: buildRounds(6)
    });
  }
};

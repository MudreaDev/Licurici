// Joc: Recunoașterea emoțiilor (dovada cea mai puternică pentru autism).
// Două tipuri de întrebări, alese aleator → mereu variat:
//  A) Vezi fața → alegi cum se simte.
//  B) Citești situația → alegi fața potrivită.
import { EMOTIONS } from '../data/content.js';
import { runLesson } from '../engine.js';
import { shuffle, sample, pick } from '../ui.js';

function buildRounds(n = 6) {
  const rounds = [];
  for (let i = 0; i < n; i++) {
    const target = pick(EMOTIONS);
    const distract = sample(EMOTIONS.filter(e => e.key !== target.key), 4);
    const opts = shuffle([target, ...distract]);

    if (i % 2 === 0) {
      // A) față → etichetă
      rounds.push({
        promptHtml: `<div class="prompt">Cum se simte?</div><div class="hugeemoji">${target.emoji}</div>`,
        speak: 'Cum se simte?',
        cols: 3,
        hint: `Fața asta arată „${target.label.toLowerCase()}".`,
        choices: opts.map(o => ({ html: `${o.label}`, correct: o.key === target.key, speak: o.label }))
      });
    } else {
      // B) situație → față
      const ctx = pick(target.contexts);
      rounds.push({
        promptHtml: `<div class="prompt">Cum se simte?</div><div class="scene">Un copil ${ctx}.</div>`,
        speak: `Cum se simte un copil care ${ctx}?`,
        cols: 3,
        hint: `Când ${ctx}, te simți ${target.label.toLowerCase()}.`,
        choices: opts.map(o => ({
          html: `<span class="big">${o.emoji}</span><span>${o.label}</span>`,
          correct: o.key === target.key, speak: o.label
        }))
      });
    }
  }
  return rounds;
}

export default {
  id: 'emotii',
  name: 'Emoții',
  emoji: '😊',
  desc: 'Recunoaște cum se simt oamenii',
  badge: 'Emoții',
  start(mount, ctx) {
    runLesson(mount, ctx, {
      gameId: 'emotii',
      title: '😊 Emoții',
      instruction: 'Alege răspunsul potrivit.',
      rounds: buildRounds(6)
    });
  }
};

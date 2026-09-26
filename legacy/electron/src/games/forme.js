// Joc: Forme — recunoașterea formelor (simbol ↔ nume).
import { SHAPES } from '../data/content.js';
import { runLesson } from '../engine.js';
import { shuffle, sample, pick } from '../ui.js';

function buildRounds(n = 6) {
  const rounds = [];
  for (let i = 0; i < n; i++) {
    const target = pick(SHAPES);
    const distract = sample(SHAPES.filter(s => s.name !== target.name), 4);
    const opts = shuffle([target, ...distract]);

    if (i % 2 === 0) {
      // formă → nume
      rounds.push({
        promptHtml: `<div class="prompt">Ce formă este?</div><div class="hugeemoji">${target.e}</div>`,
        speak: 'Ce formă este?',
        cols: 3,
        hint: `Aceasta este ${target.name}.`,
        choices: opts.map(o => ({ html: o.name, correct: o.name === target.name, speak: o.name }))
      });
    } else {
      // nume → formă
      rounds.push({
        promptHtml: `<div class="prompt">Alege forma:</div><div class="colorname">${target.name}</div>`,
        speak: target.name,
        cols: 3,
        hint: `${target.name} arată așa: ${target.e}`,
        choices: opts.map(o => ({ html: `<span class="big">${o.e}</span>`, correct: o.name === target.name }))
      });
    }
  }
  return rounds;
}

export default {
  id: 'forme',
  name: 'Forme',
  emoji: '🔷',
  desc: 'Învață formele',
  badge: 'Forme',
  start(mount, ctx) {
    runLesson(mount, ctx, {
      gameId: 'forme',
      title: '🔷 Forme',
      instruction: 'Alege forma potrivită.',
      rounds: buildRounds(6)
    });
  }
};

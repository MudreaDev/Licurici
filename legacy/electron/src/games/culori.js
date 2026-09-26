// Joc: Culori — recunoașterea culorilor (nume ↔ culoare).
import { COLORS } from '../data/content.js';
import { runLesson } from '../engine.js';
import { shuffle, sample, pick } from '../ui.js';

const swatch = (hex) => `<span class="swatch" style="background:${hex}"></span>`;

function buildRounds(n = 6) {
  const rounds = [];
  for (let i = 0; i < n; i++) {
    const target = pick(COLORS);
    const distract = sample(COLORS.filter(c => c.name !== target.name), 4);
    const opts = shuffle([target, ...distract]);

    if (i % 2 === 0) {
      // culoare → nume
      rounds.push({
        promptHtml: `<div class="prompt">Ce culoare este?</div><div class="swatch-big" style="background:${target.hex}"></div>`,
        speak: 'Ce culoare este?',
        cols: 3,
        hint: `Aceasta este culoarea ${target.name}.`,
        choices: opts.map(o => ({ html: o.name, correct: o.name === target.name, speak: o.name }))
      });
    } else {
      // nume → culoare
      rounds.push({
        promptHtml: `<div class="prompt">Alege culoarea:</div><div class="colorname">${target.name}</div>`,
        speak: target.name,
        cols: 3,
        hint: `${target.name} arată așa.`,
        choices: opts.map(o => ({ html: swatch(o.hex), correct: o.name === target.name }))
      });
    }
  }
  return rounds;
}

export default {
  id: 'culori',
  name: 'Culori',
  emoji: '🎨',
  desc: 'Învață culorile',
  badge: 'Culori',
  start(mount, ctx) {
    runLesson(mount, ctx, {
      gameId: 'culori',
      title: '🎨 Culori',
      instruction: 'Alege culoarea potrivită.',
      rounds: buildRounds(6)
    });
  }
};

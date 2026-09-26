// Joc: Comparăm — unde sunt mai multe? (noțiunea de mai mult / mai puțin / la fel)
import { runLesson } from '../engine.js';
import { randInt } from '../ui.js';
import { tier } from '../difficulty.js';
import { objectsRow, mathEmoji } from './_math.js';

function buildRounds(n = 6) {
  const maxN = Math.min(3 + tier() * 2, 20);
  const rounds = [];
  for (let i = 0; i < n; i++) {
    let a = randInt(1, maxN), b = randInt(1, maxN);
    // din când în când, egale
    if (i % 3 === 2) b = a;
    const emo = mathEmoji();
    const boxA = `<div class="cbox">${objectsRow(emo, a)}</div>`;
    const boxB = `<div class="cbox">${objectsRow(emo, b)}</div>`;
    const correctKey = a > b ? 'A' : b > a ? 'B' : 'egal';
    rounds.push({
      promptHtml: `<div class="prompt">Unde sunt mai multe?</div>`,
      speak: 'Unde sunt mai multe?',
      fixedChoices: true,   // opțiunile SUNT grupele comparate — nu le tăiem
      hint: correctKey === 'egal' ? 'Sunt la fel de multe.' : `Sunt mai multe în grupa ${correctKey}.`,
      choices: [
        { html: `${boxA}<span>Grupa A</span>`, correct: correctKey === 'A' },
        { html: `${boxB}<span>Grupa B</span>`, correct: correctKey === 'B' },
        { html: `<span class="big">🤝</span><span>La fel</span>`, correct: correctKey === 'egal' }
      ]
    });
  }
  return rounds;
}

export default {
  id: 'comparam',
  name: 'Comparăm',
  emoji: '⚖️',
  desc: 'Mai mult sau mai puțin?',
  badge: 'Matematică',
  start(mount, ctx) {
    runLesson(mount, ctx, {
      gameId: 'comparam',
      title: '⚖️ Comparăm',
      instruction: 'Alege unde sunt mai multe.',
      rounds: buildRounds(8)
    });
  }
};

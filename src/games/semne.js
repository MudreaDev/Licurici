// Joc: Semne — compară două numere cu <, > sau = (clasa 1-3).
import { runLesson } from '../engine.js';
import { randInt } from '../ui.js';
import { tier } from '../difficulty.js';

function buildRounds(n = 6) {
  const maxN = Math.min(5 + tier() * 12, 1000);
  const rounds = [];
  for (let i = 0; i < n; i++) {
    let a = randInt(1, maxN), b = randInt(1, maxN);
    if (i % 3 === 2) b = a;                 // uneori egale
    const correct = a < b ? '<' : a > b ? '>' : '=';
    rounds.push({
      promptHtml: `<div class="prompt">Ce semn se potrivește?</div>` +
        `<div class="equation">${a} <span class="q">?</span> ${b}</div>`,
      speak: 'Ce semn se potrivește?',
      cols: 3,
      hint: `${a} ${correct} ${b}`,
      choices: [
        { html: `<span class="big">&lt;</span><span>mai mic</span>`, correct: correct === '<' },
        { html: `<span class="big">=</span><span>egal</span>`,      correct: correct === '=' },
        { html: `<span class="big">&gt;</span><span>mai mare</span>`, correct: correct === '>' }
      ]
    });
  }
  return rounds;
}

export default {
  id: 'semne', name: 'Semne', emoji: '⚖️', desc: 'Mai mic, mai mare sau egal', badge: 'Matematică',
  start(mount, ctx) {
    runLesson(mount, ctx, { gameId: 'semne', title: '⚖️ Semne', instruction: 'Alege semnul potrivit: < = >', rounds: buildRounds(8) });
  }
};

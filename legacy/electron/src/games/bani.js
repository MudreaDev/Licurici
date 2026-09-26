// Joc: Bani — câți lei sunt? Numără monedele/bancnotele (clasa 1-4).
import { MONEY } from '../data/school.js';
import { runLesson } from '../engine.js';
import { randInt, shuffle, pick } from '../ui.js';
import { tier } from '../difficulty.js';
import { numChoices } from './_math.js';

function coin(v) {
  const cls = v >= 10 ? 'coin bill' : v >= 5 ? 'coin c5' : 'coin c1';
  return `<span class="${cls}">${v}<small>lei</small></span>`;
}

function buildRounds(n = 6) {
  const t = tier();
  const nCoins = Math.min(2 + Math.floor(t / 2), 8);
  const values = t <= 2 ? [1, 5] : [1, 5, 10];
  const rounds = [];
  for (let i = 0; i < n; i++) {
    const coins = Array.from({ length: randInt(2, nCoins) }, () => pick(values));
    const total = coins.reduce((s, v) => s + v, 0);
    rounds.push({
      promptHtml: `<div class="prompt">Câți lei sunt?</div><div class="mathrow money">${coins.map(coin).join(' ')}</div>`,
      speak: 'Câți lei sunt?',
      cols: 3,
      hint: `În total sunt ${total} lei.`,
      choices: numChoices(total, 1, total + 10).map(v => ({ html: `<span class="big">${v}</span><span>lei</span>`, correct: v === total }))
    });
  }
  return rounds;
}

export default {
  id: 'bani', name: 'Bani', emoji: '🪙', desc: 'Numără leii', badge: 'Bani',
  start(mount, ctx) {
    runLesson(mount, ctx, { gameId: 'bani', title: '🪙 Bani', instruction: 'Câți lei sunt în total?', rounds: buildRounds(8) });
  }
};

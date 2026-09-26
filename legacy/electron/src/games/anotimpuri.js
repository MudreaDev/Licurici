// Joc: Anotimpuri — în ce anotimp se potrivește? (Științe / mediu)
import { SEASONS } from '../data/school.js';
import { runLesson } from '../engine.js';
import { pick, sample, shuffle } from '../ui.js';

function buildRounds(n = 6) {
  const rounds = [];
  for (let i = 0; i < n; i++) {
    const season = pick(SEASONS);
    const item = pick(season.items);
    const others = sample(SEASONS.filter(s => s.name !== season.name), 4);
    const opts = shuffle([season, ...others]);
    rounds.push({
      promptHtml: `<div class="prompt">În ce anotimp?</div><div class="hugeemoji">${item}</div>`,
      speak: 'În ce anotimp?',
      cols: 3,
      hint: `Aceasta e ${season.name}.`,
      choices: opts.map(o => ({ html: `<span class="big">${o.e}</span><span>${o.name}</span>`, correct: o.name === season.name }))
    });
  }
  return rounds;
}

export default {
  id: 'anotimpuri', name: 'Anotimpuri', emoji: '🍂', desc: 'Ce se potrivește fiecărui anotimp', badge: 'Științe',
  start(mount, ctx) {
    runLesson(mount, ctx, { gameId: 'anotimpuri', title: '🍂 Anotimpuri', instruction: 'În ce anotimp se potrivește?', rounds: buildRounds(6) });
  }
};

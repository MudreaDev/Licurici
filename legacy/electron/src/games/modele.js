// Joc: Modele — continuă șirul. Ce urmează? (gândire logică, atenție)
import { PATTERN_TOKENS } from '../data/content.js';
import { runLesson } from '../engine.js';
import { sample, shuffle, randInt } from '../ui.js';
import { store } from '../store.js';

function buildRounds(n = 6) {
  const hard = store.get('difficulty') === 'mediu';
  const rounds = [];
  for (let i = 0; i < n; i++) {
    // Model de tip AB, ABC sau AABB
    const kinds = hard ? ['AB', 'ABC', 'AABB'] : ['AB', 'AABB'];
    const kind = kinds[randInt(0, kinds.length - 1)];
    let unit;
    if (kind === 'AB') { const [a, b] = sample(PATTERN_TOKENS, 2); unit = [a, b]; }
    else if (kind === 'ABC') { const [a, b, c] = sample(PATTERN_TOKENS, 3); unit = [a, b, c]; }
    else { const [a, b] = sample(PATTERN_TOKENS, 2); unit = [a, a, b, b]; }

    // Construim șirul, ascundem ultimul element
    const reps = hard ? 2 : 2;
    let seq = [];
    for (let r = 0; r < reps; r++) seq = seq.concat(unit);
    seq = seq.concat(unit.slice(0, unit.length - 1)); // șir incomplet
    const answer = unit[unit.length - 1];

    const shown = seq.map(t => `<span>${t}</span>`).join(' ') + ' <span style="opacity:.4">❔</span>';
    const distract = sample(PATTERN_TOKENS.filter(t => t !== answer), 4);
    const opts = shuffle([answer, ...distract]);

    rounds.push({
      promptHtml: `<div class="prompt">Ce urmează?</div><div class="hugeemoji" style="font-size:56px">${shown}</div>`,
      speak: 'Ce urmează în șir?',
      cols: 3,
      hint: 'Uită-te la ordinea care se repetă.',
      choices: opts.map(o => ({ html: `<span class="big">${o}</span>`, correct: o === answer, speak: '' }))
    });
  }
  return rounds;
}

export default {
  id: 'modele',
  name: 'Modele',
  emoji: '🔁',
  desc: 'Continuă șirul care se repetă',
  badge: 'Logică',
  start(mount, ctx) {
    runLesson(mount, ctx, {
      gameId: 'modele',
      title: '🔁 Modele',
      instruction: 'Alege ce urmează în șir.',
      rounds: buildRounds(6)
    });
  }
};

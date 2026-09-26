// Joc: Alfabetul — recunoașterea literelor și a sunetului de început.
// Trei tipuri de întrebări, alese aleator → mereu variat:
//  A) obiect → cu ce literă începe
//  B) literă → alege obiectul care începe cu ea
//  C) literă MARE → găsește litera mică la fel
import { ALPHABET } from '../data/content.js';
import { runLesson } from '../engine.js';
import { shuffle, sample, pick } from '../ui.js';

// Litere unice (ALPHABET are câteva litere cu mai multe cuvinte-exemplu)
const LETTERS = [...new Set(ALPHABET.map(a => a.l))];

function buildRounds(n = 6) {
  const rounds = [];
  for (let i = 0; i < n; i++) {
    const kind = i % 3;
    const entry = pick(ALPHABET);

    if (kind === 0) {
      // obiect → literă
      const distract = sample(LETTERS.filter(l => l !== entry.l), 4);
      const opts = shuffle([entry.l, ...distract]);
      rounds.push({
        promptHtml: `<div class="prompt">Cu ce literă începe?</div><div class="hugeemoji">${entry.e}</div><div class="scene">${entry.w}</div>`,
        speak: `Cu ce literă începe ${entry.w}?`,
        cols: 3,
        hint: `„${entry.w}" începe cu litera ${entry.l}.`,
        choices: opts.map(l => ({ html: `<span class="big">${l}</span>`, correct: l === entry.l }))
      });
    } else if (kind === 1) {
      // literă → obiect
      const others = sample(ALPHABET.filter(a => a.l !== entry.l), 4);
      const opts = shuffle([entry, ...others]);
      rounds.push({
        promptHtml: `<div class="prompt">Alege obiectul care începe cu:</div><div class="hugeemoji">${entry.l}</div>`,
        speak: `Alege obiectul care începe cu litera ${entry.l}.`,
        cols: 3,
        hint: `${entry.e} „${entry.w}" începe cu ${entry.l}.`,
        choices: opts.map(o => ({ html: `<span class="big">${o.e}</span>`, correct: o.l === entry.l && o.w === entry.w }))
      });
    } else {
      // literă MARE → literă mică
      const low = entry.l.toLowerCase();
      const distract = sample(LETTERS.filter(l => l !== entry.l).map(l => l.toLowerCase()), 4);
      const opts = shuffle([low, ...distract]);
      rounds.push({
        promptHtml: `<div class="prompt">Găsește aceeași literă mică:</div><div class="hugeemoji">${entry.l}</div>`,
        speak: 'Găsește aceeași literă, dar mică.',
        cols: 3,
        hint: `Litera mică pentru ${entry.l} este ${low}.`,
        choices: opts.map(l => ({ html: `<span class="big">${l}</span>`, correct: l === low }))
      });
    }
  }
  return rounds;
}

export default {
  id: 'alfabetul',
  name: 'Alfabetul',
  emoji: '🔤',
  desc: 'Învață literele',
  badge: 'Litere',
  start(mount, ctx) {
    runLesson(mount, ctx, {
      gameId: 'alfabetul',
      title: '🔤 Alfabetul',
      instruction: 'Alege litera potrivită.',
      rounds: buildRounds(6)
    });
  }
};

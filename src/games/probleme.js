// Joc: Probleme cu text — mică problemă în cuvinte, alegi răspunsul (clasa 2-4).
// Operația și mărimea numerelor cresc cu tier-ul: la început adunare/scădere mici,
// mai adânc apar și înmulțirea și numere mai mari. Motorul (engine.js) scalează
// automat câte variante se arată.
import { runLesson } from '../engine.js';
import { pick, randInt } from '../ui.js';
import { tier } from '../difficulty.js';
import { numChoices } from './_math.js';

const NAMES = ['Ana', 'Dan', 'Maria', 'Andrei', 'Ioana', 'Radu', 'Elena', 'Mihai'];
const ITEMS = [
  { w: 'mere', e: '🍎' }, { w: 'baloane', e: '🎈' }, { w: 'flori', e: '🌸' },
  { w: 'mașinuțe', e: '🚗' }, { w: 'căpșuni', e: '🍓' }, { w: 'cireșe', e: '🍒' },
  { w: 'steluțe', e: '⭐' }, { w: 'pisici', e: '🐱' }, { w: 'peștișori', e: '🐟' }
];

function buildRounds(n = 6) {
  const t = tier();
  const cap = Math.min(10 + t * 8, 100);
  const rounds = [];
  for (let i = 0; i < n; i++) {
    const name = pick(NAMES);
    const it = pick(ITEMS);
    const kinds = t >= 3 ? ['add', 'sub', 'mul'] : ['add', 'sub'];
    const kind = kinds[i % kinds.length];   // variem operațiile în cadrul lecției
    let text, ans, hint;

    if (kind === 'add') {
      const a = randInt(2, Math.max(3, Math.round(cap * 0.6)));
      const b = randInt(1, Math.max(2, Math.round(cap * 0.4)));
      ans = a + b;
      text = `${name} are ${a} ${it.w} ${it.e} și mai primește ${b}. Câte ${it.w} are acum?`;
      hint = `${a} plus ${b} fac ${ans}.`;
    } else if (kind === 'sub') {
      const a = randInt(3, Math.max(4, cap));
      const b = randInt(1, a - 1);
      ans = a - b;
      text = `${name} are ${a} ${it.w} ${it.e} și dăruiește ${b}. Câte îi rămân?`;
      hint = `${a} minus ${b} fac ${ans}.`;
    } else {
      const groups = randInt(2, Math.min(2 + t, 6));
      const per = randInt(2, Math.min(2 + t, 9));
      ans = groups * per;
      text = `${groups} copii au fiecare ${per} ${it.w} ${it.e}. Câte ${it.w} sunt în total?`;
      hint = `${groups} ori ${per} fac ${ans}.`;
    }

    rounds.push({
      promptHtml: `<div class="prompt">Rezolvă problema 🤔</div><div class="scene">${text}</div>`,
      speak: 'Citește problema și alege răspunsul.',
      hint,
      choices: numChoices(ans, Math.max(0, ans - 10), ans + 12).map(v => ({
        html: `<span class="big">${v}</span>`, correct: v === ans
      }))
    });
  }
  return rounds;
}

export default {
  id: 'probleme',
  name: 'Probleme',
  emoji: '💡',
  desc: 'Probleme cu text — gândește și alege',
  badge: 'Matematică',
  start(mount, ctx) {
    runLesson(mount, ctx, {
      gameId: 'probleme',
      title: '💡 Probleme',
      instruction: 'Citește problema și alege răspunsul.',
      rounds: buildRounds(6)
    });
  }
};

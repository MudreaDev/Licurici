// Motorul de lecție „alege răspunsul corect".
// Aplică principii dovedite:
//  - Recompensă imediată la răspuns corect (<1s), plus laudă pentru efort.
//  - Fără pedeapsă la greșeală: nu blocăm, nu marcăm cu roșu alarmant.
//  - Învățare fără eroare: după greșeli, evidențiem tot mai mult răspunsul corect
//    și estompăm distractorii, ca fiecare încercare să se termine cu succes.
//  - O singură sarcină pe ecran, ținte mari, instrucțiune citită cu voce.
import { el, clear, speak, speakSeq, celebrate, shuffle } from './ui.js';
import { fireflySVG } from './mascot.js';
import { optionCount, roundCount } from './difficulty.js';

// Coloane potrivite pentru numărul de variante afișate (grilă echilibrată).
function colsFor(n) { return n <= 2 ? 2 : n === 4 ? 2 : 3; }

// Rostește un rund: fie o secvență de clipuri (ex. ecuație), fie un singur text.
function sayRound(r, fallback) {
  if (r.speakSeq && r.speakSeq.length) speakSeq(r.speakSeq);
  else speak(r.speak || fallback || '');
}
import { sfx } from './audio.js';
import { store } from './store.js';

const PRAISE = ['Bravo! 🌟', 'Foarte bine! 💚', 'Excelent! ✨', 'Ai reușit! 🎉', 'Super! 👏', 'Perfect! 🌈'];
const GENTLE = ['Mai încearcă 🙂', 'Aproape! Încearcă alta', 'Nu-i nimic, mai încearcă'];

// spec: { title, instruction, rounds: [ {promptHtml, speak, choices:[{html,correct,speak}], cols, hint} ] }
export function runLesson(mount, ctx, spec) {
  // Scalare universală a dificultății: câte runde arătăm (mai puține la început).
  // Jocurile care au nevoie de toate rundele pot cere spec.fixedRounds.
  const roundN = roundCount();
  const rounds = spec.fixedRounds
    ? spec.rounds
    : spec.rounds.slice(0, Math.min(spec.rounds.length, roundN));
  let idx = 0;
  let perfectCount = 0;   // câte întrebări nimerite din prima

  const screen = el('div', { class: 'screen' });
  mount.appendChild(screen);

  function renderProgress() {
    const dots = el('div', { class: 'progress-dots' });
    rounds.forEach((_, i) => {
      dots.appendChild(el('div', {
        class: 'dot ' + (i < idx ? 'done' : i === idx ? 'active' : '')
      }));
    });
    return dots;
  }

  function renderRound() {
    clear(screen);
    const r = rounds[idx];
    let attempts = 0;
    let solved = false;

    // Scalare universală: arătăm optionCount() variante (mai multe = mai greu, cu
    // cât nivelul e mai adânc). Păstrăm mereu răspunsul corect + distractori aleși
    // aleator. Jocurile al căror text presupune un număr fix de variante (ex. „trei
    // sunt la fel") cer spec.fixedChoices / r.fixedChoices ca să nu fie tăiate.
    const optN = optionCount();
    let choices = r.choices;
    if (!spec.fixedChoices && !r.fixedChoices && choices.length > optN) {
      const correct = choices.filter(c => c.correct);
      const wrong = shuffle(choices.filter(c => !c.correct)).slice(0, Math.max(1, optN - correct.length));
      choices = shuffle([...correct, ...wrong]);
    }

    screen.appendChild(el('h1', { text: spec.title }));
    if (spec.instruction) {
      screen.appendChild(el('p', { class: 'lead', text: spec.instruction }));
    }
    screen.appendChild(renderProgress());

    // Stimulul (întrebarea) + buton de recitire
    const stim = el('div', { class: 'stimulus', html: r.promptHtml });
    const replay = el('button', {
      class: 'iconbtn', title: 'Citește din nou', 'aria-label': 'Citește din nou',
      onclick: () => sayRound(r)
    }, '🔊');
    replay.style.marginTop = '14px';
    stim.appendChild(replay);
    screen.appendChild(stim);

    const feedback = el('div', { class: 'feedback' });

    // Butoanele de răspuns (numărul de coloane se potrivește câte variante afișăm)
    const cols = colsFor(choices.length);
    const wrap = el('div', { class: 'answers cols-' + cols });
    const buttons = [];
    choices.forEach((c) => {
      const b = el('button', {
        class: 'choice', html: c.html,
        onclick: () => onChoose(c, b)
      });
      buttons.push(b);
      wrap.appendChild(b);
    });

    screen.appendChild(wrap);
    screen.appendChild(feedback);

    // Citește instrucțiunea/întrebarea automat
    sayRound(r, spec.instruction);

    function fadeDistractors(strong) {
      buttons.forEach((b, i) => {
        if (!choices[i].correct) b.classList.toggle('dimmed', true);
      });
      if (strong) {
        const ci = choices.findIndex(c => c.correct);
        if (ci >= 0) buttons[ci].classList.add('hint-correct');
      }
    }

    function onChoose(choice, btn) {
      if (solved) return;
      if (choice.correct) {
        solved = true;
        if (attempts === 0) perfectCount++;
        btn.classList.remove('dimmed');
        btn.classList.add('correct');
        buttons.forEach(b => { b.disabled = true; });
        sfx.good();
        feedback.className = 'feedback good';
        feedback.textContent = PRAISE[Math.floor(Math.random() * PRAISE.length)];
        speak('Bravo');
        setTimeout(next, 1100);
      } else {
        // Greșeală: blând, fără pedeapsă. Ajutăm tot mai mult.
        attempts++;
        sfx.gentle();
        btn.classList.add('tryagain');
        setTimeout(() => btn.classList.remove('tryagain'), 600);
        feedback.className = 'feedback gentle';
        feedback.textContent = r.hint && attempts >= 1
          ? r.hint
          : GENTLE[Math.min(attempts - 1, GENTLE.length - 1)];
        if (attempts === 1) speak('Mai încearcă');
        // Învățare fără eroare: estompăm distractorii, apoi arătăm clar corectul.
        if (attempts >= 1) fadeDistractors(attempts >= 2);
      }
    }
  }

  function next() {
    idx++;
    if (idx >= rounds.length) return finish();
    renderRound();
  }

  function finish() {
    clear(screen);
    store.markPlayed(spec.gameId || 'joc');
    // Steluțe: generos, dar răsplătește și acuratețea din prima.
    const earned = 1 + Math.round((perfectCount / rounds.length) * 2); // 1..3
    store.addStars(earned);
    store.recordStat(spec.gameId || 'joc', { correct: perfectCount, total: rounds.length, stars: earned });
    celebrate();

    const box = el('div', { class: 'finish' });
    box.appendChild(el('div', { class: 'finish-mascot', html: fireflySVG(110, true) }));
    box.appendChild(el('div', { class: 'bigstars', text: '⭐'.repeat(earned) }));
    box.appendChild(el('h2', { text: 'Ai terminat! 🎉' }));
    box.appendChild(el('p', {
      class: 'lead',
      text: `Ai răspuns corect la ${perfectCount} din ${rounds.length} din prima. Ai câștigat ${earned} ${earned === 1 ? 'steluță' : 'steluțe'}.`
    }));
    speak('Ai terminat! Bravo!');

    const row = el('div', { class: 'row' });
    if (ctx.level) {
      if (ctx.onComplete) ctx.onComplete(earned);
      row.appendChild(el('button', { class: 'btn', onclick: () => ctx.next() }, '➡️ Următorul'));
      row.appendChild(el('button', { class: 'btn ghost', onclick: () => ctx.restart() }, '🔁 Din nou'));
      row.appendChild(el('button', { class: 'btn mint', onclick: () => ctx.goMap() }, '🗺️ Hartă'));
    } else {
      row.appendChild(el('button', { class: 'btn', onclick: () => ctx.restart() }, '🔁 Încă o dată'));
      row.appendChild(el('button', { class: 'btn mint', onclick: () => ctx.goHome() }, '🏠 Alt joc'));
    }
    box.appendChild(row);
    screen.appendChild(box);
  }

  renderRound();
}

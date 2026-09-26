// Joc: Ce urmează? — pune pașii rutinei în ordine (funcții executive, independență).
// Interacțiune fără eroare: accept doar pasul corect următor; la greșeală, indiciu blând.
import { ROUTINES } from '../data/content.js';
import { el, clear, speak, shuffle, pick, showFinish } from '../ui.js';
import { sfx } from '../audio.js';
import { store } from '../store.js';

export default {
  id: 'secventa',
  name: 'Ce urmează?',
  emoji: '📋',
  desc: 'Pune pașii în ordinea corectă',
  badge: 'Ordine',
  start(mount, ctx) {
    const routine = pick(ROUTINES);
    const steps = routine.steps;           // ordinea corectă
    const pool = shuffle(steps.map((s, i) => ({ ...s, order: i })));
    let nextExpected = 0;

    const screen = el('div', { class: 'screen' });
    mount.appendChild(screen);
    screen.appendChild(el('h1', { text: '📋 Ce urmează?' }));
    screen.appendChild(el('p', { class: 'lead', text: `Pune pașii în ordine: ${routine.name}` }));
    speak(`Pune pașii în ordine. ${routine.name}`);

    // Rândul rezultat (ordinea construită)
    const seqRow = el('div', { class: 'seq-row' });
    // Sloturi goale, numerotate
    const slots = steps.map((_, i) => {
      const slot = el('div', { class: 'seq-slot' }, el('span', { class: 'num', text: String(i + 1) }));
      seqRow.appendChild(slot);
      return slot;
    });
    screen.appendChild(seqRow);

    const feedback = el('div', { class: 'feedback' });
    screen.appendChild(feedback);

    // Bazinul de pași amestecați
    const poolWrap = el('div', { class: 'pool' });
    screen.appendChild(poolWrap);

    pool.forEach(step => {
      const card = el('button', { class: 'step-card' },
        el('div', { class: 'step-emoji', text: step.emoji }),
        el('div', { class: 'step-txt', text: step.t })
      );
      card.addEventListener('click', () => choose(step, card));
      poolWrap.appendChild(card);
    });

    function choose(step, card) {
      if (card.disabled) return;
      if (step.order === nextExpected) {
        sfx.good();
        card.disabled = true;
        card.classList.add('placed');
        // Mută în slot
        const slot = slots[nextExpected];
        clear(slot);
        slot.classList.add('filled');
        slot.appendChild(el('div', { class: 'step-emoji', text: step.emoji }));
        slot.appendChild(el('div', { class: 'step-txt', text: step.t }));
        nextExpected++;
        feedback.className = 'feedback good';
        feedback.textContent = 'Bravo! 🌟';
        if (nextExpected >= steps.length) {
          setTimeout(() => showFinish(screen, ctx, {
            stars: 3, message: 'Ordine perfectă! 🎉', sub: routine.name, gameId: 'secventa'
          }), 800);
          store.markPlayed('secventa'); store.addStars(3);
        }
      } else {
        sfx.gentle();
        card.classList.add('shake');
        setTimeout(() => card.classList.remove('shake'), 500);
        feedback.className = 'feedback gentle';
        const want = steps[nextExpected];
        feedback.textContent = `Întâi: ${want.t}`;
        speak(`Întâi ${want.t}`);
      }
    }
  }
};

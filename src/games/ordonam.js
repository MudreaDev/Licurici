// Joc: În ordine — pune numerele de la mic la mare (tap în ordine crescătoare).
// Fără eroare: accept doar numărul corect următor; la greșeală, indiciu blând.
import { el, clear, speak, shuffle, showFinish } from '../ui.js';
import { sfx } from '../audio.js';
import { store } from '../store.js';

export default {
  id: 'ordonam',
  name: 'În ordine',
  emoji: '🔢',
  desc: 'Numerele de la mic la mare',
  badge: 'Numere',
  start(mount, ctx) {
    const N = store.get('difficulty') === 'mediu' ? 6 : 5;
    const nums = Array.from({ length: N }, (_, i) => i + 1);
    const pool = shuffle(nums);
    let next = 1;

    const screen = el('div', { class: 'screen' });
    mount.appendChild(screen);
    screen.appendChild(el('h1', { text: '🔢 În ordine' }));
    screen.appendChild(el('p', { class: 'lead', text: 'Atinge numerele de la mic la mare.' }));
    speak('Atinge numerele de la mic la mare.');

    const slotRow = el('div', { class: 'seq-row' });
    const slots = nums.map((_, i) => {
      const s = el('div', { class: 'seq-slot num-slot' }, el('span', { class: 'num', text: String(i + 1) }));
      slotRow.appendChild(s);
      return s;
    });
    screen.appendChild(slotRow);

    const feedback = el('div', { class: 'feedback' });
    screen.appendChild(feedback);

    const poolWrap = el('div', { class: 'pool' });
    screen.appendChild(poolWrap);

    pool.forEach(v => {
      const card = el('button', { class: 'numtile' }, el('span', { class: 'big', text: String(v) }));
      card.addEventListener('click', () => choose(v, card));
      poolWrap.appendChild(card);
    });

    function choose(v, card) {
      if (card.disabled) return;
      if (v === next) {
        sfx.good();
        card.disabled = true; card.classList.add('placed');
        const slot = slots[next - 1];
        clear(slot); slot.classList.add('filled');
        slot.appendChild(el('span', { class: 'big', text: String(v) }));
        next++;
        feedback.className = 'feedback good';
        feedback.textContent = 'Bravo! 🌟';
        if (next > N) {
          store.markPlayed('ordonam'); store.addStars(3);
          setTimeout(() => showFinish(screen, ctx, { stars: 3, message: 'Ordine perfectă! 🎉', gameId: 'ordonam' }), 700);
        }
      } else {
        sfx.gentle();
        card.classList.add('shake');
        setTimeout(() => card.classList.remove('shake'), 500);
        feedback.className = 'feedback gentle';
        feedback.textContent = `Urmează: ${next}`;
        speak(String(next));
      }
    }
  }
};

// Joc: Perechi — memorie clasică. Întoarce câte două cărți și găsește perechile.
import { MATCH_ITEMS } from '../data/content.js';
import { el, clear, speak, sample, shuffle, showFinish } from '../ui.js';
import { sfx } from '../audio.js';
import { store } from '../store.js';

export default {
  id: 'perechi',
  name: 'Perechi',
  emoji: '🃏',
  desc: 'Găsește perechile la fel',
  badge: 'Memorie',
  start(mount, ctx) {
    const pairs = store.get('difficulty') === 'mediu' ? 6 : 3;
    const chosen = sample(MATCH_ITEMS, pairs);
    const deck = shuffle([...chosen, ...chosen].map((e, i) => ({ e, id: i })));

    let first = null;     // {card, e}
    let lock = false;
    let found = 0;
    let timer = null;

    const screen = el('div', { class: 'screen' });
    mount.appendChild(screen);
    screen.appendChild(el('h1', { text: '🃏 Perechi' }));
    screen.appendChild(el('p', { class: 'lead', text: 'Întoarce câte două cărți și găsește perechile la fel.' }));
    speak('Găsește perechile la fel.');

    const feedback = el('div', { class: 'feedback' });

    const board = el('div', { class: 'pairs pairs-' + pairs });
    deck.forEach(item => {
      const card = el('button', { class: 'pcard' },
        el('span', { class: 'pback', text: '✨' }),
        el('span', { class: 'pface', text: item.e })
      );
      card.addEventListener('click', () => flip(item, card));
      board.appendChild(card);
    });
    screen.appendChild(board);
    screen.appendChild(feedback);

    function flip(item, card) {
      if (lock || card.classList.contains('open') || card.classList.contains('matched')) return;
      card.classList.add('open');
      sfx.tap();
      if (!first) { first = { item, card }; return; }
      // a doua carte
      if (first.item.e === item.e && first.item.id !== item.id) {
        // pereche!
        sfx.good();
        first.card.classList.add('matched');
        card.classList.add('matched');
        feedback.className = 'feedback good'; feedback.textContent = 'Pereche! 🌟';
        first = null;
        found++;
        if (found >= pairs) {
          store.markPlayed('perechi'); store.addStars(3);
          setTimeout(() => showFinish(screen, ctx, { stars: 3, message: 'Le-ai găsit pe toate! 🎉', gameId: 'perechi' }), 700);
        }
      } else {
        // nu se potrivesc — le întoarcem la loc
        lock = true;
        feedback.className = 'feedback gentle'; feedback.textContent = 'Mai încearcă 🙂';
        const a = first.card, b = card;
        first = null;
        timer = setTimeout(() => {
          a.classList.remove('open'); b.classList.remove('open');
          lock = false;
        }, 900);
      }
    }

    // curăță timer-ul dacă utilizatorul pleacă
    ctx.setCleanup(() => { if (timer) clearTimeout(timer); });
  }
};

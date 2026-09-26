// Joc: Memorie — privește șirul de pătrate care se aprind, apoi repetă-l.
// (memorie de lucru). Blând: la greșeală NU se termină — arătăm din nou și reîncerci.
import { el, clear, speak, showFinish } from '../ui.js';
import { sfx } from '../audio.js';
import { store } from '../store.js';

const TILES = [
  { key: 0, color: '#7fc0a3', emoji: '🟢', freq: 392.00 },
  { key: 1, color: '#5b9bb5', emoji: '🔵', freq: 523.25 },
  { key: 2, color: '#f2cf6b', emoji: '🟡', freq: 659.25 },
  { key: 3, color: '#a9a3d1', emoji: '🟣', freq: 783.99 }
];

export default {
  id: 'memorie',
  name: 'Memorie',
  emoji: '🧠',
  desc: 'Ține minte șirul și repetă-l',
  badge: 'Memorie',
  start(mount, ctx) {
    const startLen = store.get('difficulty') === 'mediu' ? 3 : 2;
    const targetLevels = 4;          // câte niveluri pentru a termina
    let level = 0;
    let sequence = [];
    let inputPos = 0;
    let accepting = false;

    const screen = el('div', { class: 'screen' });
    mount.appendChild(screen);
    screen.appendChild(el('h1', { text: '🧠 Memorie' }));
    const lead = el('p', { class: 'lead', text: 'Privește cu atenție…' });
    screen.appendChild(lead);

    const board = el('div', { class: 'simon' });
    const tileEls = TILES.map(t => {
      const d = el('button', { class: 'simon-tile', 'aria-label': 'pătrat' });
      d.style.background = t.color;
      d.textContent = t.emoji;
      d.addEventListener('click', () => onTap(t));
      board.appendChild(d);
      return d;
    });
    screen.appendChild(board);

    const feedback = el('div', { class: 'feedback' });
    screen.appendChild(feedback);

    function flash(tile) {
      const dEl = tileEls[tile.key];
      dEl.classList.add('lit');
      sfx.note(tile.freq);
      setTimeout(() => dEl.classList.remove('lit'), 420);
    }

    function nextLevel() {
      level++;
      if (level > targetLevels) {
        store.markPlayed('memorie'); store.addStars(3);
        return showFinish(screen, ctx, { stars: 3, message: 'Memorie de campion! 🎉', sub: `Ai ținut minte ${sequence.length} pași.`, gameId: 'memorie' });
      }
      // Adaugă un pas nou aleator
      sequence.push(TILES[Math.floor(Math.random() * TILES.length)]);
      // La primul nivel pornim direct cu lungimea de start
      while (sequence.length < startLen) sequence.push(TILES[Math.floor(Math.random() * TILES.length)]);
      playSequence();
    }

    function playSequence() {
      accepting = false;
      inputPos = 0;
      lead.textContent = 'Privește cu atenție…';
      feedback.textContent = '';
      let i = 0;
      const iv = setInterval(() => {
        if (i >= sequence.length) {
          clearInterval(iv);
          setTimeout(() => {
            accepting = true;
            lead.textContent = 'Acum e rândul tău! Repetă șirul.';
            speak('Acum e rândul tău');
          }, 300);
          return;
        }
        flash(sequence[i]);
        i++;
      }, 720);
    }

    function onTap(tile) {
      if (!accepting) return;
      flash(tile);
      if (tile.key === sequence[inputPos].key) {
        inputPos++;
        if (inputPos >= sequence.length) {
          accepting = false;
          feedback.className = 'feedback good';
          feedback.textContent = 'Bravo! 🌟';
          sfx.good();
          setTimeout(nextLevel, 900);
        }
      } else {
        // Blând: nu pierzi. Arătăm din nou.
        accepting = false;
        feedback.className = 'feedback gentle';
        feedback.textContent = 'Hai să privim din nou 🙂';
        speak('Hai să privim din nou');
        setTimeout(playSequence, 1100);
      }
    }

    nextLevel();
  }
};

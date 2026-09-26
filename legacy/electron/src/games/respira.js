// „Joc": Respiră — colț de liniște / autoreglare (inspirat de Zones of Regulation).
// Fără scor, fără presiune. Cerc care crește la inspir și scade la expir, cu text.
import { el, clear, speak } from '../ui.js';
import { store } from '../store.js';

export default {
  id: 'respira',
  name: 'Respiră',
  emoji: '🫧',
  desc: 'Un moment de liniște și calm',
  badge: 'Calm',
  start(mount, ctx) {
    const screen = el('div', { class: 'screen' });
    mount.appendChild(screen);

    const wrap = el('div', { class: 'breathe-wrap' });
    screen.appendChild(wrap);

    wrap.appendChild(el('h1', { text: '🫧 Respiră' }));
    const instr = el('div', { class: 'breathe-instruction', text: 'Apasă „Start" și respiră cu mine.' });
    const circle = el('div', { class: 'breathe-circle', text: '🫧' });
    wrap.appendChild(circle);
    wrap.appendChild(instr);

    const startBtn = el('button', { class: 'btn' }, '▶️ Start');
    const stopBtn = el('button', { class: 'btn ghost' }, '⏹️ Gata');
    const row = el('div', { class: 'row' }, startBtn, stopBtn);
    wrap.appendChild(row);

    let timers = [];
    let running = false;

    function clearTimers() { timers.forEach(t => clearTimeout(t)); timers = []; }

    // Un ciclu: Inspiră (4s, crește) → Ține (2s) → Expiră (4s, scade).
    function cycle() {
      if (!running) return;
      instr.textContent = 'Inspiră… 🌬️';
      speak('Inspiră');
      circle.style.transition = 'transform 4s ease-in-out';
      circle.style.transform = 'scale(1.6)';
      timers.push(setTimeout(() => {
        if (!running) return;
        instr.textContent = 'Ține… 😌';
        speak('Ține');
        timers.push(setTimeout(() => {
          if (!running) return;
          instr.textContent = 'Expiră… 😮‍💨';
          speak('Expiră');
          circle.style.transition = 'transform 4s ease-in-out';
          circle.style.transform = 'scale(1)';
          timers.push(setTimeout(cycle, 4200));
        }, 2000));
      }, 4200));
    }

    startBtn.addEventListener('click', () => {
      if (running) return;
      running = true;
      cycle();
    });
    stopBtn.addEventListener('click', () => { stop(); ctx.goHome(); });

    function stop() {
      running = false;
      clearTimers();
      circle.style.transform = 'scale(1)';
    }

    // Oprește animația/vocea dacă utilizatorul pleacă din ecran.
    ctx.setCleanup(stop);
  }
};

// Mecanica REUTILIZABILĂ „trage-și-plasează" — folosită în episoadele de explorat
// și în jocuri de sortare. Cu pointer events (merge la mouse și touch).
//
// Principii (prietenos cu autismul, ca tot restul aplicației):
//  - Fără pedeapsă: o plasare greșită se întoarce blând înapoi, nu se marchează cu roșu.
//  - Ținte MARI, o singură sarcină pe ecran, recompensă imediată la potrivire corectă.
//  - Învățare fără eroare: după câteva încercări, coșul corect „respiră" ca indiciu.
import { el, clear, speak, shuffle, showFinish } from './ui.js';
import { sfx } from './audio.js';
import { store } from './store.js';

// spec: {
//   zones: [{ id, name, emoji }],          // coșurile (ținte)
//   items: [{ emoji, zone, label? }],      // piesele de tras (zone = id-ul coșului corect)
//   speak?: text,                          // instrucțiune rostită
//   onSolvedAll: fn                        // apelat când toate piesele sunt la locul lor
// }
// Întoarce elementul rădăcină (îl adaugi în scenă). Curăță singur listenerii globali
// prin closure-uri legate de element (nimic global persistent).
export function makeDragDrop(spec) {
  const root = el('div', { class: 'dd' });

  // ---- Coșurile (ținte) ----
  const zonesRow = el('div', { class: 'dd-zones' });
  const zoneEls = {};
  const missCount = {};
  spec.zones.forEach(z => {
    missCount[z.id] = 0;
    const zEl = el('div', { class: 'dd-zone', 'data-zone': z.id },
      el('div', { class: 'dz-emoji', text: z.emoji }),
      el('div', { class: 'dz-name', text: z.name }),
      el('div', { class: 'dz-drop' })   // aici „aterizează" piesele potrivite
    );
    zoneEls[z.id] = zEl;
    zonesRow.appendChild(zEl);
  });

  // ---- Tava cu piese ----
  const tray = el('div', { class: 'dd-tray' });
  let remaining = spec.items.length;

  shuffle(spec.items).forEach((it) => {
    const piece = el('div', {
      class: 'dd-piece', tabindex: '0', role: 'button',
      'aria-label': it.label || 'piesă'
    },
      el('span', { class: 'dp-emoji', text: it.emoji }),
      it.label ? el('span', { class: 'dp-label', text: it.label }) : null
    );
    piece._item = it;
    tray.appendChild(piece);
    attachDrag(piece);
  });

  root.appendChild(zonesRow);
  root.appendChild(tray);

  // ---- Logica de tragere (pointer events) ----
  function attachDrag(piece) {
    let dragging = false, ghost = null, startX = 0, startY = 0, done = false;

    const onDown = (e) => {
      if (done) return;
      e.preventDefault();
      dragging = true;
      const r = piece.getBoundingClientRect();
      startX = e.clientX; startY = e.clientY;
      ghost = piece.cloneNode(true);
      ghost.classList.add('dd-ghost');
      ghost.style.width = r.width + 'px';
      ghost.style.height = r.height + 'px';
      ghost.style.left = r.left + 'px';
      ghost.style.top = r.top + 'px';
      document.body.appendChild(ghost);
      piece.classList.add('grabbing');
      sfx.tap();
      window.addEventListener('pointermove', onMove);
      window.addEventListener('pointerup', onUp);
    };

    const onMove = (e) => {
      if (!dragging) return;
      ghost.style.transform = `translate(${e.clientX - startX}px, ${e.clientY - startY}px) scale(1.06)`;
      const z = zoneUnder(e.clientX, e.clientY);
      Object.values(zoneEls).forEach(el => el.classList.remove('over'));
      if (z) zoneEls[z].classList.add('over');
    };

    const onUp = (e) => {
      if (!dragging) return;
      dragging = false;
      window.removeEventListener('pointermove', onMove);
      window.removeEventListener('pointerup', onUp);
      piece.classList.remove('grabbing');
      Object.values(zoneEls).forEach(el => el.classList.remove('over'));
      const target = zoneUnder(e.clientX, e.clientY);
      if (ghost) { ghost.remove(); ghost = null; }
      if (target && target === piece._item.zone) {
        landCorrect(piece, target);
        done = true;
      } else if (target) {
        wrongDrop(piece, target);
      }
      // fără țintă → piesa rămâne în tavă (ghost dispărut = revine vizual)
    };

    piece.addEventListener('pointerdown', onDown);
    // Accesibilitate: Enter/Space plasează în primul coș liber corect (fără mouse).
    piece.addEventListener('keydown', (ev) => {
      if (done) return;
      if (ev.key === 'Enter' || ev.key === ' ') { ev.preventDefault(); landCorrect(piece, piece._item.zone); done = true; }
    });
  }

  // Ce coș se află sub punctul (x,y)?
  function zoneUnder(x, y) {
    for (const z of spec.zones) {
      const r = zoneEls[z.id].getBoundingClientRect();
      if (x >= r.left && x <= r.right && y >= r.top && y <= r.bottom) return z.id;
    }
    return null;
  }

  function landCorrect(piece, zoneId) {
    sfx.good();
    piece.classList.add('placed');
    piece.style.pointerEvents = 'none';
    const slot = zoneEls[zoneId].querySelector('.dz-drop');
    const mini = el('span', { class: 'dz-item', text: piece._item.emoji });
    slot.appendChild(mini);
    zoneEls[zoneId].classList.add('pulse');
    setTimeout(() => zoneEls[zoneId].classList.remove('pulse'), 500);
    // scoate piesa din tavă cu o mică animație
    piece.classList.add('vanish');
    setTimeout(() => piece.remove(), 260);
    // NU rostim la fiecare piesă (ar suprapune vocile) — doar clinchetul; lauda vine la final.
    remaining--;
    if (remaining <= 0) setTimeout(() => spec.onSolvedAll && spec.onSolvedAll(), 600);
  }

  function wrongDrop(piece, zoneId) {
    sfx.gentle();
    piece.classList.add('bounce');
    setTimeout(() => piece.classList.remove('bounce'), 500);
    // Învățare fără eroare: după 2 greșeli, coșul CORECT „respiră" ca indiciu.
    missCount[piece._item.zone] = (missCount[piece._item.zone] || 0) + 1;
    if (missCount[piece._item.zone] >= 2) {
      zoneEls[piece._item.zone].classList.add('hint');
    }
  }

  return root;
}

// Joc de sine stătător construit pe mecanica trage-și-plasează: un ecran cu titlu +
// instrucțiune + coșuri + tavă; când toate piesele sunt la locul lor → ecran de final
// cu steluțe. Errorless prin design (piesa greșită revine), deci acordăm 3 steluțe.
// spec: { gameId, title, instruction, speak?, zones, items }
export function runDragGame(mount, ctx, spec) {
  const screen = el('div', { class: 'screen' });
  mount.appendChild(screen);

  screen.appendChild(el('h1', { text: spec.title }));
  screen.appendChild(el('p', { class: 'lead', text: spec.instruction }));

  const dd = makeDragDrop({
    zones: spec.zones,
    items: spec.items,
    onSolvedAll: () => {
      const stars = 3;
      store.markPlayed(spec.gameId);
      store.addStars(stars);
      showFinish(screen, ctx, { stars, gameId: spec.gameId, message: 'Ai grupat totul! 🎉' });
    }
  });
  screen.appendChild(dd);
  speak(spec.speak || spec.instruction);
}

// Joc: Grupăm — trage fiecare lucru în grupa lui (categorii). Joc de sine stătător
// construit pe mecanica trage-și-plasează (dragdrop.js). Scalează cu tier-ul:
// mai multe grupe și mai multe obiecte cu cât dificultatea e mai mare.
import { CATEGORIES } from '../data/content.js';
import { runDragGame } from '../dragdrop.js';
import { sample } from '../ui.js';
import { tier } from '../difficulty.js';

function build() {
  const t = tier();
  const nZones = Math.min(2 + Math.floor(t / 2), 4);   // 2 → 4 grupe
  const perZone = t >= 4 ? 3 : 2;                        // 2 → 3 obiecte pe grupă
  const cats = sample(CATEGORIES, nZones);
  const zones = cats.map(c => ({ id: c.name, name: c.name, emoji: c.emoji }));
  const items = [];
  cats.forEach(c => sample(c.items, perZone).forEach(e => items.push({ emoji: e, zone: c.name })));
  return { zones, items };
}

export default {
  id: 'grupam',
  name: 'Grupăm',
  emoji: '📦',
  desc: 'Trage fiecare lucru în grupa lui',
  badge: 'Logică',
  start(mount, ctx) {
    const { zones, items } = build();
    runDragGame(mount, ctx, {
      gameId: 'grupam',
      title: '📦 Grupăm',
      instruction: 'Trage fiecare lucru în grupa potrivită.',
      zones, items
    });
  }
};

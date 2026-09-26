// Motorul EPISOADELOR DE EXPLORAT (stil „Autobuzul magic"): o hartă ilustrată cu opriri;
// atingi o oprire, intri într-o scenă și rezolvi o provocare (trage-și-plasează) dintr-o
// mică poveste. Când toate opririle sunt gata → sărbătoare + steluțe.
//
// Prietenos cu autismul: explorare liberă (orice ordine), o sarcină pe ecran, ținte mari,
// fără pedeapsă, întoarcere clară la hartă, narațiune blândă cu voce.
import { el, clear, speak, celebrate } from './ui.js';
import { sfx } from './audio.js';
import { store } from './store.js';
import { fireflySVG } from './mascot.js';
import { sceneSVG } from './scenes.js';
import { makeDragDrop } from './dragdrop.js';

// ep: { id, title, lead, stops: [ {id, name, emoji, x, y, scene, intro, dd:{zones,items}} ], outro }
export function runEpisode(mount, ctx, ep) {
  const solved = new Set();

  const wrap = el('div', { class: 'episode' });
  mount.appendChild(wrap);

  function bg(sceneName) {
    return el('div', { class: 'scene-bg', html: sceneSVG(sceneName) });
  }

  // ---------- Harta (overworld) ----------
  const mapScene = ep.mapScene || 'harta';

  function renderMap() {
    clear(wrap);
    const stage = el('div', { class: 'episode-stage' });
    stage.appendChild(bg(mapScene));

    // Bandă de poveste sus (mascota + titlu).
    stage.appendChild(el('div', { class: 'ep-top' },
      el('span', { class: 'ep-mascot', html: fireflySVG(52, true) }),
      el('span', { class: 'ep-title', text: ep.title })
    ));

    // Pinii opririlor, așezați pe hartă.
    ep.stops.forEach((s, i) => {
      const isDone = solved.has(s.id);
      const pin = el('button', {
        class: 'map-pin' + (isDone ? ' done' : ''),
        style: `left:${s.x}%; top:${s.y}%`,
        title: s.name
      },
        el('span', { class: 'mp-num', text: isDone ? '✓' : String(i + 1) }),
        el('span', { class: 'mp-emoji', text: s.emoji }),
        el('span', { class: 'mp-name', text: s.name })
      );
      pin.addEventListener('click', () => { sfx.tap(); openStop(s); });
      stage.appendChild(pin);
    });

    // Indiciu jos: câte opriri mai sunt.
    const left = ep.stops.length - solved.size;
    stage.appendChild(el('div', { class: 'ep-hint' },
      left > 0
        ? `Atinge o oprire și rezolvă. Mai ai ${left} ${left === 1 ? 'oprire' : 'opriri'}. ✨`
        : 'Ai vizitat toate opririle! 🎉'
    ));

    wrap.appendChild(stage);
    speak(ep.lead || 'Alege o oprire pe hartă.');
    if (left === 0) setTimeout(finish, 400);
  }

  // ---------- O oprire (scenă + provocare) ----------
  function openStop(s) {
    clear(wrap);
    const stage = el('div', { class: 'episode-stage' });
    stage.appendChild(bg(s.scene));

    // Bară sus: înapoi la hartă + numele opririi.
    stage.appendChild(el('div', { class: 'ep-top' },
      el('button', { class: 'ep-back', title: 'Înapoi la hartă', onclick: () => { sfx.tap(); renderMap(); } }, '🗺️'),
      el('span', { class: 'ep-title', text: `${s.emoji} ${s.name}` })
    ));

    // Provocarea (trage-și-plasează) pe un panou blând.
    const panel = el('div', { class: 'ep-panel' });
    panel.appendChild(el('div', { class: 'ep-instr', text: s.dd.instruction }));

    const dd = makeDragDrop({
      zones: s.dd.zones,
      items: s.dd.items,
      onSolvedAll: () => onStopDone(s)
    });
    panel.appendChild(dd);
    stage.appendChild(panel);

    // Bulă de poveste cu mascota.
    stage.appendChild(el('div', { class: 'ep-bubble' },
      el('span', { class: 'eb-mascot', html: fireflySVG(46, true) }),
      el('span', { class: 'eb-text', text: s.intro })
    ));

    wrap.appendChild(stage);
    speak(s.intro);
  }

  function onStopDone(s) {
    solved.add(s.id);
    sfx.celebrate();
    speak('Ai terminat! Bravo!');
    // Panou blând de reușită pentru oprire, apoi înapoi la hartă.
    const done = el('div', { class: 'ep-stopdone' },
      el('div', { class: 'esd-mascot', html: fireflySVG(90, true) }),
      el('div', { class: 'esd-stars', text: '⭐⭐' }),
      el('h2', { text: 'Bravo! Ai rezolvat oprirea.' }),
      el('button', { class: 'btn', onclick: () => { sfx.tap(); renderMap(); } }, '🗺️ Înapoi la hartă')
    );
    const overlay = el('div', { class: 'ep-overlay' }, done);
    wrap.appendChild(overlay);
    if (store.get('motion')) celebrate();
  }

  // ---------- Final episod ----------
  function finish() {
    clear(wrap);
    store.markPlayed(ep.id);
    const earned = 3;
    store.addStars(earned);
    store.recordStat(ep.id, { correct: ep.stops.length, total: ep.stops.length, stars: earned });
    celebrate();
    speak('Ai terminat! Bravo!');

    const box = el('div', { class: 'finish' });
    box.appendChild(el('div', { class: 'finish-mascot', html: fireflySVG(110, true) }));
    box.appendChild(el('div', { class: 'bigstars', text: '⭐'.repeat(earned) }));
    box.appendChild(el('h2', { text: ep.outro || 'Ai terminat aventura! 🎉' }));
    box.appendChild(el('p', { class: 'lead', text: `Ai vizitat toate cele ${ep.stops.length} opriri. Ai câștigat ${earned} steluțe.` }));
    const row = el('div', { class: 'row' },
      el('button', { class: 'btn', onclick: () => ctx.restart() }, '🔁 Încă o dată'),
      el('button', { class: 'btn mint', onclick: () => ctx.goHome() }, '🏠 Alt joc')
    );
    box.appendChild(row);
    // Așază finalul pe o scenă blândă.
    const stage = el('div', { class: 'episode-stage' });
    stage.appendChild(bg(mapScene));
    stage.appendChild(el('div', { class: 'ep-overlay' }, box));
    wrap.appendChild(stage);
  }

  renderMap();
}

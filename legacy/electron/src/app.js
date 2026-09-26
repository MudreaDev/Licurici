// Licurici — router și cadru principal.
// Bară de sus constantă (predictibilitate), meniu de jocuri, setări, despre.
import { store, applyBodyClasses } from './store.js';
import { el, clear, speak, stopSpeak } from './ui.js';
import { sfx, unlockAudio } from './audio.js';
import { GAMES, GAME_MAP, gamesForGrade } from './games/registry.js';
import { fireflySVG } from './mascot.js';
import { startMusic, applyMusicVolume } from './music.js';
import { getLevel, worldOf, LEVELS_PER_WORLD } from './levels.js';
import { setTier, clearTier } from './difficulty.js';
import { GRADES, currentGrade, gradeInfo } from './grades.js';
import { observe as observeGfx } from './gfx.js';

const app = document.getElementById('app');
let currentCleanup = null;

applyBodyClasses();

// Deblochează sunetul + pornește muzica de fundal la prima interacțiune (cerință browser).
window.addEventListener('pointerdown', () => { unlockAudio(); startMusic(); }, { once: true });

// Structură fixă: bară sus + zonă de conținut.
const topbar = el('div', { class: 'topbar' });
const content = el('div', { id: 'content', style: 'flex:1; display:flex; flex-direction:column; overflow:hidden;' });
app.appendChild(topbar);
app.appendChild(content);

// Înlocuiește automat orice emoji cu ilustrația reală OpenMoji, oriunde în interfață.
observeGfx(app);

function renderTopbar(where) {
  clear(topbar);
  const home = el('button', { class: 'iconbtn' + (where === 'home' ? ' on' : ''), title: 'Acasă', onclick: () => go('home') },
    '🏠', el('span', { class: 'lbl', text: 'Acasă' }));
  const aquarium = el('button', { class: 'iconbtn' + (where === 'acvariu' ? ' on' : ''), title: 'Acvariul tău personal', onclick: () => go('acvariu') },
    '🐠', el('span', { class: 'lbl', text: 'Acvariu' }));
  const title = el('div', { class: 'title' },
    el('span', { class: 'logo', html: fireflySVG(40, true) }),
    el('span', { text: 'Licurici' }));
  const spacer = el('div', { class: 'spacer' });
  const stars = el('button', { class: 'iconbtn', title: 'Steluțele tale', onclick: () => go('progres') },
    '⭐', el('span', { class: 'lbl', text: String(store.get('stars') || 0) }));
  const progres = el('button', { class: 'iconbtn', title: 'Progres', onclick: () => go('progres') },
    '📊', el('span', { class: 'lbl', text: 'Progres' }));
  const settings = el('button', { class: 'iconbtn', title: 'Setări', onclick: () => go('setari') },
    '⚙️', el('span', { class: 'lbl', text: 'Setări' }));

  topbar.appendChild(home);
  topbar.appendChild(aquarium);
  topbar.appendChild(title);
  topbar.appendChild(spacer);
  topbar.appendChild(stars);
  topbar.appendChild(progres);
  topbar.appendChild(settings);
}

function mountArea() {
  const area = el('div', { style: 'flex:1; overflow:hidden; display:flex; flex-direction:column;' });
  clear(content);
  content.appendChild(area);
  return area;
}

// Navigare centralizată — curăță jocul anterior (timere/voce) înainte de a merge mai departe.
function go(dest) {
  if (currentCleanup) { try { currentCleanup(); } catch (e) {} currentCleanup = null; }
  stopSpeak();
  store.setDiffOverride(null); clearTier();   // ieșim din modul „nivel"
  sfx.tap();
  renderTopbar(dest);
  if (dest === 'home') return renderHome();
  if (dest === 'acvariu') return renderAquarium();
  if (dest === 'aventura') return renderAdventure();
  if (dest === 'progres') return renderStats();
  if (dest === 'setari') return renderSettings();
  if (dest === 'despre') return renderAbout();
  if (GAME_MAP[dest]) return renderGame(dest);
  renderHome();
}

// ---- Acvariu: scenă 3D Paper Aquarium ----
function renderAquarium() {
  const area = mountArea();
  const iframe = el('iframe', {
    src: 'http://localhost:8000/personal',
    style: 'flex:1; width:100%; height:100%; border:none; background:#051624;',
    allow: 'camera; microphone; autoplay; fullscreen'
  });
  area.appendChild(iframe);
}

// ---- Acasă: grila de jocuri ----
function renderHome() {
  const area = mountArea();
  const screen = el('div', { class: 'screen' });
  area.appendChild(screen);

  const g0 = gradeInfo(currentGrade());
  screen.appendChild(el('div', { class: 'welcome' },
    el('div', { class: 'welcome-mascot', html: fireflySVG(96, true) }),
    el('div', {},
      el('h1', { text: store.get('childName') ? `Bună, ${store.get('childName')}!` : 'Bine ai venit!' }),
      el('p', { class: 'lead', text: `Ești la ${g0.name}. Alege un joc — de fiecare dată e ceva nou. ✨` })
    )
  ));

  // Selector de clasă (grădiniță + 1-4)
  const picker = el('div', { class: 'grade-picker' });
  GRADES.forEach(gr => {
    const chip = el('button', { class: 'grade-chip' + (gr.id === currentGrade() ? ' on' : '') },
      el('span', { class: 'gc-emoji', text: gr.emoji }), el('span', { text: gr.name }));
    chip.addEventListener('click', () => { store.set('grade', gr.id); sfx.tap(); renderHome(); });
    picker.appendChild(chip);
  });
  screen.appendChild(picker);

  // Buton mare spre Aventură (niveluri nesfârșite)
  const nextLevel = store.highestLevel() + 1;
  screen.appendChild(el('div', {
    class: 'adventure-hero', role: 'button', tabindex: '0', onclick: () => go('aventura')
  },
    el('div', { class: 'adv-emoji', text: '🗺️' }),
    el('div', { class: 'adv-text' },
      el('div', { class: 'adv-title', text: 'Aventura' }),
      el('div', { class: 'adv-sub', text: `Niveluri nesfârșite · continuă de la nivelul ${nextLevel}` })
    ),
    el('div', { class: 'adv-go', text: '▶' })
  ));

  // Buton spre Acvariul personal interactiv
  screen.appendChild(el('div', {
    class: 'adventure-hero', role: 'button', tabindex: '0', onclick: () => go('acvariu'),
    style: 'background: linear-gradient(135deg, #0d4a6b, #0a3a5c); color: #eaf6ff; margin-top: 14px; border-color: rgba(88,214,255,0.4);'
  },
    el('div', { class: 'adv-emoji', text: '🐠' }),
    el('div', { class: 'adv-text' },
      el('div', { class: 'adv-title', text: 'Acvariul Meu Personal' }),
      el('div', { class: 'adv-sub', text: 'Colorează pești pe hârtie și privește-i cum înoată în 3D' })
    ),
    el('div', { class: 'adv-go', text: '▶' })
  ));

  // Constructor de card de joc (reutilizat la Explorare + secțiunile pe materii).
  const makeCard = (g) => {
    const card = el('div', {
      class: 'card', role: 'button', tabindex: '0', onclick: () => go(g.id),
      style: '--accent:' + (g.color || 'var(--primary)')
    },
      el('div', { class: 'emoji-badge' }, el('span', { class: 'emoji', text: g.emoji })),
      el('div', { class: 'name', text: g.name }),
      el('div', { class: 'desc', text: g.desc }),
      el('div', { class: 'badge', text: g.badge })
    );
    card.addEventListener('keydown', (e) => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); go(g.id); } });
    return card;
  };

  // Secțiune specială „Explorare" (episoadele stil Autobuzul magic), evidențiată sus.
  const episodes = GAMES.filter(g => g.badge === 'Explorare' && g.grades.includes(currentGrade()));
  if (episodes.length) {
    screen.appendChild(el('div', { class: 'section-title' },
      el('span', { class: 'st-emoji', text: '🧭' }), 'Explorare — povești cu provocări'));
    const egrid = el('div', { class: 'grid explore-grid' });
    episodes.forEach(g => egrid.appendChild(makeCard(g)));
    screen.appendChild(egrid);
  }

  // Jocurile clasei, grupate pe materii (fără episoade — ele apar deja la Explorare).
  gamesForGrade(currentGrade()).forEach(sec => {
    const games = sec.games.filter(g => g.badge !== 'Explorare');
    if (!games.length) return;
    screen.appendChild(el('div', { class: 'section-title' },
      el('span', { class: 'st-emoji', text: sec.subject.emoji }), sec.subject.name));
    const grid = el('div', { class: 'grid' });
    games.forEach(g => grid.appendChild(makeCard(g)));
    screen.appendChild(grid);
  });
}

// ---- Un joc (joc liber) ----
function renderGame(id) {
  const game = GAME_MAP[id];
  const area = mountArea();
  const ctx = {
    goHome: () => go('home'),
    restart: () => go(id),
    setCleanup: (fn) => { currentCleanup = fn; }
  };
  game.start(area, ctx);
}

// ---- Aventura: harta de niveluri (nesfârșite) ----
function renderAdventure() {
  const area = mountArea();
  const screen = el('div', { class: 'screen' });
  area.appendChild(screen);

  const highest = store.highestLevel();
  const current = highest + 1;
  screen.appendChild(el('div', { class: 'welcome' },
    el('div', { class: 'welcome-mascot', html: fireflySVG(84, true) }),
    el('div', {},
      el('h1', { text: '🗺️ Aventura' }),
      el('p', { class: 'lead', text: `Ai deblocat ${highest} niveluri · ⭐ ${store.get('stars') || 0} steluțe. Continuă!` })
    )
  ));

  const maxShow = Math.max(current + 5, 16);
  let curNode = null;
  let lastWorld = -1;
  let path = null;

  for (let i = 1; i <= maxShow; i++) {
    const lvl = getLevel(i);
    if (lvl.world.num !== lastWorld) {
      lastWorld = lvl.world.num;
      screen.appendChild(el('div', { class: 'world-banner', style: '--accent:' + lvl.world.color },
        el('span', { class: 'wb-emoji', text: lvl.world.emoji }),
        el('span', { text: `Lumea ${lvl.world.num + 1} · ${lvl.world.name}` })
      ));
      path = el('div', { class: 'level-path' });
      screen.appendChild(path);
    }
    const unlocked = store.isUnlocked(i);
    const stars = store.levelStars(i);
    const node = el('button', {
      class: 'level-node' + (unlocked ? '' : ' locked') + (i === current ? ' current' : ''),
      style: '--accent:' + lvl.world.color,
      disabled: unlocked ? null : true,
      onclick: unlocked ? (() => runLevel(i)) : null
    },
      el('span', { class: 'ln-num', text: String(i) }),
      el('span', { class: 'ln-emoji', text: unlocked ? lvl.game.emoji : '🔒' }),
      el('span', { class: 'ln-stars', text: stars ? '⭐'.repeat(stars) : '' })
    );
    if (i === current) curNode = node;
    path.appendChild(node);
  }

  // derulează automat la nivelul curent
  if (curNode) setTimeout(() => { try { curNode.scrollIntoView({ block: 'center' }); } catch (e) {} }, 60);
}

// Rulează un nivel din Aventură (setează dificultatea, apoi pornește jocul).
function runLevel(i) {
  if (currentCleanup) { try { currentCleanup(); } catch (e) {} currentCleanup = null; }
  stopSpeak();
  sfx.tap();

  const lvl = getLevel(i);
  store.setDiffOverride(lvl.tier >= 2 ? 'mediu' : 'usor');
  setTier(lvl.tier);
  renderTopbar('aventura');

  const area = mountArea();
  // bară subțire cu nivelul + buton spre hartă
  area.appendChild(el('div', { class: 'level-bar', style: '--accent:' + lvl.world.color },
    el('span', { class: 'lb-info', text: `Nivel ${i} · ${lvl.world.emoji} ${lvl.world.name}` }),
    el('button', { class: 'iconbtn', title: 'Înapoi la hartă', onclick: () => go('aventura') }, '🗺️')
  ));
  const sub = el('div', { style: 'flex:1; overflow:hidden; display:flex; flex-direction:column;' });
  area.appendChild(sub);

  const ctx = {
    level: true,
    goHome: () => go('home'),
    goMap: () => go('aventura'),
    restart: () => runLevel(i),
    next: () => runLevel(i + 1),
    onComplete: (stars) => { store.completeLevel(i, stars); },
    setCleanup: (fn) => { currentCleanup = fn; }
  };
  lvl.game.start(sub, ctx);
}

// ---- Progres: statistici individuale (local) ----
function renderStats() {
  const area = mountArea();
  const screen = el('div', { class: 'screen' });
  area.appendChild(screen);
  screen.appendChild(el('h1', { text: '📊 Progres' }));

  const totalPlays = GAMES.reduce((s, g) => s + ((store.stat(g.id) || {}).plays || 0), 0);
  screen.appendChild(el('div', { class: 'stat-cards' },
    el('div', { class: 'stat-card' }, el('div', { class: 'sc-big', text: String(store.get('stars') || 0) }), el('div', { class: 'sc-lbl', text: '⭐ steluțe' })),
    el('div', { class: 'stat-card' }, el('div', { class: 'sc-big', text: String(totalPlays) }), el('div', { class: 'sc-lbl', text: 'jocuri jucate' })),
    el('div', { class: 'stat-card' }, el('div', { class: 'sc-big', text: String(store.highestLevel()) }), el('div', { class: 'sc-lbl', text: 'niveluri deblocate' }))
  ));

  // Detaliu pe jocuri (doar cele exersate)
  const played = GAMES.filter(g => store.stat(g.id));
  if (!played.length) {
    screen.appendChild(el('p', { class: 'lead', text: 'Încă nu ai jucat niciun joc. Alege unul de pe pagina de start! 🌈' }));
  } else {
    const list = el('div', { class: 'stat-list' });
    played.forEach(g => {
      const s = store.stat(g.id);
      const acc = s.total ? Math.round((s.correct / s.total) * 100) : null;
      list.appendChild(el('div', { class: 'stat-row', style: '--accent:' + g.color },
        el('span', { class: 'sr-emoji', text: g.emoji }),
        el('span', { class: 'sr-name', text: g.name }),
        el('span', { class: 'sr-meta', text: `${s.plays}× jucat` + (acc != null ? ` · ${acc}% corect` : '') }),
        el('span', { class: 'sr-stars', text: s.best ? '⭐'.repeat(s.best) : '' })
      ));
    });
    screen.appendChild(list);
  }

  const row = el('div', { class: 'row', style: 'justify-content:center; margin-top:24px;' },
    el('button', { class: 'btn', onclick: () => go('home') }, '🏠 Înapoi')
  );
  screen.appendChild(row);
}

// ---- Setări (profil senzorial) ----
function renderSettings() {
  const area = mountArea();
  const screen = el('div', { class: 'screen' });
  area.appendChild(screen);
  screen.appendChild(el('h1', { text: '⚙️ Setări' }));
  screen.appendChild(el('p', { class: 'lead', text: 'Potrivește aplicația după cum îți place ție.' }));

  const list = el('div', { class: 'settings-list' });

  // Numele copilului (opțional) — pentru salut personalizat pe pagina de start.
  const nameRow = el('div', { class: 'setting' },
    el('div', { class: 'info' },
      el('div', { class: 't', text: '🙂 Numele copilului' }),
      el('div', { class: 'd', text: 'Ca să te salut pe nume (opțional)' })
    )
  );
  const nameInput = el('input', { type: 'text', class: 'name-input', maxlength: '20', placeholder: 'Numele tău', 'aria-label': 'Numele copilului' });
  nameInput.value = store.get('childName') || '';
  nameInput.addEventListener('input', () => store.set('childName', nameInput.value.trim()));
  nameRow.appendChild(nameInput);
  list.appendChild(nameRow);

  // Cursoare de volum (predefinit MEDIU)
  list.appendChild(slider('🎵 Muzică', 'Muzica de fundal', 'musicVol', () => { startMusic(); applyMusicVolume(); }));
  list.appendChild(slider('🔊 Sunete', 'Sunetele din jocuri', 'sfxVol', () => sfx.good()));
  list.appendChild(slider('🗣️ Voce', 'Instrucțiunile citite cu voce', 'voiceVol', () => speak('Bravo')));
  list.appendChild(toggle('✨ Animații', 'Mișcare și confetti (oprește dacă distrag)', 'motion'));
  list.appendChild(toggle('🌙 Stimulare redusă', 'Culori mai palide, mai liniștit', 'calm'));
  list.appendChild(toggle('🔠 Text mare', 'Litere mai mari, mai ușor de citit', 'bigText'));

  // Dificultate
  const diff = el('div', { class: 'setting' },
    el('div', { class: 'info' },
      el('div', { class: 't', text: '🎯 Dificultate' }),
      el('div', { class: 'd', text: 'Ușor = mai puține variante. Mediu = mai multe.' })
    )
  );
  const seg = el('div', { class: 'segments' });
  ['usor', 'mediu'].forEach(level => {
    const b = el('button', { text: level === 'usor' ? 'Ușor' : 'Mediu' });
    if (store.get('difficulty') === level) b.classList.add('on');
    b.addEventListener('click', () => {
      store.set('difficulty', level);
      [...seg.children].forEach(c => c.classList.remove('on'));
      b.classList.add('on');
      sfx.tap();
    });
    seg.appendChild(b);
  });
  diff.appendChild(seg);
  list.appendChild(diff);

  screen.appendChild(list);

  const info = el('div', { style: 'text-align:center; margin-top:26px;' },
    el('button', { class: 'btn ghost', onclick: () => go('despre') }, 'ℹ️ Despre Licurici')
  );
  screen.appendChild(info);
}

function toggle(title, desc, key, onChange) {
  const row = el('div', { class: 'setting' },
    el('div', { class: 'info' },
      el('div', { class: 't', text: title }),
      el('div', { class: 'd', text: desc })
    )
  );
  const sw = el('label', { class: 'switch' });
  const input = el('input', { type: 'checkbox' });
  input.checked = !!store.get(key);
  const track = el('span', { class: 'track' }, el('span', { class: 'thumb' }));
  sw.appendChild(input);
  sw.appendChild(track);
  input.addEventListener('change', () => {
    store.set(key, input.checked); sfx.tap();
    if (onChange) onChange(input.checked);
  });
  row.appendChild(sw);
  return row;
}

// Cursor de volum (0-100%), cu previzualizare la eliberare.
function slider(title, desc, key, preview) {
  const row = el('div', { class: 'setting' },
    el('div', { class: 'info' },
      el('div', { class: 't', text: title }),
      el('div', { class: 'd', text: desc })
    )
  );
  const val = el('span', { class: 'vol-val' });
  const input = el('input', { type: 'range', min: '0', max: '100', step: '5', class: 'vol-range' });
  input.value = String(Math.round(((store.get(key) == null ? 0.5 : store.get(key))) * 100));
  val.textContent = input.value + '%';
  input.addEventListener('input', () => { store.set(key, input.value / 100); val.textContent = input.value + '%'; });
  input.addEventListener('change', () => { if (preview) preview(); });
  const wrap = el('div', { class: 'vol' }, input, val);
  row.appendChild(wrap);
  return row;
}

// ---- Despre ----
function renderAbout() {
  const area = mountArea();
  const screen = el('div', { class: 'screen' });
  area.appendChild(screen);
  screen.appendChild(el('h1', { text: 'ℹ️ Despre Licurici' }));
  const box = el('div', { class: 'stimulus', style: 'text-align:left; max-width:760px;' });
  box.innerHTML = `
    <p style="font-size:20px; line-height:1.6">
      <b>Licurici</b> ajută copiii să învețe și să se joace: litere, numere, culori,
      emoții, comunicare și liniște — prin jocuri scurte și blânde. Potrivit pentru cei
      mici și pentru copiii cu autism.
    </p>
    <p style="font-size:19px; line-height:1.6; color:var(--ink-soft)">
      Jocurile sunt construite după practici recunoscute în lume (ABA, TEACCH, PECS,
      Social Stories, Zones of Regulation): o singură sarcină pe ecran, recompensă
      imediată, fără pedeapsă la greșeală, învățare fără eroare, culori calme și
      predictibilitate. Fiecare joc se generează aleator, deci e mereu ceva nou.
    </p>
    <p style="font-size:18px; line-height:1.6; color:var(--ink-soft)">
      Totul funcționează offline. Datele rămân doar pe acest calculator.
    </p>
    <p style="font-size:15px; line-height:1.5; color:var(--ink-soft)">
      Ilustrații: <b>OpenMoji</b> — proiectul open-source de emoji al HfG Schwäbisch Gmünd,
      licență CC BY-SA 4.0. Voce: Microsoft Neural (RO: Alina, EN: Jenny). Font: Fredoka (OFL).
    </p>
  `;
  screen.appendChild(box);
  const row = el('div', { class: 'row', style: 'justify-content:center; margin-top:24px;' },
    el('button', { class: 'btn', onclick: () => go('home') }, '🏠 Înapoi la jocuri')
  );
  screen.appendChild(row);
}

// Meniul aplicației (Electron) poate cere „Despre".
if (window.licurici && window.licurici.onNav) {
  window.licurici.onNav((dest) => go(dest));
}

// Pornire
go('home');

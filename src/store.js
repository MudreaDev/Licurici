// Stocare locală pentru setări și progres (fără cont, fără internet).
const KEY = 'licurici.v1';

const defaults = {
  musicVol: 0.5,        // volum muzică de fundal (0..1) — predefinit MEDIU
  sfxVol: 0.5,          // volum sunete (0..1) — predefinit MEDIU
  voiceVol: 0.5,        // volum voce/instrucțiuni (0..1) — predefinit MEDIU
  motion: true,         // animații (confetti etc.)
  calm: false,          // temă „stimulare redusă"
  bigText: false,       // text mai mare
  difficulty: 'usor',   // usor | mediu (în joc liber)
  grade: 'clasa1',      // gradinita | clasa1..clasa4 (clasa aleasă)
  childName: '',        // numele copilului (opțional)
  stars: 0,             // total steluțe adunate
  played: {},           // { gameId: nrLecțiiTerminate }
  levels: {},           // { levelIndex: nrStele }  — progresul în Aventură
  stats: {}             // { gameId: { plays, correct, total, best, last } }
};

// Suprascriere temporară a dificultății (folosită de Aventură pentru nivelurile grele).
let diffOverride = null;

let state = load();

function load() {
  try {
    const raw = localStorage.getItem(KEY);
    if (raw) return Object.assign({}, defaults, JSON.parse(raw));
  } catch (e) { /* ignoră */ }
  return Object.assign({}, defaults);
}

function persist() {
  try { localStorage.setItem(KEY, JSON.stringify(state)); } catch (e) { /* ignoră */ }
}

export const store = {
  get: (k) => {
    // În Aventură, dificultatea poate fi suprascrisă temporar (fără să schimbe setarea).
    if (k === 'difficulty' && diffOverride) return diffOverride;
    return state[k];
  },
  set: (k, v) => { state[k] = v; persist(); applyBodyClasses(); },
  all: () => ({ ...state }),
  addStars(n) { state.stars = (state.stars || 0) + n; persist(); },
  markPlayed(gameId) {
    state.played[gameId] = (state.played[gameId] || 0) + 1;
    persist();
  },

  // ---- Statistici per joc (individual, doar local) ----
  recordStat(gameId, { correct = 0, total = 0, stars = 0 } = {}) {
    const s = state.stats[gameId] || { plays: 0, correct: 0, total: 0, best: 0, last: 0 };
    s.plays += 1;
    s.correct += correct;
    s.total += total;
    if (stars > s.best) s.best = stars;
    state.stats[gameId] = s;
    persist();
  },
  stat(gameId) { return state.stats[gameId] || null; },
  allStats() { return { ...state.stats }; },

  // ---- Aventură ----
  setDiffOverride(v) { diffOverride = v; },   // 'usor' | 'mediu' | null
  levelStars(i) { return state.levels[i] || 0; },
  highestLevel() {
    const keys = Object.keys(state.levels).map(Number);
    return keys.length ? Math.max(...keys) : 0;
  },
  isUnlocked(i) { return i <= 1 || !!state.levels[i - 1]; },
  completeLevel(i, stars) {
    const prev = state.levels[i] || 0;
    if (stars > prev) state.levels[i] = stars;
    persist();
  }
};

// Aplică opțiunile care schimbă aspectul global pe <body>.
export function applyBodyClasses() {
  const b = document.body;
  b.classList.toggle('calm', !!state.calm);
  b.classList.toggle('bigtext', !!state.bigText);
  b.classList.toggle('reduce-motion', !state.motion);
}

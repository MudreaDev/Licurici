// Aventura — niveluri NESFÂRȘITE, generate procedural (spirit .kkrieger).
// Fiecare nivel = o instanță a unui joc, cu dificultate crescătoare, grupate în „lumi".
// Identitatea nivelului (ce joc, ce lume, ce tier) e deterministă din indexul lui,
// dar conținutul din interior e mereu proaspăt (aleator) → „9999-in-1", niciodată la fel.
import { GAME_MAP } from './games/registry.js';

const WORLDS = [
  { name: 'Poiana',    emoji: '🌼', color: '#7fc0a3' },
  { name: 'Pădurea',   emoji: '🌳', color: '#6bbf8a' },
  { name: 'Lacul',     emoji: '💧', color: '#5b9bb5' },
  { name: 'Muntele',   emoji: '⛰️', color: '#a9a3d1' },
  { name: 'Norii',     emoji: '☁️', color: '#8fb8d6' },
  { name: 'Stelele',   emoji: '⭐', color: '#f2cf6b' },
  { name: 'Curcubeul', emoji: '🌈', color: '#f0a9c0' }
];

export const LEVELS_PER_WORLD = 8;

// Jocurile potrivite pentru niveluri (au un „final" clar). Excludem uneltele deschise
// (Vorbește / Respiră), care nu au câștig/final, și episodul de explorat (are propriul
// flux, cu hartă și opriri — nu se potrivește ca nivel unic în Aventură).
const EXCLUDE = new Set(['comunicare', 'respira']);
const POOL = Object.keys(GAME_MAP).filter(id => !EXCLUDE.has(id) && !id.startsWith('explorare-'));

// Amestecare deterministă a pool-ului per lume, ca fiecare lume să aibă altă ordine.
function gameForLevel(i) {
  // hash simplu, determinist (fără Math.random) → același nivel = același joc mereu.
  const h = ((i * 2654435761) >>> 0) % POOL.length;
  return POOL[h];
}

export function worldOf(i) {
  const w = Math.floor((i - 1) / LEVELS_PER_WORLD);
  const base = WORLDS[w % WORLDS.length];
  const cycle = Math.floor(w / WORLDS.length);
  return { ...base, num: w, name: cycle > 0 ? `${base.name} ${cycle + 1}` : base.name };
}

export function getLevel(i) {
  const gameId = gameForLevel(i);
  // Dificultate NEMĂRGINITĂ: crește la fiecare 4 niveluri, fără plafon → cu cât mergi
  // mai departe, cu atât mai greu (numere mai mari, mai multe variante, mai multe runde).
  const tier = 1 + Math.floor((i - 1) / 4);
  return { index: i, world: worldOf(i), tier, gameId, game: GAME_MAP[gameId] };
}

export { WORLDS };

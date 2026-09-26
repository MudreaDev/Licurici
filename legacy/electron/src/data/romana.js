// Conținut de limba română avansat (clasele 2-4): părți de vorbire + singular/plural.
// Literal și corect. Emoji doar ca sprijin vizual (unde există un obiect concret).

// ---- Părți de vorbire (substantiv / verb / adjectiv) ----
export const WORD_KINDS = [
  { kind: 'substantiv', label: 'Substantiv', words: [
    { w: 'casă', e: '🏠' }, { w: 'măr', e: '🍎' }, { w: 'câine', e: '🐶' },
    { w: 'floare', e: '🌸' }, { w: 'carte', e: '📖' }, { w: 'pisică', e: '🐱' },
    { w: 'copil', e: '🧒' }, { w: 'soare', e: '☀️' }, { w: 'școală', e: '🏫' } ] },
  { kind: 'verb', label: 'Verb', words: [
    { w: 'aleargă', e: '🏃' }, { w: 'mănâncă', e: '🍽️' }, { w: 'doarme', e: '😴' },
    { w: 'cântă', e: '🎤' }, { w: 'scrie', e: '✍️' }, { w: 'citește', e: '📖' },
    { w: 'zboară', e: '🦅' }, { w: 'înoată', e: '🏊' }, { w: 'râde', e: '😄' } ] },
  { kind: 'adjectiv', label: 'Adjectiv', words: [
    { w: 'mare' }, { w: 'mic' }, { w: 'roșu' }, { w: 'frumos' }, { w: 'rapid' },
    { w: 'vesel' }, { w: 'înalt' }, { w: 'dulce' }, { w: 'nou' } ] }
];
export const KIND_LABELS = { substantiv: 'Substantiv', verb: 'Verb', adjectiv: 'Adjectiv' };

// ---- Singular → plural (forme corecte) ----
export const PLURALS = [
  { sg: 'măr', pl: 'mere', e: '🍎' }, { sg: 'casă', pl: 'case', e: '🏠' },
  { sg: 'floare', pl: 'flori', e: '🌸' }, { sg: 'copil', pl: 'copii', e: '🧒' },
  { sg: 'carte', pl: 'cărți', e: '📖' }, { sg: 'pisică', pl: 'pisici', e: '🐱' },
  { sg: 'câine', pl: 'câini', e: '🐶' }, { sg: 'stea', pl: 'stele', e: '⭐' },
  { sg: 'masă', pl: 'mese', e: '🪑' }, { sg: 'scaun', pl: 'scaune', e: '🪑' },
  { sg: 'creion', pl: 'creioane', e: '✏️' }, { sg: 'caiet', pl: 'caiete', e: '📓' },
  { sg: 'minge', pl: 'mingi', e: '⚽' }, { sg: 'băiat', pl: 'băieți', e: '👦' },
  { sg: 'fată', pl: 'fete', e: '👧' }, { sg: 'pom', pl: 'pomi', e: '🌳' },
  { sg: 'cuvânt', pl: 'cuvinte', e: '💬' }, { sg: 'om', pl: 'oameni', e: '🧑' }
];
export const ALL_PLURALS = PLURALS.map(p => p.pl);

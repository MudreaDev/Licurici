// Conținut pentru materiile școlare (clasele 1-4 + grădiniță). Totul în română,
// literal și clar. Jocurile aleg aleator din aceste bănci.

// ---- CUVINTE cu silabe (pentru „Silabe" și „Citește cuvântul") ----
export const WORDS = [
  { w: 'măr',     e: '🍎', syl: ['măr'] },
  { w: 'urs',     e: '🐻', syl: ['urs'] },
  { w: 'stea',    e: '⭐', syl: ['stea'] },
  { w: 'casă',    e: '🏠', syl: ['ca', 'să'] },
  { w: 'floare',  e: '🌸', syl: ['floa', 're'] },
  { w: 'soare',   e: '☀️', syl: ['soa', 're'] },
  { w: 'balon',   e: '🎈', syl: ['ba', 'lon'] },
  { w: 'copac',   e: '🌳', syl: ['co', 'pac'] },
  { w: 'lună',    e: '🌙', syl: ['lu', 'nă'] },
  { w: 'carte',   e: '📖', syl: ['car', 'te'] },
  { w: 'pește',   e: '🐟', syl: ['peș', 'te'] },
  { w: 'tobă',    e: '🥁', syl: ['to', 'bă'] },
  { w: 'banană',  e: '🍌', syl: ['ba', 'na', 'nă'] },
  { w: 'pisică',  e: '🐱', syl: ['pi', 'si', 'că'] },
  { w: 'mașină',  e: '🚗', syl: ['ma', 'și', 'nă'] },
  { w: 'elefant', e: '🐘', syl: ['e', 'le', 'fant'] },
  { w: 'iepure',  e: '🐰', syl: ['ie', 'pu', 're'] },
  { w: 'girafă',  e: '🦒', syl: ['gi', 'ra', 'fă'] },
  { w: 'căpșună', e: '🍓', syl: ['căp', 'șu', 'nă'] },
  { w: 'albină',  e: '🐝', syl: ['al', 'bi', 'nă'] }
];

// ---- ANIMALE și MEDIUL lor (Științe) ----
export const HABITATS = [
  { name: 'Fermă',      emoji: '🚜', animals: ['🐄', '🐖', '🐔', '🐑', '🐴', '🦆'] },
  { name: 'Junglă',     emoji: '🌴', animals: ['🦁', '🐯', '🐘', '🐒', '🦜', '🐆'] },
  { name: 'Ocean',      emoji: '🌊', animals: ['🐠', '🐙', '🦈', '🐳', '🦀', '🐬'] },
  { name: 'Pădure',     emoji: '🌲', animals: ['🦊', '🐻', '🦉', '🦌', '🐿️', '🦔'] },
  { name: 'La pol',     emoji: '❄️', animals: ['🐧', '🐻‍❄️', '🦭', '🦈'] }
];

// ---- ANOTIMPURI (Științe) ----
export const SEASONS = [
  { name: 'primăvara', e: '🌷', items: ['🌷', '🐣', '🌱', '🌦️'] },
  { name: 'vara',      e: '☀️', items: ['☀️', '🏖️', '🍉', '🩳'] },
  { name: 'toamna',    e: '🍂', items: ['🍂', '🍇', '🌰', '☔'] },
  { name: 'iarna',     e: '❄️', items: ['❄️', '⛄', '🎿', '🧣'] }
];

// ---- CORPUL uman (Științe) ----
export const BODY = [
  { name: 'ochi',    e: '👁️' }, { name: 'ureche', e: '👂' },
  { name: 'nas',     e: '👃' }, { name: 'gură',   e: '👄' },
  { name: 'mână',    e: '🖐️' }, { name: 'picior', e: '🦵' },
  { name: 'dinte',   e: '🦷' }, { name: 'inimă',  e: '❤️' }
];

// ---- BANI (lei) — monede/bancnote simple ----
export const MONEY = [
  { v: 1,  e: '🟡' },   // 1 leu
  { v: 5,  e: '🟠' },   // 5 lei
  { v: 10, e: '💵' }    // 10 lei
];

// ---- ENGLEZĂ (ca materie): cuvânt RO ↔ EN + imagine ----
export const ENGLISH = [
  { cat: 'Culori',  items: [
    { ro: 'roșu', en: 'red', e: '🔴' }, { ro: 'albastru', en: 'blue', e: '🔵' },
    { ro: 'verde', en: 'green', e: '🟢' }, { ro: 'galben', en: 'yellow', e: '🟡' } ] },
  { cat: 'Animale', items: [
    { ro: 'câine', en: 'dog', e: '🐶' }, { ro: 'pisică', en: 'cat', e: '🐱' },
    { ro: 'pește', en: 'fish', e: '🐟' }, { ro: 'pasăre', en: 'bird', e: '🐦' },
    { ro: 'urs', en: 'bear', e: '🐻' }, { ro: 'vulpe', en: 'fox', e: '🦊' } ] },
  { cat: 'Numere',  items: [
    { ro: 'unu', en: 'one', e: '1️⃣' }, { ro: 'doi', en: 'two', e: '2️⃣' },
    { ro: 'trei', en: 'three', e: '3️⃣' }, { ro: 'patru', en: 'four', e: '4️⃣' },
    { ro: 'cinci', en: 'five', e: '5️⃣' } ] },
  { cat: 'Lucruri', items: [
    { ro: 'soare', en: 'sun', e: '☀️' }, { ro: 'casă', en: 'house', e: '🏠' },
    { ro: 'măr', en: 'apple', e: '🍎' }, { ro: 'carte', en: 'book', e: '📖' },
    { ro: 'stea', en: 'star', e: '⭐' } ] }
];

// Toate cuvintele englezești (pentru distractori + voce).
export const ENGLISH_WORDS = ENGLISH.flatMap(c => c.items.map(i => i.en));

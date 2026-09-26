// Generează voce ROMÂNĂ NEURONALĂ, blândă și naturală, pentru toate replicile.
// Folosește vocea neuronală Microsoft „ro-RO-AlinaNeural" (Friendly, Positive) prin
// edge-tts (gratuit, fără cheie API). Clipurile .mp3 se împachetează în app, deci
// aplicația rămâne 100% OFFLINE — internetul e nevoie DOAR la generare.
//
// Cerințe:  python3 -m pip install --user edge-tts
// Rulează:  node tools/gen-voice.mjs
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { execFileSync } from 'child_process';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.join(__dirname, '..');
const OUT = path.join(ROOT, 'src', 'audio-ro');
const VOICE = 'ro-RO-AlinaNeural';  // feminină, blândă, naturală
const RATE = '+0%';                 // viteză NATURALĂ, normală (nu repede, nu rar)

// Importă datele reale din content.js (fără duplicare), ca modul din memorie.
const contentSrc = fs.readFileSync(path.join(ROOT, 'src', 'data', 'content.js'), 'utf8');
const mod = await import('data:text/javascript,' + encodeURIComponent(contentSrc));
const { EMOTIONS, ROUTINES, SOCIAL, AAC, ALPHABET, COLORS, SHAPES } = mod;

const schoolSrc = fs.readFileSync(path.join(ROOT, 'src', 'data', 'school.js'), 'utf8');
const school = await import('data:text/javascript,' + encodeURIComponent(schoolSrc));
const { WORDS, ENGLISH_WORDS } = school;

const istSrc = fs.readFileSync(path.join(ROOT, 'src', 'data', 'istorie.js'), 'utf8');
const ist = await import('data:text/javascript,' + encodeURIComponent(istSrc));
const { PEOPLE } = ist;

const EN_VOICE = 'en-US-JennyNeural';  // adult, clară, pronunție corectă — materia Engleză

// ---- Adună TOATE textele rostite de aplicație (trebuie să corespundă apelurilor speak()) ----
const set = new Set();
const add = (t) => { if (t && String(t).trim()) set.add(String(t).trim()); };

// Fraze fixe + prompturi + instrucțiuni
[
  'Ai terminat! Bravo!', 'Bravo', 'Mai încearcă',
  'Cum se simte?', 'Câte obiecte sunt?', 'Ce urmează în șir?',
  'Găsește obiectul la fel.', 'În ce grupă intră acest obiect?',
  'Acum e rândul tău', 'Hai să privim din nou', 'Inspiră', 'Ține', 'Expiră',
  'Alege răspunsul potrivit.', 'Alege ce e cel mai potrivit să faci.',
  'Numără obiectele și alege numărul.', 'Alege ce urmează în șir.',
  'Găsește obiectul care e la fel.', 'Alege grupa în care intră obiectul.'
].forEach(add);

// Emoții (situație → față): „Cum se simte un copil care ...?"
EMOTIONS.forEach(e => e.contexts.forEach(c => add(`Cum se simte un copil care ${c}?`)));
// Etichetele emoțiilor (utile pentru recitire viitoare)
EMOTIONS.forEach(e => add(e.label));

// Scenarii sociale (întrebarea)
SOCIAL.forEach(s => add(s.q));

// Secvențe: anunț rutină + „Întâi <pas>"
ROUTINES.forEach(r => { add(`Pune pașii în ordine. ${r.name}`); r.steps.forEach(st => add(`Întâi ${st.t}`)); });

// Cuvinte din tabla de comunicare (AAC)
AAC.forEach(cat => cat.words.forEach(w => add(w.w)));

// --- Matematică: numere 0..100 + operatori (rostite în secvență de speakSeq) ---
for (let i = 0; i <= 100; i++) add(String(i));
['Cât fac', 'plus', 'minus', 'ori', 'împărțit la'].forEach(add);
['Câte sunt în total?', 'Câte rămân?', 'Câte sunt în fiecare grupă?'].forEach(add);

// --- Alfabet ---
add('Alege litera potrivită.');
add('Găsește aceeași literă, dar mică.');
ALPHABET.forEach(a => add(`Cu ce literă începe ${a.w}?`));
[...new Set(ALPHABET.map(a => a.l))].forEach(l => add(`Alege obiectul care începe cu litera ${l}.`));

// --- Culori ---
add('Ce culoare este?'); add('Alege culoarea potrivită.');
COLORS.forEach(c => add(c.name));

// --- Forme ---
add('Ce formă este?'); add('Alege forma potrivită.');
SHAPES.forEach(s => add(s.name));

// --- Jocuri noi (ceas, comparare, ordonare, intrus, opuse, perechi) ---
['Cât e ceasul?', 'Unde sunt mai multe?', 'Care nu se potrivește?',
 'Care e opusul?', 'Atinge numerele de la mic la mare.', 'Găsește perechile la fel.'].forEach(add);

// --- Materii școlare (clasele 1-4): prompturi + cuvinte pentru silabe/citire ---
['Ce număr este?', 'Ce semn se potrivește?', 'Ce număr lipsește?', 'Câți lei sunt?',
 'Unde trăiește?', 'În ce anotimp?', 'Ce parte a corpului este?'].forEach(add);
WORDS.forEach(w => { add(`Câte silabe are cuvântul ${w.w}?`); add(w.w); });

// --- Istorie ---
['Ce simbol național este?', 'Care e din trecut?'].forEach(add);
PEOPLE.forEach(p => add(p.q));

// --- Episoade de explorat (Științe): instrucțiuni + narațiune (trage-și-plasează) ---
[
  'Alege o oprire pe hartă.',
  'Trage fiecare animal la casa lui.',
  'Trage fiecare lucru la anotimpul lui.',
  'Trage hrana la animalul potrivit.',
  'Pune fiecare gunoi în coșul potrivit.',
  'Bună! Fiecare animal are casa lui. Hai să le ducem acasă!',
  'Fiecare lucru vine cu anotimpul lui. Unde se potrivește?',
  'Iepurele mănâncă plante, leul mănâncă carne. Dă-le de mâncare!',
  'Hai să păstrăm parcul curat! Fiecare gunoi are coșul lui.',
  // Probleme cu text + joc de grupat
  'Citește problema și alege răspunsul.',
  'Trage fiecare lucru în grupa potrivită.',
  // Episod Istorie („Călătorie în timp")
  'Trage fiecare lucru: din trecut sau de acum.',
  'Trage simbolurile țării separat de obiectele obișnuite.',
  'Bunicii trăiau altfel. Ce e din trecut și ce e de acum?',
  'Țara are simbolurile ei. Care e simbol și care e un obiect obișnuit?',
  'Demult, veștile mergeau încet. Ce e din trecut și ce folosim acum?',
  // Română avansată (cls 3-4)
  'Ce fel de cuvânt este?',
  'Cum spui la mai multe?',
  // Episod Emoții & viață („O zi bună")
  'Trage fiecare față la emoția potrivită.',
  'Trage mâncarea: sănătoasă sau doar câteodată.',
  'Trage fiecare lucru: sigur sau cu grijă.',
  'Toți avem emoții. Hai să potrivim fața cu ce simte.',
  'Ce mâncăm des și ce doar câteodată?',
  'Unele lucruri cer grijă. Ce e sigur și ce atingem doar cu un adult?'
].forEach(add);

const texts = [...set];

// Lista de generat: româna (Alina) + cuvintele englezești (voce englezească).
const items = [
  ...texts.map(t => ({ text: t, voice: VOICE, rate: RATE })),
  ...[...new Set(ENGLISH_WORDS)].map(t => ({ text: t, voice: EN_VOICE, rate: '+0%' }))
];
console.log(`Generez ${items.length} clipuri (${texts.length} RO + engleză)…`);

// Incremental: nu ștergem; sărim peste clipurile deja generate (rezistent la întreruperi).
fs.mkdirSync(OUT, { recursive: true });

const manifest = {};
let n = 0, made = 0;
for (const it of items) {
  n++;
  const file = 'v' + String(n).padStart(3, '0') + '.mp3';
  const outPath = path.join(OUT, file);
  manifest[it.text] = file;
  if (fs.existsSync(outPath) && fs.statSync(outPath).size > 200) continue; // deja există
  execFileSync('python3', [
    '-m', 'edge_tts',
    '--voice', it.voice,
    '--rate=' + it.rate,
    '--text', it.text,
    '--write-media', outPath
  ], { stdio: 'ignore' });
  made++;
  if (made % 20 === 0) console.log(`  generate ${made}…`);
}
console.log(`  (${made} clipuri noi, restul deja existau)`);

// Scrie manifestul ca modul ES importabil din interfață.
const js = '// Generat automat de tools/gen-voice.mjs — NU edita manual.\n' +
  'export const VOICE = ' + JSON.stringify(manifest, null, 2) + ';\n';
fs.writeFileSync(path.join(OUT, 'manifest.js'), js, 'utf8');

console.log(`Gata: ${n} fișiere în src/audio-ro/ + manifest.js`);

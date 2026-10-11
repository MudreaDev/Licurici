// Generează clipurile de voce lipsă (ADR-016) și actualizează manifestul.
//
//   cd packages/licurici_core && dart run tool/voice_coverage.dart --write   # 1. ce lipsește
//   node tools/gen-voice/gen-voice.mjs                                       # 2. generează
//   node tools/gen-voice/gen-voice.mjs --toate                               # regenerează TOT (altă voce)
//
// Surse (în ordinea preferinței):
//   - Azure AI Speech (oficial): setează AZURE_SPEECH_KEY și AZURE_SPEECH_REGION.
//   - edge-tts (aceeași voce neurală, fără cheie): `python -m pip install --user edge-tts`
//     (alt interpretor: PYTHON=py node tools/gen-voice/gen-voice.mjs).
// Se trimit DOAR texte fixe din joc — niciodată date ale copilului. Aplicația rămâne offline:
// clipurile se împachetează în `packages/game_content/audio/ro/`.
//
// `--toate` rescrie fiecare clip românesc pe loc (aceleași nume de fișiere, manifestul nu se
// schimbă), ca toată aplicația să aibă o singură voce. Se poate relua: frazele deja refăcute cu
// setările de acum sunt notate în `regenerat.txt` și sunt sărite.
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const DIR = path.join(ROOT, 'packages', 'game_content', 'audio', 'ro');
const MANIFEST = path.join(DIR, 'voice.json');
const MISSING = path.join(DIR, 'lipsa.txt');
const REDONE = path.join(DIR, 'regenerat.txt');

// Vocea aleasă (sesiunea 11, mostra 03): Alina, puțin mai rar și puțin mai înaltă — mai caldă,
// mai ușor de urmărit pentru copiii mici. Aceeași peste tot (consecvență, ADR-016).
const VOICE = 'ro-RO-AlinaNeural';
const RATE = '-5%';
const PITCH = '+15Hz';
// Frazele cu prefixul „en:” (jocul Engleză) se rostesc cu o voce englezească de copil, fără prefix.
const VOICE_EN = 'en-US-AnaNeural';
const voiceOf = (text) =>
  text.startsWith('en:')
    ? { voice: VOICE_EN, lang: 'en-US', text: text.slice(3), rate: '+0%', pitch: '+0Hz' }
    : { voice: VOICE, lang: 'ro-RO', text, rate: RATE, pitch: PITCH };
// Setările de acum: un clip refăcut cu alte setări se reface din nou.
const SETTINGS = `${VOICE} ${RATE} ${PITCH}`;

const all = process.argv.includes('--toate');
const manifest = JSON.parse(fs.readFileSync(MANIFEST, 'utf8'));

let todo;
let redone = new Set();
if (all) {
  if (fs.existsSync(REDONE)) {
    const [head, ...lines] = fs.readFileSync(REDONE, 'utf8').split('\n');
    if (head === SETTINGS) redone = new Set(lines.filter(Boolean));
  }
  todo = Object.keys(manifest).filter((t) => !t.startsWith('en:') && !redone.has(t));
} else {
  const wanted = fs.existsSync(MISSING)
    ? fs.readFileSync(MISSING, 'utf8').split('\n').map((s) => s.trim()).filter(Boolean)
    : [];
  todo = wanted.filter((t) => !manifest[t]);
}
if (!todo.length) {
  console.log('Nimic de generat.');
  process.exit(0);
}

// Numerotare continuă: v001.mp3, v002.mp3 …
let next = Math.max(0, ...Object.values(manifest).map((f) => Number(/v(\d+)\.mp3/.exec(f)?.[1] ?? 0))) + 1;
const fileName = () => `v${String(next++).padStart(3, '0')}.mp3`;

const escapeXml = (s) => s.replace(/[<>&'"]/g, (c) => ({ '<': '&lt;', '>': '&gt;', '&': '&amp;', "'": '&apos;', '"': '&quot;' })[c]);

async function azure(phrase, out) {
  const region = process.env.AZURE_SPEECH_REGION ?? 'westeurope';
  const v = voiceOf(phrase);
  const ssml = `<speak version="1.0" xml:lang="${v.lang}"><voice name="${v.voice}"><prosody rate="${v.rate}" pitch="${v.pitch}">${escapeXml(v.text)}</prosody></voice></speak>`;
  const res = await fetch(`https://${region}.tts.speech.microsoft.com/cognitiveservices/v1`, {
    method: 'POST',
    headers: {
      'Ocp-Apim-Subscription-Key': process.env.AZURE_SPEECH_KEY,
      'Content-Type': 'application/ssml+xml',
      'X-Microsoft-OutputFormat': 'audio-24khz-48kbitrate-mono-mp3',
    },
    body: ssml,
  });
  if (!res.ok) throw new Error(`Azure ${res.status}: ${await res.text()}`);
  fs.writeFileSync(out, Buffer.from(await res.arrayBuffer()));
}

const run = promisify(execFile);

async function edgeTts(phrase, out) {
  const v = voiceOf(phrase);
  await run(
    process.env.PYTHON ?? 'python',
    ['-m', 'edge_tts', '--voice', v.voice, `--rate=${v.rate}`, `--pitch=${v.pitch}`, '--text', v.text, '--write-media', out],
    { windowsHide: true },
  );
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const useAzure = Boolean(process.env.AZURE_SPEECH_KEY);

/** Un clip, cu până la 4 încercări (serviciul refuză uneori cereri dese). */
async function synthesize(text, out) {
  for (let attempt = 1; ; attempt++) {
    try {
      if (useAzure) await azure(text, out);
      else await edgeTts(text, out);
      if (fs.statSync(out).size === 0) throw new Error('clip gol');
      return;
    } catch (e) {
      // Un clip eșuat nu lasă un fișier gol în urmă.
      fs.rmSync(out, { force: true });
      if (attempt >= 4) throw e;
      await sleep(1500 * attempt);
    }
  }
}

console.log(
  `${all ? 'Regenerez' : 'Generez'} ${todo.length} clipuri cu ${useAzure ? 'Azure AI Speech' : 'edge-tts'} (${SETTINGS})…`,
);
if (all && !redone.size) fs.writeFileSync(REDONE, `${SETTINGS}\n`);
let done = 0;
// Câteva clipuri deodată (fiecare pornește un proces): de ~4 ori mai repede. La clipurile noi,
// numele se dau înainte, în ordine.
const CONCURRENCY = Number(process.env.VOICE_JOBS ?? 4);
const jobs = todo.map((text) => ({ text, file: all ? manifest[text] : fileName() }));
async function one({ text, file }) {
  const out = path.join(DIR, file);
  // La regenerare, clipul nou se scrie alături și îl înlocuiește pe cel vechi doar dacă a reușit.
  const tmp = all ? `${out}.nou.mp3` : out;
  try {
    await synthesize(text, tmp);
    if (all) {
      fs.renameSync(tmp, out);
      fs.appendFileSync(REDONE, `${text}\n`);
    } else {
      manifest[text] = file;
      // Salvăm după fiecare clip: o întrerupere nu pierde ce s-a generat deja.
      fs.writeFileSync(MANIFEST, JSON.stringify(manifest, null, 1) + '\n');
    }
    done++;
    if (all && done % 100 === 0) console.log(`  … ${done}/${todo.length}`);
  } catch (e) {
    console.error(`  ✗ „${text}”: ${e.message}`);
  }
}
await Promise.all(
  Array.from({ length: CONCURRENCY }, async () => {
    while (jobs.length) await one(jobs.shift());
  }),
);
console.log(`Gata: ${done}/${todo.length}.`);
if (all && done === todo.length) fs.rmSync(REDONE, { force: true });

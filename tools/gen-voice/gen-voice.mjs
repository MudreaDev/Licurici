// Generează clipurile de voce lipsă (ADR-016) și actualizează manifestul.
//
//   cd packages/licurici_core && dart run tool/voice_coverage.dart --write   # 1. ce lipsește
//   node tools/gen-voice/gen-voice.mjs                                       # 2. generează
//
// Surse (în ordinea preferinței):
//   - Azure AI Speech (oficial): setează AZURE_SPEECH_KEY și AZURE_SPEECH_REGION.
//   - edge-tts (aceeași voce neurală, fără cheie): `python -m pip install --user edge-tts`.
// Se trimit DOAR texte fixe din joc — niciodată date ale copilului. Aplicația rămâne offline:
// clipurile se împachetează în `packages/game_content/audio/ro/`.
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const DIR = path.join(ROOT, 'packages', 'game_content', 'audio', 'ro');
const MANIFEST = path.join(DIR, 'voice.json');
const MISSING = path.join(DIR, 'lipsa.txt');
const VOICE = 'ro-RO-AlinaNeural';
const RATE = '+0%';

const manifest = JSON.parse(fs.readFileSync(MANIFEST, 'utf8'));
const wanted = fs.existsSync(MISSING)
  ? fs.readFileSync(MISSING, 'utf8').split('\n').map((s) => s.trim()).filter(Boolean)
  : [];
const todo = wanted.filter((t) => !manifest[t]);
if (!todo.length) {
  console.log('Nimic de generat.');
  process.exit(0);
}

// Numerotare continuă: v001.mp3, v002.mp3 …
let next = Math.max(0, ...Object.values(manifest).map((f) => Number(/v(\d+)\.mp3/.exec(f)?.[1] ?? 0))) + 1;
const fileName = () => `v${String(next++).padStart(3, '0')}.mp3`;

const escapeXml = (s) => s.replace(/[<>&'"]/g, (c) => ({ '<': '&lt;', '>': '&gt;', '&': '&amp;', "'": '&apos;', '"': '&quot;' })[c]);

async function azure(text, out) {
  const region = process.env.AZURE_SPEECH_REGION ?? 'westeurope';
  const ssml = `<speak version="1.0" xml:lang="ro-RO"><voice name="${VOICE}"><prosody rate="${RATE}">${escapeXml(text)}</prosody></voice></speak>`;
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

function edgeTts(text, out) {
  execFileSync('python', ['-m', 'edge_tts', '--voice', VOICE, `--rate=${RATE}`, '--text', text, '--write-media', out], {
    stdio: 'ignore',
  });
}

const useAzure = Boolean(process.env.AZURE_SPEECH_KEY);
console.log(`Generez ${todo.length} clipuri cu ${useAzure ? 'Azure AI Speech' : 'edge-tts'} (${VOICE})…`);
let done = 0;
for (const text of todo) {
  const file = fileName();
  const out = path.join(DIR, file);
  try {
    if (useAzure) await azure(text, out);
    else edgeTts(text, out);
    manifest[text] = file;
    done++;
    // Salvăm după fiecare clip: o întrerupere nu pierde ce s-a generat deja.
    fs.writeFileSync(MANIFEST, JSON.stringify(manifest, null, 1) + '\n');
  } catch (e) {
    console.error(`  ✗ „${text}”: ${e.message}`);
  }
}
console.log(`Gata: ${done}/${todo.length}.`);

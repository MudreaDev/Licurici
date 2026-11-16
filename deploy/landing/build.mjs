// APK-ul este copiat la build; vizitatorii descarcă exclusiv de pe site.
import { cp, mkdir, writeFile } from 'node:fs/promises';
import { createHash } from 'node:crypto';

const root = new URL('./', import.meta.url);
const output = new URL('dist/', root);
const filename = 'licurici-0.1.1-arm64-v8a.apk';
const expectedHash = '7a2817469588e3117d837f18907571f95278e78ffa94543733fd7991201e6dc3';
const response = await fetch(`https://github.com/MudreaDev/Licurici/releases/download/v0.1.1-preview.1/${filename}`, {
  signal: AbortSignal.timeout(180_000),
});
if (!response.ok) throw new Error(`Descărcare APK eșuată: HTTP ${response.status}`);
const apk = Buffer.from(await response.arrayBuffer());
if (apk.length !== 88251748 || createHash('sha256').update(apk).digest('hex') !== expectedHash) {
  throw new Error('APK-ul nu corespunde versiunii verificate. Publicarea este oprită.');
}
await mkdir(new URL('descarcari/', output), { recursive: true });
for (const entry of ['index.html', 'style.css', 'app.js', 'assets', 'vendor']) {
  await cp(new URL(entry, root), new URL(entry, output), { recursive: true });
}
await writeFile(new URL(`descarcari/${filename}`, output), apk);
console.log(`Site pregătit; ${filename}: ${apk.length} octeți, SHA-256 verificat.`);

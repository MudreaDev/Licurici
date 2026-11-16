// Verificare fără dependențe: resurse livrate, ancore, referințe CSS și configurație.
import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
const root = fileURLToPath(new URL('../../deploy/landing/', import.meta.url));
const html = fs.readFileSync(path.join(root, 'index.html'), 'utf8');
const css = fs.readFileSync(path.join(root, 'style.css'), 'utf8');
const js = fs.readFileSync(path.join(root, 'app.js'), 'utf8');
const ids = [...html.matchAll(/\bid="([^"]+)"/g)].map(m => m[1]);
assert.equal(ids.length, new Set(ids).size, 'ID duplicat');
const refs = [...html.matchAll(/(?:src|href)="([^"]+)"/g)].map(m => m[1]);
for (const ref of refs) {
  if (ref === '#') continue;
  if (ref.startsWith('/descarcari/')) {
    const apk = fs.readFileSync(path.join(root, 'dist', ref.slice(1)));
    assert.equal(crypto.createHash('sha256').update(apk).digest('hex'), '7a2817469588e3117d837f18907571f95278e78ffa94543733fd7991201e6dc3');
    continue;
  }
  if (ref.startsWith('#')) assert(ids.includes(ref.slice(1)), `Ancoră absentă: ${ref}`);
  else if (!ref.startsWith('https://')) assert(fs.existsSync(path.join(root, ref)), `Resursă absentă: ${ref}`);
}
for (const match of css.matchAll(/url\(['"]?([^)'"\s]+)/g)) {
  assert(fs.existsSync(path.join(root, match[1])), `Resursă CSS absentă: ${match[1]}`);
}
for (const name of ['home', 'emotions', 'language', 'tower', 'mirror', 'painting', 'aquarium']) {
  const file = fs.readFileSync(path.join(root, `assets/${name}.png`));
  assert.equal(file.subarray(0, 8).toString('hex'), '89504e470d0a1a0a', `PNG invalid: ${name}`);
  if (name !== 'aquarium') {
    assert.equal(file.readUInt32BE(16), 844);
    assert.equal(file.readUInt32BE(20), 390);
  }
}
assert.equal(fs.readFileSync(path.join(root, 'assets/social.jpg')).subarray(0, 3).toString('hex'), 'ffd8ff');
assert(html.includes('lang="ro"'));
assert(html.includes('Proiect de licență'));
assert(html.includes('<dd>Mihail Musteața</dd>'));
assert.equal((html.match(/class="splide__slide"/g) || []).length, 6);
assert(!js.includes('createCarousel'));
const vendor = JSON.parse(fs.readFileSync(path.join(root, 'vendor/manifest.json'), 'utf8'));
assert.equal(vendor.version, '4.1.4');
for (const [name, hash] of Object.entries(vendor.sha256)) {
  assert.equal(crypto.createHash('sha256').update(fs.readFileSync(path.join(root, 'vendor', name))).digest('hex'), hash);
}
assert(!/de master|TEZĂ DE MASTER/.test(html));
for(const match of js.matchAll(/from ['"]\.\/([^'"]+)/g)) assert(fs.existsSync(path.join(root,match[1])));
assert.equal((html.match(/<h1>/g) || []).length, 1);
assert(css.includes('prefers-reduced-motion'));
assert(!/<form\b|<iframe\b/.test(html));
assert(!/fetch\(|XMLHttpRequest|localStorage|document\.cookie/.test(js));
const config = JSON.parse(fs.readFileSync(path.join(root, 'vercel.json'), 'utf8'));
assert.equal(config.framework, null);
assert.equal(config.outputDirectory, 'dist');
assert.equal(config.buildCommand, 'node build.mjs');
assert(!html.includes('github.com'));
assert(html.includes('download="licurici-0.1.1-arm64-v8a.apk"'));
assert.equal(config.installCommand, '');
console.log('OK: ancore, resurse HTML/CSS/JS, 7 PNG + JPEG social, dimensiuni capturi, licență și configurație statică.');

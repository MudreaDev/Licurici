// Rulare locală a versiunii de test, ca pe Vercel: panoul din public/, API-ul pe /api/v1 (datele
// în memorie) și pagina de cod pe /c/COD.
//
//   node dev.js [port]      (implicit 5175; după `bash build.sh` sau un build local în public/)
import { createServer } from 'node:http';
import { readFile, stat } from 'node:fs/promises';
import { extname, join, normalize } from 'node:path';
import { fileURLToPath } from 'node:url';

import { createApp } from './lib/app.js';
import { memoryStore } from './lib/store.js';

const port = Number(process.argv[2] ?? 5175);
const root = join(fileURLToPath(new URL('.', import.meta.url)), 'public');
const app = createApp({ store: memoryStore(), secret: 'doar-local-nu-in-productie', publicUrl: `http://localhost:${port}` });
const types = { '.html': 'text/html; charset=utf-8', '.js': 'text/javascript', '.mjs': 'text/javascript', '.json': 'application/json', '.wasm': 'application/wasm', '.png': 'image/png', '.webp': 'image/webp', '.svg': 'image/svg+xml', '.ttf': 'font/ttf', '.otf': 'font/otf', '.mp3': 'audio/mpeg', '.wav': 'audio/wav' };

createServer(async (req, res) => {
  const url = new URL(req.url, 'http://localhost');
  if (url.pathname.startsWith('/api/v1/')) {
    let raw = '';
    for await (const chunk of req) raw += chunk;
    let body;
    try {
      body = raw ? JSON.parse(raw) : undefined;
    } catch {
      body = undefined;
    }
    const out = await app({ method: req.method, path: url.pathname.slice('/api/v1'.length), headers: req.headers, body });
    res.writeHead(out.status, { 'content-type': 'application/json' });
    res.end(out.body == null ? '' : JSON.stringify(out.body));
    return;
  }
  let file = /^\/c\/[A-Za-z0-9-]+\/?$/.test(url.pathname) ? '/c.html' : decodeURIComponent(url.pathname);
  if (file.endsWith('/')) file += 'index.html';
  const path = normalize(join(root, file));
  if (!path.startsWith(root)) {
    res.writeHead(403).end();
    return;
  }
  try {
    if (!(await stat(path)).isFile()) throw new Error('nu e fișier');
    res.writeHead(200, { 'content-type': types[extname(path)] ?? 'application/octet-stream' });
    res.end(await readFile(path));
  } catch {
    res.writeHead(404).end('Nu există.');
  }
}).listen(port, () => console.log(`Licurici (test Vercel) pe http://localhost:${port}`));

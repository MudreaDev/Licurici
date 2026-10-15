// Funcția Vercel pentru tot API-ul (`/api/v1/*` → aici, prin rescrierea din vercel.json).
import { createApp } from '../lib/app.js';
import { blobStore, memoryStore } from '../lib/store.js';

let app;

async function getApp() {
  if (app) return app;
  // Fără store Blob legat (ex. `vercel dev` fără variabile), datele stau în memorie.
  const store = process.env.BLOB_READ_WRITE_TOKEN || process.env.BLOB_STORE_ID ? await blobStore() : memoryStore();
  const host = process.env.PUBLIC_URL || (process.env.VERCEL_PROJECT_PRODUCTION_URL ? `https://${process.env.VERCEL_PROJECT_PRODUCTION_URL}` : '');
  app = createApp({ store, secret: process.env.AUTH_SECRET, publicUrl: host });
  return app;
}

export default async function handler(req, res) {
  const url = new URL(req.url, 'http://localhost');
  const raw = url.searchParams.get('__path') ?? url.pathname.replace(/^\/api\/v1/, '');
  const path = `/${raw.replace(/^\/+/, '')}`.replace(/\/+$/, '') || '/';
  let body = req.body;
  if (typeof body === 'string' && body) {
    try {
      body = JSON.parse(body);
    } catch {
      body = undefined;
    }
  }
  const out = await (await getApp())({ method: req.method, path, headers: req.headers, body });
  res.setHeader('cache-control', 'no-store');
  res.setHeader('x-content-type-options', 'nosniff');
  if (out.status === 204 || out.body == null) {
    res.status(out.status).end();
    return;
  }
  res.status(out.status).json(out.body);
}

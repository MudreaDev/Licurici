// Stocarea „bazei de date simple” a versiunii de test pe Vercel: documente JSON.
//
// - În producție (pe Vercel): Vercel Blob, cu acces **privat** (datele copiilor nu au URL public);
//   citirea ocolește cache-ul CDN (`useCache: false`), deci fiecare cerere vede ultima scriere.
// - Local și în teste: în memorie.
//
// Când trecem pe stiva completă (NestJS + PostgreSQL, README §4), aceleași rute se mută pe backend;
// documentele de aici se pot importa o dată (sunt JSON simplu).

export function memoryStore() {
  const docs = new Map();
  return {
    kind: 'memory',
    async get(path) {
      const v = docs.get(path);
      return v === undefined ? null : structuredClone(v);
    },
    async put(path, value) {
      docs.set(path, structuredClone(value));
    },
    async del(path) {
      docs.delete(path);
    },
    async list(prefix) {
      return [...docs.keys()].filter((k) => k.startsWith(prefix)).sort();
    },
    docs,
  };
}

export async function blobStore() {
  const { get, put, del, list } = await import('@vercel/blob');
  const key = (path) => `db/${path}.json`;
  return {
    kind: 'blob',
    async get(path) {
      const r = await get(key(path), { access: 'private', useCache: false });
      if (!r) return null;
      const text = await new Response(r.stream).text();
      return JSON.parse(text);
    },
    async put(path, value) {
      await put(key(path), JSON.stringify(value), {
        access: 'private',
        allowOverwrite: true,
        addRandomSuffix: false,
        contentType: 'application/json',
        cacheControlMaxAge: 60,
      });
    },
    async del(path) {
      await del(key(path)).catch(() => {});
    },
    async list(prefix) {
      const out = [];
      let cursor;
      do {
        const r = await list({ prefix: key(prefix).replace(/\.json$/, ''), cursor, limit: 1000 });
        for (const b of r.blobs) out.push(b.pathname.slice('db/'.length, -'.json'.length));
        cursor = r.hasMore ? r.cursor : undefined;
      } while (cursor);
      return out.sort();
    },
  };
}

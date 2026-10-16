// API-ul versiunii de test pe Vercel (aceleași rute ca backend-ul NestJS, README §12, pentru ce
// folosesc panoul și tableta), plus legarea tabletei de un copil printr-un cod dat de terapeut.
//
// Cine poate ce:
// - THERAPIST: creează copii (porecla, anul nașterii, observații), primește pentru fiecare un cod
//   de legare de unică folosință, vede sesiunile, alege planul (jocuri, niveluri, muzică).
// - PARENT: cont propriu (fără copii aici, în versiunea de test).
// - DEVICE: tableta legată prin cod — vede doar copilul ei: trimite sesiunile și preia planul.
//
// Fără date personale în jurnale; copilul are doar poreclă și anul nașterii (README §13.3).

import { createHash, createHmac, randomBytes, scryptSync, timingSafeEqual, randomUUID } from 'node:crypto';

export class HttpError extends Error {
  constructor(status, message, details = []) {
    super(message);
    this.status = status;
    this.details = details;
  }
}

const ACCESS_TTL_S = 15 * 60;
const REFRESH_TTL_S = 90 * 24 * 3600;
const LOCK_AFTER = 5;
const LOCK_MS = 15 * 60 * 1000;
// Fără litere care se confundă (0/O, 1/I/L): codul se citește și se tastează ușor.
const CODE_ALPHABET = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

const sha = (s) => createHash('sha256').update(s).digest('hex');
const b64u = (buf) => Buffer.from(buf).toString('base64url');

export function hashPassword(password) {
  const salt = randomBytes(16);
  const hash = scryptSync(password, salt, 32, { N: 16384, r: 8, p: 1 });
  return `scrypt$${b64u(salt)}$${b64u(hash)}`;
}

export function verifyPassword(password, stored) {
  const [kind, salt, hash] = String(stored).split('$');
  if (kind !== 'scrypt') return false;
  const want = Buffer.from(hash, 'base64url');
  const got = scryptSync(password, Buffer.from(salt, 'base64url'), want.length, { N: 16384, r: 8, p: 1 });
  return timingSafeEqual(want, got);
}

export function newCode(random = randomBytes) {
  const bytes = random(8);
  let s = '';
  for (let i = 0; i < 8; i++) s += CODE_ALPHABET[bytes[i] % CODE_ALPHABET.length];
  return `${s.slice(0, 4)}-${s.slice(4)}`;
}

/** Codul din ce a scris părintele: cod simplu sau legătura întreagă (…/c/ABCD-2345). */
export function normalizeCode(input) {
  const raw = String(input ?? '').trim().toUpperCase();
  const fromLink = raw.match(/\/C\/([A-Z0-9-]+)\/?$/);
  const s = (fromLink ? fromLink[1] : raw).replace(/[^A-Z0-9]/g, '');
  return s.length === 8 ? `${s.slice(0, 4)}-${s.slice(4)}` : null;
}

const GAME_ID = /^[a-z0-9-]{2,40}$/;
const MUSIC_TRACKS = ['all', 'lumini', 'valuri', 'gradina'];

function cleanNumbers(raw, min, max) {
  const out = {};
  if (!raw || typeof raw !== 'object') return out;
  for (const [k, v] of Object.entries(raw)) {
    if (!GAME_ID.test(k) || !Number.isInteger(v) || v < min || v > max) throw new HttpError(400, 'Valori nevalide în plan.');
    out[k] = v;
  }
  if (Object.keys(out).length > 200) throw new HttpError(400, 'Prea multe valori în plan.');
  return out;
}

function cleanPlan(body) {
  if (!body || !Array.isArray(body.hiddenGames)) throw new HttpError(400, 'Lipsește lista de jocuri.');
  const hiddenGames = [...new Set(body.hiddenGames)].sort();
  if (hiddenGames.length > 200 || !hiddenGames.every((g) => typeof g === 'string' && GAME_ID.test(g))) {
    throw new HttpError(400, 'Listă de jocuri nevalidă.');
  }
  const avoid = [...new Set(body.avoid ?? [])].sort();
  if (avoid.length > 50 || !avoid.every((a) => typeof a === 'string' && /^[a-z-]{2,30}$/.test(a))) {
    throw new HttpError(400, 'Imagini de evitat nevalide.');
  }
  let music;
  if (body.music != null) {
    const m = body.music;
    if (typeof m !== 'object' || typeof m.on !== 'boolean' || !MUSIC_TRACKS.includes(m.track) || Object.keys(m).length !== 2) {
      throw new HttpError(400, 'Muzică nevalidă.');
    }
    music = { on: m.on, track: m.track };
  }
  const levels = cleanNumbers(body.levels, 1, 40);
  const maxLevels = cleanNumbers(body.maxLevels, 1, 40);
  for (const [g, l] of Object.entries(levels)) {
    if (maxLevels[g] != null && l > maxLevels[g]) throw new HttpError(400, 'Nivelul de pornire nu poate fi peste plafon.', ['levels']);
  }
  return { hiddenGames, levels, maxLevels, rounds: cleanNumbers(body.rounds, 3, 12), avoid, music };
}

function emptyPlan() {
  return { hiddenGames: [], levels: {}, maxLevels: {}, rounds: {}, avoid: [], updatedAt: null, updatedBy: null, history: [] };
}

function childView(c) {
  return {
    id: c.id,
    nickname: c.nickname,
    avatar: c.avatar ?? '🙂',
    birthYear: c.birthYear ?? null,
    notes: c.notes ?? '',
    goals: c.goals ?? '',
    createdAt: c.createdAt,
    linked: (c.devices ?? 0) > 0,
    linkedAt: c.linkedAt ?? null,
    devices: c.devices ?? 0,
    lastSyncAt: c.lastSyncAt ?? null,
    playingSince: c.playingAt && Date.now() - Date.parse(c.playingAt) < 20 * 60 * 1000 ? c.playingAt : null,
  };
}

/**
 * [store] — documentele (vezi store.js); [secret] — cheia de semnare a tokenurilor;
 * [publicUrl] — adresa panoului (pentru legăturile de legare); [now] — ceasul (teste).
 */
export function createApp({ store, secret, publicUrl = '', now = () => new Date(), random = randomBytes }) {
  if (!secret || secret.length < 16) throw new Error('AUTH_SECRET lipsește sau e prea scurt');

  const sign = (payload) => {
    const body = b64u(JSON.stringify(payload));
    return `${body}.${b64u(createHmac('sha256', secret).update(body).digest())}`;
  };
  const verify = (token) => {
    const [body, mac] = String(token).split('.');
    if (!body || !mac) return null;
    const want = createHmac('sha256', secret).update(body).digest();
    const got = Buffer.from(mac, 'base64url');
    if (got.length !== want.length || !timingSafeEqual(got, want)) return null;
    const p = JSON.parse(Buffer.from(body, 'base64url').toString());
    return p.exp * 1000 > now().getTime() ? p : null;
  };

  async function issue(principal) {
    const refresh = b64u(random(32));
    await store.put(`refresh/${sha(refresh)}`, { ...principal, exp: now().getTime() + REFRESH_TTL_S * 1000 });
    return {
      accessToken: sign({ ...principal, exp: Math.floor(now().getTime() / 1000) + ACCESS_TTL_S }),
      refreshToken: refresh,
      expiresIn: ACCESS_TTL_S,
    };
  }

  async function principalOf(headers) {
    const h = headers.authorization ?? headers.Authorization ?? '';
    const m = /^Bearer (.+)$/.exec(h);
    const p = m && verify(m[1]);
    if (!p) throw new HttpError(401, 'Autentificare necesară.');
    if (p.role !== 'DEVICE') {
      const u = await store.get(`users/${p.sub}`);
      if (!u || u.deletedAt) throw new HttpError(401, 'Contul nu mai există.');
      p.user = u;
    }
    return p;
  }

  async function userByEmail(email) {
    const ref = await store.get(`emails/${sha(email)}`);
    return ref ? store.get(`users/${ref.id}`) : null;
  }

  /** Copilul [id], dacă [p] are voie la el (altfel 404, ca să nu dezvăluie că există). */
  async function childFor(p, id, write = false) {
    const c = await store.get(`children/${id}`);
    const ok = c && !c.deletedAt && (p.role === 'DEVICE' ? p.child === id : p.role === 'THERAPIST' && c.ownerId === p.sub);
    if (!ok) throw new HttpError(404, 'Copilul nu a fost găsit.');
    if (write && p.role === 'DEVICE') throw new HttpError(403, 'Tableta nu poate schimba asta.');
    return c;
  }

  async function newLinkCode(child) {
    if (child.code) await store.del(`codes/${child.code}`);
    let code;
    for (let i = 0; i < 5; i++) {
      code = newCode(random);
      if (!(await store.get(`codes/${code}`))) break;
    }
    await store.put(`codes/${code}`, { childId: child.id, createdAt: now().toISOString() });
    child.code = code;
    return code;
  }

  const linkOf = (code) => ({ code, url: publicUrl ? `${publicUrl.replace(/\/$/, '')}/c/${code}` : `/c/${code}` });

  // ----------------------------------------------------------------------------- rute
  const routes = [];
  const route = (method, pattern, fn) => {
    const keys = [];
    const re = new RegExp(`^${pattern.replace(/:(\w+)/g, (_, k) => (keys.push(k), '([^/]+)'))}$`);
    routes.push({ method, re, keys, fn });
  };

  // `storage`: „blob” = datele rămân; „memory” = Blob-ul nu e legat și datele se pierd la repornire.
  route('GET', '/health', async () => ({ ok: true, storage: store.kind ?? 'memory' }));

  route('POST', '/auth/register', async ({ body }) => {
    const email = String(body?.email ?? '').trim().toLowerCase();
    const password = String(body?.password ?? '');
    const role = body?.role === 'THERAPIST' ? 'THERAPIST' : 'PARENT';
    if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email) || email.length > 200) throw new HttpError(400, 'Adresă de e-mail nevalidă.');
    if (password.length < 10) throw new HttpError(400, 'Parola trebuie să aibă cel puțin 10 caractere.');
    if (await userByEmail(email)) throw new HttpError(409, 'Există deja un cont cu această adresă.');
    const user = { id: randomUUID(), email, role, passwordHash: hashPassword(password), createdAt: now().toISOString(), consents: {} };
    await store.put(`users/${user.id}`, user);
    await store.put(`emails/${sha(email)}`, { id: user.id });
    return { status: 201, body: await issue({ sub: user.id, role }) };
  });

  route('POST', '/auth/login', async ({ body }) => {
    const email = String(body?.email ?? '').trim().toLowerCase();
    const u = await userByEmail(email);
    const bad = new HttpError(401, 'E-mail sau parolă greșite.');
    if (!u || u.deletedAt) throw bad;
    if (u.lockedUntil && Date.parse(u.lockedUntil) > now().getTime()) {
      throw new HttpError(429, 'Prea multe încercări. Încearcă din nou peste 15 minute.');
    }
    if (!verifyPassword(String(body?.password ?? ''), u.passwordHash)) {
      u.failed = (u.failed ?? 0) + 1;
      if (u.failed >= LOCK_AFTER) {
        u.failed = 0;
        u.lockedUntil = new Date(now().getTime() + LOCK_MS).toISOString();
      }
      await store.put(`users/${u.id}`, u);
      throw bad;
    }
    if (u.failed) {
      u.failed = 0;
      await store.put(`users/${u.id}`, u);
    }
    return issue({ sub: u.id, role: u.role });
  });

  route('POST', '/auth/refresh', async ({ body }) => {
    const token = String(body?.refreshToken ?? '');
    const key = `refresh/${sha(token)}`;
    const r = token && (await store.get(key));
    if (!r || r.exp < now().getTime()) throw new HttpError(401, 'Sesiunea a expirat. Autentifică-te din nou.');
    if (r.role === 'DEVICE') {
      const c = await store.get(`children/${r.child}`);
      if (!c || c.deletedAt || (c.deviceEpoch ?? 0) !== (r.epoch ?? 0)) {
        await store.del(key);
        throw new HttpError(401, 'Tableta nu mai e legată de acest copil.');
      }
    } else {
      const u = await store.get(`users/${r.sub}`);
      if (!u || u.deletedAt) throw new HttpError(401, 'Contul nu mai există.');
    }
    await store.del(key); // rotire: fiecare refresh token merge o singură dată
    const { exp: _exp, ...principal } = r;
    return issue(principal);
  });

  route('POST', '/auth/logout', async ({ body }) => {
    if (body?.refreshToken) await store.del(`refresh/${sha(String(body.refreshToken))}`);
    return { status: 204 };
  });

  const notInTest = async () => {
    throw new HttpError(501, 'Nu e disponibil în versiunea de test.');
  };
  route('POST', '/auth/verify-email', notInTest);
  route('POST', '/auth/password/forgot', notInTest);
  route('POST', '/auth/password/reset', notInTest);
  route('POST', '/me/2fa/setup', notInTest);
  route('POST', '/me/2fa/enable', notInTest);
  route('POST', '/me/2fa/disable', notInTest);
  route('POST', '/me/verify-email', async () => ({ status: 204 }));
  route('GET', '/me/2fa', async () => ({ enabled: false }));

  route('GET', '/me', async ({ p }) => {
    if (p.role === 'DEVICE') return { role: 'DEVICE', childId: p.child };
    return { id: p.user.id, email: p.user.email, role: p.user.role, emailVerified: true };
  });

  route('GET', '/consents', async ({ p }) => (p.role === 'DEVICE' ? {} : p.user.consents ?? {}));
  route('POST', '/consents', async ({ p, body }) => {
    if (p.role === 'DEVICE') return {};
    const purpose = String(body?.purpose ?? '');
    if (!/^[A-Z_]{2,30}$/.test(purpose)) throw new HttpError(400, 'Scop nevalid.');
    const u = p.user;
    u.consents = { ...(u.consents ?? {}), [purpose]: body?.granted === true };
    u.consentLog = [...(u.consentLog ?? []), { purpose, granted: body?.granted === true, policyVersion: String(body?.policyVersion ?? ''), at: now().toISOString() }];
    await store.put(`users/${u.id}`, u);
    return u.consents;
  });

  route('GET', '/children', async ({ p }) => {
    if (p.role === 'DEVICE') return [childView(await childFor(p, p.child))];
    if (p.role !== 'THERAPIST') return [];
    const ids = p.user.children ?? [];
    const kids = [];
    for (const id of ids) {
      const c = await store.get(`children/${id}`);
      if (c && !c.deletedAt) kids.push(childView(c));
    }
    return kids;
  });

  route('POST', '/children', async ({ p, body }) => {
    if (p.role !== 'THERAPIST') throw new HttpError(403, 'Doar terapeutul adaugă copii în versiunea de test.');
    const nickname = String(body?.nickname ?? '').trim();
    if (nickname.length < 1 || nickname.length > 40) throw new HttpError(400, 'Porecla trebuie să aibă 1–40 de caractere.');
    const birthYear = body?.birthYear == null || body.birthYear === '' ? null : Number(body.birthYear);
    const year = now().getFullYear();
    if (birthYear != null && (!Number.isInteger(birthYear) || birthYear < year - 18 || birthYear > year)) {
      throw new HttpError(400, 'Anul nașterii nu e valid.');
    }
    const child = {
      id: randomUUID(),
      ownerId: p.sub,
      nickname,
      birthYear,
      notes: String(body?.notes ?? '').slice(0, 2000),
      goals: String(body?.goals ?? '').slice(0, 2000),
      avatar: '🙂',
      createdAt: now().toISOString(),
      devices: 0,
      deviceEpoch: 0,
      plan: emptyPlan(),
    };
    await newLinkCode(child);
    await store.put(`children/${child.id}`, child);
    p.user.children = [...(p.user.children ?? []), child.id];
    await store.put(`users/${p.sub}`, p.user);
    return { status: 201, body: { ...childView(child), ...linkOf(child.code) } };
  });

  route('PATCH', '/children/:id', async ({ p, params, body }) => {
    const c = await childFor(p, params.id, true);
    if (body?.nickname != null) {
      const n = String(body.nickname).trim();
      if (n.length < 1 || n.length > 40) throw new HttpError(400, 'Porecla trebuie să aibă 1–40 de caractere.');
      c.nickname = n;
    }
    if (body?.birthYear !== undefined) c.birthYear = body.birthYear == null || body.birthYear === '' ? null : Number(body.birthYear);
    if (body?.notes != null) c.notes = String(body.notes).slice(0, 2000);
    if (body?.goals != null) c.goals = String(body.goals).slice(0, 2000);
    await store.put(`children/${c.id}`, c);
    return childView(c);
  });

  route('DELETE', '/children/:id', async ({ p, params }) => {
    const c = await childFor(p, params.id, true);
    for (const s of await store.list(`sessions/${c.id}/`)) await store.del(s);
    if (c.code) await store.del(`codes/${c.code}`);
    await store.del(`children/${c.id}`);
    p.user.children = (p.user.children ?? []).filter((x) => x !== c.id);
    await store.put(`users/${p.sub}`, p.user);
    return { purgeAt: now().toISOString() };
  });

  // Legarea tabletei: codul (de unică folosință) și legătura pentru părinte.
  route('GET', '/children/:id/link', async ({ p, params }) => {
    const c = await childFor(p, params.id, true);
    return { ...(c.code ? linkOf(c.code) : { code: null, url: null }), linked: (c.devices ?? 0) > 0, linkedAt: c.linkedAt ?? null };
  });

  // Cod nou; cu `unlink: true`, tabletele legate până acum sunt deconectate (tabletă pierdută).
  route('POST', '/children/:id/link', async ({ p, params, body }) => {
    const c = await childFor(p, params.id, true);
    if (body?.unlink === true) {
      c.deviceEpoch = (c.deviceEpoch ?? 0) + 1;
      c.devices = 0;
      c.linkedAt = null;
    }
    await newLinkCode(c);
    await store.put(`children/${c.id}`, c);
    return { ...linkOf(c.code), linked: (c.devices ?? 0) > 0, linkedAt: c.linkedAt ?? null };
  });

  // Tableta: codul primit de la terapeut → tokenurile tabletei (doar pentru acest copil).
  route('POST', '/device/link', async ({ body }) => {
    const code = normalizeCode(body?.code);
    if (body?.consent !== true) throw new HttpError(400, 'Bifează acordul părintelui pentru trimiterea sesiunilor.');
    const entry = code && (await store.get(`codes/${code}`));
    if (!entry) throw new HttpError(404, 'Codul nu e bun sau a fost deja folosit. Cere terapeutului un cod nou.');
    const c = await store.get(`children/${entry.childId}`);
    if (!c || c.deletedAt) throw new HttpError(404, 'Codul nu e bun sau a fost deja folosit. Cere terapeutului un cod nou.');
    await store.del(`codes/${code}`); // de unică folosință
    c.code = null;
    c.devices = (c.devices ?? 0) + 1;
    c.linkedAt = now().toISOString();
    c.consent = { granted: true, at: c.linkedAt, policyVersion: String(body?.policyVersion ?? '') };
    await store.put(`children/${c.id}`, c);
    const pair = await issue({ sub: `device:${c.id}`, role: 'DEVICE', child: c.id, epoch: c.deviceEpoch ?? 0 });
    return { ...pair, child: { id: c.id, nickname: c.nickname } };
  });

  route('GET', '/children/:id/sessions', async ({ p, params }) => {
    const c = await childFor(p, params.id);
    const out = [];
    for (const key of await store.list(`sessions/${c.id}/`)) {
      const s = await store.get(key);
      if (s) out.push(s);
    }
    return out.sort((a, b) => String(a.record?.start ?? '').localeCompare(String(b.record?.start ?? '')));
  });

  route('POST', '/children/:id/sessions', async ({ p, params, body }) => {
    const c = await childFor(p, params.id);
    const list = Array.isArray(body?.sessions) ? body.sessions : null;
    if (!list || list.length > 50) throw new HttpError(400, 'Lot de sesiuni nevalid.');
    for (const s of list) {
      const id = s?.record?.id;
      if (typeof id !== 'string' || !/^[0-9a-f-]{8,40}$/i.test(id) || typeof s.record !== 'object') {
        throw new HttpError(400, 'Sesiune nevalidă.');
      }
      if (JSON.stringify(s).length > 512 * 1024) throw new HttpError(413, 'Sesiune prea mare.');
      // Idempotent: aceeași sesiune trimisă din nou o înlocuiește (id-ul vine de pe tabletă).
      await store.put(`sessions/${c.id}/${id}`, { id, record: s.record, facts: s.facts ?? {}, receivedAt: now().toISOString() });
    }
    c.lastSyncAt = now().toISOString();
    c.playingAt = null;
    await store.put(`children/${c.id}`, c);
    return { received: list.length };
  });

  route('POST', '/children/:id/presence', async ({ p, params }) => {
    const c = await childFor(p, params.id);
    c.playingAt = now().toISOString();
    await store.put(`children/${c.id}`, c);
    return { status: 204 };
  });

  route('GET', '/children/:id/plan', async ({ p, params }) => {
    const c = await childFor(p, params.id);
    return c.plan ?? emptyPlan();
  });

  route('PUT', '/children/:id/plan', async ({ p, params, body }) => {
    const c = await childFor(p, params.id);
    const clean = cleanPlan(body);
    const previous = c.plan ?? emptyPlan();
    const by = p.role === 'THERAPIST' ? 'THERAPIST' : 'PARENT';
    const at = now().toISOString();
    c.plan = {
      ...clean,
      // De pe tabletă nu se schimbă nivelurile alese de terapeut; muzica rămâne dacă nu vine.
      ...(p.role === 'DEVICE' ? { levels: previous.levels, maxLevels: previous.maxLevels, rounds: previous.rounds } : {}),
      music: clean.music ?? previous.music,
      updatedAt: at,
      updatedBy: by,
      history: [...(previous.history ?? []), { at, by, hidden: clean.hiddenGames.length }].slice(-50),
    };
    if (c.plan.music == null) delete c.plan.music;
    await store.put(`children/${c.id}`, c);
    return c.plan;
  });

  route('GET', '/children/:id/share', async ({ p, params }) => {
    await childFor(p, params.id);
    return [];
  });
  route('GET', '/children/:id/skills', async ({ p, params }) => {
    await childFor(p, params.id);
    return [];
  });
  route('POST', '/children/:id/sessions/:sid/summary', notInTest);
  route('POST', '/children/:id/ask', notInTest);

  route('GET', '/me/export', async ({ p }) => {
    if (p.role === 'DEVICE') throw new HttpError(403, 'Indisponibil pe tabletă.');
    const { passwordHash: _h, ...user } = p.user;
    const children = [];
    for (const id of p.user.children ?? []) {
      const c = await store.get(`children/${id}`);
      if (!c) continue;
      const sessions = [];
      for (const key of await store.list(`sessions/${id}/`)) sessions.push(await store.get(key));
      children.push({ ...childView(c), plan: c.plan, sessions });
    }
    return { exportedAt: now().toISOString(), user, children };
  });

  route('POST', '/me/delete', async ({ p, body }) => {
    if (p.role === 'DEVICE') throw new HttpError(403, 'Indisponibil pe tabletă.');
    if (!verifyPassword(String(body?.password ?? ''), p.user.passwordHash)) throw new HttpError(401, 'Parola nu e corectă.');
    for (const id of p.user.children ?? []) {
      for (const s of await store.list(`sessions/${id}/`)) await store.del(s);
      const c = await store.get(`children/${id}`);
      if (c?.code) await store.del(`codes/${c.code}`);
      await store.del(`children/${id}`);
    }
    await store.del(`emails/${sha(p.user.email)}`);
    await store.del(`users/${p.user.id}`);
    return { purgeAt: now().toISOString() };
  });

  /** O cerere: { method, path (fără /api/v1), headers, body } → { status, body }. */
  return async function handle({ method, path, headers = {}, body }) {
    try {
      const match = routes
        .map((r) => ({ r, m: r.method === method ? r.re.exec(path) : null }))
        .find((x) => x.m);
      if (!match) {
        const any = routes.some((r) => r.re.test(path));
        throw new HttpError(any ? 405 : 404, any ? 'Metodă nepermisă.' : 'Nu există.');
      }
      const params = Object.fromEntries(match.r.keys.map((k, i) => [k, decodeURIComponent(match.m[i + 1])]));
      const open = path.startsWith('/auth/') || path === '/device/link' || path === '/health';
      const p = open ? null : await principalOf(headers);
      const out = await match.r.fn({ p, params, body, headers });
      if (out && typeof out === 'object' && 'status' in out && Object.keys(out).every((k) => k === 'status' || k === 'body')) {
        return { status: out.status, body: out.body ?? null };
      }
      return { status: 200, body: out };
    } catch (e) {
      if (e instanceof HttpError) return { status: e.status, body: { statusCode: e.status, message: e.message, details: e.details } };
      console.error('eroare API', e?.name, e?.message); // fără date personale
      return { status: 503, body: { statusCode: 503, message: 'Serviciul nu e disponibil acum. Încearcă din nou.' } };
    }
  };
}

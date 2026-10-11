// Testul cap-coadă pe stiva Docker reală (README §19, §21): PostgreSQL, Redis, worker, Mailpit.
// Rulat de CI (.github/workflows/ci.yml, job-ul `stack`) și local, după
//   docker compose -f infra/docker-compose.yml up -d --build
//   node tools/e2e/stack.mjs
// Variabile: API (implicit http://localhost:3000), MAILPIT (http://localhost:8025), METRICS_TOKEN.
// Fiecare rulare folosește adrese noi, deci se poate repeta pe aceeași bază de date.
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const API = process.env.API ?? 'http://localhost:3000';
const MAILPIT = process.env.MAILPIT ?? 'http://localhost:8025';
const fixture = JSON.parse(
  readFileSync(fileURLToPath(new URL('../../backend/src/sync/sync-fixture.json', import.meta.url)), 'utf8'),
);
const run = Date.now().toString(36);
const parentEmail = `parinte-${run}@example.com`;
const therapistEmail = `specialist-${run}@example.com`;
const password = 'parola-lunga-e2e-1';

let failures = 0;
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

function check(name, ok, detail = '') {
  console.log(`${ok ? '✓' : '✗'} ${name}${ok || !detail ? '' : ` — ${detail}`}`);
  if (!ok) failures++;
  return ok;
}

async function call(method, path, { token, body, expect } = {}) {
  const res = await fetch(`${API}${path.startsWith('/health') || path === '/metrics' ? '' : '/api/v1'}${path}`, {
    method,
    headers: {
      ...(body ? { 'content-type': 'application/json' } : {}),
      ...(token ? { authorization: `Bearer ${token}` } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  let data = text;
  try {
    data = text ? JSON.parse(text) : null;
  } catch {}
  if (expect !== undefined && res.status !== expect) {
    throw new Error(`${method} ${path}: ${res.status} (așteptat ${expect}) ${text.slice(0, 300)}`);
  }
  return { status: res.status, data };
}

async function until(name, fn, { timeoutMs = 60_000, everyMs = 1000 } = {}) {
  const end = Date.now() + timeoutMs;
  let last;
  while (Date.now() < end) {
    try {
      last = await fn();
      if (last) return last;
    } catch (e) {
      last = e;
    }
    await sleep(everyMs);
  }
  throw new Error(`${name}: timp depășit (${last instanceof Error ? last.message : JSON.stringify(last)})`);
}

/** Legătura de confirmare din e-mailul ajuns în Mailpit pentru [to]. */
async function verificationToken(to) {
  return until(`e-mailul de confirmare pentru ${to}`, async () => {
    const list = await (await fetch(`${MAILPIT}/api/v1/search?query=${encodeURIComponent(`to:${to}`)}`)).json();
    const id = list.messages?.[0]?.ID;
    if (!id) return null;
    const msg = await (await fetch(`${MAILPIT}/api/v1/message/${id}`)).json();
    return /[?&]token=([A-Za-z0-9_%-]+)/.exec(msg.Text ?? msg.HTML ?? '')?.[1];
  });
}

async function login(email) {
  return (await call('POST', '/auth/login', { body: { email, password }, expect: 200 })).data.accessToken;
}

async function main() {
  await until('API gata (/health/ready)', async () => (await call('GET', '/health/ready')).status === 200, {
    timeoutMs: 180_000,
    everyMs: 3000,
  });
  check('API, PostgreSQL, Redis și stocarea răspund', true);

  // Cont nou → e-mail de confirmare prin coada `mail` → worker → Mailpit.
  await call('POST', '/auth/register', { body: { email: parentEmail, password }, expect: 201 });
  const parent = await login(parentEmail);
  const before = await call('POST', '/consents', {
    token: parent,
    body: { purpose: 'SYNC', granted: true, policyVersion: '2026-10' },
  });
  check('acordul e refuzat cât adresa nu e confirmată (403)', before.status === 403, `${before.status}`);
  const token = decodeURIComponent(await verificationToken(parentEmail));
  check('e-mailul de confirmare a ajuns (coada mail → worker → SMTP)', Boolean(token));
  await call('POST', '/auth/verify-email', { body: { token }, expect: 200 });
  const reuse = await call('POST', '/auth/verify-email', { body: { token } });
  check('legătura de confirmare e de unică folosință', reuse.status === 400, `${reuse.status}`);
  for (const purpose of ['SYNC', 'THERAPIST_SHARING']) {
    await call('POST', '/consents', { token: parent, body: { purpose, granted: true, policyVersion: '2026-10' }, expect: 200 });
  }
  check('acordurile se dau după confirmare', true);

  // Sincronizarea de pe tabletă: contractul Dart ↔ TS, idempotentă, pe PostgreSQL real.
  const child = (await call('POST', '/children', { token: parent, body: { nickname: 'Test' }, expect: 201 })).data;
  await call('POST', `/children/${child.id}/sessions`, { token: parent, body: fixture, expect: 200 });
  await call('POST', `/children/${child.id}/sessions`, { token: parent, body: fixture, expect: 200 });
  const sessions = (await call('GET', `/children/${child.id}/sessions`, { token: parent, expect: 200 })).data;
  check(
    `sincronizarea e idempotentă (${fixture.sessions.length} sesiuni după două trimiteri)`,
    sessions.length === fixture.sessions.length,
    `${sessions.length}`,
  );

  // Read model: coada `stats` → worker → child_skill_stats.
  const skills = await until('statisticile pe trepte', async () => {
    const r = await call('GET', `/children/${child.id}/skills`, { token: parent, expect: 200 });
    return r.data.length ? r.data : null;
  });
  check(
    `worker-ul a calculat statisticile pe ${skills.length} trepte`,
    skills.every((s) => s.attempts > 0 && s.accuracy >= 0 && s.accuracy <= 1),
  );

  // Partajarea cu specialistul: doar citire, auditată, vizibilă în exportul părintelui.
  await call('POST', '/auth/register', { body: { email: therapistEmail, password, role: 'THERAPIST' }, expect: 201 });
  const therapist = await login(therapistEmail);
  const hidden = await call('GET', `/children/${child.id}/sessions`, { token: therapist });
  check('specialistul fără partajare primește 404', hidden.status === 404, `${hidden.status}`);
  await call('POST', `/children/${child.id}/share`, { token: parent, body: { email: therapistEmail }, expect: 200 });
  const seen = await call('GET', `/children/${child.id}/sessions`, { token: therapist });
  check('specialistul cu partajare citește sesiunile', seen.status === 200 && seen.data.length > 0, `${seen.status}`);
  const write = await call('POST', `/children/${child.id}/sessions`, { token: therapist, body: fixture });
  check('specialistul nu poate scrie sesiuni (403)', write.status === 403, `${write.status}`);
  const exported = (await call('GET', '/me/export', { token: parent, expect: 200 })).data;
  const accesses = exported.children?.[0]?.accesses ?? [];
  check(
    'exportul părintelui conține sesiunile și accesările specialistului',
    exported.children?.[0]?.sessions?.length === fixture.sessions.length && accesses.some((a) => a.by === therapistEmail),
    JSON.stringify(accesses).slice(0, 200),
  );

  // Ștergerea copilului: acces tăiat imediat.
  await call('DELETE', `/children/${child.id}`, { token: parent, expect: 202 });
  const gone = await call('GET', `/children/${child.id}/sessions`, { token: parent });
  check('după ștergere copilul nu mai e accesibil (404)', gone.status === 404, `${gone.status}`);

  // Metricile (dacă e configurat tokenul).
  if (process.env.METRICS_TOKEN) {
    const res = await fetch(`${API}/metrics`, { headers: { authorization: `Bearer ${process.env.METRICS_TOKEN}` } });
    const text = await res.text();
    check(
      '/metrics numără sesiunile și nu conține id-uri',
      res.status === 200 && /licurici_synced_sessions_total \d/.test(text) && !text.includes(child.id),
      `${res.status}`,
    );
    const open = await fetch(`${API}/metrics`);
    check('/metrics fără token → 404', open.status === 404, `${open.status}`);
  }

  // Refresh tokenul e de unică folosință (Redis real, GETDEL).
  const pair = (await call('POST', '/auth/login', { body: { email: parentEmail, password }, expect: 200 })).data;
  await call('POST', '/auth/refresh', { body: { refreshToken: pair.refreshToken }, expect: 200 });
  const replay = await call('POST', '/auth/refresh', { body: { refreshToken: pair.refreshToken } });
  check('refresh tokenul folosit a doua oară e refuzat (401)', replay.status === 401, `${replay.status}`);
}

main()
  .catch((e) => {
    console.error(`✗ ${e.message}`);
    failures++;
  })
  .finally(() => {
    console.log(failures ? `\n${failures} verificări au eșuat.` : '\nToate verificările au trecut.');
    process.exitCode = failures ? 1 : 0;
  });

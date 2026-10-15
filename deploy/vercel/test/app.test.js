import { test } from 'node:test';
import assert from 'node:assert/strict';

import { createApp, newCode, normalizeCode } from '../lib/app.js';
import { memoryStore } from '../lib/store.js';

function setup() {
  let t = new Date('2026-10-16T10:00:00Z');
  const store = memoryStore();
  const app = createApp({ store, secret: 'secret-de-test-lung-123', publicUrl: 'https://panou.test', now: () => t });
  const call = async (method, path, body, token) =>
    app({ method, path, body, headers: token ? { authorization: `Bearer ${token}` } : {} });
  return { app, store, call, advance: (ms) => (t = new Date(t.getTime() + ms)) };
}

async function therapist(call, email = 'dr@example.md') {
  const r = await call('POST', '/auth/register', { email, password: 'parola-lunga-1', role: 'THERAPIST' });
  assert.equal(r.status, 201);
  return r.body.accessToken;
}

test('codurile: 8 caractere fără litere care se confundă; se recunosc și din legătură', () => {
  for (let i = 0; i < 50; i++) {
    const c = newCode();
    assert.match(c, /^[A-Z2-9]{4}-[A-Z2-9]{4}$/);
    assert.doesNotMatch(c, /[01OIL]/);
  }
  assert.equal(normalizeCode('abcd-2345'), 'ABCD-2345');
  assert.equal(normalizeCode(' ABCD2345 '), 'ABCD-2345');
  assert.equal(normalizeCode('https://panou.test/c/ABCD-2345'), 'ABCD-2345');
  assert.equal(normalizeCode('scurt'), null);
});

test('terapeutul: cont, copil nou cu cod de legare, fișa copilului, planul cu muzica', async () => {
  const { call } = setup();
  const token = await therapist(call);
  assert.equal((await call('GET', '/me', null, token)).body.role, 'THERAPIST');
  const created = await call('POST', '/children', { nickname: 'Ilinca', birthYear: 2020, notes: 'Lucrăm atenția comună.' }, token);
  assert.equal(created.status, 201);
  assert.match(created.body.code, /^[A-Z2-9]{4}-[A-Z2-9]{4}$/);
  assert.equal(created.body.url, `https://panou.test/c/${created.body.code}`);
  assert.equal(created.body.linked, false);
  const kids = await call('GET', '/children', null, token);
  assert.deepEqual(kids.body.map((k) => k.nickname), ['Ilinca']);
  const id = created.body.id;
  const edited = await call('PATCH', `/children/${id}`, { goals: 'Așteptarea rândului' }, token);
  assert.equal(edited.body.goals, 'Așteptarea rândului');
  const plan = await call('PUT', `/children/${id}/plan`, { hiddenGames: ['simon'], levels: { emotii: 3 }, maxLevels: { emotii: 5 }, music: { on: false, track: 'valuri' } }, token);
  assert.equal(plan.status, 200);
  assert.equal(plan.body.updatedBy, 'THERAPIST');
  assert.deepEqual(plan.body.music, { on: false, track: 'valuri' });
  assert.equal((await call('PUT', `/children/${id}/plan`, { hiddenGames: [], levels: { emotii: 8 }, maxLevels: { emotii: 5 } }, token)).status, 400);
  // Alt terapeut nu vede copilul (404, nu 403).
  const other = await therapist(call, 'alt@example.md');
  assert.equal((await call('GET', `/children/${id}/sessions`, null, other)).status, 404);
});

test('tableta: codul de unică folosință → tokenuri doar pentru copilul ei; sesiuni și plan', async () => {
  const { call } = setup();
  const token = await therapist(call);
  const child = (await call('POST', '/children', { nickname: 'Matei' }, token)).body;
  assert.equal((await call('POST', '/device/link', { code: child.code })).status, 400, 'fără acordul părintelui');
  const linked = await call('POST', '/device/link', { code: child.url, consent: true });
  assert.equal(linked.status, 200);
  assert.equal(linked.body.child.nickname, 'Matei');
  // A doua oară codul nu mai merge.
  assert.equal((await call('POST', '/device/link', { code: child.code, consent: true })).status, 404);

  // Exact fluxul tabletei (SyncClient): refresh → copiii → sesiuni → plan.
  const pair = (await call('POST', '/auth/refresh', { refreshToken: linked.body.refreshToken })).body;
  assert.equal((await call('POST', '/auth/refresh', { refreshToken: linked.body.refreshToken })).status, 401, 'rotit');
  const dev = pair.accessToken;
  const kids = (await call('GET', '/children', null, dev)).body;
  assert.equal(kids.length, 1);
  assert.equal(kids[0].id, child.id);
  assert.equal((await call('POST', '/children', { nickname: 'X' }, dev)).status, 403);
  const record = { id: '0190f1a2-0000-7000-8000-000000000001', start: '2026-10-16T09:00:00Z', trials: [] };
  assert.equal((await call('POST', `/children/${child.id}/sessions`, { sessions: [{ record, facts: { n: 1 } }] }, dev)).status, 200);
  // Retrimisă: tot o singură sesiune.
  await call('POST', `/children/${child.id}/sessions`, { sessions: [{ record, facts: { n: 1 } }] }, dev);
  const seen = (await call('GET', `/children/${child.id}/sessions`, null, token)).body;
  assert.equal(seen.length, 1);
  assert.equal(seen[0].record.id, record.id);
  // Planul ales de terapeut ajunge la tabletă; tableta nu poate schimba nivelurile.
  await call('PUT', `/children/${child.id}/plan`, { hiddenGames: ['cauta'], levels: { emotii: 3 } }, token);
  assert.deepEqual((await call('GET', `/children/${child.id}/plan`, null, dev)).body.hiddenGames, ['cauta']);
  const fromTablet = (await call('PUT', `/children/${child.id}/plan`, { hiddenGames: [], levels: { emotii: 9 } }, dev)).body;
  assert.deepEqual(fromTablet.levels, { emotii: 3 });
  assert.equal(fromTablet.updatedBy, 'PARENT');
  const view = (await call('GET', '/children', null, token)).body[0];
  assert.equal(view.linked, true);
  assert.ok(view.lastSyncAt);
});

test('cod nou cu deconectare: tableta veche nu mai poate reîmprospăta', async () => {
  const { call } = setup();
  const token = await therapist(call);
  const child = (await call('POST', '/children', { nickname: 'Ana' }, token)).body;
  const linked = (await call('POST', '/device/link', { code: child.code, consent: true })).body;
  const fresh = (await call('POST', `/children/${child.id}/link`, { unlink: true }, token)).body;
  assert.notEqual(fresh.code, child.code);
  assert.equal(fresh.linked, false);
  assert.equal((await call('POST', '/auth/refresh', { refreshToken: linked.refreshToken })).status, 401);
  assert.equal((await call('POST', '/device/link', { code: fresh.code, consent: true })).status, 200);
});

test('parola greșită de 5 ori blochează 15 minute; tokenul de acces expiră', async () => {
  const { call, advance } = setup();
  const token = await therapist(call);
  for (let i = 0; i < 5; i++) {
    assert.equal((await call('POST', '/auth/login', { email: 'dr@example.md', password: 'gresita-gresita' })).status, 401);
  }
  assert.equal((await call('POST', '/auth/login', { email: 'dr@example.md', password: 'parola-lunga-1' })).status, 429);
  advance(16 * 60 * 1000);
  assert.equal((await call('POST', '/auth/login', { email: 'dr@example.md', password: 'parola-lunga-1' })).status, 200);
  assert.equal((await call('GET', '/me', null, token)).status, 401, 'expirat după 15 min');
});

test('ștergerea copilului și a contului șterg tot; exportul conține copiii și sesiunile', async () => {
  const { call, store } = setup();
  const token = await therapist(call);
  const child = (await call('POST', '/children', { nickname: 'Dan' }, token)).body;
  const dev = (await call('POST', '/device/link', { code: child.code, consent: true })).body.accessToken;
  await call('POST', `/children/${child.id}/sessions`, { sessions: [{ record: { id: 'abcdef12-3456', start: 'x' } }] }, dev);
  const exp = (await call('GET', '/me/export', null, token)).body;
  assert.equal(exp.children[0].sessions.length, 1);
  assert.equal(exp.user.passwordHash, undefined);
  assert.equal((await call('POST', '/me/delete', { password: 'nu-asta-e-parola' }, token)).status, 401);
  assert.equal((await call('POST', '/me/delete', { password: 'parola-lunga-1' }, token)).status, 200);
  assert.deepEqual([...store.docs.keys()].filter((k) => !k.startsWith('refresh/')), []);
});

test('rute necunoscute, metode greșite, erori fără detalii interne', async () => {
  const { call } = setup();
  assert.equal((await call('GET', '/nu-exista')).status, 404);
  assert.equal((await call('GET', '/auth/login')).status, 405);
  assert.equal((await call('GET', '/children')).status, 401);
  assert.equal((await call('GET', '/health')).body.ok, true);
});

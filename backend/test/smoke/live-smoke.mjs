// Test de fum pentru canalul live (Socket.IO real), pe build-ul compilat: `npx nest build && node test/smoke/live-smoke.mjs`.
// Nu rulează în Jest: Nest 12 e ESM, iar Jest-ul proiectului e CommonJS.
import { createRequire } from 'node:module';
import assert from 'node:assert/strict';

const require = createRequire(import.meta.url);
const { NestFactory } = await import('@nestjs/core');
const { Module } = await import('@nestjs/common');
const { io } = require('socket.io-client');
const { LiveAccess } = require('../../dist/live/live.js');
const { LiveGateway } = require('../../dist/live/live.gateway.js');
const { RedisIoAdapter } = require('../../dist/live/redis-io.adapter.js');

const CHILD = '0190a1b2-0000-7000-8000-000000000001';
const OTHER = '0190a1b2-0000-7000-8000-000000000002';
const access = new LiveAccess(
  { verifyAccess: (t) => { if (t !== 'tok-ana') throw new Error('401'); return { id: 'p1', role: 'PARENT' }; } },
  { assert: async (_u, id) => { if (id !== CHILD) throw new Error('404'); return { id, parentId: 'p1', deletedAt: null }; } },
);

class SmokeModule {}
Module({ providers: [{ provide: LiveAccess, useValue: access }, LiveGateway] })(SmokeModule);

const app = await NestFactory.create(SmokeModule, { logger: false });
app.useWebSocketAdapter(new RedisIoAdapter(app, 'redis://localhost:1', ['http://localhost:8080']));
await app.listen(0, '127.0.0.1');
const url = `http://127.0.0.1:${app.getHttpServer().address().port}`;
const gateway = app.get(LiveGateway);
const opts = (token) => ({ path: '/api/v1/live', transports: ['websocket'], auth: { token }, reconnection: false });
const wait = (ms) => new Promise((r) => setTimeout(r, ms));

const bad = io(url, opts('gresit'));
await wait(300);
assert.equal(bad.connected, false, 'tokenul greșit trebuie respins');

const s = io(url, opts('tok-ana'));
await new Promise((r) => s.on('connect', r));
await wait(50);
assert.deepEqual(await s.emitWithAck('watch', { childId: CHILD }), { ok: true });
assert.deepEqual(await s.emitWithAck('watch', { childId: OTHER }), { ok: false });
const got = [];
s.on('session.synced', (e) => got.push(e));
gateway.publish({ type: 'session.synced', childId: OTHER, count: 9 });
gateway.publish({ type: 'session.synced', childId: CHILD, count: 2 });
await wait(200);
assert.deepEqual(got, [{ type: 'session.synced', childId: CHILD, count: 2 }]);

s.close();
bad.close();
await app.close();
console.log('live: OK (autentificare, camere, evenimente)');

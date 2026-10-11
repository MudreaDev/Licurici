import { Metrics, metricsAuthorized, routeTemplate } from './metrics';

describe('Metrics', () => {
  it('ruta apare ca șablon, fără id-uri; o cale necunoscută devine „unmatched”', async () => {
    const m = new Metrics(false);
    const child = '0190a1b2-0000-7000-8000-000000000001';
    const route = routeTemplate({ baseUrl: '', route: { path: '/api/v1/children/:childId/sessions' } });
    m.observe('POST', route, 200, 0.042);
    m.observe('GET', routeTemplate({ baseUrl: '' }), 404, 0.001);
    const text = await m.registry.metrics();
    expect(text).toContain('route="/api/v1/children/:childId/sessions"');
    expect(text).toContain('route="unmatched"');
    expect(text).toContain('status="2xx"');
    expect(text).not.toContain(child);
  });

  it('contorul de sesiuni și lungimea cozilor', async () => {
    const m = new Metrics(false);
    m.syncedSessions.inc(3);
    m.queueJobs.set({ queue: 'stats', state: 'waiting' }, 2);
    const text = await m.registry.metrics();
    expect(text).toContain('licurici_synced_sessions_total 3');
    expect(text).toContain('licurici_queue_jobs{queue="stats",state="waiting"} 2');
  });

  it('/metrics doar cu tokenul configurat; fără token configurat, nimeni', () => {
    const token = 'x'.repeat(32);
    expect(metricsAuthorized(token, `Bearer ${token}`)).toBe(true);
    expect(metricsAuthorized(token, `Bearer ${'y'.repeat(32)}`)).toBe(false);
    expect(metricsAuthorized(token, undefined)).toBe(false);
    expect(metricsAuthorized(token, token)).toBe(false);
    expect(metricsAuthorized(undefined, 'Bearer ')).toBe(false);
  });
});

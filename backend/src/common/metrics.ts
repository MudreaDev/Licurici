import { timingSafeEqual } from 'node:crypto';

import { Counter, collectDefaultMetrics, Gauge, Histogram, Registry } from 'prom-client';

/**
 * Metricile Prometheus (ADR-018): durata cererilor HTTP și lungimea cozilor. Etichetele nu
 * conțin niciodată date personale sau id-uri: ruta apare ca șablon (`/api/v1/children/:childId/
 * sessions`), nu cu id-ul copilului; o cale necunoscută devine `unmatched` (altfel oricine ar
 * putea umple Prometheus cu etichete inventate).
 */
export class Metrics {
  readonly registry = new Registry();

  readonly httpDuration = new Histogram({
    name: 'licurici_http_request_duration_seconds',
    help: 'Durata cererilor HTTP, pe metodă, rută (șablon) și clasa codului de răspuns.',
    labelNames: ['method', 'route', 'status'] as const,
    // p95 țintă pentru sincronizare: 200 ms (README §19, tools/k6/sync.js).
    buckets: [0.01, 0.025, 0.05, 0.1, 0.2, 0.3, 0.5, 1, 2, 5],
    registers: [this.registry],
  });

  readonly syncedSessions = new Counter({
    name: 'licurici_synced_sessions_total',
    help: 'Sesiuni primite de pe tablete (inclusiv retrimiterile idempotente).',
    registers: [this.registry],
  });

  readonly queueJobs = new Gauge({
    name: 'licurici_queue_jobs',
    help: 'Job-uri în cozile BullMQ, pe coadă și stare.',
    labelNames: ['queue', 'state'] as const,
    registers: [this.registry],
  });

  constructor(withDefaults = true) {
    if (withDefaults) collectDefaultMetrics({ register: this.registry, prefix: 'licurici_' });
  }

  observe(method: string, route: string | undefined, status: number, seconds: number): void {
    this.httpDuration.observe({ method, route: route ?? 'unmatched', status: `${Math.floor(status / 100)}xx` }, seconds);
  }
}

/** Ruta ca șablon, din Express: `baseUrl` + `route.path`; fără potrivire → undefined. */
export function routeTemplate(req: { baseUrl?: string; route?: { path?: unknown } }): string | undefined {
  const path = req.route?.path;
  return typeof path === 'string' ? `${req.baseUrl ?? ''}${path}` : undefined;
}

/**
 * `/metrics` cere `Authorization: Bearer <METRICS_TOKEN>`. Fără token configurat, ruta nu
 * există (404) — metricile sunt opționale și nu se expun niciodată din greșeală.
 */
export function metricsAuthorized(expected: string | undefined, header: string | undefined): boolean {
  if (!expected) return false;
  const given = Buffer.from(header?.startsWith('Bearer ') ? header.slice(7) : '');
  const want = Buffer.from(expected);
  return given.length === want.length && timingSafeEqual(given, want);
}

import { Controller, Get, Inject, Logger } from '@nestjs/common';
import { HealthCheck, HealthCheckService, HealthIndicatorService } from '@nestjs/terminus';
import type { Redis } from 'ioredis';

import { ENV, type Env } from '../config/env';
import { PrismaService } from '../prisma/prisma.service';
import { REDIS } from '../redis/redis.module';

const TIMEOUT_MS = 2000;

function withTimeout<T>(p: Promise<T>, ms = TIMEOUT_MS): Promise<T> {
  return Promise.race([
    p,
    new Promise<T>((_, reject) => setTimeout(() => reject(new Error(`timeout ${ms} ms`)), ms)),
  ]);
}

/**
 * - `GET /health` — liveness: procesul răspunde (Docker `HEALTHCHECK`, fără dependențe);
 * - `GET /health/ready` — readiness: PostgreSQL, Redis și stocarea S3 sunt accesibile.
 * Răspunsurile nu conțin date personale sau detalii de configurare.
 */
@Controller('health')
export class HealthController {
  private readonly log = new Logger(HealthController.name);

  constructor(
    private readonly health: HealthCheckService,
    private readonly indicators: HealthIndicatorService,
    private readonly prisma: PrismaService,
    @Inject(REDIS) private readonly redis: Redis,
    @Inject(ENV) private readonly env: Env,
  ) {}

  @Get()
  live() {
    return { status: 'ok' };
  }

  @Get('ready')
  @HealthCheck()
  ready() {
    return this.health.check([
      () => this.probe('postgres', () => this.prisma.$queryRaw`SELECT 1`),
      () => this.probe('redis', () => this.pingRedis()),
      () => this.probe('storage', () => this.pingStorage()),
    ]);
  }

  private async probe<K extends string>(key: K, fn: () => Promise<unknown>) {
    const indicator = this.indicators.check(key);
    try {
      await withTimeout(fn());
      return indicator.up();
    } catch (e) {
      // Detaliile (host, port, mesajul driverului) rămân în log, nu în răspunsul public.
      this.log.warn(`${key} indisponibil: ${e instanceof Error ? e.message : String(e)}`);
      return indicator.down({ message: 'indisponibil' });
    }
  }

  private async pingRedis(): Promise<void> {
    if (this.redis.status === 'wait') await this.redis.connect();
    const pong = await this.redis.ping();
    if (pong !== 'PONG') throw new Error('răspuns neașteptat');
  }

  /**
   * Neutru față de furnizor: orice server S3 răspunde la o cerere neautentificată
   * (de obicei 403). Contează doar că răspunde și nu dă eroare de server.
   */
  private async pingStorage(): Promise<void> {
    const res = await fetch(this.env.S3_ENDPOINT, { method: 'HEAD', signal: AbortSignal.timeout(TIMEOUT_MS) });
    if (res.status >= 500) throw new Error(`HTTP ${res.status}`);
  }
}

import { Controller, Get, Header, Headers, Inject } from '@nestjs/common';
import { ApiExcludeController } from '@nestjs/swagger';
import { ModuleRef } from '@nestjs/core';
import { getQueueToken } from '@nestjs/bullmq';
import type { Queue } from 'bullmq';

import { NotFoundError } from '../common/errors';
import { Metrics, metricsAuthorized } from '../common/metrics';
import { ENV, type Env } from '../config/env';
import { Queues } from '../queues/queues';

const STATES = ['waiting', 'active', 'delayed', 'failed'] as const;

/** BullMQ reîncearcă la nesfârșit când Redis e jos: colectarea nu are voie să aștepte după el. */
const QUEUE_TIMEOUT_MS = 1000;

function withTimeout<T>(p: Promise<T>): Promise<T> {
  let timer: NodeJS.Timeout | undefined;
  const timeout = new Promise<never>((_, reject) => {
    timer = setTimeout(() => reject(new Error('timeout')), QUEUE_TIMEOUT_MS);
  });
  return Promise.race([p, timeout]).finally(() => clearTimeout(timer));
}

/**
 * `GET /metrics` pentru Prometheus (ADR-018): doar cu `METRICS_TOKEN`; în producție Traefik
 * nici nu rutează calea (Prometheus citește din rețeaua internă Docker).
 */
@ApiExcludeController()
@Controller('metrics')
export class MetricsController {
  constructor(
    @Inject(Metrics) private readonly metrics: Metrics,
    @Inject(ENV) private readonly env: Env,
    private readonly modules: ModuleRef,
  ) {}

  @Get()
  @Header('content-type', 'text/plain; version=0.0.4; charset=utf-8')
  async scrape(@Headers('authorization') auth?: string): Promise<string> {
    if (!metricsAuthorized(this.env.METRICS_TOKEN, auth)) throw new NotFoundError();
    // Lungimea cozilor, citită la fiecare colectare; o coadă indisponibilă nu strică restul.
    await Promise.all(
      Object.values(Queues).map(async (name) => {
        try {
          const queue = this.modules.get<Queue>(getQueueToken(name), { strict: false });
          const counts = await withTimeout(queue.getJobCounts(...STATES));
          for (const state of STATES) this.metrics.queueJobs.set({ queue: name, state }, counts[state] ?? 0);
        } catch {
          // Redis jos: /health/ready o spune; metricile HTTP rămân utile.
        }
      }),
    );
    return this.metrics.registry.metrics();
  }
}

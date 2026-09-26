import { Processor, WorkerHost } from '@nestjs/bullmq';
import { Inject, Logger, OnApplicationBootstrap } from '@nestjs/common';
import type { Job } from 'bullmq';
import type { Redis } from 'ioredis';

import { ENV, type Env } from '../config/env';
import { PrismaService } from '../prisma/prisma.service';
import { Queues } from '../queues/queues';
import { REDIS } from '../redis/redis.module';
import { computeSkillStats } from './skill-stats';

/** Șterge lock-ul doar dacă îl deținem (compare-and-delete atomic). */
const RELEASE_LOCK = `if redis.call('get', KEYS[1]) == ARGV[1] then return redis.call('del', KEYS[1]) else return 0 end`;

export class LockBusyError extends Error {}

export interface RecomputeStatsJob {
  childId: string;
}

/**
 * Recalculează statisticile unui copil (job `stats` → `recompute`).
 * Idempotent: rezultatul depinde doar de evenimentele din baza de date, deci un retry
 * produce aceeași stare. Un lock Redis per copil evită două recalculări simultane; dacă e ocupat,
 * job-ul eșuează și BullMQ îl reîncearcă cu backoff (nu îl sărim — am pierde evenimente noi).
 */
@Processor(Queues.stats)
export class StatsProcessor extends WorkerHost implements OnApplicationBootstrap {
  private readonly log = new Logger(StatsProcessor.name);

  constructor(
    private readonly prisma: PrismaService,
    @Inject(REDIS) private readonly redis: Redis,
    @Inject(ENV) private readonly env: Env,
  ) {
    super();
  }

  onApplicationBootstrap(): void {
    this.worker.concurrency = this.env.WORKER_CONCURRENCY;
  }

  async process(job: Job<RecomputeStatsJob>): Promise<{ skills: number }> {
    const { childId } = job.data;
    const lockKey = `lock:stats:${childId}`;
    const owner = `${job.id}:${job.attemptsMade}`;
    const locked = await this.redis.set(lockKey, owner, 'PX', 30_000, 'NX');
    if (!locked) throw new LockBusyError(`statisticile copilului sunt deja în lucru`);
    try {
      const events = await this.prisma.gameEvent.findMany({
        where: { session: { childId }, skill: { not: null }, firstTry: { not: null } },
        select: { skill: true, firstTry: true, at: true },
      });
      const stats = computeSkillStats(
        events.map((e) => ({ skill: e.skill!, firstTry: e.firstTry!, at: e.at })),
      );
      await this.prisma.$transaction([
        this.prisma.childSkillStats.deleteMany({ where: { childId } }),
        this.prisma.childSkillStats.createMany({ data: stats.map((s) => ({ childId, ...s })) }),
      ]);
      await this.redis.del(`cache:stats:${childId}`);
      this.log.log(`statistici recalculate: ${stats.length} abilități`);
      return { skills: stats.length };
    } finally {
      await this.redis.eval(RELEASE_LOCK, 1, lockKey, owner);
    }
  }
}

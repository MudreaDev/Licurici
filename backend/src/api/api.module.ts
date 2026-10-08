import { getQueueToken } from '@nestjs/bullmq';
import { Module } from '@nestjs/common';
import { APP_FILTER } from '@nestjs/core';
import type { Queue } from 'bullmq';
import type { Redis } from 'ioredis';

import { AuthService } from '../auth/auth.service';
import { AuthGuard } from '../auth/guard';
import { TokenService } from '../auth/tokens';
import { ChildAccess } from '../children/access';
import { ChildrenService } from '../children/children';
import { CommonModule } from '../common.module';
import { GamePlanService } from '../children/plan';
import { SharingService } from '../children/sharing';
import { DomainErrorFilter } from '../common/domain-error.filter';
import { ConsentService } from '../consents/consents';
import { ENV, type Env } from '../config/env';
import { GdprService } from '../gdpr/gdpr';
import { Queues } from '../queues/queues';
import { PrismaRepos } from '../data/repos';
import { PrismaService } from '../prisma/prisma.service';
import { REDIS } from '../redis/redis.module';
import { SessionSummaryService } from '../reports/session-summary';
import { SummaryFlow } from '../reports/summary-flow';
import { SyncService } from '../sync/sessions';
import { AuthController, ChildrenController, ConsentsController, MeController } from './controllers';

/**
 * Modulele de domeniu ale API-ului. Serviciile sunt TypeScript simplu (testate fără Nest);
 * aici doar le legăm de Prisma, Redis și configurație.
 */
@Module({
  // CommonModule exportă cozile BullMQ (coada `gdpr` pentru ștergerea definitivă).
  imports: [CommonModule],
  controllers: [AuthController, ChildrenController, ConsentsController, MeController],
  providers: [
    { provide: APP_FILTER, useClass: DomainErrorFilter },
    { provide: PrismaRepos, inject: [PrismaService], useFactory: (db: PrismaService) => new PrismaRepos(db) },
    {
      provide: TokenService,
      inject: [ENV, REDIS],
      useFactory: (env: Env, redis: Redis) => new TokenService(env.JWT_SECRET, redis),
    },
    {
      provide: AuthService,
      inject: [PrismaRepos, TokenService, REDIS],
      useFactory: (r: PrismaRepos, t: TokenService, redis: Redis) => new AuthService(r.users, t, redis),
    },
    { provide: ChildAccess, inject: [PrismaRepos], useFactory: (r: PrismaRepos) => new ChildAccess(r.childAccess) },
    {
      provide: ChildrenService,
      inject: [PrismaRepos],
      useFactory: (r: PrismaRepos) => new ChildrenService(r.children),
    },
    { provide: ConsentService, inject: [PrismaRepos], useFactory: (r: PrismaRepos) => new ConsentService(r.consents) },
    {
      provide: SharingService,
      inject: [ChildAccess, ConsentService, PrismaRepos],
      useFactory: (a: ChildAccess, c: ConsentService, r: PrismaRepos) => new SharingService(a, c, r.sharing),
    },
    {
      provide: GamePlanService,
      inject: [ChildAccess, PrismaRepos],
      useFactory: (a: ChildAccess, r: PrismaRepos) => new GamePlanService(a, r.plan),
    },
    {
      provide: GdprService,
      inject: [ChildAccess, PrismaRepos, getQueueToken(Queues.gdpr), AuthService],
      useFactory: (a: ChildAccess, r: PrismaRepos, queue: Queue, auth: AuthService) =>
        new GdprService(a, r.gdpr, {
          // jobId fix → programarea e idempotentă (o a doua cerere nu dublează ștergerea).
          schedulePurge: async (childId, at) => {
            await queue.add(
              'purge-child',
              { childId },
              { jobId: `purge-child-${childId}`, delay: Math.max(0, at.getTime() - Date.now()) },
            );
          },
          schedulePurgeAccount: async (userId, at) => {
            await queue.add(
              'purge-account',
              { userId },
              { jobId: `purge-account-${userId}`, delay: Math.max(0, at.getTime() - Date.now()) },
            );
          },
        }, { confirm: (id, password) => auth.confirmPassword(id, password) }),
    },
    {
      provide: SyncService,
      inject: [ChildAccess, PrismaRepos, ConsentService],
      useFactory: (a: ChildAccess, r: PrismaRepos, c: ConsentService) => new SyncService(a, r.sessions, c),
    },
    {
      provide: SummaryFlow,
      inject: [ChildAccess, PrismaRepos, REDIS, ENV],
      useFactory: (a: ChildAccess, r: PrismaRepos, redis: Redis, env: Env) =>
        new SummaryFlow(
          a,
          r.sessions,
          r.summaries,
          r.consents,
          redis,
          // Fără cheie: endpoint-ul răspunde 503, panoul rămâne pe rezumatul din reguli.
          env.ANTHROPIC_API_KEY ? new SessionSummaryService() : null,
          env.AI_SUMMARIES_PER_DAY,
        ),
    },
    AuthGuard,
  ],
})
export class ApiModule {}

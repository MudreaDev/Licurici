import { Module } from '@nestjs/common';
import { APP_FILTER } from '@nestjs/core';
import type { Redis } from 'ioredis';

import { AuthService } from '../auth/auth.service';
import { AuthGuard } from '../auth/guard';
import { TokenService } from '../auth/tokens';
import { ChildAccess } from '../children/access';
import { ChildrenService } from '../children/children';
import { SharingService } from '../children/sharing';
import { DomainErrorFilter } from '../common/domain-error.filter';
import { ConsentService } from '../consents/consents';
import { ENV, type Env } from '../config/env';
import { PrismaRepos } from '../data/repos';
import { PrismaService } from '../prisma/prisma.service';
import { REDIS } from '../redis/redis.module';
import { SessionSummaryService } from '../reports/session-summary';
import { SummaryFlow } from '../reports/summary-flow';
import { SyncService } from '../sync/sessions';
import { AuthController, ChildrenController, ConsentsController } from './controllers';

/**
 * Modulele de domeniu ale API-ului. Serviciile sunt TypeScript simplu (testate fără Nest);
 * aici doar le legăm de Prisma, Redis și configurație.
 */
@Module({
  controllers: [AuthController, ChildrenController, ConsentsController],
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
      inject: [PrismaRepos, TokenService],
      useFactory: (r: PrismaRepos, t: TokenService) => new AuthService(r.users, t),
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

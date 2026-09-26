import { BullModule } from '@nestjs/bullmq';
import { Module } from '@nestjs/common';
import { LoggerModule } from 'nestjs-pino';

import { ConfigModule } from './config/config.module';
import { ENV, type Env } from './config/env';
import { PrismaModule } from './prisma/prisma.module';
import { QueueErrorLogger } from './queues/queue-errors';
import { Queues, bullConnection, defaultJobOptions } from './queues/queues';
import { RedisModule } from './redis/redis.module';

function hasPrettyLogs(): boolean {
  try {
    require.resolve('pino-pretty');
    return true;
  } catch {
    return false;
  }
}

/**
 * Infrastructura comună API + worker: configurație, loguri, PostgreSQL, Redis, cozi.
 * API-ul și worker-ul sunt același cod (monolit modular, ADR-05), pornit în două procese.
 */
@Module({
  imports: [
    ConfigModule,
    LoggerModule.forRootAsync({
      inject: [ENV],
      useFactory: (env: Env) => ({
        pinoHttp: {
          level: env.LOG_LEVEL,
          // Loguri colorate doar local; în container (fără devDependencies) rămân JSON.
          transport: env.NODE_ENV === 'development' && hasPrettyLogs() ? { target: 'pino-pretty' } : undefined,
          // Fără date personale în loguri (README §13.4).
          redact: {
            paths: ['req.headers.authorization', 'req.headers.cookie', '*.email', '*.password', '*.nickname'],
            censor: '[ascuns]',
          },
          autoLogging: { ignore: (req) => req.url?.startsWith('/health') ?? false },
        },
      }),
    }),
    PrismaModule,
    RedisModule,
    BullModule.forRootAsync({
      inject: [ENV],
      useFactory: (env: Env) => ({ connection: bullConnection(env), defaultJobOptions }),
    }),
    BullModule.registerQueue(...Object.values(Queues).map((name) => ({ name }))),
  ],
  providers: [QueueErrorLogger],
  exports: [BullModule],
})
export class CommonModule {}

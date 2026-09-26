import { Global, Inject, Logger, Module, OnModuleDestroy } from '@nestjs/common';
import { Redis } from 'ioredis';

import { ENV, type Env } from '../config/env';

/** Clientul Redis partajat (cache, rate limit, idempotență, lock-uri — README §10). */
export const REDIS = Symbol('REDIS');

@Global()
@Module({
  providers: [
    {
      provide: REDIS,
      inject: [ENV],
      useFactory: (env: Env) => {
        const redis = new Redis(env.REDIS_URL, {
          lazyConnect: true,
          maxRetriesPerRequest: 2,
          enableOfflineQueue: false,
        });
        // Fără handler, ioredis raportează fiecare reconectare eșuată ca eroare netratată.
        const log = new Logger('Redis');
        redis.on('error', (e: Error) => log.warn(e.message));
        return redis;
      },
    },
  ],
  exports: [REDIS],
})
export class RedisModule implements OnModuleDestroy {
  constructor(@Inject(REDIS) private readonly redis: Redis) {}

  async onModuleDestroy(): Promise<void> {
    this.redis.disconnect();
  }
}

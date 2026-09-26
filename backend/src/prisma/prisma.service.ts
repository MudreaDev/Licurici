import { Inject, Injectable, OnModuleDestroy } from '@nestjs/common';
import { PrismaPg } from '@prisma/adapter-pg';

import { ENV, type Env } from '../config/env';
import { PrismaClient } from '../generated/prisma/client';

/**
 * Acces la PostgreSQL prin Prisma 7 (ADR-07), cu driverul `pg` (pool de conexiuni).
 * Conexiunea se deschide leneș, la prima interogare — pornirea nu depinde de baza de date,
 * iar `/health/ready` raportează corect dacă nu e disponibilă.
 */
@Injectable()
export class PrismaService extends PrismaClient implements OnModuleDestroy {
  constructor(@Inject(ENV) env: Env) {
    super({ adapter: new PrismaPg({ connectionString: env.DATABASE_URL }) });
  }

  async onModuleDestroy(): Promise<void> {
    await this.$disconnect();
  }
}

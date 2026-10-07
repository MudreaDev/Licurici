import { InjectQueue } from '@nestjs/bullmq';
import { Injectable, type OnModuleInit } from '@nestjs/common';
import type { Queue } from 'bullmq';

import { Queues } from '../queues/queues';

/**
 * Programează zilnic (03:30) job-ul `expire-sessions` din coada `gdpr` (retenția de 24 de luni).
 * `upsertJobScheduler` e idempotent: oricâte worker-e pornesc, rămâne o singură programare.
 */
@Injectable()
export class RetentionScheduler implements OnModuleInit {
  constructor(@InjectQueue(Queues.gdpr) private readonly queue: Queue) {}

  async onModuleInit(): Promise<void> {
    await this.queue.upsertJobScheduler('expire-sessions', { pattern: '30 3 * * *' }, { name: 'expire-sessions' });
  }
}

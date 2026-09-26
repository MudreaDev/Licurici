import { getQueueToken } from '@nestjs/bullmq';
import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { ModuleRef } from '@nestjs/core';
import type { Queue } from 'bullmq';

import { Queues } from './queues';

/**
 * Conectează erorile de conexiune ale cozilor la log. Fără handler, o întrerupere Redis
 * apare ca „Unhandled error event”; cu el, API-ul rămâne pornit și raportează în `/health/ready`.
 */
@Injectable()
export class QueueErrorLogger implements OnModuleInit {
  private readonly log = new Logger('Queues');

  constructor(private readonly moduleRef: ModuleRef) {}

  onModuleInit(): void {
    for (const name of Object.values(Queues)) {
      const queue = this.moduleRef.get<Queue>(getQueueToken(name), { strict: false });
      queue.on('error', (e: Error) => this.log.warn(`${name}: ${e.message}`));
    }
  }
}

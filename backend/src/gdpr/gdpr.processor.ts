import { Processor, WorkerHost } from '@nestjs/bullmq';
import { Logger } from '@nestjs/common';
import type { Job } from 'bullmq';

import { PrismaService } from '../prisma/prisma.service';
import { Queues } from '../queues/queues';

export interface PurgeChildJob {
  childId: string;
}

/**
 * Ștergerea definitivă a unui copil (GDPR art. 17), la finalul perioadei de grație.
 * Șterge doar dacă profilul e încă marcat șters (dacă părintele a anulat, nu face nimic).
 * Cascada din schemă ia cu ea sesiunile, rezumatele, statisticile și legăturile.
 * Idempotent: a doua rulare nu mai găsește nimic de șters.
 */
@Processor(Queues.gdpr)
export class GdprProcessor extends WorkerHost {
  private readonly log = new Logger(GdprProcessor.name);

  constructor(private readonly prisma: PrismaService) {
    super();
  }

  async process(job: Job<PurgeChildJob>): Promise<{ deleted: number }> {
    if (job.name !== 'purge-child') return { deleted: 0 };
    const { count } = await this.prisma.child.deleteMany({
      where: { id: job.data.childId, deletedAt: { not: null } },
    });
    // Fără id-ul copilului în log (date personale minimizate); doar rezultatul.
    this.log.log(`ștergere definitivă: ${count} profil(e)`);
    return { deleted: count };
  }
}

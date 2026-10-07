import { Processor, WorkerHost } from '@nestjs/bullmq';
import { Logger } from '@nestjs/common';
import type { Job } from 'bullmq';

import { PrismaService } from '../prisma/prisma.service';
import { Queues } from '../queues/queues';
import { expireSessions } from './retention';

export interface PurgeChildJob {
  childId: string;
}

export interface PurgeAccountJob {
  userId: string;
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

  async process(job: Job<PurgeChildJob | PurgeAccountJob>): Promise<{ deleted: number }> {
    if (job.name === 'expire-sessions') {
      // Retenția (24 de luni): sesiunile vechi pleacă cu rezumatele și evenimentele lor (cascadă).
      const deleted = await expireSessions(this.prisma, new Date());
      this.log.log(`retenție: ${deleted} sesiuni expirate șterse`);
      return { deleted };
    }
    if (job.name === 'purge-account') {
      // Cascada din schemă ia copiii, sesiunile, consimțămintele, dispozitivele, partajările.
      const { count } = await this.prisma.user.deleteMany({
        where: { id: (job.data as PurgeAccountJob).userId, deletedAt: { not: null } },
      });
      this.log.log(`ștergere definitivă: ${count} cont(uri)`);
      return { deleted: count };
    }
    if (job.name !== 'purge-child') return { deleted: 0 };
    const { count } = await this.prisma.child.deleteMany({
      where: { id: (job.data as PurgeChildJob).childId, deletedAt: { not: null } },
    });
    // Fără id-ul copilului în log (date personale minimizate); doar rezultatul.
    this.log.log(`ștergere definitivă: ${count} profil(e)`);
    return { deleted: count };
  }
}

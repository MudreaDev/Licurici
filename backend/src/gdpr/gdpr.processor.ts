import { Processor, WorkerHost } from '@nestjs/bullmq';
import { Logger } from '@nestjs/common';
import type { Job } from 'bullmq';

import { PrismaService } from '../prisma/prisma.service';
import { Queues } from '../queues/queues';
import { archiveRows, expireConsentArchive, expireSessions } from './retention';

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
      // Retenția: sesiunile mai vechi de 24 de luni și dovezile arhivate de peste 3 ani.
      const now = new Date();
      const deleted = (await expireSessions(this.prisma, now)) + (await expireConsentArchive(this.prisma, now));
      this.log.log(`retenție: ${deleted} înregistrări expirate șterse`);
      return { deleted };
    }
    if (job.name === 'purge-account') {
      const userId = (job.data as PurgeAccountJob).userId;
      // Dovezile consimțământului rămân 3 ani, fără identificatori; restul pleacă în cascadă
      // (copiii, sesiunile, consimțămintele, dispozitivele, partajările).
      const deleted = await this.prisma.$transaction(async (tx) => {
        const user = await tx.user.findFirst({ where: { id: userId, deletedAt: { not: null } }, select: { id: true } });
        if (!user) return 0;
        const consents = await tx.consent.findMany({ where: { userId } });
        if (consents.length) await tx.consentArchive.createMany({ data: archiveRows(userId, consents) });
        return (await tx.user.deleteMany({ where: { id: userId, deletedAt: { not: null } } })).count;
      });
      this.log.log(`ștergere definitivă: ${deleted} cont(uri)`);
      return { deleted };
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

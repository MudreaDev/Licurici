import { InjectQueue, Processor, WorkerHost } from '@nestjs/bullmq';
import { Injectable, Logger, type OnModuleInit } from '@nestjs/common';
import type { Job, Queue } from 'bullmq';

import type { MailJob } from '../auth/email-flows';
import { PrismaService } from '../prisma/prisma.service';
import { Queues } from '../queues/queues';
import { isoWeek } from './weekly';

/**
 * Raportul săptămânal (README §17): lunea la 08:00 (ora României), job-ul `weekly-reports` din
 * coada `reports` pune în coada `mail` câte un e-mail pentru fiecare părinte cu adresa confirmată
 * și acordul `WEEKLY_REPORT` dat. `jobId` = cont + săptămână → o reluare nu trimite de două ori.
 */
@Injectable()
export class WeeklyReportScheduler implements OnModuleInit {
  constructor(@InjectQueue(Queues.reports) private readonly queue: Queue) {}

  async onModuleInit(): Promise<void> {
    await this.queue.upsertJobScheduler(
      'weekly-reports',
      { pattern: '0 8 * * 1', tz: 'Europe/Bucharest' },
      { name: 'weekly-reports' },
    );
  }
}

@Processor(Queues.reports)
export class WeeklyReportProcessor extends WorkerHost {
  private readonly log = new Logger(WeeklyReportProcessor.name);

  constructor(
    private readonly prisma: PrismaService,
    @InjectQueue(Queues.mail) private readonly mail: Queue<MailJob>,
  ) {
    super();
  }

  async process(job: Job): Promise<{ queued: number }> {
    if (job.name !== 'weekly-reports') return { queued: 0 };
    const week = isoWeek(new Date());
    const parents = await this.prisma.user.findMany({
      where: { role: 'PARENT', deletedAt: null, verifiedAt: { not: null } },
      select: { id: true },
    });
    let queued = 0;
    for (const { id } of parents) {
      const consent = await this.prisma.consent.findFirst({
        where: { userId: id, purpose: 'WEEKLY_REPORT' },
        orderBy: { at: 'desc' },
      });
      if (!consent?.granted) continue;
      await this.mail.add('weekly-report', { kind: 'weekly-report', userId: id, week }, { jobId: `weekly-${id}-${week}` });
      queued++;
    }
    this.log.log(`raport săptămânal ${week}: ${queued} e-mailuri în coadă`);
    return { queued };
  }
}

import { Processor, WorkerHost } from '@nestjs/bullmq';
import { Inject, Logger } from '@nestjs/common';
import type { Job } from 'bullmq';

import type { MailJob } from '../auth/email-flows';
import { ENV, type Env } from '../config/env';
import { PrismaService } from '../prisma/prisma.service';
import { Queues } from '../queues/queues';
import type { SessionFacts } from '../reports/session-summary';
import { weeklyDigest, type WeeklyDigest } from '../reports/weekly';
import { mailLink, renderMail, renderWeekly, SmtpMailProvider, type Mail, type MailProvider } from './mail';

/**
 * Coada `mail`: e-mailurile tranzacționale (confirmarea adresei, parola nouă) și raportul
 * săptămânal. Fără `SMTP_URL` job-ul se încheie fără trimitere (dezvoltare fără Mailpit).
 * Retry cu backoff din `defaultJobOptions`; un cont șters între timp nu mai primește nimic.
 */
@Processor(Queues.mail)
export class MailProcessor extends WorkerHost {
  private readonly log = new Logger(MailProcessor.name);
  private readonly provider: MailProvider | null;

  constructor(
    private readonly prisma: PrismaService,
    @Inject(ENV) private readonly env: Env,
  ) {
    super();
    this.provider = env.SMTP_URL ? new SmtpMailProvider(env.SMTP_URL, env.MAIL_FROM) : null;
  }

  async process(job: Job<MailJob>): Promise<{ sent: boolean }> {
    const data = job.data;
    const user = await this.prisma.user.findFirst({
      where: { id: data.userId, deletedAt: null },
      select: { email: true },
    });
    if (!user || !this.provider) {
      this.log.warn(`e-mail ${data.kind} netrimis (${user ? 'SMTP_URL lipsă' : 'cont inexistent'})`);
      return { sent: false };
    }
    const mail: Mail | null =
      data.kind === 'weekly-report'
        ? await this.weekly(data.userId, user.email)
        : renderMail(data.kind, user.email, mailLink(this.env.APP_URL, data.kind, data.token));
    if (!mail) return { sent: false };
    await this.provider.send(mail);
    // Fără adresă în log (README §13.4).
    this.log.log(`e-mail ${data.kind} trimis`);
    return { sent: true };
  }

  /** Raportul: doar dacă acordul e încă dat și măcar un copil a avut sesiuni în ultimele 7 zile. */
  private async weekly(userId: string, email: string): Promise<Mail | null> {
    const consent = await this.prisma.consent.findFirst({
      where: { userId, purpose: 'WEEKLY_REPORT' },
      orderBy: { at: 'desc' },
    });
    if (!consent?.granted) return null;
    const now = new Date();
    const since = new Date(now.getTime() - 14 * 24 * 3600 * 1000);
    const children = await this.prisma.child.findMany({
      where: { parentId: userId, deletedAt: null },
      orderBy: { createdAt: 'asc' },
      include: {
        therapySessions: { where: { startedAt: { gte: since } }, select: { startedAt: true, facts: true } },
      },
    });
    const digests = children
      .map((c) =>
        weeklyDigest(
          c.nickname,
          c.therapySessions.map((s) => ({ startedAt: s.startedAt, facts: s.facts as unknown as SessionFacts })),
          now,
        ),
      )
      .filter((d): d is WeeklyDigest => d != null);
    return digests.length ? renderWeekly(email, digests, this.env.APP_URL) : null;
  }
}

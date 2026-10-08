import { Processor, WorkerHost } from '@nestjs/bullmq';
import { Inject, Logger } from '@nestjs/common';
import type { Job } from 'bullmq';

import type { MailJob } from '../auth/email-flows';
import { ENV, type Env } from '../config/env';
import { PrismaService } from '../prisma/prisma.service';
import { Queues } from '../queues/queues';
import { mailLink, renderMail, SmtpMailProvider, type MailProvider } from './mail';

/**
 * Coada `mail`: e-mailurile tranzacționale (confirmarea adresei, parola nouă).
 * Fără `SMTP_URL` job-ul se încheie fără trimitere (dezvoltare fără Mailpit).
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
    const { kind, userId, token } = job.data;
    const user = await this.prisma.user.findFirst({ where: { id: userId, deletedAt: null }, select: { email: true } });
    if (!user || !this.provider) {
      this.log.warn(`e-mail ${kind} netrimis (${user ? 'SMTP_URL lipsă' : 'cont inexistent'})`);
      return { sent: false };
    }
    await this.provider.send(renderMail(kind, user.email, mailLink(this.env.APP_URL, kind, token)));
    // Fără adresă în log (README §13.4).
    this.log.log(`e-mail ${kind} trimis`);
    return { sent: true };
  }
}

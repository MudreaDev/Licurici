import { Module } from '@nestjs/common';

import { CommonModule } from './common.module';
import { GdprProcessor } from './gdpr/gdpr.processor';
import { RetentionScheduler } from './gdpr/retention.scheduler';
import { MailProcessor } from './mail/mail.processor';
import { StatsProcessor } from './stats/stats.processor';

/** Procesul worker: consumă cozile BullMQ. Scalare: `docker compose up --scale worker=N`. */
@Module({
  imports: [CommonModule],
  providers: [StatsProcessor, GdprProcessor, RetentionScheduler, MailProcessor],
})
export class WorkerModule {}

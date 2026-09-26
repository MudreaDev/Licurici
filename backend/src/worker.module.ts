import { Module } from '@nestjs/common';

import { CommonModule } from './common.module';
import { StatsProcessor } from './stats/stats.processor';

/** Procesul worker: consumă cozile BullMQ. Scalare: `docker compose up --scale worker=N`. */
@Module({
  imports: [CommonModule],
  providers: [StatsProcessor],
})
export class WorkerModule {}

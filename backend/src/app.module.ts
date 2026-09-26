import { Module } from '@nestjs/common';
import { TerminusModule } from '@nestjs/terminus';

import { CommonModule } from './common.module';
import { HealthController } from './health/health.controller';

/** Procesul API (REST + WebSocket). Modulele de domeniu (auth, children, sync…) se adaugă aici. */
@Module({
  imports: [CommonModule, TerminusModule],
  controllers: [HealthController],
})
export class AppModule {}

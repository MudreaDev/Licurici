import { Module } from '@nestjs/common';
import { TerminusModule } from '@nestjs/terminus';

import { ApiModule } from './api/api.module';
import { CommonModule } from './common.module';
import { HealthController } from './health/health.controller';

/** Procesul API (REST + WebSocket): sănătate + modulele de domeniu (auth, copii, sincronizare, rezumate). */
@Module({
  imports: [CommonModule, TerminusModule, ApiModule],
  controllers: [HealthController],
})
export class AppModule {}

import { NestFactory } from '@nestjs/core';
import { Logger } from 'nestjs-pino';

import { initSentry } from './common/sentry';
import { WorkerModule } from './worker.module';

/** Worker-ul nu deschide porturi HTTP: doar consumă job-uri din Redis. */
async function bootstrap() {
  initSentry(process.env.SENTRY_DSN, process.env.NODE_ENV ?? 'development');
  const app = await NestFactory.createApplicationContext(WorkerModule, { bufferLogs: true });
  app.useLogger(app.get(Logger));
  app.enableShutdownHooks();
}

void bootstrap();

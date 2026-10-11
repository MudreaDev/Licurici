import { NestFactory } from '@nestjs/core';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import { Logger } from 'nestjs-pino';

import { AppModule } from './app.module';
import { corsOrigins, ENV, type Env } from './config/env';
import { RedisIoAdapter } from './live/redis-io.adapter';
import { initSentry } from './common/sentry';
import { Metrics, routeTemplate } from './common/metrics';

async function bootstrap() {
  initSentry(process.env.SENTRY_DSN, process.env.NODE_ENV ?? 'development');
  const app = await NestFactory.create(AppModule, { bufferLogs: true });
  app.useLogger(app.get(Logger));
  const env = app.get<Env>(ENV);

  app.setGlobalPrefix('api/v1', { exclude: ['health', 'health/ready', 'metrics'] });
  // Durata fiecărei cereri, pe ruta-șablon (fără id-uri) — ADR-018.
  const metrics = app.get(Metrics);
  app.use((req: Parameters<typeof routeTemplate>[0] & { method: string }, res: { statusCode: number; on(e: 'finish', f: () => void): void }, next: () => void) => {
    const start = process.hrtime.bigint();
    res.on('finish', () =>
      metrics.observe(req.method, routeTemplate(req), res.statusCode, Number(process.hrtime.bigint() - start) / 1e9),
    );
    next();
  });
  app.enableShutdownHooks();
  // Panoul web rulează pe altă origine (alt port în dezvoltare, alt subdomeniu în producție).
  // Tokenurile merg în antetul Authorization, nu în cookie-uri → fără `credentials`.
  app.enableCors({
    origin: corsOrigins(env),
    methods: ['GET', 'POST', 'PUT', 'DELETE'],
    allowedHeaders: ['content-type', 'authorization'],
    maxAge: 600,
  });
  // Canalul live al panoului (Socket.IO + adapterul Redis, ADR-010).
  const io = new RedisIoAdapter(app, env.REDIS_URL, corsOrigins(env));
  await io.connect();
  app.useWebSocketAdapter(io);

  if (env.NODE_ENV !== 'production') {
    const doc = new DocumentBuilder()
      .setTitle('Licurici API')
      .setDescription('API-ul platformei Licurici (README §12)')
      .setVersion('0.1.0')
      .addBearerAuth()
      .build();
    SwaggerModule.setup('api/docs', app, () => SwaggerModule.createDocument(app, doc));
  }

  await app.listen(env.PORT, '0.0.0.0');
}

void bootstrap();

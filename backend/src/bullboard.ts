import { timingSafeEqual } from 'node:crypto';

import { createBullBoard } from '@bull-board/api';
import { BullMQAdapter } from '@bull-board/api/bullMQAdapter';
import { ExpressAdapter } from '@bull-board/express';
import { Queue } from 'bullmq';
import express, { type NextFunction, type Request, type Response } from 'express';

import { loadEnv } from './config/env';
import { Queues, bullConnection } from './queues/queues';

/**
 * Bull Board (README §18): cozile BullMQ văzute în browser — doar în dezvoltare, pe un port
 * separat (3001), cu parolă (`BULLBOARD_PASSWORD`). Joburile au doar id-uri (fără e-mailuri,
 * README §13.4), deci nu expune date personale. În producție nu pornește.
 */
export function basicAuth(password: string) {
  const expected = Buffer.from(`admin:${password}`);
  return (req: Request, res: Response, next: NextFunction) => {
    const header = req.headers.authorization ?? '';
    const given = Buffer.from(header.startsWith('Basic ') ? Buffer.from(header.slice(6), 'base64').toString() : '');
    if (given.length === expected.length && timingSafeEqual(given, expected)) return next();
    res.setHeader('WWW-Authenticate', 'Basic realm="Licurici cozi"').status(401).send('Autentificare necesară.');
  };
}

function main() {
  const env = loadEnv();
  if (env.NODE_ENV === 'production') throw new Error('Bull Board rulează doar în dezvoltare.');
  if (!env.BULLBOARD_PASSWORD) throw new Error('Setează BULLBOARD_PASSWORD.');
  const connection = bullConnection(env);
  const adapter = new ExpressAdapter().setBasePath('/');
  createBullBoard({
    queues: Object.values(Queues).map((name) => new BullMQAdapter(new Queue(name, { connection }), { readOnlyMode: false })),
    serverAdapter: adapter,
  });
  const app = express();
  app.use(basicAuth(env.BULLBOARD_PASSWORD));
  app.use('/', adapter.getRouter());
  app.listen(3001, () => console.log('Bull Board: http://localhost:3001 (utilizator admin)'));
}

if (require.main === module) main();

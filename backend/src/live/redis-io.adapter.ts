import type { INestApplicationContext } from '@nestjs/common';
import { IoAdapter } from '@nestjs/platform-socket.io';
import { createAdapter } from '@socket.io/redis-adapter';
import { Redis } from 'ioredis';
import type { Server, ServerOptions } from 'socket.io';

/**
 * Socket.IO cu adapterul Redis (ADR-010): mai multe instanțe de API împart camerele, deci un
 * eveniment emis de instanța care a primit sincronizarea ajunge la panoul conectat la alta.
 * CORS: aceleași origini ca REST-ul.
 */
export class RedisIoAdapter extends IoAdapter {
  private adapter?: ReturnType<typeof createAdapter>;

  constructor(
    app: INestApplicationContext,
    private readonly redisUrl: string,
    private readonly origins: string[],
  ) {
    super(app);
  }

  async connect(): Promise<void> {
    const pub = new Redis(this.redisUrl, { lazyConnect: true });
    const sub = pub.duplicate();
    pub.on('error', () => undefined);
    sub.on('error', () => undefined);
    try {
      await Promise.all([pub.connect(), sub.connect()]);
      this.adapter = createAdapter(pub, sub);
    } catch {
      // Fără Redis: canalul merge doar în instanța curentă (destul pentru o singură instanță).
      pub.disconnect();
      sub.disconnect();
    }
  }

  override createIOServer(port: number, options?: ServerOptions): Server {
    const server = super.createIOServer(port, {
      ...(options as ServerOptions),
      serveClient: false,
      path: '/api/v1/live',
      cors: { origin: this.origins, methods: ['GET', 'POST'] },
      // Doar WebSocket: fără long polling (mai puține cereri, CSP simplu).
      transports: ['websocket'],
    }) as Server;
    if (this.adapter) server.adapter(this.adapter);
    return server;
  }
}

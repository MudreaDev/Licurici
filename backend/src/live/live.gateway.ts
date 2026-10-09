import { Inject, Logger } from '@nestjs/common';
import {
  ConnectedSocket,
  MessageBody,
  type OnGatewayConnection,
  SubscribeMessage,
  WebSocketGateway,
  WebSocketServer,
} from '@nestjs/websockets';
import type { Server, Socket } from 'socket.io';

import type { AuthUser } from '../auth/tokens';
import { LiveAccess, type LiveEvent, type LiveEvents, childRoom } from './live';
import { REDIS } from '../redis/redis.module';
import { presenceKey, type PresenceStore } from './presence';

/**
 * Canalul live al panoului (ADR-010, README §8): Socket.IO pe `/api/v1/live`, camere
 * `child:{id}`. Panoul se conectează cu tokenul de acces, cere „watch” pentru copiii pe care îi
 * vede și primește `session.synced` / `plan.changed`. Cu adapterul Redis (`main.ts`),
 * evenimentele ajung la panouri conectate la oricare instanță a API-ului.
 * Evenimentele au doar id-uri și numere — niciun conținut al sesiunilor.
 */
@WebSocketGateway()
export class LiveGateway implements OnGatewayConnection, LiveEvents {
  private readonly log = new Logger(LiveGateway.name);

  @WebSocketServer() server?: Server;

  constructor(
    @Inject(LiveAccess) private readonly access: LiveAccess,
    // Direct din Redis (nu prin PresenceService, care publică prin acest gateway).
    @Inject(REDIS) private readonly store: Pick<PresenceStore, 'get'>,
  ) {}

  handleConnection(client: Socket): void {
    const user = this.access.connect(client.handshake.auth?.token);
    if (!user) {
      client.disconnect(true);
      return;
    }
    (client.data as { user?: AuthUser }).user = user;
  }

  @SubscribeMessage('watch')
  async watch(
    @ConnectedSocket() client: Socket,
    @MessageBody() body: { childId?: unknown },
  ): Promise<{ ok: boolean; playing?: boolean }> {
    const user = (client.data as { user?: AuthUser }).user;
    const room = user ? await this.access.canWatch(user, body?.childId) : null;
    if (!room) return { ok: false };
    await client.join(room);
    // Starea de acum, ca panoul deschis în timpul unei sesiuni să o vadă imediat.
    const playing = (await this.store.get(presenceKey(body.childId as string)).catch(() => null)) != null;
    return { ok: true, playing };
  }

  publish(event: LiveEvent): void {
    if (!this.server) return;
    this.server.to(childRoom(event.childId)).emit(event.type, event);
    this.log.debug(`live ${event.type}`);
  }
}

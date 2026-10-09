import type { AuthUser } from '../auth/tokens';
import type { ChildAccess } from '../children/access';
import type { ConsentService } from '../consents/consents';
import type { LiveEvents } from './live';

/** Ce din Redis folosim (în teste, o hartă). */
export interface PresenceStore {
  set(key: string, value: string, mode: 'EX', seconds: number): Promise<unknown>;
  get(key: string): Promise<string | null>;
  del(key: string): Promise<number>;
}

/** Semnul „se joacă acum” al copilului în Redis. */
export const presenceKey = (childId: string) => `presence:${childId}`;

/** O sesiune nu durează mai mult; dacă tableta nu anunță finalul, prezența se stinge singură. */
export const PRESENCE_TTL_SECONDS = 20 * 60;

/**
 * „Se joacă acum” (README §21): tableta anunță începutul unei sesiuni (doar cu trimiterea
 * automată pornită, deci cu acordul de sincronizare); sesiunea sincronizată o încheie.
 * În Redis stă doar un semn cu termen, fără nimic despre joc.
 */
export class PresenceService {
  constructor(
    private readonly access: ChildAccess,
    private readonly consents: ConsentService,
    private readonly store: PresenceStore,
    private readonly live: LiveEvents,
  ) {}

  async start(user: AuthUser, childId: string): Promise<void> {
    const child = await this.access.assert(user, childId, 'write');
    await this.consents.require(child.parentId, 'SYNC', 'Prezența cere consimțământul părintelui pentru sincronizare.');
    await this.store.set(presenceKey(childId), '1', 'EX', PRESENCE_TTL_SECONDS);
    this.live.publish({ type: 'presence', childId, playing: true });
  }

  /** După sincronizarea sesiunii: copilul a terminat. */
  async stop(childId: string): Promise<void> {
    if ((await this.store.del(presenceKey(childId))) > 0) {
      this.live.publish({ type: 'presence', childId, playing: false });
    }
  }

  async playing(childId: string): Promise<boolean> {
    return (await this.store.get(presenceKey(childId))) != null;
  }
}

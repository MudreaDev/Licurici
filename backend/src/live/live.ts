import type { AuthUser, TokenService } from '../auth/tokens';
import type { ChildAccess } from '../children/access';

/** Evenimentele trimise panoului (ADR-010: WebSocket doar pentru dashboard). */
export type LiveEvent =
  | { type: 'session.synced'; childId: string; count: number }
  | { type: 'plan.changed'; childId: string; by: 'PARENT' | 'THERAPIST' }
  | { type: 'presence'; childId: string; playing: boolean };

/** Cine anunță: serviciile de domeniu nu știu de Socket.IO (în teste, o listă). */
export interface LiveEvents {
  publish(event: LiveEvent): void;
}

/** Camera unui copil: o vede doar cine are drept de citire (părintele, specialistul legat). */
export const childRoom = (childId: string) => `child:${childId}`;

/**
 * Autorizarea canalului live, fără Socket.IO (testabilă): la conectare, tokenul de acces (JWT,
 * 15 min); la „watch”, aceeași regulă de acces ca în REST. Un copil străin = refuz, fără să
 * aflăm dacă există.
 */
export class LiveAccess {
  constructor(
    private readonly tokens: Pick<TokenService, 'verifyAccess'>,
    private readonly access: Pick<ChildAccess, 'assert'>,
  ) {}

  /** null = conexiune refuzată. */
  connect(token: unknown): AuthUser | null {
    if (typeof token !== 'string' || token.length > 2000) return null;
    try {
      return this.tokens.verifyAccess(token);
    } catch {
      return null;
    }
  }

  async canWatch(user: AuthUser, childId: unknown): Promise<string | null> {
    if (typeof childId !== 'string' || !/^[0-9a-f-]{36}$/i.test(childId)) return null;
    try {
      await this.access.assert(user, childId, 'read');
      return childRoom(childId);
    } catch {
      return null;
    }
  }
}

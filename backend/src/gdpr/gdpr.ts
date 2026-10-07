import { z } from 'zod';

import type { AuthUser } from '../auth/tokens';
import type { ChildAccess } from '../children/access';
import { ForbiddenError, UnauthorizedError } from '../common/errors';
import { parseWith } from '../common/validation';

export interface GdprExport {
  format: 'licurici-export';
  version: 1;
  exportedAt: string;
  account: { email: string; role: string; createdAt: string };
  consents: { purpose: string; granted: boolean; policyVersion: string; at: string }[];
  children: {
    nickname: string;
    avatar: string;
    birthYear: number | null;
    sessions: { record: unknown; summary: unknown | null }[];
  }[];
}

export interface GdprRepo {
  account(userId: string): Promise<GdprExport['account']>;
  consentLog(userId: string): Promise<GdprExport['consents']>;
  childrenWithSessions(parentId: string): Promise<GdprExport['children']>;
  /** Marchează copilul șters și taie imediat partajările; ștergerea definitivă o face worker-ul. */
  softDeleteChild(childId: string, at: Date): Promise<void>;
  /** Marchează contul șters: copiii lui șterși, partajările tăiate (și cele ale specialistului),
   *  e-mailul anonimizat (poate fi refolosit), parola ștearsă (nu se mai poate autentifica). */
  softDeleteAccount(userId: string, at: Date): Promise<void>;
  audit(actorId: string, action: string, targetId: string): Promise<void>;
}

export interface PurgeQueue {
  /** Programează ștergerea definitivă (coada `gdpr`, worker) după perioada de grație. */
  schedulePurge(childId: string, at: Date): Promise<void>;
  /** Ștergerea definitivă a contului (cu tot ce ține de el, în cascadă). */
  schedulePurgeAccount(userId: string, at: Date): Promise<void>;
}

/** Verifică parola contului (implementată de `AuthService.confirmPassword`). */
export interface PasswordCheck {
  confirm(userId: string, password: string): Promise<boolean>;
}

export const deleteAccountSchema = z.object({ password: z.string().min(1).max(200) }).strict();

/** Zile în care părintele poate anula ștergerea (greșeli), apoi datele dispar definitiv. */
export const PURGE_AFTER_DAYS = 7;

/**
 * Drepturile părintelui asupra datelor (GDPR art. 15, 17, 20; Legea 195/2024; README §13):
 * export complet într-un format citibil de mașină și ștergerea profilului unui copil.
 */
export class GdprService {
  constructor(
    private readonly access: ChildAccess,
    private readonly repo: GdprRepo,
    private readonly queue: PurgeQueue,
    private readonly passwords: PasswordCheck,
    private readonly now: () => Date = () => new Date(),
  ) {}

  async export(user: AuthUser): Promise<GdprExport> {
    if (user.role !== 'PARENT') throw new ForbiddenError('Exportul datelor copilului îl cere părintele.');
    const [account, consents, children] = await Promise.all([
      this.repo.account(user.id),
      this.repo.consentLog(user.id),
      this.repo.childrenWithSessions(user.id),
    ]);
    await this.repo.audit(user.id, 'gdpr.export', user.id);
    return {
      format: 'licurici-export',
      version: 1,
      exportedAt: this.now().toISOString(),
      account,
      consents,
      children,
    };
  }

  async deleteChild(user: AuthUser, childId: string): Promise<{ purgeAt: string }> {
    if (user.role !== 'PARENT') throw new ForbiddenError('Doar părintele poate șterge profilul copilului.');
    await this.access.assert(user, childId, 'write');
    const now = this.now();
    const purgeAt = new Date(now.getTime() + PURGE_AFTER_DAYS * 24 * 3600 * 1000);
    await this.repo.softDeleteChild(childId, now);
    await this.queue.schedulePurge(childId, purgeAt);
    await this.repo.audit(user.id, 'gdpr.child.delete', childId);
    return { purgeAt: purgeAt.toISOString() };
  }

  /**
   * Ștergerea contului (GDPR art. 17), pentru părinte și specialist: cere parola din nou,
   * taie accesul imediat, iar ștergerea definitivă vine după perioada de grație. Tokenurile de
   * acces deja emise mai trăiesc cel mult 15 minute, dar nu mai găsesc nimic: copiii sunt
   * marcați șterși, partajările tăiate, iar reîmprospătarea sesiunii e refuzată.
   */
  async deleteAccount(user: AuthUser, body: unknown): Promise<{ purgeAt: string }> {
    const { password } = parseWith(deleteAccountSchema, body);
    if (user.role === 'ADMIN') throw new ForbiddenError('Conturile de administrator nu se șterg din aplicație.');
    if (!(await this.passwords.confirm(user.id, password))) throw new UnauthorizedError('Parola nu e corectă.');
    const now = this.now();
    const purgeAt = new Date(now.getTime() + PURGE_AFTER_DAYS * 24 * 3600 * 1000);
    // Auditul întâi: rândul rămâne până la ștergerea definitivă (cascadă cu contul).
    await this.repo.audit(user.id, 'gdpr.account.delete', user.id);
    await this.repo.softDeleteAccount(user.id, now);
    await this.queue.schedulePurgeAccount(user.id, purgeAt);
    return { purgeAt: purgeAt.toISOString() };
  }
}

import type { AuthUser } from '../auth/tokens';
import type { ChildAccess } from '../children/access';
import { ForbiddenError } from '../common/errors';

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
  audit(actorId: string, action: string, targetId: string): Promise<void>;
}

export interface PurgeQueue {
  /** Programează ștergerea definitivă (coada `gdpr`, worker) după perioada de grație. */
  schedulePurge(childId: string, at: Date): Promise<void>;
}

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
}

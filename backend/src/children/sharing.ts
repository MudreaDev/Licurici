import { z } from 'zod';

import type { AuthUser } from '../auth/tokens';
import type { ConsentService } from '../consents/consents';
import { ForbiddenError, NotFoundError } from '../common/errors';
import { parseWith } from '../common/validation';
import type { ChildAccess } from './access';

export const shareSchema = z
  .object({
    email: z.preprocess((v) => (typeof v === 'string' ? v.trim().toLowerCase() : v), z.email().max(254)),
    /** Partajarea expiră implicit (minimizare): 90 de zile, maxim un an. */
    days: z.number().int().min(1).max(365).default(90),
  })
  .strict();

export interface Share {
  therapistId: string;
  expiresAt: Date;
}

export interface SharingRepo {
  findTherapist(email: string): Promise<{ id: string } | null>;
  upsertLink(childId: string, therapistId: string, expiresAt: Date): Promise<void>;
  removeLink(childId: string, therapistId: string): Promise<boolean>;
  links(childId: string): Promise<Share[]>;
  audit(actorId: string, action: string, targetId: string): Promise<void>;
}

/**
 * Părintele partajează copilul cu un specialist (README §2.1): doar el, doar cu consimțământul
 * `THERAPIST_SHARING`, doar cu un cont de specialist existent, pe timp limitat, revocabil oricând.
 * Fiecare acțiune intră în jurnalul de audit. Un e-mail necunoscut primește același răspuns ca
 * unul greșit (nu dezvăluim cine are cont).
 */
export class SharingService {
  constructor(
    private readonly access: ChildAccess,
    private readonly consents: ConsentService,
    private readonly repo: SharingRepo,
    private readonly now: () => Date = () => new Date(),
  ) {}

  private async owner(user: AuthUser, childId: string) {
    if (user.role !== 'PARENT') throw new ForbiddenError('Doar părintele poate partaja datele copilului.');
    return this.access.assert(user, childId, 'write');
  }

  async share(user: AuthUser, childId: string, body: unknown): Promise<Share> {
    const child = await this.owner(user, childId);
    const { email, days } = parseWith(shareSchema, body);
    await this.consents.require(
      child.parentId,
      'THERAPIST_SHARING',
      'Partajarea cu un specialist cere consimțământul părintelui.',
    );
    const therapist = await this.repo.findTherapist(email);
    if (!therapist) throw new NotFoundError('Nu există un cont de specialist cu acest e-mail.');
    const expiresAt = new Date(this.now().getTime() + days * 24 * 3600 * 1000);
    await this.repo.upsertLink(childId, therapist.id, expiresAt);
    await this.repo.audit(user.id, 'child.share', childId);
    return { therapistId: therapist.id, expiresAt };
  }

  async revoke(user: AuthUser, childId: string, therapistId: string): Promise<void> {
    await this.owner(user, childId);
    if (!(await this.repo.removeLink(childId, therapistId))) throw new NotFoundError('Partajarea nu există.');
    await this.repo.audit(user.id, 'child.unshare', childId);
  }

  async list(user: AuthUser, childId: string): Promise<Share[]> {
    await this.owner(user, childId);
    return this.repo.links(childId);
  }
}

import { z } from 'zod';

import type { AuthUser } from '../auth/tokens';
import { ForbiddenError } from '../common/errors';
import { parseWith } from '../common/validation';

/** Scopurile pentru care părintele își dă (sau își retrage) consimțământul (README §13). */
export const consentPurposes = ['SYNC', 'WEEKLY_REPORT', 'THERAPIST_SHARING', 'PUSH_NOTIFICATIONS', 'AI_SUMMARY'] as const;
export type ConsentPurpose = (typeof consentPurposes)[number];

export const consentSchema = z
  .object({
    purpose: z.enum(consentPurposes),
    granted: z.boolean(),
    /** Versiunea politicii de confidențialitate acceptate (dovada a ce s-a acceptat). */
    policyVersion: z.string().min(1).max(16),
  })
  .strict();

export interface ConsentStore {
  /** Ultima decizie a utilizatorului pentru scop (consimțământul se poate retrage oricând). */
  granted(userId: string, purpose: ConsentPurpose): Promise<boolean>;
  /** Jurnal append-only: fiecare decizie e un rând nou, cu data (dovadă, GDPR art. 7). */
  record(userId: string, data: z.infer<typeof consentSchema>): Promise<void>;
  current(userId: string): Promise<Record<ConsentPurpose, boolean>>;
}

export class ConsentService {
  constructor(private readonly store: ConsentStore) {}

  async set(user: AuthUser, body: unknown): Promise<Record<ConsentPurpose, boolean>> {
    if (user.role !== 'PARENT') throw new ForbiddenError('Consimțământul pentru datele copilului îl dă părintele.');
    await this.store.record(user.id, parseWith(consentSchema, body));
    return this.store.current(user.id);
  }

  get(user: AuthUser): Promise<Record<ConsentPurpose, boolean>> {
    return this.store.current(user.id);
  }

  /** Aruncă 403 dacă părintele nu a consimțit (sau și-a retras consimțământul). */
  async require(parentId: string, purpose: ConsentPurpose, message: string): Promise<void> {
    if (!(await this.store.granted(parentId, purpose))) throw new ForbiddenError(message);
  }
}

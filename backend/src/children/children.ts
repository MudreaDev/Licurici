import { z } from 'zod';

import type { AuthUser } from '../auth/tokens';
import { ForbiddenError } from '../common/errors';
import { parseWith } from '../common/validation';

/** Profilul copilului (ADR-012, README §13.3): poreclă + avatar, an de naștere opțional. */
export const createChildSchema = z
  .object({
    nickname: z.string().trim().min(1).max(40),
    avatar: z.string().max(16).default('🐞'),
    birthYear: z.number().int().min(2005).max(2030).optional(),
  })
  .strict();

export interface ChildSummary {
  id: string;
  nickname: string;
  avatar: string;
  birthYear: number | null;
}

export interface ChildrenRepo {
  ownedBy(parentId: string): Promise<ChildSummary[]>;
  linkedTo(therapistId: string, now: Date): Promise<ChildSummary[]>;
  create(parentId: string, data: z.infer<typeof createChildSchema>): Promise<ChildSummary>;
}

export class ChildrenService {
  constructor(
    private readonly repo: ChildrenRepo,
    private readonly now: () => Date = () => new Date(),
  ) {}

  /** Părintele își vede copiii; specialistul, doar copiii partajați cu el (legături active). */
  list(user: AuthUser): Promise<ChildSummary[]> {
    return user.role === 'THERAPIST' ? this.repo.linkedTo(user.id, this.now()) : this.repo.ownedBy(user.id);
  }

  create(user: AuthUser, body: unknown): Promise<ChildSummary> {
    if (user.role !== 'PARENT') throw new ForbiddenError('Doar părintele poate crea profilul copilului.');
    return this.repo.create(user.id, parseWith(createChildSchema, body));
  }
}

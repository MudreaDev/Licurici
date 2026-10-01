import type { AuthUser } from '../auth/tokens';
import { ForbiddenError, NotFoundError } from '../common/errors';

export interface ChildRow {
  id: string;
  parentId: string;
  deletedAt: Date | null;
}

export interface ChildRepo {
  findChild(id: string): Promise<ChildRow | null>;
  /** Legătură specialist ↔ copil activă (neexpirată) la momentul [now]. */
  hasActiveLink(childId: string, therapistId: string, now: Date): Promise<boolean>;
}

export type AccessMode = 'read' | 'write';

/**
 * Cine vede datele unui copil (README §2.1, §13): părintele lui (citire + scriere) și
 * specialistul căruia părintele i-a partajat copilul (`CareLink`, doar citire, cât timp nu a
 * expirat). Oricine altcineva primește 404 — nu aflăm nici măcar că acel copil există.
 */
export class ChildAccess {
  constructor(
    private readonly repo: ChildRepo,
    private readonly now: () => Date = () => new Date(),
  ) {}

  async assert(user: AuthUser, childId: string, mode: AccessMode): Promise<ChildRow> {
    const child = await this.repo.findChild(childId);
    if (!child || child.deletedAt) throw new NotFoundError('Copilul nu există.');
    if (user.role === 'PARENT' && child.parentId === user.id) return child;
    if (user.role === 'THERAPIST' && (await this.repo.hasActiveLink(childId, user.id, this.now()))) {
      if (mode === 'write') throw new ForbiddenError('Specialistul poate doar vizualiza datele copilului.');
      return child;
    }
    throw new NotFoundError('Copilul nu există.');
  }
}

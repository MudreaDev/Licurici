import type { AuthUser } from '../auth/tokens';
import { NotFoundError, ValidationError } from '../common/errors';
import { ChildAccess } from './access';
import { type GamePlan, GamePlanService, type PlanRepo } from './plan';

const CHILD = '0190a1b2-0000-7000-8000-000000000001';
const parent: AuthUser = { id: 'p1', role: 'PARENT' };
const therapist: AuthUser = { id: 't1', role: 'THERAPIST' };
const stranger: AuthUser = { id: 't2', role: 'THERAPIST' };
const now = new Date('2026-10-09T08:00:00Z');

function setup({ linked = true } = {}) {
  let stored: GamePlan | null = null;
  const auditLog: string[] = [];
  const repo: PlanRepo = {
    read: async () => stored,
    write: async (_c, p) => void (stored = p),
    audit: async (actor, action) => void auditLog.push(`${actor}:${action}`),
  };
  const access = new ChildAccess(
    {
      findChild: async (id) => (id === CHILD ? { id, parentId: 'p1', deletedAt: null } : null),
      hasActiveLink: async (_c, t) => linked && t === 't1',
    },
    () => now,
  );
  return { plan: new GamePlanService(access, repo, () => now), auditLog, stored: () => stored };
}

describe('GamePlanService', () => {
  it('fără plan: toate jocurile (listă goală)', async () => {
    const { plan } = setup();
    await expect(plan.get(parent, CHILD)).resolves.toEqual({ hiddenGames: [], updatedAt: null, updatedBy: null });
  });

  it('părintele și specialistul cu partajare activă pot alege jocurile; fiecare schimbare e în audit', async () => {
    const { plan, auditLog } = setup();
    const a = await plan.put(parent, CHILD, { hiddenGames: ['simon', 'pescarul', 'simon'] });
    expect(a.hiddenGames).toEqual(['pescarul', 'simon']);
    expect(a.updatedBy).toBe('PARENT');
    const b = await plan.put(therapist, CHILD, { hiddenGames: ['cauta'] });
    expect(b.updatedBy).toBe('THERAPIST');
    expect(b.updatedAt).toEqual(now);
    await expect(plan.get(parent, CHILD)).resolves.toMatchObject({ hiddenGames: ['cauta'] });
    expect(auditLog).toEqual(['p1:child.plan', 't1:child.plan']);
  });

  it('specialistul fără partajare (sau expirată) și oricine altcineva: 404', async () => {
    const { plan } = setup({ linked: false });
    await expect(plan.put(therapist, CHILD, { hiddenGames: [] })).rejects.toBeInstanceOf(NotFoundError);
    await expect(plan.get(stranger, CHILD)).rejects.toBeInstanceOf(NotFoundError);
  });

  it('doar id-uri de joc, cel mult 200, fără alte câmpuri', async () => {
    const { plan } = setup();
    await expect(plan.put(parent, CHILD, { hiddenGames: ['Nume Copil'] })).rejects.toBeInstanceOf(ValidationError);
    await expect(plan.put(parent, CHILD, { hiddenGames: [], notes: 'x' })).rejects.toBeInstanceOf(ValidationError);
    await expect(
      plan.put(parent, CHILD, { hiddenGames: Array.from({ length: 201 }, (_, i) => `joc-${i}`) }),
    ).rejects.toBeInstanceOf(ValidationError);
  });
});

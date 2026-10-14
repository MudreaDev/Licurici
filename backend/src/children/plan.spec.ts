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
    await expect(plan.get(parent, CHILD)).resolves.toEqual({
      hiddenGames: [],
      levels: {},
      maxLevels: {},
      rounds: {},
      avoid: [],
      updatedAt: null,
      updatedBy: null,
      history: [],
    });
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
    // Istoricul: o linie de schimbare de fază pentru fiecare.
    expect(b.history.map((h) => [h.by, h.hidden])).toEqual([
      ['PARENT', 2],
      ['THERAPIST', 1],
    ]);
  });

  it('specialistul fără partajare (sau expirată) și oricine altcineva: 404', async () => {
    const { plan } = setup({ linked: false });
    await expect(plan.put(therapist, CHILD, { hiddenGames: [] })).rejects.toBeInstanceOf(NotFoundError);
    await expect(plan.get(stranger, CHILD)).rejects.toBeInstanceOf(NotFoundError);
  });

  it('nivelul de pornire pe joc: între 1 și 40, doar pentru id-uri de joc', async () => {
    const { plan } = setup();
    const p = await plan.put(therapist, CHILD, { hiddenGames: [], levels: { pescarul: 5, simon: 3 } });
    expect(p.levels).toEqual({ pescarul: 5, simon: 3 });
    await expect(plan.put(parent, CHILD, { hiddenGames: [], levels: { pescarul: 0 } })).rejects.toBeInstanceOf(ValidationError);
    await expect(plan.put(parent, CHILD, { hiddenGames: [], levels: { 'Nume Copil': 2 } })).rejects.toBeInstanceOf(ValidationError);
    // Plafonul de dificultate: păstrat, iar pornirea nu poate fi peste el.
    const capped = await plan.put(therapist, CHILD, { hiddenGames: [], levels: { simon: 3 }, maxLevels: { simon: 6, emotii: 4 } });
    expect(capped.maxLevels).toEqual({ simon: 6, emotii: 4 });
    expect((await plan.put(therapist, CHILD, { hiddenGames: [], rounds: { emotii: 4 } })).rounds).toEqual({ emotii: 4 });
    await expect(plan.put(therapist, CHILD, { hiddenGames: [], rounds: { emotii: 50 } })).rejects.toBeInstanceOf(ValidationError);
    expect((await plan.put(parent, CHILD, { hiddenGames: [], avoid: ['insecte', 'caini', 'caini'] })).avoid).toEqual(['caini', 'insecte']);
    await expect(plan.put(parent, CHILD, { hiddenGames: [], avoid: ['Text Liber!'] })).rejects.toBeInstanceOf(ValidationError);
    // Muzica de fundal: aleasă de specialist, rămâne la schimbările care n-o trimit.
    expect((await plan.put(therapist, CHILD, { hiddenGames: [], music: { on: false, track: 'valuri' } })).music).toEqual({
      on: false,
      track: 'valuri',
    });
    expect((await plan.put(parent, CHILD, { hiddenGames: ['cauta'] })).music).toEqual({ on: false, track: 'valuri' });
    await expect(plan.put(parent, CHILD, { hiddenGames: [], music: { on: true, track: 'rock' } })).rejects.toBeInstanceOf(ValidationError);
    await expect(plan.put(parent, CHILD, { hiddenGames: [], music: { on: true, track: 'all', vol: 1 } })).rejects.toBeInstanceOf(
      ValidationError,
    );
    await expect(
      plan.put(therapist, CHILD, { hiddenGames: [], levels: { simon: 8 }, maxLevels: { simon: 6 } }),
    ).rejects.toBeInstanceOf(ValidationError);
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

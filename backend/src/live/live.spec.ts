import type { AuthUser } from '../auth/tokens';
import { ForbiddenError, NotFoundError, UnauthorizedError } from '../common/errors';
import { LiveAccess, type LiveEvent } from './live';
import { PresenceService } from './presence';

const CHILD = '0190a1b2-0000-7000-8000-000000000001';
const OTHER = '0190a1b2-0000-7000-8000-000000000002';

const users: Record<string, AuthUser> = { 'tok-ana': { id: 'p1', role: 'PARENT' } };
const access = new LiveAccess(
  {
    verifyAccess: (t: string) => {
      const u = users[t];
      if (!u) throw new UnauthorizedError();
      return u;
    },
  },
  {
    assert: async (_u, childId) => {
      if (childId !== CHILD) throw new NotFoundError('Copilul nu există.');
      return { id: CHILD, parentId: 'p1', deletedAt: null };
    },
  },
);

describe('LiveAccess', () => {
  it('conectare doar cu token valid; „watch” doar pentru copiii vizibili', async () => {
    expect(access.connect('tok-ana')).toEqual(users['tok-ana']);
    expect(access.connect('altul')).toBeNull();
    expect(access.connect(undefined)).toBeNull();
    expect(await access.canWatch(users['tok-ana'], CHILD)).toBe(`child:${CHILD}`);
    expect(await access.canWatch(users['tok-ana'], OTHER)).toBeNull();
    expect(await access.canWatch(users['tok-ana'], '../x')).toBeNull();
  });
});

describe('PresenceService (se joacă acum)', () => {
  function presenceSetup(syncConsent = true) {
    const data = new Map<string, string>();
    const events: LiveEvent[] = [];
    const service = new PresenceService(
      { assert: async (u: AuthUser, id: string) => {
        if (u.id !== 'p1' || id !== CHILD) throw new NotFoundError('Copilul nu există.');
        return { id, parentId: 'p1', deletedAt: null };
      } } as never,
      { require: async () => {
        if (!syncConsent) throw new ForbiddenError('fără acord');
      } } as never,
      {
        set: async (k: string, v: string) => data.set(k, v),
        get: async (k: string) => data.get(k) ?? null,
        del: async (k: string) => (data.delete(k) ? 1 : 0),
      },
      { publish: (e) => events.push(e) },
    );
    return { service, events };
  }

  it('începe la semnalul tabletei, se termină când sesiunea ajunge pe server', async () => {
    const { service, events } = presenceSetup();
    await service.start(users['tok-ana'], CHILD);
    expect(await service.playing(CHILD)).toBe(true);
    await service.stop(CHILD);
    await service.stop(CHILD); // a doua oară: nicio veste nouă
    expect(await service.playing(CHILD)).toBe(false);
    expect(events).toEqual([
      { type: 'presence', childId: CHILD, playing: true },
      { type: 'presence', childId: CHILD, playing: false },
    ]);
  });

  it('doar părintele copilului și doar cu acordul de sincronizare', async () => {
    await expect(presenceSetup().service.start({ id: 't1', role: 'THERAPIST' }, CHILD)).rejects.toBeInstanceOf(
      NotFoundError,
    );
    const noConsent = presenceSetup(false);
    await expect(noConsent.service.start(users['tok-ana'], CHILD)).rejects.toBeInstanceOf(ForbiddenError);
    expect(noConsent.events).toHaveLength(0);
  });
});

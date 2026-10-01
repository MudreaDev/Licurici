import type { AuthUser } from '../auth/tokens';
import { ForbiddenError, NotFoundError, ValidationError } from '../common/errors';
import { ConsentService, type ConsentStore } from '../consents/consents';
import { ChildAccess } from './access';
import { type Share, SharingService, type SharingRepo } from './sharing';

const CHILD = '0190a1b2-0000-7000-8000-000000000001';
const parent: AuthUser = { id: 'p1', role: 'PARENT' };
const therapist: AuthUser = { id: 't1', role: 'THERAPIST' };
const now = new Date('2026-10-01T12:00:00Z');

function setup({ consent = true } = {}) {
  const links = new Map<string, Date>();
  const auditLog: string[] = [];
  const repo: SharingRepo = {
    findTherapist: async (email) => (email === 'dr@clinica.md' ? { id: 't1' } : null),
    upsertLink: async (_c, t, e) => void links.set(t, e),
    removeLink: async (_c, t) => links.delete(t),
    links: async () => [...links].map(([therapistId, expiresAt]): Share => ({ therapistId, expiresAt })),
    audit: async (actor, action) => void auditLog.push(`${actor}:${action}`),
  };
  const access = new ChildAccess(
    {
      findChild: async (id) => (id === CHILD ? { id, parentId: 'p1', deletedAt: null } : null),
      hasActiveLink: async (_c, t, at) => (links.get(t)?.getTime() ?? 0) > at.getTime(),
    },
    () => now,
  );
  const store: ConsentStore = {
    granted: async (_u, p) => consent && p === 'THERAPIST_SHARING',
    record: async () => undefined,
    current: async () => ({}) as never,
  };
  return { access, links, auditLog, sharing: new SharingService(access, new ConsentService(store), repo, () => now) };
}

describe('SharingService', () => {
  it('părintele partajează cu specialistul (90 de zile implicit) → specialistul poate citi; audit', async () => {
    const { sharing, access, auditLog } = setup();
    const share = await sharing.share(parent, CHILD, { email: ' DR@clinica.md ' });
    expect(share.expiresAt.toISOString()).toBe('2026-12-30T12:00:00.000Z');
    await expect(access.assert(therapist, CHILD, 'read')).resolves.toBeTruthy();
    expect(auditLog).toEqual(['p1:child.share']);
  });

  it('revocarea taie accesul imediat', async () => {
    const { sharing, access } = setup();
    await sharing.share(parent, CHILD, { email: 'dr@clinica.md', days: 7 });
    await sharing.revoke(parent, CHILD, 't1');
    await expect(access.assert(therapist, CHILD, 'read')).rejects.toBeInstanceOf(NotFoundError);
    await expect(sharing.revoke(parent, CHILD, 't1')).rejects.toBeInstanceOf(NotFoundError);
  });

  it('fără consimțământ, de către specialist, către e-mail necunoscut sau pe termen prea lung → refuz', async () => {
    await expect(setup({ consent: false }).sharing.share(parent, CHILD, { email: 'dr@clinica.md' })).rejects.toBeInstanceOf(
      ForbiddenError,
    );
    const { sharing } = setup();
    await expect(sharing.share(therapist, CHILD, { email: 'dr@clinica.md' })).rejects.toBeInstanceOf(ForbiddenError);
    await expect(sharing.share(parent, CHILD, { email: 'altcineva@x.md' })).rejects.toBeInstanceOf(NotFoundError);
    await expect(sharing.share(parent, CHILD, { email: 'dr@clinica.md', days: 1000 })).rejects.toBeInstanceOf(
      ValidationError,
    );
  });
});

import type { AuthUser } from '../auth/tokens';
import { ChildAccess, type ChildRow } from '../children/access';
import { ForbiddenError, NotFoundError, UnauthorizedError, ValidationError } from '../common/errors';
import { GdprService, type GdprRepo } from './gdpr';

const CHILD = '0190a1b2-0000-7000-8000-000000000001';
const parent: AuthUser = { id: 'p1', role: 'PARENT' };
const otherParent: AuthUser = { id: 'p2', role: 'PARENT' };
const therapist: AuthUser = { id: 't1', role: 'THERAPIST' };
const now = new Date('2026-10-01T12:00:00Z');

function setup() {
  const child: ChildRow = { id: CHILD, parentId: 'p1', deletedAt: null };
  let linked = true;
  const audit: string[] = [];
  const purges: [string, Date][] = [];
  const accountPurges: [string, Date][] = [];
  const deletedAccounts: string[] = [];
  const repo: GdprRepo = {
    account: async () => ({ email: 'ana@example.md', role: 'PARENT', createdAt: '2026-09-01T00:00:00.000Z' }),
    consentLog: async () => [{ purpose: 'SYNC', granted: true, policyVersion: '2026-10', at: '2026-09-02T00:00:00.000Z' }],
    childrenWithSessions: async () => [
      {
        nickname: 'Ilinca',
        avatar: '🐞',
        birthYear: 2020,
        sessions: [{ record: { id: 's1' }, summary: null }],
        accesses: [{ by: 'logoped@example.md', at: '2026-09-05T10:00:00.000Z' }],
      },
    ],
    softDeleteChild: async (_id, at) => {
      child.deletedAt = at;
      linked = false;
    },
    softDeleteAccount: async (userId) => {
      deletedAccounts.push(userId);
      if (userId === child.parentId) child.deletedAt = now;
      linked = false;
    },
    audit: async (actor, action) => void audit.push(`${actor}:${action}`),
  };
  const access = new ChildAccess(
    { findChild: async (id) => (id === CHILD ? child : null), hasActiveLink: async () => linked },
    () => now,
  );
  const gdpr = new GdprService(
    access,
    repo,
    {
      schedulePurge: async (id, at) => void purges.push([id, at]),
      schedulePurgeAccount: async (id, at) => void accountPurges.push([id, at]),
    },
    { confirm: async (_id, password) => password === 'parola-corecta' },
    () => now,
  );
  return { gdpr, access, audit, purges, accountPurges, deletedAccounts };
}

describe('GdprService', () => {
  it('exportul conține contul, jurnalul consimțămintelor, copiii și sesiunile; e auditat', async () => {
    const { gdpr, audit } = setup();
    const out = await gdpr.export(parent);
    expect(out.format).toBe('licurici-export');
    expect(out.account.email).toBe('ana@example.md');
    expect(out.consents).toHaveLength(1);
    expect(out.children[0].sessions).toHaveLength(1);
    // Părintele vede cine a văzut datele copilului (art. 15).
    expect(out.children[0].accesses).toEqual([{ by: 'logoped@example.md', at: '2026-09-05T10:00:00.000Z' }]);
    expect(audit).toEqual(['p1:gdpr.export']);
    await expect(gdpr.export(therapist)).rejects.toBeInstanceOf(ForbiddenError);
  });

  it('ștergerea copilului: acces tăiat imediat (și pentru specialist), ștergere definitivă peste 7 zile', async () => {
    const { gdpr, access, purges, audit } = setup();
    await expect(access.assert(therapist, CHILD, 'read')).resolves.toBeTruthy();
    expect(await gdpr.deleteChild(parent, CHILD)).toEqual({ purgeAt: '2026-10-08T12:00:00.000Z' });
    await expect(access.assert(parent, CHILD, 'read')).rejects.toBeInstanceOf(NotFoundError);
    await expect(access.assert(therapist, CHILD, 'read')).rejects.toBeInstanceOf(NotFoundError);
    expect(purges).toEqual([[CHILD, new Date('2026-10-08T12:00:00.000Z')]]);
    expect(audit).toEqual(['p1:gdpr.child.delete']);
  });

  it('nimeni altcineva nu poate șterge copilul', async () => {
    const { gdpr } = setup();
    await expect(gdpr.deleteChild(otherParent, CHILD)).rejects.toBeInstanceOf(NotFoundError);
    await expect(gdpr.deleteChild(therapist, CHILD)).rejects.toBeInstanceOf(ForbiddenError);
  });

  it('ștergerea contului: cere parola; copilul dispare și pentru specialist; ștergere definitivă peste 7 zile', async () => {
    const { gdpr, access, accountPurges, deletedAccounts, audit } = setup();
    await expect(gdpr.deleteAccount(parent, { password: 'greșită' })).rejects.toBeInstanceOf(UnauthorizedError);
    await expect(gdpr.deleteAccount(parent, {})).rejects.toBeInstanceOf(ValidationError);
    expect(deletedAccounts).toEqual([]);
    expect(await gdpr.deleteAccount(parent, { password: 'parola-corecta' })).toEqual({
      purgeAt: '2026-10-08T12:00:00.000Z',
    });
    expect(deletedAccounts).toEqual(['p1']);
    await expect(access.assert(therapist, CHILD, 'read')).rejects.toBeInstanceOf(NotFoundError);
    expect(accountPurges).toEqual([['p1', new Date('2026-10-08T12:00:00.000Z')]]);
    expect(audit).toEqual(['p1:gdpr.account.delete']);
  });

  it('și specialistul își poate șterge contul; administratorul nu, din aplicație', async () => {
    const { gdpr, deletedAccounts } = setup();
    await gdpr.deleteAccount(therapist, { password: 'parola-corecta' });
    expect(deletedAccounts).toEqual(['t1']);
    await expect(gdpr.deleteAccount({ id: 'a1', role: 'ADMIN' }, { password: 'parola-corecta' })).rejects.toBeInstanceOf(
      ForbiddenError,
    );
  });
});

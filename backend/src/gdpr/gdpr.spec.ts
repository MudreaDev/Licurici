import type { AuthUser } from '../auth/tokens';
import { ChildAccess, type ChildRow } from '../children/access';
import { ForbiddenError, NotFoundError } from '../common/errors';
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
  const repo: GdprRepo = {
    account: async () => ({ email: 'ana@example.md', role: 'PARENT', createdAt: '2026-09-01T00:00:00.000Z' }),
    consentLog: async () => [{ purpose: 'SYNC', granted: true, policyVersion: '2026-10', at: '2026-09-02T00:00:00.000Z' }],
    childrenWithSessions: async () => [
      { nickname: 'Ilinca', avatar: '🐞', birthYear: 2020, sessions: [{ record: { id: 's1' }, summary: null }] },
    ],
    softDeleteChild: async (_id, at) => {
      child.deletedAt = at;
      linked = false;
    },
    audit: async (actor, action) => void audit.push(`${actor}:${action}`),
  };
  const access = new ChildAccess(
    { findChild: async (id) => (id === CHILD ? child : null), hasActiveLink: async () => linked },
    () => now,
  );
  const gdpr = new GdprService(access, repo, { schedulePurge: async (id, at) => void purges.push([id, at]) }, () => now);
  return { gdpr, access, audit, purges };
}

describe('GdprService', () => {
  it('exportul conține contul, jurnalul consimțămintelor, copiii și sesiunile; e auditat', async () => {
    const { gdpr, audit } = setup();
    const out = await gdpr.export(parent);
    expect(out.format).toBe('licurici-export');
    expect(out.account.email).toBe('ana@example.md');
    expect(out.consents).toHaveLength(1);
    expect(out.children[0].sessions).toHaveLength(1);
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
});

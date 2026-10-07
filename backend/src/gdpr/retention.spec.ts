import {
  RETENTION_MONTHS,
  archiveRows,
  expireCareLinks,
  expireConsentArchive,
  expireSessions,
  retentionCutoff,
} from './retention';

describe('retenția sesiunilor', () => {
  it('pragul e acum minus 24 de luni', () => {
    expect(RETENTION_MONTHS).toBe(24);
    expect(retentionCutoff(new Date('2026-10-08T12:00:00Z')).toISOString()).toBe('2024-10-08T12:00:00.000Z');
  });

  it('se șterg doar sesiunile începute înainte de prag, din ambele tabele', async () => {
    const seen: Date[] = [];
    const del = (count: number) => async (q: { where: { startedAt: { lt: Date } } }) => {
      seen.push(q.where.startedAt.lt);
      return { count };
    };
    const now = new Date('2026-10-08T12:00:00Z');
    const deleted = await expireSessions({ therapySession: { deleteMany: del(2) }, gameSession: { deleteMany: del(1) } }, now);
    expect(deleted).toBe(3);
    expect(seen.map((d) => d.toISOString())).toEqual(['2024-10-08T12:00:00.000Z', '2024-10-08T12:00:00.000Z']);
  });

  it('dovezile consimțământului: arhivate fără id în clar, șterse după 3 ani', async () => {
    const rows = archiveRows('u-123', [
      { purpose: 'SYNC', policyVersion: '2026-10', granted: true, at: new Date('2026-10-01'), userId: 'u-123', ipHash: 'x' },
    ]);
    expect(rows).toHaveLength(1);
    expect(rows[0].subject).toMatch(/^[0-9a-f]{64}$/);
    expect(JSON.stringify(rows)).not.toContain('u-123');
    expect(Object.keys(rows[0]).sort()).toEqual(['at', 'granted', 'policyVersion', 'purpose', 'subject']);

    let before: Date | undefined;
    const n = await expireConsentArchive(
      { consentArchive: { deleteMany: async (q) => ((before = q.where.archivedAt.lt), { count: 4 }) } },
      new Date('2026-10-08T12:00:00Z'),
    );
    expect(n).toBe(4);
    expect(before!.toISOString()).toBe('2023-10-08T12:00:00.000Z');
  });

  it('partajările expirate dispar', async () => {
    const now = new Date('2026-10-08T12:00:00Z');
    let lt: Date | undefined;
    expect(await expireCareLinks({ careLink: { deleteMany: async (q) => ((lt = q.where.expiresAt.lt), { count: 2 }) } }, now)).toBe(2);
    expect(lt).toEqual(now);
  });
});

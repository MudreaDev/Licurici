import { RETENTION_MONTHS, expireSessions, retentionCutoff } from './retention';

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
});

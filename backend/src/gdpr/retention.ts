/** Sesiunile copilului se păstrează cel mult atâtea luni (README §13.3, politica de retenție). */
export const RETENTION_MONTHS = 24;

/** Sesiunile începute înainte de această dată se șterg. */
export function retentionCutoff(now: Date, months = RETENTION_MONTHS): Date {
  const d = new Date(now);
  d.setUTCMonth(d.getUTCMonth() - months);
  return d;
}

type DeleteMany = (q: { where: { startedAt: { lt: Date } } }) => PromiseLike<{ count: number }>;

/** Ce din Prisma folosește ștergerea (ușor de înlocuit în teste). */
export interface RetentionDb {
  therapySession: { deleteMany: DeleteMany };
  gameSession: { deleteMany: DeleteMany };
}

/** Șterge sesiunile mai vechi decât pragul (rezumatele și evenimentele pleacă în cascadă). */
export async function expireSessions(db: RetentionDb, now: Date): Promise<number> {
  const before = retentionCutoff(now);
  const where = { startedAt: { lt: before } };
  const [therapy, games] = await Promise.all([
    db.therapySession.deleteMany({ where }),
    db.gameSession.deleteMany({ where }),
  ]);
  return therapy.count + games.count;
}

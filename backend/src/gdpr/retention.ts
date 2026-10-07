import { createHash } from 'node:crypto';

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

/** Dovezile consimțământului se păstrează atâția ani după ștergerea contului. */
export const CONSENT_ARCHIVE_YEARS = 3;

export interface ConsentRow {
  purpose: string;
  policyVersion: string;
  granted: boolean;
  at: Date;
}

/** Rândurile de arhivă pentru acordurile unui cont șters: fără id-ul în clar, doar hash-ul lui. */
export function archiveRows<T extends ConsentRow>(
  userId: string,
  consents: T[],
): { subject: string; purpose: T['purpose']; policyVersion: string; granted: boolean; at: Date }[] {
  const subject = createHash('sha256').update(`licurici-consent:${userId}`).digest('hex');
  return consents.map((c) => ({ subject, purpose: c.purpose, policyVersion: c.policyVersion, granted: c.granted, at: c.at }));
}

export interface ConsentArchiveDb {
  consentArchive: { deleteMany: (q: { where: { archivedAt: { lt: Date } } }) => PromiseLike<{ count: number }> };
}

/** Șterge dovezile arhivate de mai mult de 3 ani. */
export async function expireConsentArchive(db: ConsentArchiveDb, now: Date): Promise<number> {
  const before = new Date(now);
  before.setUTCFullYear(before.getUTCFullYear() - CONSENT_ARCHIVE_YEARS);
  return (await db.consentArchive.deleteMany({ where: { archivedAt: { lt: before } } })).count;
}

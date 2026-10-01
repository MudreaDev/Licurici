import { z } from 'zod';

import type { AuthUser } from '../auth/tokens';
import type { ChildAccess } from '../children/access';
import type { ConsentService } from '../consents/consents';
import { ValidationError } from '../common/errors';
import { parseWith } from '../common/validation';
import { sessionFactsSchema, type SessionFacts } from '../reports/session-summary';

const iso = z.iso.datetime({ offset: true });
const mood = z.enum(['bucuros', 'linistit', 'obosit', 'trist', 'suparat']).nullable();

/** O încercare: exact câmpurile din `Trial.toJson()` (licurici_core). Fără text liber. */
const trialSchema = z
  .object({
    stepId: z.string().max(16),
    gameId: z.string().max(40),
    correct: z.boolean(),
    promptLevel: z.enum(['P0', 'P1', 'P2', 'P3', 'P4']),
    attempts: z.number().int().min(1).max(20),
    latencyMs: z.number().int().min(0).max(600_000).nullable(),
    stimulusId: z.string().max(40).nullable(),
    stimulusSet: z.string().max(40).nullable(),
    seed: z.number().int().nullable(),
    difficulty: z.number().nullable(),
    offTargetTaps: z.number().int().min(0).max(1000),
    targetId: z.string().max(40).nullable(),
    chosenId: z.string().max(40).nullable(),
    at: iso,
  })
  .strict();

/** `SessionRecord.toJson()` din licurici_core. */
export const sessionRecordSchema = z
  .object({
    id: z.uuid(),
    childId: z.string().max(40),
    start: iso,
    end: iso,
    trials: z.array(trialSchema).max(2000),
    events: z
      .array(
        z
          .object({
            kind: z.enum(['pause', 'breathing', 'abandoned', 'choiceMade']),
            at: iso,
            gameId: z.string().max(40).nullable(),
          })
          .strict(),
      )
      .max(500),
    moodBefore: mood,
    moodAfter: mood,
  })
  .strict();

export const pushBodySchema = z
  .object({
    sessions: z
      .array(z.object({ record: sessionRecordSchema, facts: sessionFactsSchema }).strict())
      .min(1)
      .max(200),
  })
  .strict();

export type SessionRecordJson = z.infer<typeof sessionRecordSchema>;

export interface StoredSession {
  id: string;
  childId: string;
  startedAt: Date;
  endedAt: Date;
  moodBefore: string | null;
  moodAfter: string | null;
  record: SessionRecordJson;
  facts: SessionFacts;
  hasSummary: boolean;
}

export interface SessionRepo {
  upsert(session: Omit<StoredSession, 'hasSummary'>): Promise<void>;
  list(childId: string): Promise<StoredSession[]>;
  get(childId: string, sessionId: string): Promise<StoredSession | null>;
}

/**
 * Sincronizarea sesiunilor de pe dispozitiv (ADR-011, outbox): idempotentă după id-ul
 * sesiunii (retrimiterea o actualizează), doar de către părinte, doar pentru copilul lui și
 * doar cu consimțământul lui pentru sincronizare.
 * `childId` din înregistrare (pe dispozitiv: „local”) e înlocuit cu cel din cale.
 */
export class SyncService {
  constructor(
    private readonly access: ChildAccess,
    private readonly sessions: SessionRepo,
    private readonly consents: ConsentService,
  ) {}

  async push(user: AuthUser, childId: string, body: unknown): Promise<{ accepted: number }> {
    const child = await this.access.assert(user, childId, 'write');
    // Fără cont + consimțământ, nimic nu pleacă de pe dispozitiv (README §2, principiul 7).
    await this.consents.require(child.parentId, 'SYNC', 'Sincronizarea cere consimțământul părintelui.');
    const { sessions } = parseWith(pushBodySchema, body);
    for (const { record } of sessions) {
      if (Date.parse(record.end) < Date.parse(record.start)) {
        throw new ValidationError([`sessions.${record.id}: sfârșitul e înaintea începutului`]);
      }
    }
    for (const { record, facts } of sessions) {
      await this.sessions.upsert({
        id: record.id,
        childId,
        startedAt: new Date(record.start),
        endedAt: new Date(record.end),
        moodBefore: record.moodBefore,
        moodAfter: record.moodAfter,
        record: { ...record, childId },
        facts,
      });
    }
    return { accepted: sessions.length };
  }

  async list(user: AuthUser, childId: string): Promise<StoredSession[]> {
    await this.access.assert(user, childId, 'read');
    return this.sessions.list(childId);
  }
}

import type { AuthUser } from '../auth/tokens';
import type { ChildAccess } from '../children/access';
import type { ConsentPurpose } from '../consents/consents';
import { ForbiddenError, NotFoundError, RateLimitedError, UnavailableError } from '../common/errors';
import type { SessionRepo } from '../sync/sessions';
import { type SessionFacts, type SessionSummary, SummaryUnavailableError } from './session-summary';

export interface SummaryRepo {
  get(sessionId: string): Promise<SessionSummary | null>;
  save(sessionId: string, model: string, summary: SessionSummary): Promise<void>;
}

export interface ConsentRepo {
  /** Ultima decizie a utilizatorului pentru scopul dat (consimțământul se poate retrage). */
  granted(userId: string, purpose: ConsentPurpose): Promise<boolean>;
}

export interface Counter {
  incr(key: string): Promise<number>;
  expire(key: string, seconds: number): Promise<number>;
}

export interface Summarizer {
  readonly model: string;
  summarize(facts: SessionFacts): Promise<SessionSummary>;
}

/**
 * Rezumatul AI al unei sesiuni (ADR-029), cerut din panou de părinte sau de specialist:
 * acces → cache (un rezumat se generează o singură dată) → consimțământul PĂRINTELUI pentru
 * AI → limită zilnică per cont (Redis) → Claude. Fără cheie sau la eroare → 503, iar panoul
 * rămâne pe rezumatul din reguli.
 */
export class SummaryFlow {
  constructor(
    private readonly access: ChildAccess,
    private readonly sessions: SessionRepo,
    private readonly summaries: SummaryRepo,
    private readonly consents: ConsentRepo,
    private readonly counter: Counter,
    private readonly summarizer: Summarizer | null,
    private readonly perDay: number,
    private readonly now: () => Date = () => new Date(),
  ) {}

  async summary(
    user: AuthUser,
    childId: string,
    sessionId: string,
  ): Promise<{ summary: SessionSummary; cached: boolean }> {
    const child = await this.access.assert(user, childId, 'read');
    const session = await this.sessions.get(childId, sessionId);
    if (!session) throw new NotFoundError('Sesiunea nu există.');

    const cached = await this.summaries.get(sessionId);
    if (cached) return { summary: cached, cached: true };

    if (!(await this.consents.granted(child.parentId, 'AI_SUMMARY'))) {
      throw new ForbiddenError('Părintele nu și-a dat consimțământul pentru rezumatele scrise de AI.');
    }
    if (!this.summarizer) throw new UnavailableError('Rezumatele AI nu sunt configurate pe acest server.');

    const day = this.now().toISOString().slice(0, 10);
    const key = `ai-summary:${user.id}:${day}`;
    const used = await this.counter.incr(key);
    if (used === 1) await this.counter.expire(key, 26 * 3600);
    if (used > this.perDay) throw new RateLimitedError('Limita zilnică de rezumate AI a fost atinsă.');

    let summary: SessionSummary;
    try {
      summary = await this.summarizer.summarize(session.facts);
    } catch (e) {
      if (e instanceof SummaryUnavailableError) throw new UnavailableError(e.message);
      throw e;
    }
    await this.summaries.save(sessionId, this.summarizer.model, summary);
    return { summary, cached: false };
  }
}

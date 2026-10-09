import Anthropic from '@anthropic-ai/sdk';
import { z } from 'zod';

import type { AuthUser } from '../auth/tokens';
import type { ChildAccess } from '../children/access';
import { ForbiddenError, RateLimitedError, UnavailableError } from '../common/errors';
import { parseWith } from '../common/validation';
import type { SessionRepo } from '../sync/sessions';
import { SUMMARY_MODEL, type SessionFacts, SummaryUnavailableError } from './session-summary';
import type { ConsentRepo, Counter } from './summary-flow';

/** Întrebarea din panou, cu cel mult câteva replici anterioare (conversația rămâne în panou). */
export const askSchema = z
  .object({
    question: z.string().trim().min(3).max(500),
    history: z
      .array(z.object({ role: z.enum(['user', 'assistant']), text: z.string().max(2000) }).strict())
      .max(6)
      .default([]),
  })
  .strict();

export type AskBody = z.infer<typeof askSchema>;

/** Câte sesiuni (cele mai recente) primește modelul. */
export const ASK_SESSIONS = 20;

/** Datele trimise modelului: doar faptele agregate pe sesiune (fără încercări, fără nume). */
export function askContext(sessions: { startedAt: Date; facts: SessionFacts }[]) {
  return sessions.slice(-ASK_SESSIONS).map(({ startedAt, facts: f }) => ({
    date: startedAt.toISOString().slice(0, 10),
    durationMin: f.durationMin,
    games: f.games,
    trials: f.trials,
    independence: Math.round(f.independence * 100) / 100,
    meanPromptLevel: Math.round(f.meanPromptLevel * 10) / 10,
    medianLatencyMs: f.medianLatencyMs,
    steps: f.steps.map((s) => ({
      stepId: s.stepId,
      objective: s.objective,
      trials: s.trials,
      independence: Math.round(s.independence * 100) / 100,
    })),
    topConfusions: f.topConfusions,
    pauses: f.pauses,
    breathingUsed: f.breathingUsed,
    abandoned: f.abandoned,
    moodBefore: f.moodBefore,
    moodAfter: f.moodAfter,
  }));
}

export const ASK_SYSTEM_PROMPT = `Ești asistentul platformei Licurici, o aplicație de exersare pentru copii (inclusiv cu autism, ADHD sau întârzieri de limbaj). Un adult (părintele sau specialistul copilului) te întreabă despre progresul copilului. Primești datele agregate ale ultimelor sesiuni de joc, calculate de aplicație.

Răspunzi în limba română, scurt (cel mult 150 de cuvinte), clar și cald. Datele sunt singura sursă de adevăr: folosește doar ce arată ele și spune deschis când datele nu ajung pentru un răspuns (de exemplu, prea puține încercări sau sesiuni). Nu pui diagnostice, nu faci afirmații medicale și nu compari copilul cu alți copii; jocurile nu sunt teste standardizate. Pentru întrebări medicale sau despre tratament, recomanzi discuția cu specialistul copilului. Nu știi numele sau genul copilului: scrie neutru. Când dai o cifră, spune din ce perioadă e. Dacă întrebarea nu are legătură cu copilul și jocurile lui, spui politicos că poți răspunde doar despre progresul din aplicație.

Câmpuri: independence = răspunsuri corecte din prima, fără ajutor (0–1); meanPromptLevel = ajutorul mediu (0 = deloc, 4 = model complet); medianLatencyMs = timpul median de răspuns; topConfusions = ce a ales copilul în locul țintei; moodBefore/moodAfter = dispoziția aleasă de copil; pauses și breathingUsed = pauze cerute și exercițiul de respirație (lucruri bune, autoreglare).`;

export interface Asker {
  ask(context: ReturnType<typeof askContext>, body: AskBody): Promise<string>;
}

/** Claude, cu promptul de sistem fix (cache-uit) și datele în mesajul utilizatorului. */
export class ClaudeAsker implements Asker {
  constructor(private readonly client: Anthropic = new Anthropic()) {}

  async ask(context: ReturnType<typeof askContext>, body: AskBody): Promise<string> {
    let response: Anthropic.Beta.BetaMessage;
    try {
      response = await this.client.beta.messages.create({
        model: SUMMARY_MODEL,
        max_tokens: 4000,
        betas: ['server-side-fallback-2026-07-01'],
        fallbacks: 'default',
        system: [{ type: 'text', text: ASK_SYSTEM_PROMPT, cache_control: { type: 'ephemeral' } }],
        output_config: { effort: 'low' },
        messages: [
          { role: 'user', content: `Datele ultimelor sesiuni (JSON):\n${JSON.stringify(context)}` },
          { role: 'assistant', content: 'Am citit datele. Ce vrei să știi?' },
          ...body.history.map((h) => ({ role: h.role, content: h.text })),
          { role: 'user', content: body.question },
        ],
      });
    } catch (error) {
      if (error instanceof Anthropic.RateLimitError) throw new SummaryUnavailableError('Limită de utilizare atinsă.');
      if (error instanceof Anthropic.APIError) throw new SummaryUnavailableError(`Serviciul AI a răspuns ${error.status}.`);
      throw error;
    }
    if (response.stop_reason !== 'end_turn') throw new SummaryUnavailableError(`Răspuns incomplet (${response.stop_reason}).`);
    return response.content.flatMap((b) => (b.type === 'text' ? [b.text] : [])).join('').trim();
  }
}

/**
 * „Întreabă despre progres” (README §21, chat AI în panou): acces la copil → consimțământul
 * PĂRINTELUI pentru AI (`AI_SUMMARY`) → limita zilnică per cont → Claude, cu datele agregate.
 * Întrebările și răspunsurile nu se salvează și nu se loghează (pot conține date personale).
 */
export class AskFlow {
  constructor(
    private readonly access: ChildAccess,
    private readonly sessions: SessionRepo,
    private readonly consents: ConsentRepo,
    private readonly counter: Counter,
    private readonly asker: Asker | null,
    private readonly perDay: number,
    private readonly now: () => Date = () => new Date(),
  ) {}

  async ask(user: AuthUser, childId: string, raw: unknown): Promise<{ answer: string; sessions: number }> {
    const body = parseWith(askSchema, raw);
    const child = await this.access.assert(user, childId, 'read');
    if (!(await this.consents.granted(child.parentId, 'AI_SUMMARY'))) {
      throw new ForbiddenError('Părintele nu și-a dat consimțământul pentru răspunsurile scrise de AI.');
    }
    if (!this.asker) throw new UnavailableError('Întrebările AI nu sunt configurate pe acest server.');
    const sessions = await this.sessions.list(childId);
    if (sessions.length === 0) return { answer: 'Încă nu există sesiuni sincronizate pentru acest copil.', sessions: 0 };

    const key = `ai-ask:${user.id}:${this.now().toISOString().slice(0, 10)}`;
    const used = await this.counter.incr(key);
    if (used === 1) await this.counter.expire(key, 26 * 3600);
    if (used > this.perDay) throw new RateLimitedError('Limita zilnică de întrebări AI a fost atinsă.');

    const context = askContext(sessions);
    try {
      return { answer: await this.asker.ask(context, body), sessions: context.length };
    } catch (e) {
      if (e instanceof SummaryUnavailableError) throw new UnavailableError(e.message);
      throw e;
    }
  }
}

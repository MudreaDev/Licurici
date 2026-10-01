import Anthropic from '@anthropic-ai/sdk';
import { zodOutputFormat } from '@anthropic-ai/sdk/helpers/zod';
import { z } from 'zod';

/**
 * Rezumatul unei sesiuni scris de Claude pentru părinte și specialist (ADR-029).
 *
 * Faptele (procente, confuzii, oboseală) le calculează `SessionReport` din `licurici_core`;
 * aici intră DOAR `toAiJson()`: agregate pseudonimizate, fără nume, id-uri, date sau text liber.
 * Modelul doar formulează. Dacă apelul eșuează sau e refuzat, panoul folosește rezumatul din
 * reguli (`parentSummary` / `specialistNotes`), deci AI-ul nu e niciodată pe drumul critic.
 */

/** Ce primește modelul — aceeași formă ca `SessionReport.toAiJson()` din Dart. */
export const sessionFactsSchema = z
  .object({
    durationMin: z.number().int().nonnegative(),
    games: z.array(z.string()),
    trials: z.number().int().nonnegative(),
    accuracy: z.number().min(0).max(1),
    independence: z.number().min(0).max(1),
    meanPromptLevel: z.number().min(0).max(4),
    medianLatencyMs: z.number().int().nullable(),
    steps: z.array(
      z
        .object({
          stepId: z.string(),
          objective: z.string(),
          trials: z.number().int(),
          accuracy: z.number(),
          independence: z.number(),
          meanPromptLevel: z.number(),
          medianLatencyMs: z.number().int().nullable(),
          independenceDeltaPts: z.number().int().nullable(),
        })
        .strict(),
    ),
    topConfusions: z.array(z.object({ target: z.string(), chosen: z.string(), count: z.number().int() }).strict()),
    fatigueLatencyIncrease: z.number().nullable(),
    pauses: z.number().int(),
    breathingUsed: z.number().int(),
    abandoned: z.boolean(),
    moodBefore: z.string().nullable(),
    moodAfter: z.string().nullable(),
  })
  // Orice câmp necunoscut (ex. un nume strecurat din greșeală) e respins înainte de apel.
  .strict();

export type SessionFacts = z.infer<typeof sessionFactsSchema>;

/** Ce întoarce modelul (ieșire structurată, validată). */
export const sessionSummarySchema = z.object({
  /** 3–5 propoziții calde, fără jargon, pentru părinte. */
  parent: z.string(),
  /** O idee concretă de activitate acasă, legată de datele sesiunii. */
  homeIdea: z.string(),
  /** Observații pentru specialist, fiecare susținută de o cifră din date. */
  specialist: z.array(z.string()),
  /** Ce ar putea ajusta specialistul în plan (sugestii, nu decizii). */
  planSuggestions: z.array(z.string()),
});

export type SessionSummary = z.infer<typeof sessionSummarySchema>;

export const SUMMARY_MODEL = 'claude-opus-5-5';

/**
 * Promptul de sistem e fix (fără date variabile), ca să fie cache-uit între cereri.
 * Datele sesiunii vin în mesajul utilizatorului.
 */
export const SYSTEM_PROMPT = `Ești asistentul platformei Licurici, o aplicație de exersare pentru copii (inclusiv cu autism, ADHD sau întârzieri de limbaj). Primești datele agregate ale unei sesiuni de joc, calculate de aplicație, și scrii două rezumate în limba română.

Datele sunt singura sursă de adevăr: folosește doar cifrele și faptele primite, nu inventa nimic și nu deduce lucruri pe care datele nu le arată. Nu pui diagnostice și nu faci afirmații medicale; jocurile nu sunt teste standardizate. Nu știi numele sau genul copilului: scrie neutru („copilul”, „a lucrat”), fără forme de masculin sau feminin acordate cu el.

Pentru părinte: ton cald și simplu, 3–5 propoziții, fără coduri de treaptă, fără procente reci și fără cuvinte ca „greșit”, „eșec”, „slab”. Începe cu ce a mers bine. Pauzele cerute și folosirea exercițiului de respirație sunt lucruri bune (autoreglare). Dispoziția („moodBefore”/„moodAfter”) a fost aleasă chiar de copil; prezint-o ca atare. Ideea pentru acasă trebuie să fie o activitate scurtă, concretă, legată de datele sesiunii (de exemplu de confuzia cea mai frecventă).

Pentru specialist: observații scurte și precise, fiecare susținută de o cifră din date (independență, nivel mediu de ajutor P0–P4, latență mediană, confuzii, oboseală, pauze). Semnalează eșantioanele mici (sub 5 încercări pe treaptă) ca neconcludente. Sugestiile pentru plan sunt opțiuni de luat în calcul, decizia aparține specialistului.

Câmpuri: independence = răspunsuri corecte din prima, fără ajutor; meanPromptLevel = ajutorul mediu (0 = deloc, 4 = model complet); independenceDeltaPts = diferența față de sesiunea anterioară, în puncte procentuale; fatigueLatencyIncrease = creșterea relativă a timpului de răspuns în a doua jumătate a sesiunii.`;

export class SummaryUnavailableError extends Error {}

export class SessionSummaryService {
  readonly model = SUMMARY_MODEL;

  constructor(private readonly client: Anthropic = new Anthropic()) {}

  async summarize(rawFacts: unknown): Promise<SessionSummary> {
    const facts = sessionFactsSchema.parse(rawFacts);
    let response: Anthropic.Beta.BetaMessage;
    try {
      response = await this.client.beta.messages.create({
        model: SUMMARY_MODEL,
        max_tokens: 16000,
        // La un refuz al clasificatorilor, API-ul reia cererea pe un model potrivit (server-side).
        betas: ['server-side-fallback-2026-07-01'],
        fallbacks: 'default',
        system: [{ type: 'text', text: SYSTEM_PROMPT, cache_control: { type: 'ephemeral' } }],
        output_config: { effort: 'medium', format: zodOutputFormat(sessionSummarySchema) },
        messages: [{ role: 'user', content: `Datele sesiunii (JSON):\n${JSON.stringify(facts)}` }],
      });
    } catch (error) {
      if (error instanceof Anthropic.RateLimitError) {
        throw new SummaryUnavailableError('Limită de utilizare atinsă; se folosește rezumatul din reguli.');
      }
      if (error instanceof Anthropic.APIError) {
        throw new SummaryUnavailableError(`Serviciul AI a răspuns ${error.status}.`);
      }
      throw error;
    }
    if (response.stop_reason !== 'end_turn') {
      throw new SummaryUnavailableError(`Răspuns incomplet (${response.stop_reason}).`);
    }
    const text = response.content
      .flatMap((b) => (b.type === 'text' ? [b.text] : []))
      .join('');
    const parsed = sessionSummarySchema.safeParse(JSON.parse(text));
    if (!parsed.success) throw new SummaryUnavailableError('Răspunsul nu respectă schema.');
    return parsed.data;
  }
}

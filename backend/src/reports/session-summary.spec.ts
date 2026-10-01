import Anthropic from '@anthropic-ai/sdk';

import { SessionSummaryService, SummaryUnavailableError, SUMMARY_MODEL, SYSTEM_PROMPT } from './session-summary';

const facts = {
  durationMin: 12,
  games: ['ce-simte', 'pescarul'],
  trials: 24,
  accuracy: 0.79,
  independence: 0.71,
  meanPromptLevel: 0.6,
  medianLatencyMs: 2500,
  steps: [
    {
      stepId: 'EMO3',
      objective: 'Spune ce simte cineva într-o situație',
      trials: 8,
      accuracy: 0.88,
      independence: 0.75,
      meanPromptLevel: 0.5,
      medianLatencyMs: 2400,
      independenceDeltaPts: 25,
    },
  ],
  topConfusions: [{ target: 'trist', chosen: 'suparat', count: 3 }],
  fatigueLatencyIncrease: 0.2,
  pauses: 1,
  breathingUsed: 0,
  abandoned: false,
  moodBefore: 'obosit',
  moodAfter: 'bucuros',
};

const summary = {
  parent: 'A lucrat foarte bine la emoții.',
  homeIdea: 'Jucați „ghicește emoția” cu fețe desenate.',
  specialist: ['EMO3: independență 75% (+25 pp).'],
  planSuggestions: ['De confirmat EMO3 în sesiunea următoare.'],
};

function fakeClient(response: Partial<Anthropic.Beta.BetaMessage> | Error) {
  const create = jest.fn(async () => {
    if (response instanceof Error) throw response;
    return response;
  });
  return { client: { beta: { messages: { create } } } as unknown as Anthropic, create };
}

describe('SessionSummaryService', () => {
  it('trimite doar datele agregate, cu promptul fix cache-uit, și validează răspunsul', async () => {
    const { client, create } = fakeClient({
      stop_reason: 'end_turn',
      content: [{ type: 'text', text: JSON.stringify(summary), citations: null }],
    });
    const out = await new SessionSummaryService(client).summarize(facts);
    expect(out).toEqual(summary);

    const req = (create.mock.calls[0] as unknown[])[0] as Record<string, any>;
    expect(req.model).toBe(SUMMARY_MODEL);
    expect(req.system[0].text).toBe(SYSTEM_PROMPT);
    expect(req.system[0].cache_control).toEqual({ type: 'ephemeral' });
    expect(req.fallbacks).toBe('default');
    expect(req.messages[0].content).toContain('"independence":0.71');
  });

  it('respinge câmpurile necunoscute (ex. un nume) înainte de orice apel', async () => {
    const { client, create } = fakeClient(new Error('nu trebuie apelat'));
    await expect(
      new SessionSummaryService(client).summarize({ ...facts, childName: 'Ilinca' }),
    ).rejects.toThrow();
    expect(create).not.toHaveBeenCalled();
  });

  it('refuz sau răspuns trunchiat → SummaryUnavailableError (panoul folosește rezumatul din reguli)', async () => {
    for (const stop_reason of ['refusal', 'max_tokens'] as const) {
      const { client } = fakeClient({ stop_reason, content: [] });
      await expect(new SessionSummaryService(client).summarize(facts)).rejects.toBeInstanceOf(
        SummaryUnavailableError,
      );
    }
  });

  it('JSON care nu respectă schema → SummaryUnavailableError', async () => {
    const { client } = fakeClient({
      stop_reason: 'end_turn',
      content: [{ type: 'text', text: JSON.stringify({ parent: 'x' }), citations: null }],
    });
    await expect(new SessionSummaryService(client).summarize(facts)).rejects.toBeInstanceOf(
      SummaryUnavailableError,
    );
  });
});

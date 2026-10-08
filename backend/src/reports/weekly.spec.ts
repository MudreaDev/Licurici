import { renderWeekly } from '../mail/mail';
import type { SessionFacts } from './session-summary';
import { digestLines, isoWeek, weeklyDigest, type WeekSession } from './weekly';

function facts(over: Partial<SessionFacts>): SessionFacts {
  return {
    durationMin: 10,
    games: ['emotii'],
    trials: 10,
    accuracy: 0.8,
    independence: 0.5,
    meanPromptLevel: 1,
    medianLatencyMs: 2000,
    steps: [],
    topConfusions: [],
    fatigueLatencyIncrease: null,
    pauses: 0,
    breathingUsed: 0,
    abandoned: false,
    moodBefore: null,
    moodAfter: null,
    ...over,
  };
}

const step = (stepId: string, objective: string, trials: number, independence: number) => ({
  stepId,
  objective,
  trials,
  accuracy: 1,
  independence,
  meanPromptLevel: 0,
  medianLatencyMs: null,
  independenceDeltaPts: null,
});

const now = new Date('2026-10-12T06:00:00Z'); // luni
const daysAgo = (d: number) => new Date(now.getTime() - d * 24 * 3600 * 1000);

describe('raportul săptămânal', () => {
  it('săptămâna ISO', () => {
    expect(isoWeek(new Date('2026-10-12T06:00:00Z'))).toBe('2026-W42');
    expect(isoWeek(new Date('2027-01-01T12:00:00Z'))).toBe('2026-W53');
    expect(isoWeek(new Date('2026-01-01T12:00:00Z'))).toBe('2026-W01');
  });

  it('fără sesiuni în ultimele 7 zile nu iese nimic', () => {
    expect(weeklyDigest('Ilinca', [{ startedAt: daysAgo(9), facts: facts({}) }], now)).toBeNull();
  });

  it('adună săptămâna, o compară cu cea dinainte și alege obiectivele cele mai exersate', () => {
    const sessions: WeekSession[] = [
      { startedAt: daysAgo(10), facts: facts({ trials: 10, independence: 0.4 }) },
      {
        startedAt: daysAgo(3),
        facts: facts({
          trials: 20,
          independence: 0.6,
          durationMin: 12,
          moodAfter: 'bucuros',
          steps: [step('EMO1', 'Recunoaște emoțiile', 15, 0.6), step('POT1', 'Potrivește identic', 5, 0.6)],
        }),
      },
      {
        startedAt: daysAgo(1),
        facts: facts({
          trials: 20,
          independence: 0.8,
          durationMin: 8,
          moodAfter: 'obosit',
          steps: [step('EMO1', 'Recunoaște emoțiile', 10, 0.9), step('ATN1', 'Atenția', 10, 0.7)],
        }),
      },
    ];
    const d = weeklyDigest('Ilinca', sessions, now)!;
    expect(d).toMatchObject({ sessions: 2, minutes: 20, trials: 40, deltaPts: 30, calmEndings: 1 });
    expect(d.independence).toBeCloseTo(0.7);
    expect(d.steps.map((s) => s.objective)).toEqual(['Recunoaște emoțiile', 'Atenția', 'Potrivește identic']);
    expect(d.steps[0].independence).toBeCloseTo(0.72);
    const lines = digestLines(d);
    expect(lines[0]).toBe('Ilinca: 2 sesiuni, 20 min, 40 de încercări.');
    expect(lines[1]).toContain('cu 30 de puncte mai mult');
    expect(lines[2]).toBe('• Recunoaște emoțiile — 25 de încercări, 72% singur(ă)');
  });

  it('e-mailul are un bloc pe copil, legătura spre panou și cum se oprește', () => {
    const d = weeklyDigest('Ilinca <3', [{ startedAt: daysAgo(2), facts: facts({}) }], now)!;
    const m = renderWeekly('ana@example.md', [d], 'http://panou/');
    expect(m.subject).toBe('Săptămâna lui Ilinca <3 în Licurici');
    expect(m.text).toContain('Ilinca <3: o sesiune, 10 min, 10 încercări.');
    expect(m.text).toContain('http://panou/#/parinte');
    expect(m.text).toContain('Contul meu');
    expect(m.html).toContain('Ilinca &lt;3');
  });
});

import { answersFromTrials, computeSkillStats } from './skill-stats';

describe('computeSkillStats', () => {
  const d = (s: string) => new Date(`2026-09-${s}T10:00:00Z`);

  it('agregă pe abilitate: încercări, reușite din prima, acuratețe, ultima dată', () => {
    const stats = computeSkillStats([
      { skill: 'adunare', firstTry: true, at: d('20') },
      { skill: 'adunare', firstTry: false, at: d('22') },
      { skill: 'adunare', firstTry: true, at: d('21') },
      { skill: 'culori', firstTry: true, at: d('19') },
    ]);
    expect(stats).toEqual([
      { skill: 'adunare', attempts: 3, firstTry: 2, accuracy: 0.667, lastPlayed: d('22') },
      { skill: 'culori', attempts: 1, firstTry: 1, accuracy: 1, lastPlayed: d('19') },
    ]);
  });

  it('fără evenimente → listă goală', () => {
    expect(computeSkillStats([])).toEqual([]);
  });
});

describe('answersFromTrials', () => {
  const trial = (o: Partial<{ stepId: string; correct: boolean; promptLevel: string; attempts: number }>) => ({
    stepId: 'POT2',
    correct: true,
    promptLevel: 'P0',
    attempts: 1,
    at: '2026-10-01T10:00:00.000Z',
    ...o,
  });

  it('independent = corect, din prima, fără ajutor; treapta e abilitatea', () => {
    const stats = computeSkillStats(
      answersFromTrials([
        trial({}),
        trial({ promptLevel: 'P3' }),
        trial({ attempts: 2 }),
        trial({ correct: false }),
        trial({ stepId: 'EMO3' }),
      ]),
    );
    expect(stats.map((s) => [s.skill, s.attempts, s.firstTry, s.accuracy])).toEqual([
      ['EMO3', 1, 1, 1],
      ['POT2', 4, 1, 0.25],
    ]);
  });
});

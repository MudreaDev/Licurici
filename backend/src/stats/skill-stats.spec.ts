import { computeSkillStats } from './skill-stats';

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

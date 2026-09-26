/**
 * Calculul read-model-ului `child_skill_stats` (CQRS-lite, README §9) din evenimentele de joc.
 * Funcție pură → testată fără bază de date; worker-ul doar citește evenimentele și scrie rezultatul.
 */
export interface AnswerEvent {
  skill: string;
  firstTry: boolean;
  at: Date;
}

export interface SkillStats {
  skill: string;
  attempts: number;
  firstTry: number;
  /** Acuratețea din prima încercare, 0..1 (ce folosește și regula adaptivă). */
  accuracy: number;
  lastPlayed: Date;
}

export function computeSkillStats(events: readonly AnswerEvent[]): SkillStats[] {
  const bySkill = new Map<string, SkillStats>();
  for (const e of events) {
    const s = bySkill.get(e.skill) ?? {
      skill: e.skill,
      attempts: 0,
      firstTry: 0,
      accuracy: 0,
      lastPlayed: e.at,
    };
    s.attempts += 1;
    if (e.firstTry) s.firstTry += 1;
    if (e.at > s.lastPlayed) s.lastPlayed = e.at;
    bySkill.set(e.skill, s);
  }
  return [...bySkill.values()]
    .map((s) => ({ ...s, accuracy: Math.round((s.firstTry / s.attempts) * 1000) / 1000 }))
    .sort((a, b) => a.skill.localeCompare(b.skill));
}

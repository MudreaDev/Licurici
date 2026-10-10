import type { AuthUser } from '../auth/tokens';
import type { ChildAccess } from '../children/access';

/**
 * Calculul read-model-ului `child_skill_stats` (CQRS-lite, README §9) din încercările sesiunilor
 * sincronizate (`therapy_sessions.record.trials`). „Abilitatea” = treapta din traseul de
 * dezvoltare (`stepId`, ex. `POT2`). Funcție pură → testată fără bază de date; worker-ul doar
 * citește sesiunile și scrie rezultatul.
 */
export interface AnswerEvent {
  skill: string;
  firstTry: boolean;
  at: Date;
}

export interface SkillStats {
  skill: string;
  attempts: number;
  /** Reușite independente: corect, din prima, fără ajutor (P0). */
  firstTry: number;
  /** Independența, 0..1 (aceeași definiție ca KPI-ul din `SessionReport`). */
  accuracy: number;
  lastPlayed: Date;
}

/** Câmpurile din `Trial.toJson()` de care avem nevoie (restul se ignoră). */
export interface TrialLike {
  stepId: string;
  correct: boolean;
  promptLevel: string;
  attempts: number;
  at: string;
}

/** Încercările sesiunilor → evenimente de răspuns. Independent = corect, o încercare, P0. */
export function answersFromTrials(trials: readonly TrialLike[]): AnswerEvent[] {
  return trials.map((t) => ({
    skill: t.stepId,
    firstTry: t.correct && t.attempts === 1 && t.promptLevel === 'P0',
    at: new Date(t.at),
  }));
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

/** Cine pune recalcularea în coadă (în teste, o listă). */
export interface StatsQueue {
  recompute(childId: string): Promise<void>;
}

export interface SkillStatsRepo {
  list(childId: string): Promise<SkillStats[]>;
}

/** Citirea read-model-ului: aceeași regulă de acces ca sesiunile (părintele, specialistul legat). */
export class SkillStatsService {
  constructor(
    private readonly access: ChildAccess,
    private readonly repo: SkillStatsRepo,
  ) {}

  async list(user: AuthUser, childId: string): Promise<SkillStats[]> {
    await this.access.assert(user, childId, 'read');
    return this.repo.list(childId);
  }
}

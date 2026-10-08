import { z } from 'zod';

import type { AuthUser } from '../auth/tokens';
import { parseWith } from '../common/validation';
import type { ChildAccess } from './access';

/**
 * Planul de jocuri al copilului (plan §5.1): ce jocuri **nu** vede copilul pe tabletă. Lista e
 * de id-uri de joc (slug-uri), nu date despre copil. Un joc nou din aplicație apare implicit.
 */
export const planSchema = z
  .object({
    hiddenGames: z
      .array(z.string().regex(/^[a-z0-9-]{2,40}$/))
      .max(200)
      .transform((xs) => [...new Set(xs)].sort()),
  })
  .strict();

export interface PlanChange {
  at: Date;
  by: 'PARENT' | 'THERAPIST';
  /** Câte jocuri erau scoase după schimbare. */
  hidden: number;
}

export interface GamePlan {
  hiddenGames: string[];
  /** Când s-a schimbat ultima dată și de cine (rolul), ca tableta să știe dacă e mai nou. */
  updatedAt: Date | null;
  updatedBy: 'PARENT' | 'THERAPIST' | null;
  /** Istoricul schimbărilor (cele mai recente 50): liniile de schimbare de fază din grafice. */
  history: PlanChange[];
}

export interface PlanRepo {
  read(childId: string): Promise<GamePlan | null>;
  write(childId: string, plan: GamePlan): Promise<void>;
  audit(actorId: string, action: string, targetId: string): Promise<void>;
}

/**
 * Cine alege jocurile copilului: părintele lui și specialistul cu care l-a partajat (cât timp
 * partajarea e activă) — e singurul lucru pe care specialistul îl poate schimba (plan §5.1);
 * restul datelor copilului rămân doar de citit pentru el. Fiecare schimbare intră în audit,
 * ca să apară ca „schimbare de fază” în graficele copilului.
 */
export class GamePlanService {
  constructor(
    private readonly access: ChildAccess,
    private readonly repo: PlanRepo,
    private readonly now: () => Date = () => new Date(),
  ) {}

  async get(user: AuthUser, childId: string): Promise<GamePlan> {
    await this.access.assert(user, childId, 'read');
    return (await this.repo.read(childId)) ?? { hiddenGames: [], updatedAt: null, updatedBy: null, history: [] };
  }

  async put(user: AuthUser, childId: string, body: unknown): Promise<GamePlan> {
    // Citirea e suficientă ca drept: specialistul are voie aici (doar pentru plan).
    await this.access.assert(user, childId, 'read');
    const { hiddenGames } = parseWith(planSchema, body);
    const previous = await this.repo.read(childId);
    const by: PlanChange['by'] = user.role === 'THERAPIST' ? 'THERAPIST' : 'PARENT';
    const at = this.now();
    const plan: GamePlan = {
      hiddenGames,
      updatedAt: at,
      updatedBy: by,
      history: [...(previous?.history ?? []), { at, by, hidden: hiddenGames.length }].slice(-50),
    };
    await this.repo.write(childId, plan);
    await this.repo.audit(user.id, 'child.plan', childId);
    return plan;
  }
}

import { z } from 'zod';

import type { AuthUser } from '../auth/tokens';
import { parseWith } from '../common/validation';
import type { LiveEvents } from '../live/live';
import type { ChildAccess } from './access';

/**
 * Planul de jocuri al copilului (plan §5.1): ce jocuri **nu** vede copilul pe tabletă. Lista e
 * de id-uri de joc (slug-uri), nu date despre copil. Un joc nou din aplicație apare implicit.
 */
const gameId = z.string().regex(/^[a-z0-9-]{2,40}$/);

/** Piesele de fundal din aplicație (`MusicTrack`): toate pe rând sau una anume. */
export const musicTracks = ['all', 'lumini', 'valuri', 'gradina'] as const;

// Alias (nu interfață): trebuie să fie valoare JSON pentru Prisma.
export type MusicChoice = {
  on: boolean;
  track: (typeof musicTracks)[number];
};

export const planSchema = z
  .object({
    hiddenGames: z
      .array(gameId)
      .max(200)
      .transform((xs) => [...new Set(xs)].sort()),
    /** Nivelul de pornire ales de specialist pentru unele jocuri (ADR-025, `GameConfig`). */
    levels: z
      .record(gameId, z.number().int().min(1).max(40))
      .refine((r) => Object.keys(r).length <= 200)
      .default({}),
    /** Plafonul de dificultate pe joc: jocul adaptiv nu urcă peste el (ADR-025). */
    maxLevels: z
      .record(gameId, z.number().int().min(1).max(40))
      .refine((r) => Object.keys(r).length <= 200)
      .default({}),
    /** Categoriile de imagini de evitat (ex. `caini`, `insecte`) — `licurici_core/lib/src/avoid.dart`. */
    avoid: z
      .array(z.string().regex(/^[a-z-]{2,30}$/))
      .max(50)
      .transform((xs) => [...new Set(xs)].sort())
      .default([]),
    /** Câte runde are o tură, pe joc (jocurile cu alegere). */
    rounds: z
      .record(gameId, z.number().int().min(3).max(12))
      .refine((r) => Object.keys(r).length <= 200)
      .default({}),
    /** Muzica liniștită de fundal pe tabletă: pornită/oprită și piesa (lipsă = neschimbată). */
    music: z
      .object({ on: z.boolean(), track: z.enum(musicTracks) })
      .strict()
      .optional(),
  })
  .strict()
  .refine((p) => Object.entries(p.levels).every(([g, l]) => p.maxLevels[g] == null || l <= p.maxLevels[g]), {
    message: 'nivelul de pornire nu poate fi peste plafon',
    path: ['levels'],
  });

export interface PlanChange {
  at: Date;
  by: 'PARENT' | 'THERAPIST';
  /** Câte jocuri erau scoase după schimbare. */
  hidden: number;
}

export interface GamePlan {
  hiddenGames: string[];
  /** Nivelul de pornire pe joc (doar jocurile pentru care s-a ales). */
  levels: Record<string, number>;
  /** Plafonul de dificultate pe joc (doar jocurile pentru care s-a ales). */
  maxLevels: Record<string, number>;
  /** Câte runde pe tură, pe joc. */
  rounds: Record<string, number>;
  /** Categoriile de imagini de evitat. */
  avoid: string[];
  /** Muzica de fundal aleasă din panou (lipsă = cum e pe tabletă). */
  music?: MusicChoice;
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
    private readonly live?: LiveEvents,
  ) {}

  async get(user: AuthUser, childId: string): Promise<GamePlan> {
    await this.access.assert(user, childId, 'read');
    return (await this.repo.read(childId)) ?? { hiddenGames: [], levels: {}, maxLevels: {}, rounds: {}, avoid: [], updatedAt: null, updatedBy: null, history: [] };
  }

  async put(user: AuthUser, childId: string, body: unknown): Promise<GamePlan> {
    // Citirea e suficientă ca drept: specialistul are voie aici (doar pentru plan).
    await this.access.assert(user, childId, 'read');
    const { hiddenGames, levels, maxLevels, rounds, avoid, music } = parseWith(planSchema, body);
    const previous = await this.repo.read(childId);
    const by: PlanChange['by'] = user.role === 'THERAPIST' ? 'THERAPIST' : 'PARENT';
    const at = this.now();
    const plan: GamePlan = {
      hiddenGames,
      levels,
      maxLevels,
      rounds,
      avoid,
      ...((music ?? previous?.music) ? { music: music ?? previous?.music } : {}),
      updatedAt: at,
      updatedBy: by,
      history: [...(previous?.history ?? []), { at, by, hidden: hiddenGames.length }].slice(-50),
    };
    await this.repo.write(childId, plan);
    await this.repo.audit(user.id, 'child.plan', childId);
    this.live?.publish({ type: 'plan.changed', childId, by });
    return plan;
  }
}

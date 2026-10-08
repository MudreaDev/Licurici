import type { SessionFacts } from './session-summary';

/** O sesiune, cât îi trebuie raportului. */
export interface WeekSession {
  startedAt: Date;
  facts: SessionFacts;
}

export interface StepLine {
  objective: string;
  trials: number;
  /** Independența (0–1) pe săptămână, ponderată cu încercările. */
  independence: number;
}

/** Rezumatul unei săptămâni pentru un copil (doar cifre agregate, fără răspunsuri individuale). */
export interface WeeklyDigest {
  nickname: string;
  sessions: number;
  minutes: number;
  trials: number;
  independence: number;
  /** Diferența de independență față de săptămâna dinainte, în puncte procentuale (null = fără date). */
  deltaPts: number | null;
  /** Obiectivele cele mai exersate (cel mult 3). */
  steps: StepLine[];
  /** De câte ori a ales copilul cum se simte „bucuros” sau „liniștit” la final. */
  calmEndings: number;
}

const DAY = 24 * 3600 * 1000;

/** Săptămâna ISO (`2026-W41`) a unei date — cheia de idempotență a raportului. */
export function isoWeek(d: Date): string {
  const t = new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate()));
  const day = t.getUTCDay() || 7;
  t.setUTCDate(t.getUTCDate() + 4 - day);
  const year = t.getUTCFullYear();
  const week = Math.ceil(((t.getTime() - Date.UTC(year, 0, 1)) / DAY + 1) / 7);
  return `${year}-W${String(week).padStart(2, '0')}`;
}

function weighted(sessions: WeekSession[]): { trials: number; independence: number } {
  const trials = sessions.reduce((n, s) => n + s.facts.trials, 0);
  if (trials === 0) return { trials, independence: 0 };
  return { trials, independence: sessions.reduce((n, s) => n + s.facts.independence * s.facts.trials, 0) / trials };
}

/**
 * Rezumatul celor 7 zile dinaintea lui [now], comparat cu cele 7 zile de dinainte.
 * Null dacă săptămâna n-a avut nicio sesiune (atunci nu trimitem nimic despre copil).
 */
export function weeklyDigest(nickname: string, all: WeekSession[], now: Date): WeeklyDigest | null {
  const from = now.getTime() - 7 * DAY;
  const week = all.filter((s) => s.startedAt.getTime() >= from && s.startedAt.getTime() < now.getTime());
  if (week.length === 0) return null;
  const before = all.filter((s) => s.startedAt.getTime() >= from - 7 * DAY && s.startedAt.getTime() < from);
  const cur = weighted(week);
  const prev = weighted(before);

  const byStep = new Map<string, { objective: string; trials: number; indep: number }>();
  for (const s of week) {
    for (const st of s.facts.steps) {
      const e = byStep.get(st.stepId) ?? { objective: st.objective, trials: 0, indep: 0 };
      e.trials += st.trials;
      e.indep += st.independence * st.trials;
      byStep.set(st.stepId, e);
    }
  }
  const steps = [...byStep.values()]
    .filter((e) => e.trials > 0)
    .sort((a, b) => b.trials - a.trials)
    .slice(0, 3)
    .map((e) => ({ objective: e.objective, trials: e.trials, independence: e.indep / e.trials }));

  return {
    nickname,
    sessions: week.length,
    minutes: week.reduce((n, s) => n + s.facts.durationMin, 0),
    trials: cur.trials,
    independence: cur.independence,
    deltaPts: prev.trials > 0 && cur.trials > 0 ? Math.round((cur.independence - prev.independence) * 100) : null,
    steps,
    calmEndings: week.filter((s) => s.facts.moodAfter === 'bucuros' || s.facts.moodAfter === 'linistit').length,
  };
}

const pct = (x: number) => `${Math.round(x * 100)}%`;

/** „20 de încercări”, „12 încercări” (în română, de la 20 în sus se pune „de”). */
const count = (n: number, word: string) => (n % 100 >= 20 || (n >= 100 && n % 100 === 0) ? `${n} de ${word}` : `${n} ${word}`);

/** Textul pentru un copil (cald, scurt, fără jargon — ca rezumatul din panou). */
export function digestLines(d: WeeklyDigest): string[] {
  const lines = [
    `${d.nickname}: ${d.sessions === 1 ? 'o sesiune' : count(d.sessions, 'sesiuni')}, ${d.minutes} min, ` +
      `${d.trials === 1 ? 'o încercare' : count(d.trials, 'încercări')}.`,
    `A lucrat singur(ă) la ${pct(d.independence)} din încercări` +
      (d.deltaPts == null
        ? '.'
        : d.deltaPts > 0
          ? ` — cu ${d.deltaPts === 1 ? 'un punct' : count(d.deltaPts, 'puncte')} mai mult decât săptămâna trecută.`
          : d.deltaPts < 0
            ? ` (săptămâna trecută: ${pct(d.independence - d.deltaPts / 100)}; e normal să varieze).`
            : ', la fel ca săptămâna trecută.'),
  ];
  for (const s of d.steps) lines.push(`• ${s.objective} — ${count(s.trials, 'încercări')}, ${pct(s.independence)} singur(ă)`);
  if (d.calmEndings > 0) {
    lines.push(`A încheiat ${d.calmEndings === 1 ? 'o sesiune' : `${d.calmEndings} sesiuni`} spunând că e bucuros sau liniștit.`);
  }
  return lines;
}

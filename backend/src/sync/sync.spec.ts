import { readFileSync } from 'node:fs';
import { join } from 'node:path';

import type { AuthUser } from '../auth/tokens';
import { ChildAccess, type ChildRepo, type ChildRow } from '../children/access';
import { ForbiddenError, NotFoundError, RateLimitedError, UnavailableError, ValidationError } from '../common/errors';
import type { SessionSummary } from '../reports/session-summary';
import type { LiveEvent } from '../live/live';
import { AskFlow, type AskBody, type Asker } from '../reports/ask';
import { SummaryFlow, type Summarizer, type SummaryRepo } from '../reports/summary-flow';
import { ConsentService, type ConsentStore } from '../consents/consents';
import { SkillStatsService } from '../stats/skill-stats';
import { type SessionRepo, type StoredSession, SyncService } from './sessions';

/** Corpul trimis de tabletă, generat de `licurici_core/tool/sync_fixture.dart` (contract Dart ↔ TS). */
const fixture = JSON.parse(readFileSync(join(__dirname, 'sync-fixture.json'), 'utf8')) as {
  sessions: { record: { id: string; childId: string }; facts: unknown }[];
};

const parent: AuthUser = { id: 'p1', role: 'PARENT' };
const otherParent: AuthUser = { id: 'p2', role: 'PARENT' };
const therapist: AuthUser = { id: 't1', role: 'THERAPIST' };
const strangerTherapist: AuthUser = { id: 't2', role: 'THERAPIST' };
const CHILD = '0190a1b2-0000-7000-8000-000000000001';

class Children implements ChildRepo {
  child: ChildRow = { id: CHILD, parentId: 'p1', deletedAt: null };
  linkExpires: Date | null = new Date('2026-12-31');
  audit?: (actorId: string, action: string, targetId: string) => Promise<void>;
  async findChild(id: string) {
    return id === this.child.id ? this.child : null;
  }
  async hasActiveLink(childId: string, therapistId: string, now: Date) {
    return childId === CHILD && therapistId === 't1' && (this.linkExpires === null || this.linkExpires > now);
  }
}

class Sessions implements SessionRepo {
  readonly rows = new Map<string, Omit<StoredSession, 'hasSummary'>>();
  async upsert(s: Omit<StoredSession, 'hasSummary'>) {
    this.rows.set(s.id, s);
  }
  async list(childId: string) {
    return [...this.rows.values()].filter((s) => s.childId === childId).map((s) => ({ ...s, hasSummary: false }));
  }
  async get(childId: string, id: string) {
    const s = this.rows.get(id);
    return s && s.childId === childId ? { ...s, hasSummary: false } : null;
  }
}

class Consents implements ConsentStore {
  readonly log: { userId: string; purpose: string; granted: boolean }[] = [];
  async granted(userId: string, purpose: string) {
    return [...this.log].reverse().find((c) => c.userId === userId && c.purpose === purpose)?.granted ?? false;
  }
  async record(userId: string, d: { purpose: string; granted: boolean }) {
    this.log.push({ userId, purpose: d.purpose, granted: d.granted });
  }
  async current() {
    return {} as never;
  }
}

function setup(now = new Date('2026-10-01T12:00:00Z'), syncConsent = true) {
  const children = new Children();
  const access = new ChildAccess(children, () => now);
  const sessions = new Sessions();
  const store = new Consents();
  if (syncConsent) store.log.push({ userId: 'p1', purpose: 'SYNC', granted: true });
  const consents = new ConsentService(store);
  return { children, access, sessions, store, consents, sync: new SyncService(access, sessions, consents) };
}

describe('ChildAccess', () => {
  it('părintele lui: citire și scriere; alt părinte: 404 (nu aflăm că există)', async () => {
    const { access } = setup();
    await expect(access.assert(parent, CHILD, 'write')).resolves.toMatchObject({ id: CHILD });
    await expect(access.assert(otherParent, CHILD, 'read')).rejects.toBeInstanceOf(NotFoundError);
    await expect(access.assert(parent, 'alt-copil', 'read')).rejects.toBeInstanceOf(NotFoundError);
  });

  it('specialistul legat: doar citire, cât timp legătura e activă', async () => {
    const { access, children } = setup();
    await expect(access.assert(therapist, CHILD, 'read')).resolves.toBeTruthy();
    await expect(access.assert(therapist, CHILD, 'write')).rejects.toBeInstanceOf(ForbiddenError);
    await expect(access.assert(strangerTherapist, CHILD, 'read')).rejects.toBeInstanceOf(NotFoundError);
    children.linkExpires = new Date('2026-09-01');
    await expect(access.assert(therapist, CHILD, 'read')).rejects.toBeInstanceOf(NotFoundError);
  });

  it('copilul șters (GDPR) nu mai e accesibil nici părintelui', async () => {
    const { access, children } = setup();
    children.child.deletedAt = new Date();
    await expect(access.assert(parent, CHILD, 'read')).rejects.toBeInstanceOf(NotFoundError);
  });
});

describe('SyncService', () => {
  it('contract: acceptă exact ce trimite tableta (JSON generat din licurici_core)', async () => {
    const { sync, sessions } = setup();
    expect(await sync.push(parent, CHILD, fixture)).toEqual({ accepted: fixture.sessions.length });
    const stored = await sessions.list(CHILD);
    expect(stored).toHaveLength(fixture.sessions.length);
    // „local” de pe dispozitiv devine id-ul real al copilului.
    expect(stored.every((s) => s.record.childId === CHILD)).toBe(true);
  });

  it('idempotent: retrimiterea nu dublează sesiunile', async () => {
    const { sync, sessions } = setup();
    await sync.push(parent, CHILD, fixture);
    await sync.push(parent, CHILD, fixture);
    expect(sessions.rows.size).toBe(fixture.sessions.length);
  });

  it('specialistul nu poate scrie; câmpurile în plus (ex. un nume) sunt respinse', async () => {
    const { sync, sessions } = setup();
    await expect(sync.push(therapist, CHILD, fixture)).rejects.toBeInstanceOf(ForbiddenError);
    const withName = { sessions: [{ ...fixture.sessions[0], record: { ...fixture.sessions[0].record, nickname: 'Ilinca' } }] };
    await expect(sync.push(parent, CHILD, withName)).rejects.toBeInstanceOf(ValidationError);
    const withFactsName = { sessions: [{ ...fixture.sessions[0], facts: { ...(fixture.sessions[0].facts as object), childName: 'x' } }] };
    await expect(sync.push(parent, CHILD, withFactsName)).rejects.toBeInstanceOf(ValidationError);
    expect(sessions.rows.size).toBe(0);
  });

  it('fără consimțământ pentru sincronizare (sau după retragere) → 403, nimic salvat', async () => {
    const none = setup(undefined, false);
    await expect(none.sync.push(parent, CHILD, fixture)).rejects.toBeInstanceOf(ForbiddenError);
    expect(none.sessions.rows.size).toBe(0);

    const withdrawn = setup();
    await withdrawn.consents.set(parent, { purpose: 'SYNC', granted: false, policyVersion: '2026-10' });
    await expect(withdrawn.sync.push(parent, CHILD, fixture)).rejects.toBeInstanceOf(ForbiddenError);
  });

  it('doar părintele își dă consimțământul; scopurile necunoscute sunt respinse', async () => {
    const { consents } = setup();
    await expect(
      consents.set(therapist, { purpose: 'SYNC', granted: true, policyVersion: '1' }),
    ).rejects.toBeInstanceOf(ForbiddenError);
    await expect(
      consents.set(parent, { purpose: 'MARKETING', granted: true, policyVersion: '1' }),
    ).rejects.toBeInstanceOf(ValidationError);
  });

  it('acordul se dă doar de pe o adresă confirmată; retragerea merge oricând', async () => {
    const store = new Consents();
    let verified = false;
    const consents = new ConsentService(store, async () => verified);
    const grant = { purpose: 'SYNC', granted: true, policyVersion: '2026-10' };
    await expect(consents.set(parent, grant)).rejects.toThrow(/Confirmă întâi adresa/);
    expect(store.log).toHaveLength(0);
    await expect(consents.set(parent, { ...grant, granted: false })).resolves.toBeDefined();
    verified = true;
    await consents.set(parent, grant);
    expect(await store.granted('p1', 'SYNC')).toBe(true);
  });

  it('fiecare accesare a specialistului intră în jurnalul de audit; ale părintelui nu', async () => {
    const children = new Children();
    const audit: string[] = [];
    children.audit = async (actor: string, action: string, target: string) => void audit.push(`${actor} ${action} ${target}`);
    const access = new ChildAccess(children, () => new Date('2026-10-01T12:00:00Z'));
    await access.assert(parent, CHILD, 'read');
    await access.assert(therapist, CHILD, 'read');
    await expect(access.assert(strangerTherapist, CHILD, 'read')).rejects.toBeInstanceOf(NotFoundError);
    expect(audit).toEqual([`t1 child.read ${CHILD}`]);
  });

  it('specialistul legat poate citi sesiunile', async () => {
    const { sync } = setup();
    await sync.push(parent, CHILD, fixture);
    await expect(sync.list(therapist, CHILD)).resolves.toHaveLength(fixture.sessions.length);
  });

  it('pune recalcularea statisticilor în coadă; o coadă căzută nu strică sincronizarea', async () => {
    const { access, sessions, consents } = setup();
    const queued: string[] = [];
    const ok = new SyncService(access, sessions, consents, undefined, { recompute: async (id) => void queued.push(id) });
    await ok.push(parent, CHILD, fixture);
    expect(queued).toEqual([CHILD]);

    const down = new SyncService(access, sessions, consents, undefined, {
      recompute: () => Promise.reject(new Error('redis jos')),
    });
    await expect(down.push(parent, CHILD, fixture)).resolves.toEqual({ accepted: fixture.sessions.length });
  });
});

describe('SkillStatsService', () => {
  const row = { skill: 'POT2', attempts: 4, firstTry: 3, accuracy: 0.75, lastPlayed: new Date('2026-10-01') };
  const make = () => {
    const { access } = setup();
    return new SkillStatsService(access, { list: async () => [row] });
  };

  it('părintele și specialistul legat văd statisticile; un străin primește 404', async () => {
    await expect(make().list(parent, CHILD)).resolves.toEqual([row]);
    await expect(make().list(therapist, CHILD)).resolves.toEqual([row]);
    await expect(make().list(otherParent, CHILD)).rejects.toBeInstanceOf(NotFoundError);
    await expect(make().list(strangerTherapist, CHILD)).rejects.toBeInstanceOf(NotFoundError);
  });
});

describe('SummaryFlow', () => {
  const summary: SessionSummary = { parent: 'Bine.', homeIdea: 'Idee.', specialist: ['x'], planSuggestions: [] };

  async function flowSetup(opts: { consent?: boolean; perDay?: number; summarizer?: Summarizer | null } = {}) {
    const { access, sessions, sync } = setup();
    await sync.push(parent, CHILD, fixture);
    const saved = new Map<string, SessionSummary>();
    const summaries: SummaryRepo = {
      get: async (id) => saved.get(id) ?? null,
      save: async (id, _m, s) => void saved.set(id, s),
    };
    const counts = new Map<string, number>();
    const counter = {
      incr: async (k: string) => counts.set(k, (counts.get(k) ?? 0) + 1).get(k)!,
      expire: async () => 1,
    };
    const calls: unknown[] = [];
    const summarizer: Summarizer = { model: 'claude-opus-5-5', summarize: async (f) => (calls.push(f), summary) };
    const flow = new SummaryFlow(
      access,
      sessions,
      summaries,
      { granted: async () => opts.consent ?? true },
      counter,
      opts.summarizer === undefined ? summarizer : opts.summarizer,
      opts.perDay ?? 30,
      () => new Date('2026-10-01T12:00:00Z'),
    );
    return { flow, calls, sid: fixture.sessions[0].record.id };
  }

  it('generează o dată, apoi servește din cache; AI-ul primește doar faptele agregate', async () => {
    const { flow, calls, sid } = await flowSetup();
    expect(await flow.summary(parent, CHILD, sid)).toEqual({ summary, cached: false });
    expect(await flow.summary(therapist, CHILD, sid)).toEqual({ summary, cached: true });
    expect(calls).toEqual([fixture.sessions[0].facts]);
  });

  it('fără consimțământul părintelui pentru AI → 403, fără apel', async () => {
    const { flow, calls, sid } = await flowSetup({ consent: false });
    await expect(flow.summary(parent, CHILD, sid)).rejects.toBeInstanceOf(ForbiddenError);
    expect(calls).toHaveLength(0);
  });

  it('limita zilnică → 429; fără cheie AI pe server → 503', async () => {
    const limited = await flowSetup({ perDay: 1 });
    await limited.flow.summary(parent, CHILD, limited.sid);
    await expect(limited.flow.summary(parent, CHILD, fixture.sessions[1].record.id)).rejects.toBeInstanceOf(
      RateLimitedError,
    );
    const off = await flowSetup({ summarizer: null });
    await expect(off.flow.summary(parent, CHILD, off.sid)).rejects.toBeInstanceOf(UnavailableError);
  });

  it('alt părinte nu poate cere rezumatul (404)', async () => {
    const { flow, sid } = await flowSetup();
    await expect(flow.summary(otherParent, CHILD, sid)).rejects.toBeInstanceOf(NotFoundError);
  });
});

describe('AskFlow (întreabă despre progres)', () => {
  async function askSetup(opts: { consent?: boolean; perDay?: number; asker?: Asker | null } = {}) {
    const { access, sessions, sync } = setup();
    await sync.push(parent, CHILD, fixture);
    const counts = new Map<string, number>();
    const counter = {
      incr: async (k: string) => counts.set(k, (counts.get(k) ?? 0) + 1).get(k)!,
      expire: async () => 1,
    };
    const calls: { context: unknown[]; body: AskBody }[] = [];
    const asker: Asker = { ask: async (context, body) => (calls.push({ context, body }), 'Răspuns.') };
    const flow = new AskFlow(
      access,
      sessions,
      { granted: async () => opts.consent ?? true },
      counter,
      opts.asker === undefined ? asker : opts.asker,
      opts.perDay ?? 30,
      () => new Date('2026-10-01T12:00:00Z'),
    );
    return { flow, calls };
  }

  it('răspunde din faptele agregate (fără încercări individuale), pentru părinte și specialistul legat', async () => {
    const { flow, calls } = await askSetup();
    expect(await flow.ask(parent, CHILD, { question: 'Cum a mers săptămâna asta?' })).toEqual({
      answer: 'Răspuns.',
      sessions: fixture.sessions.length,
    });
    await flow.ask(therapist, CHILD, {
      question: 'Și la emoții?',
      history: [
        { role: 'user', text: 'Cum a mers?' },
        { role: 'assistant', text: 'Bine.' },
      ],
    });
    expect(calls[1].body.history).toHaveLength(2);
    const sent = JSON.stringify(calls[0].context);
    expect(sent).not.toContain('"trials":[');
    expect(sent).not.toContain('latencyMs"');
    await expect(flow.ask(strangerTherapist, CHILD, { question: 'Cum a mers?' })).rejects.toBeInstanceOf(NotFoundError);
  });

  it('validare, consimțământ, limită, fără cheie', async () => {
    const { flow } = await askSetup();
    await expect(flow.ask(parent, CHILD, { question: 'x' })).rejects.toBeInstanceOf(ValidationError);
    await expect(flow.ask(parent, CHILD, { question: 'a'.repeat(501) })).rejects.toBeInstanceOf(ValidationError);
    const noConsent = await askSetup({ consent: false });
    await expect(noConsent.flow.ask(parent, CHILD, { question: 'Cum a mers?' })).rejects.toBeInstanceOf(ForbiddenError);
    expect(noConsent.calls).toHaveLength(0);
    const limited = await askSetup({ perDay: 1 });
    await limited.flow.ask(parent, CHILD, { question: 'Cum a mers?' });
    await expect(limited.flow.ask(parent, CHILD, { question: 'Și acum?' })).rejects.toBeInstanceOf(RateLimitedError);
    const off = await askSetup({ asker: null });
    await expect(off.flow.ask(parent, CHILD, { question: 'Cum a mers?' })).rejects.toBeInstanceOf(UnavailableError);
  });
});

describe('evenimentele live (ADR-010)', () => {
  it('sincronizarea anunță panoul: doar id-ul copilului și câte sesiuni', async () => {
    const { access, sessions, consents } = setup();
    const events: LiveEvent[] = [];
    const sync = new SyncService(access, sessions, consents, { publish: (e) => events.push(e) });
    await sync.push(parent, CHILD, fixture);
    expect(events).toEqual([{ type: 'session.synced', childId: CHILD, count: fixture.sessions.length }]);
    await expect(sync.push(otherParent, CHILD, fixture)).rejects.toBeInstanceOf(NotFoundError);
    expect(events).toHaveLength(1);
  });
});

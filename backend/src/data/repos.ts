import type { UserRepo } from '../auth/auth.service';
import type { Role } from '../auth/tokens';
import type { ChildRepo } from '../children/access';
import type { ChildrenRepo } from '../children/children';
import type { PlanRepo } from '../children/plan';
import type { SharingRepo } from '../children/sharing';
import type { GdprRepo } from '../gdpr/gdpr';
import { type ConsentStore, consentPurposes } from '../consents/consents';
import type { PrismaService } from '../prisma/prisma.service';
import type { ConsentRepo, SummaryRepo } from '../reports/summary-flow';
import type { SessionFacts, SessionSummary } from '../reports/session-summary';
import type { SessionRecordJson, SessionRepo, StoredSession } from '../sync/sessions';

/** Implementările Prisma ale interfețelor de domeniu (singurul loc care știe de tabele). */
export class PrismaRepos {
  constructor(private readonly db: PrismaService) {}

  readonly users: UserRepo = {
    findByEmail: async (email) => {
      const u = await this.db.user.findFirst({ where: { email, deletedAt: null } });
      return u ? PrismaRepos.userRow(u) : null;
    },
    create: async (data) => {
      const u = await this.db.user.create({ data });
      return { id: u.id, role: u.role as Role };
    },
    findById: async (id) => {
      const u = await this.db.user.findFirst({ where: { id, deletedAt: null } });
      return u ? PrismaRepos.userRow(u) : null;
    },
    setTotp: async (id, secret, enabledAt) => {
      await this.db.user.update({ where: { id }, data: { totpSecret: secret, totpEnabledAt: enabledAt } });
    },
    setVerified: async (id, at) => {
      await this.db.user.update({ where: { id }, data: { verifiedAt: at } });
    },
    setPassword: async (id, passwordHash) => {
      await this.db.user.update({ where: { id }, data: { passwordHash } });
    },
  };

  private static userRow(u: {
    id: string;
    role: string;
    email: string;
    passwordHash: string | null;
    totpSecret: string | null;
    totpEnabledAt: Date | null;
    verifiedAt: Date | null;
  }) {
    return {
      id: u.id,
      role: u.role as Role,
      email: u.email,
      passwordHash: u.passwordHash,
      totpSecret: u.totpSecret,
      totpEnabledAt: u.totpEnabledAt,
      verifiedAt: u.verifiedAt,
    };
  }

  readonly childAccess: ChildRepo = {
    findChild: (id) => this.db.child.findUnique({ where: { id }, select: { id: true, parentId: true, deletedAt: true } }),
    hasActiveLink: async (childId, therapistId, now) =>
      (await this.db.careLink.count({
        where: { childId, therapistId, OR: [{ expiresAt: null }, { expiresAt: { gt: now } }] },
      })) > 0,
  };

  private static childSelect = { id: true, nickname: true, avatar: true, birthYear: true } as const;

  readonly children: ChildrenRepo = {
    ownedBy: (parentId) =>
      this.db.child.findMany({
        where: { parentId, deletedAt: null },
        select: PrismaRepos.childSelect,
        orderBy: { createdAt: 'asc' },
      }),
    linkedTo: (therapistId, now) =>
      this.db.child.findMany({
        where: {
          deletedAt: null,
          careLinks: { some: { therapistId, OR: [{ expiresAt: null }, { expiresAt: { gt: now } }] } },
        },
        select: PrismaRepos.childSelect,
        orderBy: { createdAt: 'asc' },
      }),
    create: (parentId, data) =>
      this.db.child.create({
        data: { parentId, nickname: data.nickname, avatar: data.avatar, birthYear: data.birthYear },
        select: PrismaRepos.childSelect,
      }),
  };

  readonly sessions: SessionRepo = {
    upsert: async (s) => {
      const data = {
        childId: s.childId,
        startedAt: s.startedAt,
        endedAt: s.endedAt,
        moodBefore: s.moodBefore,
        moodAfter: s.moodAfter,
        record: s.record,
        facts: s.facts,
      };
      await this.db.therapySession.upsert({ where: { id: s.id }, create: { id: s.id, ...data }, update: data });
    },
    list: async (childId) =>
      (
        await this.db.therapySession.findMany({
          where: { childId },
          orderBy: { startedAt: 'asc' },
          include: { summary: { select: { sessionId: true } } },
        })
      ).map(PrismaRepos.toStored),
    get: async (childId, id) => {
      const row = await this.db.therapySession.findFirst({
        where: { id, childId },
        include: { summary: { select: { sessionId: true } } },
      });
      return row ? PrismaRepos.toStored(row) : null;
    },
  };

  private static toStored(row: {
    id: string;
    childId: string;
    startedAt: Date;
    endedAt: Date;
    moodBefore: string | null;
    moodAfter: string | null;
    record: unknown;
    facts: unknown;
    summary: { sessionId: string } | null;
  }): StoredSession {
    return {
      id: row.id,
      childId: row.childId,
      startedAt: row.startedAt,
      endedAt: row.endedAt,
      moodBefore: row.moodBefore,
      moodAfter: row.moodAfter,
      record: row.record as SessionRecordJson,
      facts: row.facts as SessionFacts,
      hasSummary: row.summary !== null,
    };
  }

  readonly summaries: SummaryRepo = {
    get: async (sessionId) =>
      ((await this.db.sessionSummary.findUnique({ where: { sessionId } }))?.content as SessionSummary | undefined) ??
      null,
    save: async (sessionId, model, content) => {
      await this.db.sessionSummary.upsert({
        where: { sessionId },
        create: { sessionId, model, content },
        update: {},
      });
    },
  };

  readonly consents: ConsentRepo & ConsentStore = {
    granted: async (userId, purpose) =>
      (await this.db.consent.findFirst({ where: { userId, purpose }, orderBy: { at: 'desc' } }))?.granted ?? false,
    record: async (userId, data) => {
      await this.db.consent.create({ data: { userId, ...data } });
    },
    current: async (userId) => {
      const entries = await Promise.all(
        consentPurposes.map(async (p) => [p, await this.consents.granted(userId, p)] as const),
      );
      return Object.fromEntries(entries) as Record<(typeof consentPurposes)[number], boolean>;
    },
  };

  readonly sharing: SharingRepo = {
    findTherapist: (email) =>
      this.db.user.findFirst({ where: { email, role: 'THERAPIST', deletedAt: null }, select: { id: true } }),
    upsertLink: async (childId, therapistId, expiresAt) => {
      await this.db.careLink.upsert({
        where: { childId_therapistId: { childId, therapistId } },
        create: { childId, therapistId, expiresAt },
        update: { expiresAt },
      });
    },
    removeLink: async (childId, therapistId) =>
      (await this.db.careLink.deleteMany({ where: { childId, therapistId } })).count > 0,
    links: async (childId) =>
      (
        await this.db.careLink.findMany({
          where: { childId },
          orderBy: { createdAt: 'asc' },
          include: { therapist: { select: { email: true } } },
        })
      ).map((l) => ({
        therapistId: l.therapistId,
        email: l.therapist.email,
        // Partajările vechi fără termen sunt afișate ca expirând „acum” — trebuie reînnoite.
        expiresAt: l.expiresAt ?? new Date(0),
      })),
    audit: async (actorId, action, targetId) => {
      await this.db.auditLog.create({ data: { actorId, action, targetId } });
    },
  };

  /** Planul de jocuri stă în `child_settings.extra.plan` (fără tabel nou). */
  readonly plan: PlanRepo = {
    read: async (childId) => {
      const row = await this.db.childSettings.findUnique({ where: { childId }, select: { extra: true } });
      type Stored = {
        hiddenGames?: string[];
        levels?: Record<string, number>;
        maxLevels?: Record<string, number>;
        rounds?: Record<string, number>;
        updatedAt?: string;
        updatedBy?: string;
        history?: { at: string; by: string; hidden: number }[];
      };
      const plan = (row?.extra as { plan?: Stored } | null)?.plan;
      if (!plan) return null;
      return {
        hiddenGames: Array.isArray(plan.hiddenGames) ? plan.hiddenGames : [],
        levels: plan.levels && typeof plan.levels === 'object' ? plan.levels : {},
        maxLevels: plan.maxLevels && typeof plan.maxLevels === 'object' ? plan.maxLevels : {},
        rounds: plan.rounds && typeof plan.rounds === 'object' ? plan.rounds : {},
        updatedAt: plan.updatedAt ? new Date(plan.updatedAt) : null,
        updatedBy: plan.updatedBy === 'THERAPIST' ? 'THERAPIST' : plan.updatedBy === 'PARENT' ? 'PARENT' : null,
        history: (plan.history ?? []).map((h) => ({
          at: new Date(h.at),
          by: h.by === 'THERAPIST' ? ('THERAPIST' as const) : ('PARENT' as const),
          hidden: h.hidden,
        })),
      };
    },
    write: async (childId, plan) => {
      const row = await this.db.childSettings.findUnique({ where: { childId }, select: { extra: true } });
      const extra = {
        ...((row?.extra as Record<string, unknown> | null) ?? {}),
        plan: {
          ...plan,
          updatedAt: plan.updatedAt?.toISOString(),
          history: plan.history.map((h) => ({ ...h, at: h.at.toISOString() })),
        },
      };
      await this.db.childSettings.upsert({
        where: { childId },
        create: { childId, extra, updatedAt: plan.updatedAt ?? new Date() },
        update: { extra },
      });
    },
    audit: async (actorId, action, targetId) => {
      await this.db.auditLog.create({ data: { actorId, action, targetId } });
    },
  };

  readonly gdpr: GdprRepo = {
    account: async (userId) => {
      const u = await this.db.user.findUniqueOrThrow({ where: { id: userId } });
      return { email: u.email, role: u.role, createdAt: u.createdAt.toISOString() };
    },
    consentLog: async (userId) =>
      (await this.db.consent.findMany({ where: { userId }, orderBy: { at: 'asc' } })).map((c) => ({
        purpose: c.purpose,
        granted: c.granted,
        policyVersion: c.policyVersion,
        at: c.at.toISOString(),
      })),
    childrenWithSessions: async (parentId) =>
      (
        await this.db.child.findMany({
          where: { parentId, deletedAt: null },
          include: { therapySessions: { orderBy: { startedAt: 'asc' }, include: { summary: true } } },
        })
      ).map((c) => ({
        nickname: c.nickname,
        avatar: c.avatar,
        birthYear: c.birthYear,
        sessions: c.therapySessions.map((s) => ({ record: s.record, summary: s.summary?.content ?? null })),
      })),
    softDeleteAccount: async (userId, at) => {
      await this.db.$transaction([
        this.db.careLink.deleteMany({ where: { OR: [{ therapistId: userId }, { child: { parentId: userId } }] } }),
        this.db.child.updateMany({ where: { parentId: userId, deletedAt: null }, data: { deletedAt: at } }),
        this.db.user.update({
          where: { id: userId },
          data: {
            deletedAt: at,
            passwordHash: null,
            totpSecret: null,
            totpEnabledAt: null,
            email: `sters-${userId}@licurici.invalid`,
          },
        }),
      ]);
    },
    softDeleteChild: async (childId, at) => {
      await this.db.$transaction([
        this.db.child.update({ where: { id: childId }, data: { deletedAt: at } }),
        this.db.careLink.deleteMany({ where: { childId } }),
      ]);
    },
    audit: async (actorId, action, targetId) => {
      await this.db.auditLog.create({ data: { actorId, action, targetId } });
    },
  };
}

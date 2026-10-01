import type { UserRepo } from '../auth/auth.service';
import type { Role } from '../auth/tokens';
import type { ChildRepo } from '../children/access';
import type { ChildrenRepo } from '../children/children';
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
      return u ? { id: u.id, role: u.role as Role, passwordHash: u.passwordHash } : null;
    },
    create: async (data) => {
      const u = await this.db.user.create({ data });
      return { id: u.id, role: u.role as Role };
    },
  };

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

  readonly consents: ConsentRepo = {
    granted: async (userId, purpose) =>
      (await this.db.consent.findFirst({ where: { userId, purpose }, orderBy: { at: 'desc' } }))?.granted ?? false,
  };
}

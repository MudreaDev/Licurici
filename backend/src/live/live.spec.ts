import type { AuthUser } from '../auth/tokens';
import { NotFoundError, UnauthorizedError } from '../common/errors';
import { LiveAccess } from './live';

const CHILD = '0190a1b2-0000-7000-8000-000000000001';
const OTHER = '0190a1b2-0000-7000-8000-000000000002';

const users: Record<string, AuthUser> = { 'tok-ana': { id: 'p1', role: 'PARENT' } };
const access = new LiveAccess(
  {
    verifyAccess: (t: string) => {
      const u = users[t];
      if (!u) throw new UnauthorizedError();
      return u;
    },
  },
  {
    assert: async (_u, childId) => {
      if (childId !== CHILD) throw new NotFoundError('Copilul nu există.');
      return { id: CHILD, parentId: 'p1', deletedAt: null };
    },
  },
);

describe('LiveAccess', () => {
  it('conectare doar cu token valid; „watch” doar pentru copiii vizibili', async () => {
    expect(access.connect('tok-ana')).toEqual(users['tok-ana']);
    expect(access.connect('altul')).toBeNull();
    expect(access.connect(undefined)).toBeNull();
    expect(await access.canWatch(users['tok-ana'], CHILD)).toBe(`child:${CHILD}`);
    expect(await access.canWatch(users['tok-ana'], OTHER)).toBeNull();
    expect(await access.canWatch(users['tok-ana'], '../x')).toBeNull();
  });
});

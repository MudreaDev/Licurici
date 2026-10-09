import type { ErrorEvent } from '@sentry/node';

import { initSentry, scrubEvent, scrubText } from './sentry';

describe('Sentry fără date personale', () => {
  it('fără DSN nu pornește', () => {
    expect(initSentry(undefined, 'test')).toBe(false);
  });

  it('scoate cererea, utilizatorul, breadcrumbs, variabilele; ascunde e-mailurile din mesaje', () => {
    const event = {
      type: undefined,
      message: 'Unique constraint failed for ana.pop@example.md',
      request: { url: 'http://api/children?x=1', headers: { authorization: 'Bearer x' }, data: '{"password":"p"}' },
      user: { id: 'u1', email: 'ana@example.md' },
      breadcrumbs: [{ message: 'GET /children' }],
      extra: { body: 'x' },
      exception: {
        values: [
          {
            type: 'PrismaClientKnownRequestError',
            value: 'email `ana@example.md` already exists',
            stacktrace: { frames: [{ function: 'register', vars: { password: 'p' } }] },
          },
        ],
      },
    } as unknown as ErrorEvent;
    const out = scrubEvent(event);
    expect(out.request).toBeUndefined();
    expect(out.user).toBeUndefined();
    expect(out.breadcrumbs).toBeUndefined();
    expect(out.extra).toBeUndefined();
    expect(out.message).toBe('Unique constraint failed for [e-mail]');
    expect(out.exception!.values![0].value).toBe('email `[e-mail]` already exists');
    expect(out.exception!.values![0].stacktrace!.frames![0].vars).toBeUndefined();
    expect(out.exception!.values![0].type).toBe('PrismaClientKnownRequestError');
    expect(scrubText('fără adrese')).toBe('fără adrese');
  });
});

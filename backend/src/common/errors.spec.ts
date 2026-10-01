import { ForbiddenError, ValidationError } from './errors';

// Filtrul importă @nestjs/common (ESM); testăm doar logica pură, reexportată fără Nest.
jest.mock('@nestjs/common', () => ({
  Catch: () => () => undefined,
  HttpException: class {},
  Logger: class {
    warn() {}
  },
}));

// eslint-disable-next-line @typescript-eslint/no-require-imports
const { errorResponse } = require('./domain-error.filter') as typeof import('./domain-error.filter');

describe('errorResponse', () => {
  it('erorile de domeniu își păstrează codul și detaliile', () => {
    expect(errorResponse(new ForbiddenError('Nu.'))).toEqual({ statusCode: 403, message: 'Nu.' });
    expect(errorResponse(new ValidationError(['email: invalid']))).toEqual({
      statusCode: 400,
      message: 'Date invalide.',
      details: ['email: invalid'],
    });
  });

  it('Postgres / Redis indisponibile → 503 (temporar), nu 500', () => {
    const refused = Object.assign(new Error('connect ECONNREFUSED 127.0.0.1:6379'), { code: 'ECONNREFUSED' });
    const prisma = Object.assign(new Error("Can't reach database server"), { code: 'P1001' });
    const redisClosed = new Error('Connection is closed.');
    for (const e of [refused, prisma, redisClosed]) expect(errorResponse(e).statusCode).toBe(503);
  });

  it('orice altceva → 500, fără detalii interne în răspuns', () => {
    expect(errorResponse(new TypeError('x is undefined at secret.ts:12'))).toEqual({
      statusCode: 500,
      message: 'Eroare internă.',
    });
  });
});

import { EnvValidationError, loadEnv } from './env';

const valid = {
  DATABASE_URL: 'postgresql://licurici:secret@postgres:5432/licurici',
  REDIS_URL: 'redis://:secret@redis:6379',
  S3_ENDPOINT: 'http://storage:9000',
  S3_ACCESS_KEY: 'licurici',
  S3_SECRET_KEY: 'secret-secret',
  JWT_SECRET: 'x'.repeat(32),
};

describe('loadEnv', () => {
  it('acceptă o configurație validă și pune valorile implicite', () => {
    const env = loadEnv(valid);
    expect(env.PORT).toBe(3000);
    expect(env.NODE_ENV).toBe('development');
    expect(env.WORKER_CONCURRENCY).toBe(4);
  });

  it('convertește numerele din text', () => {
    expect(loadEnv({ ...valid, PORT: '8080' }).PORT).toBe(8080);
  });

  it('eșuează clar când lipsește o variabilă obligatorie', () => {
    const { DATABASE_URL: _, ...missing } = valid;
    expect(() => loadEnv(missing)).toThrow(EnvValidationError);
    expect(() => loadEnv(missing)).toThrow(/DATABASE_URL/);
  });

  it('respinge un URL de bază de date care nu e PostgreSQL', () => {
    expect(() => loadEnv({ ...valid, DATABASE_URL: 'mysql://x@y/z' })).toThrow(/DATABASE_URL/);
  });
});

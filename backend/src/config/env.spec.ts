import { corsOrigins, EnvValidationError, loadEnv } from './env';

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

  it('cheile goale din .env (ex. `SENTRY_DSN=`) înseamnă „nesetat”, nu o valoare invalidă', () => {
    const env = loadEnv({ ...valid, SENTRY_DSN: '', ANTHROPIC_API_KEY: '', SMTP_URL: ' ', METRICS_TOKEN: '' });
    expect(env.SENTRY_DSN).toBeUndefined();
    expect(env.ANTHROPIC_API_KEY).toBeUndefined();
    expect(env.SMTP_URL).toBeUndefined();
    // O obligatorie goală rămâne o eroare clară.
    expect(() => loadEnv({ ...valid, JWT_SECRET: '' })).toThrow(/JWT_SECRET/);
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

  it('CORS: originea panoului sau lista explicită, fără căi și fără dubluri', () => {
    expect(corsOrigins(loadEnv(valid))).toEqual(['http://localhost:8080']);
    expect(
      corsOrigins(loadEnv({ ...valid, CORS_ORIGINS: 'https://panou.licurici.ro/, http://localhost:8080 ,https://panou.licurici.ro' })),
    ).toEqual(['https://panou.licurici.ro', 'http://localhost:8080']);
  });
});

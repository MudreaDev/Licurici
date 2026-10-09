import { z } from 'zod';

/**
 * Configurația din variabile de mediu, validată la pornire (fail fast):
 * dacă lipsește ceva, procesul se oprește cu un mesaj clar, nu la prima cerere.
 * Secretele vin DOAR din mediu (`.env` e ignorat de git) — README §22.
 */
export const envSchema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  PORT: z.coerce.number().int().positive().default(3000),
  LOG_LEVEL: z.enum(['fatal', 'error', 'warn', 'info', 'debug', 'trace']).default('info'),

  DATABASE_URL: z.url({ protocol: /^postgres(ql)?$/ }),
  REDIS_URL: z.url({ protocol: /^rediss?$/ }),

  /** Stocare obiecte S3-compatibilă (ADR-15): RustFS în dezvoltare, S3 administrat în UE în producție. */
  S3_ENDPOINT: z.url(),
  S3_ACCESS_KEY: z.string().min(3),
  S3_SECRET_KEY: z.string().min(8),

  /** Semnează tokenurile de acces (JWT, 15 min — ADR-012). Minim 32 de caractere aleatoare. */
  JWT_SECRET: z.string().min(32),

  /** Rezumatele sesiunii cu Claude (ADR-029). Lipsă = doar rezumatele din reguli. */
  ANTHROPIC_API_KEY: z.string().min(1).optional(),

  /** Câte rezumate AI poate cere un cont pe zi (limită în Redis). */
  AI_SUMMARIES_PER_DAY: z.coerce.number().int().min(0).max(1000).default(30),

  /** E-mailurile tranzacționale (coada `mail`): `smtp://mailpit:1025` în dezvoltare, releul
   *  SMTP Brevo în producție. Lipsă = nu se trimite nimic (job-ul doar notează în log). */
  SMTP_URL: z.url({ protocol: /^smtps?$/ }).optional(),
  MAIL_FROM: z.string().min(3).default('Licurici <nu-raspunde@licurici.local>'),

  /** Adresa panoului (legăturile din e-mailuri duc acolo). */
  APP_URL: z.url().default('http://localhost:8080'),

  /** Parola pentru Bull Board (doar dezvoltare, port 3001; utilizator `admin`). */
  BULLBOARD_PASSWORD: z.string().min(8).optional(),

  /** Câte job-uri procesează un worker în paralel, pe coadă. */
  WORKER_CONCURRENCY: z.coerce.number().int().min(1).max(64).default(4),
});

export type Env = z.infer<typeof envSchema>;

export class EnvValidationError extends Error {}

export function loadEnv(source: Record<string, string | undefined> = process.env): Env {
  const result = envSchema.safeParse(source);
  if (!result.success) {
    const details = result.error.issues.map((i) => `  - ${i.path.join('.')}: ${i.message}`).join('\n');
    throw new EnvValidationError(`Configurație invalidă:\n${details}`);
  }
  return result.data;
}

/** Token de injecție pentru configurație. */
export const ENV = Symbol('ENV');

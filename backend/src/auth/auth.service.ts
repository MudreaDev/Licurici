import { createHash } from 'node:crypto';

import { z } from 'zod';

import { ConflictError, RateLimitedError, UnauthorizedError } from '../common/errors';

import { DUMMY_HASH, hashPassword, verifyPassword } from './passwords';
import { Role, TokenPair, TokenService } from './tokens';

export const credentialsSchema = z
  .object({
    // Normalizat înainte de validare: „ Ana@Example.MD ” și „ana@example.md” sunt același cont.
    email: z.preprocess((v) => (typeof v === 'string' ? v.trim().toLowerCase() : v), z.email().max(254)),
    password: z.string().min(10).max(200),
  })
  .strict();

export const registerSchema = credentialsSchema
  .extend({
    // Contul de copil nu există (ADR-012); adminii nu se înregistrează singuri.
    role: z.enum(['PARENT', 'THERAPIST']).default('PARENT'),
  })
  .strict();

/** Ce din Prisma folosește serviciul (ușor de înlocuit în teste). */
export interface UserRepo {
  findByEmail(email: string): Promise<{ id: string; role: Role; passwordHash: string | null } | null>;
  create(data: { email: string; passwordHash: string; role: Role }): Promise<{ id: string; role: Role }>;
  /** Doar conturile active (nemarcate șterse). */
  findById(id: string): Promise<{ id: string; role: Role; passwordHash: string | null } | null>;
}

/** Contorul încercărilor greșite (Redis; în teste, memorie). */
export interface LoginAttempts {
  get(key: string): Promise<string | null>;
  incr(key: string): Promise<number>;
  expire(key: string, seconds: number): Promise<number>;
  del(key: string): Promise<number>;
}

/** După atâtea parole greșite la rând, contul e blocat temporar (DPIA: forța brută). */
export const MAX_FAILED_LOGINS = 5;
export const LOCKOUT_SECONDS = 15 * 60;

export class AuthService {
  constructor(
    private readonly users: UserRepo,
    private readonly tokens: TokenService,
    private readonly attempts?: LoginAttempts,
  ) {}

  /** Cheia contorului: hash-ul e-mailului (în Redis nu stă e-mailul în clar). */
  private static attemptsKey(email: string): string {
    return `login-fail:${createHash('sha256').update(email).digest('hex')}`;
  }

  async register(body: z.infer<typeof registerSchema>): Promise<TokenPair> {
    if (await this.users.findByEmail(body.email)) {
      throw new ConflictError('Există deja un cont cu acest e-mail.');
    }
    const user = await this.users.create({
      email: body.email,
      passwordHash: await hashPassword(body.password),
      role: body.role,
    });
    return this.tokens.issue(user);
  }

  async login(body: z.infer<typeof credentialsSchema>): Promise<TokenPair> {
    const key = AuthService.attemptsKey(body.email);
    // Blocarea se aplică și e-mailurilor fără cont: răspunsul nu dezvăluie cine e înscris.
    if (this.attempts && Number((await this.attempts.get(key)) ?? 0) >= MAX_FAILED_LOGINS) {
      throw new RateLimitedError('Prea multe încercări. Încearcă din nou peste 15 minute.');
    }
    const user = await this.users.findByEmail(body.email);
    // Verificăm și când contul nu există, ca durata să nu dezvăluie ce e-mailuri sunt înscrise.
    const ok = await verifyPassword(user?.passwordHash ?? DUMMY_HASH, body.password);
    if (!user || !user.passwordHash || !ok) {
      if (this.attempts) {
        const n = await this.attempts.incr(key);
        if (n === 1) await this.attempts.expire(key, LOCKOUT_SECONDS);
      }
      throw new UnauthorizedError('E-mail sau parolă greșită.');
    }
    await this.attempts?.del(key);
    return this.tokens.issue(user);
  }

  /** Un cont șters nu-și mai poate reînnoi sesiunea, chiar dacă refresh tokenul era valid. */
  async refresh(refreshToken: string): Promise<TokenPair> {
    const pair = await this.tokens.rotate(refreshToken);
    const { id } = this.tokens.verifyAccess(pair.accessToken);
    if (!(await this.users.findById(id))) {
      await this.tokens.revoke(pair.refreshToken);
      throw new UnauthorizedError('Contul nu mai există.');
    }
    return pair;
  }

  /** Parola contului, cerută din nou înainte de acțiuni ireversibile (ștergerea contului). */
  async confirmPassword(userId: string, password: string): Promise<boolean> {
    const user = await this.users.findById(userId);
    const ok = await verifyPassword(user?.passwordHash ?? DUMMY_HASH, password);
    return Boolean(user?.passwordHash) && ok;
  }

  logout(refreshToken: string): Promise<void> {
    return this.tokens.revoke(refreshToken);
  }
}

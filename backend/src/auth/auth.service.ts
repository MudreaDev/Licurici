import { createHash } from 'node:crypto';

import { z } from 'zod';

import { ConflictError, RateLimitedError, TotpRequiredError, UnauthorizedError, ValidationError } from '../common/errors';
import { parseWith } from '../common/validation';

import { DUMMY_HASH, hashPassword, verifyPassword } from './passwords';
import { AuthUser, Role, TokenPair, TokenService } from './tokens';
import { newTotpSecret, otpauthUrl, verifyTotp } from './totp';

export const credentialsSchema = z
  .object({
    // Normalizat înainte de validare: „ Ana@Example.MD ” și „ana@example.md” sunt același cont.
    email: z.preprocess((v) => (typeof v === 'string' ? v.trim().toLowerCase() : v), z.email().max(254)),
    password: z.string().min(10).max(200),
  })
  .strict();

/** La autentificare poate veni și codul TOTP (doar pentru conturile cu 2FA activat). */
export const loginSchema = credentialsSchema
  .extend({ code: z.string().regex(/^\d{6}$/).optional() })
  .strict();

const codeSchema = z.object({ code: z.string().regex(/^\d{6}$/) }).strict();
const disableSchema = z.object({ password: z.string().min(1).max(200), code: z.string().regex(/^\d{6}$/) }).strict();

export const registerSchema = credentialsSchema
  .extend({
    // Contul de copil nu există (ADR-012); adminii nu se înregistrează singuri.
    role: z.enum(['PARENT', 'THERAPIST']).default('PARENT'),
  })
  .strict();

/** Ce din Prisma folosește serviciul (ușor de înlocuit în teste). */
export interface UserRow {
  id: string;
  role: Role;
  email?: string;
  passwordHash: string | null;
  /** Cheia TOTP (și înainte de activare) și data activării 2FA. */
  totpSecret?: string | null;
  totpEnabledAt?: Date | null;
  /** Când și-a confirmat adresa de e-mail (null = încă nu). */
  verifiedAt?: Date | null;
}

export interface UserRepo {
  findByEmail(email: string): Promise<UserRow | null>;
  create(data: { email: string; passwordHash: string; role: Role }): Promise<{ id: string; role: Role }>;
  /** Doar conturile active (nemarcate șterse). */
  findById(id: string): Promise<UserRow | null>;
  /** Salvează cheia TOTP și starea 2FA (null, null = dezactivat). */
  setTotp(id: string, secret: string | null, enabledAt: Date | null): Promise<void>;
  setVerified(id: string, at: Date): Promise<void>;
  setPassword(id: string, passwordHash: string): Promise<void>;
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
    private readonly now: () => Date = () => new Date(),
    /** După înregistrare (trimiterea legăturii de confirmare). O eroare aici nu strică contul. */
    private readonly onRegistered?: (userId: string) => Promise<unknown>,
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
    await this.onRegistered?.(user.id).catch(() => undefined);
    return this.tokens.issue(user);
  }

  async login(body: z.infer<typeof loginSchema>): Promise<TokenPair> {
    const key = AuthService.attemptsKey(body.email);
    // Blocarea se aplică și e-mailurilor fără cont: răspunsul nu dezvăluie cine e înscris.
    if (this.attempts && Number((await this.attempts.get(key)) ?? 0) >= MAX_FAILED_LOGINS) {
      throw new RateLimitedError('Prea multe încercări. Încearcă din nou peste 15 minute.');
    }
    const user = await this.users.findByEmail(body.email);
    // Verificăm și când contul nu există, ca durata să nu dezvăluie ce e-mailuri sunt înscrise.
    const ok = await verifyPassword(user?.passwordHash ?? DUMMY_HASH, body.password);
    const fail = async (message: string): Promise<never> => {
      if (this.attempts) {
        const n = await this.attempts.incr(key);
        if (n === 1) await this.attempts.expire(key, LOCKOUT_SECONDS);
      }
      throw new UnauthorizedError(message);
    };
    if (!user || !user.passwordHash || !ok) return fail('E-mail sau parolă greșită.');
    // Al doilea pas: codul din aplicația de autentificare (un cod greșit contează ca încercare).
    if (user.totpEnabledAt && user.totpSecret) {
      if (!body.code) throw new TotpRequiredError();
      if (!verifyTotp(user.totpSecret, body.code, this.now())) return fail('Codul nu e corect.');
    }
    await this.attempts?.del(key);
    return this.tokens.issue(user);
  }

  /** Contul: adresa și dacă e confirmată (pentru panou). */
  async account(user: AuthUser): Promise<{ email: string | null; role: Role; emailVerified: boolean }> {
    const u = await this.users.findById(user.id);
    if (!u) throw new UnauthorizedError();
    return { email: u.email ?? null, role: u.role, emailVerified: Boolean(u.verifiedAt) };
  }

  /** Starea 2FA a contului. */
  async totpStatus(user: AuthUser): Promise<{ enabled: boolean }> {
    const u = await this.users.findById(user.id);
    return { enabled: Boolean(u?.totpEnabledAt) };
  }

  /** Pasul 1: o cheie nouă (încă inactivă) + legătura pentru aplicația de autentificare. */
  async setupTotp(user: AuthUser): Promise<{ secret: string; otpauthUrl: string }> {
    const u = await this.users.findById(user.id);
    if (!u) throw new UnauthorizedError();
    if (u.totpEnabledAt) throw new ConflictError('Autentificarea în doi pași e deja activă.');
    const secret = newTotpSecret();
    await this.users.setTotp(user.id, secret, null);
    return { secret, otpauthUrl: otpauthUrl(secret, u.email ?? user.id) };
  }

  /** Pasul 2: primul cod corect activează 2FA (dovada că aplicația a primit cheia). */
  async enableTotp(user: AuthUser, body: unknown): Promise<{ enabled: true }> {
    const { code } = parseWith(codeSchema, body);
    const u = await this.users.findById(user.id);
    if (!u?.totpSecret || u.totpEnabledAt) throw new ConflictError('Pornește întâi configurarea.');
    if (!verifyTotp(u.totpSecret, code, this.now())) throw new ValidationError(['code: codul nu e corect']);
    await this.users.setTotp(user.id, u.totpSecret, this.now());
    return { enabled: true };
  }

  /** Oprirea 2FA cere și parola, și un cod valid. */
  async disableTotp(user: AuthUser, body: unknown): Promise<{ enabled: false }> {
    const { password, code } = parseWith(disableSchema, body);
    const u = await this.users.findById(user.id);
    if (!u?.totpEnabledAt || !u.totpSecret) return { enabled: false };
    const ok = await this.confirmPassword(user.id, password);
    if (!ok || !verifyTotp(u.totpSecret, code, this.now())) throw new UnauthorizedError('Parola sau codul nu sunt corecte.');
    await this.users.setTotp(user.id, null, null);
    return { enabled: false };
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

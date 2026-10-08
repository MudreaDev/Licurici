import { createHash, randomBytes } from 'node:crypto';

import { z } from 'zod';

import { RateLimitedError, ValidationError } from '../common/errors';
import { parseWith } from '../common/validation';

import { credentialsSchema, type LoginAttempts, type UserRepo } from './auth.service';
import { hashPassword } from './passwords';
import type { AuthUser, TokenService, TokenStore } from './tokens';

/** Ce fel de e-mail trimite worker-ul (coada `mail`). */
export type MailKind = 'verify-email' | 'reset-password';

/** Job-ul din coada `mail`: doar id-ul contului și tokenul; adresa o citește worker-ul din bază,
 *  ca în Redis să nu stea e-mailuri. */
export interface MailJob {
  kind: MailKind;
  userId: string;
  token: string;
}

export interface MailOutbox {
  enqueue(job: MailJob): Promise<void>;
}

export const VERIFY_TTL_SECONDS = 48 * 3600;
export const RESET_TTL_SECONDS = 3600;
/** Câte e-mailuri de un fel poate cere un cont (sau o adresă) pe oră. */
export const MAILS_PER_HOUR = 3;

const tokenSchema = z.object({ token: z.string().min(20).max(200) }).strict();
const forgotSchema = credentialsSchema.pick({ email: true }).strict();
const resetSchema = z.object({ token: z.string().min(20).max(200), password: credentialsSchema.shape.password }).strict();

/**
 * Confirmarea adresei de e-mail și resetarea parolei (README §21, Sprint 3).
 * Tokenurile sunt aleatoare (256 de biți), de unică folosință, cu termen; în Redis stă doar
 * hash-ul lor. Cererile de resetare răspund la fel și pentru adresele fără cont.
 */
export class EmailFlows {
  constructor(
    private readonly users: UserRepo,
    private readonly store: TokenStore,
    private readonly tokens: TokenService,
    private readonly outbox: MailOutbox,
    private readonly limits?: LoginAttempts,
    private readonly now: () => Date = () => new Date(),
  ) {}

  private static key(kind: MailKind, token: string): string {
    return `${kind}:${createHash('sha256').update(token).digest('hex')}`;
  }

  /** Limita pe oră (fără limitator — în teste — nu limităm). */
  private async allow(scope: string): Promise<boolean> {
    if (!this.limits) return true;
    const key = `mail-limit:${createHash('sha256').update(scope).digest('hex')}`;
    const n = await this.limits.incr(key);
    if (n === 1) await this.limits.expire(key, 3600);
    return n <= MAILS_PER_HOUR;
  }

  private async send(kind: MailKind, userId: string, ttl: number): Promise<void> {
    const token = randomBytes(32).toString('base64url');
    await this.store.set(EmailFlows.key(kind, token), userId, 'EX', ttl);
    await this.outbox.enqueue({ kind, userId, token });
  }

  /** Trimite (din nou) legătura de confirmare. La înregistrare se cheamă singură. */
  async requestVerification(user: Pick<AuthUser, 'id'>): Promise<{ sent: boolean }> {
    const u = await this.users.findById(user.id);
    if (!u || u.verifiedAt) return { sent: false };
    if (!(await this.allow(`verify:${user.id}`))) {
      throw new RateLimitedError('Ți-am trimis deja câteva e-mailuri. Încearcă din nou peste o oră.');
    }
    await this.send('verify-email', user.id, VERIFY_TTL_SECONDS);
    return { sent: true };
  }

  async verify(body: unknown): Promise<{ verified: true }> {
    const { token } = parseWith(tokenSchema, body);
    const userId = await this.store.getdel(EmailFlows.key('verify-email', token));
    if (!userId || !(await this.users.findById(userId))) {
      throw new ValidationError(['token: legătura a expirat sau a fost deja folosită']);
    }
    await this.users.setVerified(userId, this.now());
    return { verified: true };
  }

  /** Mereu același răspuns: nu dezvăluim dacă adresa are cont. */
  async forgot(body: unknown): Promise<{ ok: true }> {
    const { email } = parseWith(forgotSchema, body);
    if (await this.allow(`reset:${email}`)) {
      const u = await this.users.findByEmail(email);
      if (u?.passwordHash) await this.send('reset-password', u.id, RESET_TTL_SECONDS);
    }
    return { ok: true };
  }

  /** Parola nouă închide toate sesiunile deschise (și pe cele ale cuiva care o aflase). */
  async reset(body: unknown): Promise<{ ok: true }> {
    const { token, password } = parseWith(resetSchema, body);
    const userId = await this.store.getdel(EmailFlows.key('reset-password', token));
    const u = userId ? await this.users.findById(userId) : null;
    if (!u) throw new ValidationError(['token: legătura a expirat sau a fost deja folosită']);
    await this.users.setPassword(u.id, await hashPassword(password));
    // Cine a primit legătura pe e-mail și-a dovedit și adresa.
    if (!u.verifiedAt) await this.users.setVerified(u.id, this.now());
    await this.tokens.revokeAll(u.id);
    return { ok: true };
  }
}

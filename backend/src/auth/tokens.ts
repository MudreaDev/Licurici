import { createHash, randomBytes } from 'node:crypto';

import jwt from 'jsonwebtoken';

import { UnauthorizedError } from '../common/errors';

/** Ce din Redis folosim (ușor de înlocuit în teste). */
export interface TokenStore {
  set(key: string, value: string, mode: 'EX', seconds: number): Promise<unknown>;
  getdel(key: string): Promise<string | null>;
  del(key: string): Promise<number>;
  get(key: string): Promise<string | null>;
}

export type Role = 'PARENT' | 'THERAPIST' | 'ADMIN';

export interface AuthUser {
  id: string;
  role: Role;
}

export interface TokenPair {
  accessToken: string;
  refreshToken: string;
  expiresIn: number;
}

export const ACCESS_TTL_SECONDS = 15 * 60;
export const REFRESH_TTL_SECONDS = 30 * 24 * 3600;
/** Generația trebuie să trăiască mai mult decât orice lanț de rotiri (fiecare rotire = încă 30 de zile). */
const GENERATION_TTL_SECONDS = 5 * 365 * 24 * 3600;

/**
 * Tokenuri (ADR-012): access JWT scurt (15 min, HS256) + refresh token opac, de unică
 * folosință, rotit la fiecare reîmprospătare. În Redis se ține doar hash-ul refresh tokenului →
 * revocare imediată, iar o scurgere a Redis nu dă tokenuri utilizabile.
 */
export class TokenService {
  constructor(
    private readonly secret: string,
    private readonly store: TokenStore,
  ) {}

  private static key(refreshToken: string): string {
    return `refresh:${createHash('sha256').update(refreshToken).digest('hex')}`;
  }

  async issue(user: AuthUser): Promise<TokenPair> {
    const accessToken = jwt.sign({ role: user.role }, this.secret, {
      algorithm: 'HS256',
      subject: user.id,
      expiresIn: ACCESS_TTL_SECONDS,
    });
    const refreshToken = randomBytes(32).toString('base64url');
    await this.store.set(
      TokenService.key(refreshToken),
      JSON.stringify({ id: user.id, role: user.role, gen: await this.generation(user.id) }),
      'EX',
      REFRESH_TTL_SECONDS,
    );
    return { accessToken, refreshToken, expiresIn: ACCESS_TTL_SECONDS };
  }

  /** Schimbă un refresh token pe o pereche nouă. GETDEL e atomic: un token deja folosit
   *  (de exemplu furat) nu mai merge a doua oară. */
  async rotate(refreshToken: string): Promise<TokenPair> {
    const raw = await this.store.getdel(TokenService.key(refreshToken));
    if (!raw) throw new UnauthorizedError('Sesiune expirată. Autentifică-te din nou.');
    const { id, role, gen } = JSON.parse(raw) as AuthUser & { gen?: string };
    // Sesiunile deschise înainte de o schimbare a parolei nu se mai reînnoiesc.
    if ((gen ?? '') !== (await this.generation(id))) {
      throw new UnauthorizedError('Parola s-a schimbat. Autentifică-te din nou.');
    }
    return this.issue({ id, role });
  }

  private static genKey(userId: string): string {
    return `refresh-gen:${userId}`;
  }

  /** „Generația” sesiunilor contului: se schimbă la `revokeAll`; lipsă = sesiunile inițiale. */
  private async generation(userId: string): Promise<string> {
    return (await this.store.get(TokenService.genKey(userId))) ?? '';
  }

  /** Închide toate sesiunile contului (după resetarea parolei): refresh tokenurile emise până
   *  acum nu se mai pot roti. Tokenurile de acces expiră singure în cel mult 15 minute. */
  async revokeAll(userId: string): Promise<void> {
    await this.store.set(TokenService.genKey(userId), randomBytes(8).toString('hex'), 'EX', GENERATION_TTL_SECONDS);
  }

  async revoke(refreshToken: string): Promise<void> {
    await this.store.del(TokenService.key(refreshToken));
  }

  verifyAccess(token: string): AuthUser {
    try {
      const p = jwt.verify(token, this.secret, { algorithms: ['HS256'] }) as jwt.JwtPayload;
      if (typeof p.sub !== 'string' || !['PARENT', 'THERAPIST', 'ADMIN'].includes(p.role)) throw new Error();
      return { id: p.sub, role: p.role as Role };
    } catch {
      throw new UnauthorizedError();
    }
  }
}

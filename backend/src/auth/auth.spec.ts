import { ConflictError, RateLimitedError, TotpRequiredError, UnauthorizedError, ValidationError } from '../common/errors';
import { AuthService, LoginAttempts, MAX_FAILED_LOGINS, registerSchema, UserRepo } from './auth.service';
import { EmailFlows, MAILS_PER_HOUR, type MailJob } from './email-flows';
import { hashPassword, verifyPassword } from './passwords';
import { Role, TokenService, TokenStore } from './tokens';
import { base32Decode, totpCode } from './totp';

export class MemoryStore implements TokenStore {
  readonly data = new Map<string, string>();
  async set(key: string, value: string) {
    this.data.set(key, value);
    return 'OK';
  }
  async getdel(key: string) {
    const v = this.data.get(key) ?? null;
    this.data.delete(key);
    return v;
  }
  async del(key: string) {
    return this.data.delete(key) ? 1 : 0;
  }
  async get(key: string) {
    return this.data.get(key) ?? null;
  }
}

export class MemoryUsers implements UserRepo {
  readonly rows: {
    id: string;
    email: string;
    role: Role;
    passwordHash: string;
    totpSecret?: string | null;
    totpEnabledAt?: Date | null;
    verifiedAt?: Date | null;
  }[] = [];
  async findByEmail(email: string) {
    return this.rows.find((r) => r.email === email) ?? null;
  }
  async create(data: { email: string; passwordHash: string; role: Role }) {
    const row = { id: `u${this.rows.length + 1}`, ...data };
    this.rows.push(row);
    return row;
  }
  async findById(id: string) {
    return this.rows.find((r) => r.id === id) ?? null;
  }
  async setTotp(id: string, secret: string | null, enabledAt: Date | null) {
    const r = this.rows.find((x) => x.id === id)!;
    r.totpSecret = secret;
    r.totpEnabledAt = enabledAt;
  }
  async setVerified(id: string, at: Date) {
    this.rows.find((x) => x.id === id)!.verifiedAt = at;
  }
  async setPassword(id: string, passwordHash: string) {
    this.rows.find((x) => x.id === id)!.passwordHash = passwordHash;
  }
}

function setup() {
  const store = new MemoryStore();
  const users = new MemoryUsers();
  const tokens = new TokenService('x'.repeat(32), store);
  return { store, users, tokens, auth: new AuthService(users, tokens) };
}

const creds = registerSchema.parse({ email: ' Ana@Example.MD ', password: 'parola-lunga-1' });

describe('parole (Argon2id)', () => {
  it('hash-ul e Argon2id și se verifică doar cu parola corectă', async () => {
    const h = await hashPassword('parola-lunga-1');
    expect(h.startsWith('$argon2id$')).toBe(true);
    expect(await verifyPassword(h, 'parola-lunga-1')).toBe(true);
    expect(await verifyPassword(h, 'alta-parola')).toBe(false);
    expect(await verifyPassword('nu-e-hash', 'x')).toBe(false);
  });
});

describe('AuthService', () => {
  it('înregistrare: e-mail normalizat, parolă doar ca hash, rol implicit PARENT', async () => {
    const { auth, users, tokens } = setup();
    const pair = await auth.register(creds);
    expect(users.rows[0].email).toBe('ana@example.md');
    expect(users.rows[0].passwordHash).not.toContain('parola');
    expect(tokens.verifyAccess(pair.accessToken)).toEqual({ id: 'u1', role: 'PARENT' });
    await expect(auth.register(creds)).rejects.toBeInstanceOf(ConflictError);
  });

  it('nu se poate crea cont de copil sau de admin', () => {
    expect(() => registerSchema.parse({ ...creds, password: 'parola-lunga-1', role: 'ADMIN' })).toThrow();
    expect(() => registerSchema.parse({ email: 'a@b.md', password: 'scurta' })).toThrow();
  });

  it('autentificare: parolă greșită și cont inexistent dau același răspuns', async () => {
    const { auth } = setup();
    await auth.register(creds);
    await expect(auth.login({ email: 'ana@example.md', password: 'parola-gresita' })).rejects.toBeInstanceOf(
      UnauthorizedError,
    );
    await expect(auth.login({ email: 'nimeni@example.md', password: 'parola-lunga-1' })).rejects.toThrow(
      'E-mail sau parolă greșită.',
    );
    const pair = await auth.login({ email: 'ana@example.md', password: 'parola-lunga-1' });
    expect(pair.expiresIn).toBe(900);
  });

  it('refresh token: rotit, de unică folosință, revocabil; în Redis doar hash-ul', async () => {
    const { auth, store } = setup();
    const first = await auth.register(creds);
    expect([...store.data.keys()].some((k) => k.includes(first.refreshToken))).toBe(false);

    const second = await auth.refresh(first.refreshToken);
    expect(second.refreshToken).not.toBe(first.refreshToken);
    await expect(auth.refresh(first.refreshToken)).rejects.toBeInstanceOf(UnauthorizedError);

    await auth.logout(second.refreshToken);
    await expect(auth.refresh(second.refreshToken)).rejects.toBeInstanceOf(UnauthorizedError);
  });

  it('un access token falsificat e respins', async () => {
    const { tokens } = setup();
    const other = new TokenService('y'.repeat(32), new MemoryStore());
    const forged = (await other.issue({ id: 'u1', role: 'ADMIN' })).accessToken;
    expect(() => tokens.verifyAccess(forged)).toThrow(UnauthorizedError);
  });

  it('cont șters: sesiunea nu se mai reînnoiește; parola se verifică pentru acțiuni ireversibile', async () => {
    const { auth, users } = setup();
    const pair = await auth.register(creds);
    expect(await auth.confirmPassword('u1', 'parola-lunga-1')).toBe(true);
    expect(await auth.confirmPassword('u1', 'alta-parola-x')).toBe(false);
    expect(await auth.confirmPassword('nimeni', 'parola-lunga-1')).toBe(false);
    users.rows.splice(0, 1); // contul a fost marcat șters (findById nu-l mai găsește)
    await expect(auth.refresh(pair.refreshToken)).rejects.toBeInstanceOf(UnauthorizedError);
  });

  it('după 5 parole greșite contul e blocat temporar (și cu parola bună); reușita resetează contorul', async () => {
    const counts = new Map<string, number>();
    const attempts: LoginAttempts = {
      get: async (k) => (counts.has(k) ? String(counts.get(k)) : null),
      incr: async (k) => {
        counts.set(k, (counts.get(k) ?? 0) + 1);
        return counts.get(k)!;
      },
      expire: async () => 1,
      del: async (k) => (counts.delete(k) ? 1 : 0),
    };
    const store = new MemoryStore();
    const users = new MemoryUsers();
    const auth = new AuthService(users, new TokenService('x'.repeat(32), store), attempts);
    await auth.register(creds);
    const wrong = { ...creds, password: 'gresita-1234' };

    // Câteva greșeli, apoi reușita: contorul se resetează.
    await expect(auth.login(wrong)).rejects.toBeInstanceOf(UnauthorizedError);
    await expect(auth.login(creds)).resolves.toBeTruthy();
    expect(counts.size).toBe(0);

    for (let i = 0; i < MAX_FAILED_LOGINS; i++) {
      await expect(auth.login(wrong)).rejects.toBeInstanceOf(UnauthorizedError);
    }
    await expect(auth.login(creds)).rejects.toBeInstanceOf(RateLimitedError);
    // Cheia e hash-ul e-mailului, nu e-mailul.
    expect([...counts.keys()].join()).not.toContain('example');
  });

  it('2FA: configurare → activare cu un cod corect → la login se cere codul; oprirea cere parola și codul', async () => {
    const now = new Date('2026-10-08T12:00:00Z');
    const users = new MemoryUsers();
    const auth = new AuthService(users, new TokenService('x'.repeat(32), new MemoryStore()), undefined, () => now);
    await auth.register(creds);
    const me = { id: 'u1', role: 'PARENT' as const };
    expect(await auth.totpStatus(me)).toEqual({ enabled: false });

    const { secret, otpauthUrl } = await auth.setupTotp(me);
    expect(otpauthUrl).toContain(`secret=${secret}`);
    expect(otpauthUrl).toContain('ana%40example.md');
    const code = totpCode(base32Decode(secret), now);
    // Înainte de activare, login-ul merge fără cod.
    await expect(auth.login(creds)).resolves.toBeTruthy();
    await expect(auth.enableTotp(me, { code: '000000' === code ? '111111' : '000000' })).rejects.toBeInstanceOf(
      ValidationError,
    );
    expect(await auth.enableTotp(me, { code })).toEqual({ enabled: true });
    expect(await auth.totpStatus(me)).toEqual({ enabled: true });
    await expect(auth.setupTotp(me)).rejects.toBeInstanceOf(ConflictError);

    // Parola bună fără cod → se cere codul; cod greșit → refuzat; cod bun → intră.
    await expect(auth.login(creds)).rejects.toBeInstanceOf(TotpRequiredError);
    await expect(auth.login({ ...creds, code: code === '123456' ? '654321' : '123456' })).rejects.toBeInstanceOf(
      UnauthorizedError,
    );
    await expect(auth.login({ ...creds, code })).resolves.toBeTruthy();

    await expect(auth.disableTotp(me, { password: 'alta-parola', code })).rejects.toBeInstanceOf(UnauthorizedError);
    expect(await auth.disableTotp(me, { password: 'parola-lunga-1', code })).toEqual({ enabled: false });
    await expect(auth.login(creds)).resolves.toBeTruthy();
  });
});

type TokenMail = Extract<MailJob, { token: string }>;

describe('EmailFlows (confirmarea adresei, parola nouă)', () => {
  function flows() {
    const base = setup();
    const sent: TokenMail[] = [];
    const mail = new EmailFlows(base.users, base.store, base.tokens, { enqueue: async (j) => void sent.push(j as TokenMail) });
    const auth = new AuthService(base.users, base.tokens, undefined, undefined, (id) => mail.requestVerification({ id }));
    return { ...base, sent, mail, auth };
  }

  it('la înregistrare pleacă legătura; tokenul confirmă adresa o singură dată', async () => {
    const { auth, mail, sent, users, store } = flows();
    await auth.register(creds);
    expect(sent).toHaveLength(1);
    expect(sent[0]).toMatchObject({ kind: 'verify-email', userId: 'u1' });
    // În Redis stă doar hash-ul tokenului.
    expect([...store.data.keys()].some((k) => k.includes(sent[0].token))).toBe(false);
    expect((await auth.account({ id: 'u1', role: 'PARENT' })).emailVerified).toBe(false);
    await mail.verify({ token: sent[0].token });
    expect(users.rows[0].verifiedAt).toBeInstanceOf(Date);
    expect((await auth.account({ id: 'u1', role: 'PARENT' })).emailVerified).toBe(true);
    await expect(mail.verify({ token: sent[0].token })).rejects.toBeInstanceOf(ValidationError);
    // Adresa confirmată nu mai primește legături.
    expect(await mail.requestVerification({ id: 'u1' })).toEqual({ sent: false });
  });

  it('„am uitat parola”: același răspuns pentru orice adresă; parola nouă închide sesiunile vechi', async () => {
    const { auth, mail, sent, tokens } = flows();
    const old = await auth.register(creds);
    sent.length = 0;
    expect(await mail.forgot({ email: 'nimeni@example.md' })).toEqual({ ok: true });
    expect(sent).toHaveLength(0);
    expect(await mail.forgot({ email: 'ANA@example.md' })).toEqual({ ok: true });
    expect(sent).toMatchObject([{ kind: 'reset-password', userId: 'u1' }]);
    await expect(mail.reset({ token: sent[0].token, password: 'scurta' })).rejects.toBeInstanceOf(ValidationError);
    // Tokenul de confirmare nu merge pe drumul parolei (și invers).
    await expect(mail.verify({ token: sent[0].token })).rejects.toBeInstanceOf(ValidationError);
    await mail.reset({ token: sent[0].token, password: 'parola-noua-22' });
    await expect(mail.reset({ token: sent[0].token, password: 'parola-noua-33' })).rejects.toBeInstanceOf(ValidationError);
    await expect(tokens.rotate(old.refreshToken)).rejects.toBeInstanceOf(UnauthorizedError);
    await expect(auth.login({ email: 'ana@example.md', password: 'parola-lunga-1' })).rejects.toBeInstanceOf(UnauthorizedError);
    const fresh = await auth.login({ email: 'ana@example.md', password: 'parola-noua-22' });
    // Sesiunile de după schimbare se rotesc normal.
    await expect(tokens.rotate(fresh.refreshToken)).resolves.toHaveProperty('accessToken');
    // Legătura venită pe e-mail dovedește și adresa.
    expect((await auth.account({ id: 'u1', role: 'PARENT' })).emailVerified).toBe(true);
  });

  it('limita: cel mult câteva e-mailuri pe oră pentru același cont', async () => {
    const base = setup();
    const counts = new Map<string, number>();
    const limits: LoginAttempts = {
      get: async (k) => String(counts.get(k) ?? 0),
      incr: async (k) => {
        counts.set(k, (counts.get(k) ?? 0) + 1);
        return counts.get(k)!;
      },
      expire: async () => 1,
      del: async (k) => (counts.delete(k) ? 1 : 0),
    };
    const sent: TokenMail[] = [];
    const mail = new EmailFlows(base.users, base.store, base.tokens, { enqueue: async (j) => void sent.push(j as TokenMail) }, limits);
    await base.auth.register(creds);
    for (let i = 0; i < MAILS_PER_HOUR; i++) await mail.requestVerification({ id: 'u1' });
    await expect(mail.requestVerification({ id: 'u1' })).rejects.toBeInstanceOf(RateLimitedError);
    for (let i = 0; i < MAILS_PER_HOUR + 2; i++) await mail.forgot({ email: 'ana@example.md' });
    expect(sent.filter((j) => j.kind === 'reset-password')).toHaveLength(MAILS_PER_HOUR);
  });
});

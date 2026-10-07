import { ConflictError, UnauthorizedError } from '../common/errors';
import { AuthService, registerSchema, UserRepo } from './auth.service';
import { hashPassword, verifyPassword } from './passwords';
import { Role, TokenService, TokenStore } from './tokens';

class MemoryStore implements TokenStore {
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
}

class MemoryUsers implements UserRepo {
  readonly rows: { id: string; email: string; role: Role; passwordHash: string }[] = [];
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
});

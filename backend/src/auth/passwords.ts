import { hash, verify } from '@node-rs/argon2';

/**
 * Parolele adulților: Argon2id (ADR-012), parametrii minimi recomandați de OWASP
 * (19 MiB memorie, 2 iterații, paralelism 1). Algoritmul implicit al bibliotecii e Argon2id.
 */
const PARAMS = { memoryCost: 19456, timeCost: 2, parallelism: 1 } as const;

export const hashPassword = (password: string): Promise<string> => hash(password, PARAMS);

export const verifyPassword = (passwordHash: string, password: string): Promise<boolean> =>
  verify(passwordHash, password).catch(() => false);

/** Hash fix folosit când e-mailul nu există, ca timpul de răspuns să nu-l dezvăluie. */
export const DUMMY_HASH =
  '$argon2id$v=19$m=19456,t=2,p=1$c29tZXNhbHRzb21lc2FsdA$5Wf9JnN0TzKcnB0vQx4mE5dS1k3YzQGQnVq3m7X7x0M';

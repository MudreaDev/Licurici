/**
 * Erorile de domeniu: serviciile (auth, acces, sincronizare, rezumate) sunt TypeScript simplu,
 * fără Nest, ușor de testat; `DomainErrorFilter` le traduce în coduri HTTP.
 */
export class DomainError extends Error {
  constructor(
    message: string,
    readonly status: number,
    readonly details?: string[],
  ) {
    super(message);
    this.name = new.target.name;
  }
}

export class ValidationError extends DomainError {
  constructor(details: string[]) {
    super('Date invalide.', 400, details);
  }
}
export class UnauthorizedError extends DomainError {
  constructor(message = 'Neautentificat.') {
    super(message, 401);
  }
}
/** Parola e corectă, dar contul cere și codul din aplicația de autentificare (2FA). */
export class TotpRequiredError extends DomainError {
  constructor() {
    super('Introdu codul din aplicația de autentificare.', 401, ['totp']);
  }
}
export class ForbiddenError extends DomainError {
  constructor(message = 'Acces interzis.') {
    super(message, 403);
  }
}
/** Folosită și pentru „nu ai acces”, ca să nu dezvăluim existența resursei. */
export class NotFoundError extends DomainError {
  constructor(message = 'Nu există.') {
    super(message, 404);
  }
}
export class ConflictError extends DomainError {
  constructor(message: string) {
    super(message, 409);
  }
}
export class RateLimitedError extends DomainError {
  constructor(message: string) {
    super(message, 429);
  }
}
export class UnavailableError extends DomainError {
  constructor(message: string) {
    super(message, 503);
  }
}

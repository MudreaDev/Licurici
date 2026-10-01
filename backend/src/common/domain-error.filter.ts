import { ArgumentsHost, Catch, ExceptionFilter, HttpException, Logger } from '@nestjs/common';

import { DomainError } from './errors';

/** Erori de infrastructură (bază de date, Redis) — temporare, deci 503, nu 500. */
export function isInfrastructureError(error: unknown): boolean {
  if (!(error instanceof Error)) return false;
  const code = (error as { code?: unknown }).code;
  return (
    ['ECONNREFUSED', 'ECONNRESET', 'ETIMEDOUT', 'ENOTFOUND', 'EAI_AGAIN', 'P1001', 'P1002', 'P1017'].includes(
      String(code),
    ) ||
    error.name === 'MaxRetriesPerRequestError' ||
    /Connection is closed|Stream isn't writeable|enableOfflineQueue/.test(error.message)
  );
}

/** Corpul răspunsului de eroare: `{ statusCode, message, details? }`, fără detalii interne. */
export function errorResponse(error: unknown): { statusCode: number; message: string; details?: string[] } {
  if (error instanceof DomainError) {
    return { statusCode: error.status, message: error.message, ...(error.details ? { details: error.details } : {}) };
  }
  if (isInfrastructureError(error)) {
    return { statusCode: 503, message: 'Serviciul e temporar indisponibil. Încearcă din nou în câteva momente.' };
  }
  return { statusCode: 500, message: 'Eroare internă.' };
}

/** Traduce erorile în răspunsuri HTTP; erorile HTTP ale Nest (ex. ParseUUIDPipe) rămân ale lui. */
@Catch()
export class DomainErrorFilter implements ExceptionFilter {
  private readonly log = new Logger('Errors');

  catch(error: unknown, host: ArgumentsHost): void {
    const res = host.switchToHttp().getResponse<{
      status(code: number): { json(body: unknown): void };
    }>();
    if (error instanceof HttpException) {
      const body = error.getResponse();
      res.status(error.getStatus()).json(typeof body === 'string' ? { statusCode: error.getStatus(), message: body } : body);
      return;
    }
    const body = errorResponse(error);
    // Fără mesajul brut în log la erorile de domeniu (pot conține date de intrare); doar tipul.
    if (body.statusCode >= 500) this.log.warn(`${body.statusCode} ${error instanceof Error ? error.name : 'unknown'}`);
    res.status(body.statusCode).json(body);
  }
}

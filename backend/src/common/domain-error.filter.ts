import { ArgumentsHost, Catch, ExceptionFilter } from '@nestjs/common';

import { DomainError } from './errors';

/** Traduce erorile de domeniu în răspunsuri HTTP: `{ statusCode, message, details? }`. */
@Catch(DomainError)
export class DomainErrorFilter implements ExceptionFilter {
  catch(error: DomainError, host: ArgumentsHost): void {
    const res = host.switchToHttp().getResponse<{
      status(code: number): { json(body: unknown): void };
    }>();
    res.status(error.status).json({
      statusCode: error.status,
      message: error.message,
      ...(error.details ? { details: error.details } : {}),
    });
  }
}

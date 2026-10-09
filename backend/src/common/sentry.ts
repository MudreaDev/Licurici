import * as Sentry from '@sentry/node';
import type { ErrorEvent } from '@sentry/node';

/**
 * Erorile neașteptate în Sentry (ADR-018) — doar dacă e setat `SENTRY_DSN` (proiect în regiunea
 * UE). Fără date personale: fără cererea HTTP, fără utilizator, fără breadcrumbs, iar adresele
 * de e-mail din mesaje se ascund (README §13.4). Fără tracing.
 */
export function initSentry(dsn: string | undefined, environment: string, release?: string): boolean {
  if (!dsn) return false;
  Sentry.init({
    dsn,
    environment,
    release,
    tracesSampleRate: 0,
    maxBreadcrumbs: 0,
    beforeSend: scrubEvent,
  });
  return true;
}

const EMAIL = /[^\s@"'`<>()]+@[^\s@"'`<>()]+\.[a-z]{2,}/gi;

export function scrubText(text: string): string {
  return text.replace(EMAIL, '[e-mail]');
}

/** Ce rămâne dintr-un eveniment: tipul erorii, mesajul curățat, stiva, mediul. */
export function scrubEvent(event: ErrorEvent): ErrorEvent {
  delete event.request;
  delete event.user;
  delete event.breadcrumbs;
  delete event.extra;
  if (event.message) event.message = scrubText(event.message);
  for (const ex of event.exception?.values ?? []) {
    if (ex.value) ex.value = scrubText(ex.value);
    for (const frame of ex.stacktrace?.frames ?? []) delete frame.vars;
  }
  return event;
}

/** Trimite o eroare neașteptată (no-op fără DSN). */
export function captureError(error: unknown): void {
  if (Sentry.getClient()) Sentry.captureException(error);
}

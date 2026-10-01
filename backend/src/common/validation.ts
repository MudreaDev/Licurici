import type { z } from 'zod';

import { ValidationError } from './errors';

/** Validează intrarea cu zod; mesajele numesc câmpul, nu valoarea (fără date personale în loguri). */
export function parseWith<T extends z.ZodType>(schema: T, input: unknown): z.infer<T> {
  const r = schema.safeParse(input);
  if (!r.success) {
    throw new ValidationError(r.error.issues.map((i) => `${i.path.join('.') || 'corp'}: ${i.message}`));
  }
  return r.data;
}

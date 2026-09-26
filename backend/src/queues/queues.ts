import type { DefaultJobOptions } from 'bullmq';

import type { Env } from '../config/env';

/** Cozile BullMQ (ADR-09). Fiecare job TREBUIE să fie idempotent (livrare at-least-once). */
export const Queues = {
  stats: 'stats',
  mail: 'mail',
  reports: 'reports',
  gdpr: 'gdpr',
  content: 'content',
  push: 'push',
} as const;

export type QueueName = (typeof Queues)[keyof typeof Queues];

/** Retry cu backoff exponențial (1s, 2s, 4s, 8s, 16s); job-urile reușite se curăță. */
export const defaultJobOptions: DefaultJobOptions = {
  attempts: 5,
  backoff: { type: 'exponential', delay: 1000 },
  removeOnComplete: { count: 1000, age: 24 * 3600 },
  removeOnFail: { age: 7 * 24 * 3600 },
};

/** Conexiunea BullMQ: aceeași instanță Redis, fără limită de retry (cerința BullMQ pentru worker). */
export function bullConnection(env: Env) {
  const url = new URL(env.REDIS_URL);
  return {
    host: url.hostname,
    port: Number(url.port || 6379),
    username: url.username || undefined,
    password: url.password ? decodeURIComponent(url.password) : undefined,
    tls: url.protocol === 'rediss:' ? {} : undefined,
    maxRetriesPerRequest: null,
  };
}

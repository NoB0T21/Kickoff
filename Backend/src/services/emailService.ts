import { Queue } from 'bullmq';
import { bullConnection } from '../config/redis.js';

export const emailQueue = new Queue('email-queue', {
  connection: bullConnection,
});

export interface EmailJobData {
  to: string;
  subject: string;
  text: string;
  html?: string;
}

/**
 * Enqueue an email to be sent asynchronously by the worker.
 */
export async function queueEmail(data: EmailJobData) {
  await emailQueue.add('send-email', data, {
    attempts: 3,
    backoff: {
      type: 'exponential',
      delay: 5000,
    },
  });
}

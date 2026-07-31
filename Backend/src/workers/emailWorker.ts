import { Worker } from 'bullmq';
import nodemailer from 'nodemailer';
import { bullConnection } from '../config/redis.js';
import { env } from '../config/env.js';

// Setup SMTP Transporter
const transporter = nodemailer.createTransport({
  // host: env.SMTP_HOST,
  // port: env.SMTP_PORT,
  // secure: env.SMTP_SECURE,
  service: 'gmail',
  auth: {
    user: env.SMTP_USER,
    pass: env.SMTP_PASS,
  },
});

// Create Worker
export const emailWorker = new Worker(
  'email-queue',
  async (job) => {
    const { to, subject, text, html } = job.data;
    
    console.log(`[EmailWorker] Processing job ${job.id} to ${to}`);
    
    try {
      const info = await transporter.sendMail({
        from: env.SMTP_FROM,
        to,
        subject,
        text,
        html,
      });
      console.log(`[EmailWorker] Email sent to ${to}. MessageId: ${info.messageId}`);
    } catch (error) {
      console.error(`[EmailWorker] Failed to send email to ${to}:`, error);
      throw error; // Re-throw to trigger BullMQ retry logic
    }
  },
  {
    connection: bullConnection,
  }
);

emailWorker.on('failed', (job, err) => {
  console.error(`[EmailWorker] Job ${job?.id} failed with error: ${err.message}`);
});

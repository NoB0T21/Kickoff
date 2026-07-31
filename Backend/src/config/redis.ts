import { Redis } from 'ioredis';
import dotenv from 'dotenv';

dotenv.config();

const redisUrl = process.env.REDIS_URL || 'redis://127.0.0.1:6379';

// ioredis instance for BullMQ (maxRetriesPerRequest must be null)
export const bullConnection = new Redis(redisUrl, {
  maxRetriesPerRequest: null,
});
export type RedisConnection = typeof bullConnection;

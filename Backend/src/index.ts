import Fastify, { FastifyInstance } from 'fastify';
import cors from '@fastify/cors';
import jwt from '@fastify/jwt';
import rateLimit from '@fastify/rate-limit';
import { env } from './config/env.js';
import { pool } from './config/db.js';
import { registerErrorHandler } from './middleware/errorHandler.js';
import { registerRoutes } from './routes.js';
import './workers/emailWorker.js';

const server: FastifyInstance = Fastify({
  logger: true,
});

// ── Plugins ──

// CORS
await server.register(cors, {
  origin: '*', // Adjust to specific origins in production
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
});

// JWT — local signature verification using Supabase JWT secret
await server.register(jwt, {
  secret: env.SUPABASE_JWT_SECRET,
});

// Rate limiting — stricter on auth endpoints
await server.register(rateLimit, {
  max: 100,
  timeWindow: '1 minute',
  keyGenerator: (request) => request.ip,
});

// ── Error Handler ──
registerErrorHandler(server);

// ── Type Augmentation ──
declare module 'fastify' {
  interface FastifyRequest {
    userId: string;
  }
}

// ── Health Check ──
server.get('/health', async (request, reply) => {
  try {
    const client = await pool.connect();
    const result = await client.query('SELECT NOW()');
    client.release();
    return {
      status: 'healthy',
      database: 'connected',
      timestamp: result.rows[0].now,
    };
  } catch (error: any) {
    server.log.error(error);
    reply.status(500).send({
      status: 'unhealthy',
      database: 'disconnected',
      error: error.message,
    });
  }
});

// ── Routes ──
await registerRoutes(server);

// ── Start Server ──
server.listen({ port: env.PORT, host: env.HOST }, (err, address) => {
  if (err) {
    server.log.error(err);
    process.exit(1);
  }
  server.log.info(`Server listening on ${address}`);
});

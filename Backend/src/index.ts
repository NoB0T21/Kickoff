import Fastify, { FastifyInstance, FastifyReply, FastifyRequest } from 'fastify';
import cors from '@fastify/cors';
import jwt from '@fastify/jwt';
import dotenv from 'dotenv';
import { pool } from './config/db.js';

dotenv.config();

const server: FastifyInstance = Fastify({
  logger: true,
});

// Configure CORS
await server.register(cors, {
  origin: '*', // Adjust to specific origins in production
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
});

// Register JWT Plugin
const jwtSecret = process.env.SUPABASE_JWT_SECRET || 'super-secret-temp-key';
await server.register(jwt, {
  secret: jwtSecret,
});

// Authentication Decorator
server.decorate(
  'authenticate',
  async (request: FastifyRequest, reply: FastifyReply) => {
    try {
      await request.jwtVerify();
    } catch (err) {
      reply.status(401).send({ error: 'Unauthorized: Invalid token' });
    }
  }
);

// Global Health Check
server.get('/health', async (request, reply) => {
  try {
    // Check Database connection
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

// Start Server
const PORT = parseInt(process.env.PORT || '3000', 10);
const HOST = process.env.HOST || '0.0.0.0';

server.listen({ port: PORT, host: HOST }, (err, address) => {
  if (err) {
    server.log.error(err);
    process.exit(1);
  }
  server.log.info(`Server listening on ${address}`);
});

declare module 'fastify' {
  interface FastifyInstance {
    authenticate: (request: FastifyRequest, reply: FastifyReply) => Promise<void>;
  }
}

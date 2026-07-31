import { FastifyInstance } from 'fastify';
import { authRoutes } from './controllers/authRoutes.js';
import { profileRoutes } from './controllers/profileRoutes.js';
import { followRoutes } from './controllers/followRoutes.js';

/**
 * Central route registration — registers all route plugins.
 */
export async function registerRoutes(server: FastifyInstance) {
  await server.register(authRoutes);
  await server.register(profileRoutes);
  await server.register(followRoutes);
}

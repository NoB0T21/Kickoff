import { FastifyInstance } from 'fastify';
import { authGuard } from '../middleware/authGuard.js';
import { followService } from '../services/followService.js';
import {
  ProfileIdParams,
  ProfileIdParamsType,
  PaginationQuery,
  PaginationQueryType,
} from '../schemas/profileSchemas.js';

/**
 * Follow/Unfollow routes with cursor-paginated follower/following lists.
 */
export async function followRoutes(server: FastifyInstance) {
  /**
   * POST /api/profiles/:id/follow
   * Authenticated — follow a user.
   */
  server.post<{ Params: ProfileIdParamsType }>(
    '/api/profiles/:id/follow',
    {
      onRequest: [authGuard],
      schema: { params: ProfileIdParams },
    },
    async (request, reply) => {
      await followService.followUser(request.userId, request.params.id);
      return reply.code(200).send({ success: true });
    },
  );

  /**
   * POST /api/profiles/:id/unfollow
   * Authenticated — unfollow a user.
   */
  server.post<{ Params: ProfileIdParamsType }>(
    '/api/profiles/:id/unfollow',
    {
      onRequest: [authGuard],
      schema: { params: ProfileIdParams },
    },
    async (request, reply) => {
      await followService.unfollowUser(request.userId, request.params.id);
      return reply.code(200).send({ success: true });
    },
  );

  /**
   * GET /api/profiles/:id/followers
   * Public — get paginated followers list.
   */
  server.get<{ Params: ProfileIdParamsType; Querystring: PaginationQueryType }>(
    '/api/profiles/:id/followers',
    {
      schema: {
        params: ProfileIdParams,
        querystring: PaginationQuery,
      },
    },
    async (request, reply) => {
      const { cursor, limit } = request.query;
      const result = await followService.getFollowers(request.params.id, cursor, limit);
      return reply.code(200).send(result);
    },
  );

  /**
   * GET /api/profiles/:id/following
   * Public — get paginated following list.
   */
  server.get<{ Params: ProfileIdParamsType; Querystring: PaginationQueryType }>(
    '/api/profiles/:id/following',
    {
      schema: {
        params: ProfileIdParams,
        querystring: PaginationQuery,
      },
    },
    async (request, reply) => {
      const { cursor, limit } = request.query;
      const result = await followService.getFollowing(request.params.id, cursor, limit);
      return reply.code(200).send(result);
    },
  );
}

import { FastifyInstance } from 'fastify';
import { authGuard } from '../middleware/authGuard.js';
import { profileService } from '../services/profileService.js';
import {
  UpdateProfileBody,
  UpdateProfileBodyType,
  UsernameCheckQuery,
  UsernameCheckQueryType,
  ProfileIdParams,
  ProfileIdParamsType,
} from '../schemas/profileSchemas.js';

/**
 * Profile routes — CRUD for athlete profiles.
 */
export async function profileRoutes(server: FastifyInstance) {
  /**
   * GET /api/profiles/username-check
   * Public — checks if a username is available (UX pre-check only).
   */
  server.get<{ Querystring: UsernameCheckQueryType }>(
    '/api/profiles/username-check',
    { schema: { querystring: UsernameCheckQuery } },
    async (request, reply) => {
      const { username } = request.query;
      const available = await profileService.checkUsername(username);
      return reply.code(200).send({ available });
    },
  );

  /**
   * GET /api/profiles/me
   * Authenticated — returns the caller's own profile.
   */
  server.get(
    '/api/profiles/me',
    { onRequest: [authGuard] },
    async (request, reply) => {
      const profile = await profileService.getMyProfile(request.userId);
      return reply.code(200).send(profile);
    },
  );

  /**
   * PUT /api/profiles/me
   * Authenticated — update the caller's profile.
   * Sets has_completed_onboarding = true when required fields are present.
   */
  server.put<{ Body: UpdateProfileBodyType }>(
    '/api/profiles/me',
    {
      onRequest: [authGuard],
      schema: { body: UpdateProfileBody },
    },
    async (request, reply) => {
      const profile = await profileService.updateProfile(request.userId, request.body);
      return reply.code(200).send(profile);
    },
  );

  /**
   * DELETE /api/profiles/me
   * Authenticated — soft-deletes the account with PII anonymization.
   */
  server.delete(
    '/api/profiles/me',
    { onRequest: [authGuard] },
    async (request, reply) => {
      await profileService.deleteAccount(request.userId);
      return reply.code(200).send({
        success: true,
        message: 'Account scheduled for deletion.',
      });
    },
  );

  /**
   * GET /api/profiles/:id
   * Public — view any profile by ID (excludes soft-deleted).
   */
  server.get<{ Params: ProfileIdParamsType }>(
    '/api/profiles/:id',
    { schema: { params: ProfileIdParams } },
    async (request, reply) => {
      const profile = await profileService.getProfile(request.params.id);
      return reply.code(200).send(profile);
    },
  );

  /**
   * POST /api/profiles/me/avatar-upload-url
   * Authenticated — generates a signed upload URL for avatar upload.
   */
  server.post(
    '/api/profiles/me/avatar-upload-url',
    { onRequest: [authGuard] },
    async (request, reply) => {
      const result = await profileService.generateAvatarUploadUrl(request.userId);
      return reply.code(200).send(result);
    },
  );
}

import { FastifyRequest, FastifyReply } from 'fastify';
import { supabaseAdmin } from '../config/supabase.js';

/**
 * Auth guard middleware — verifies the JWT from the Authorization header
 * by calling Supabase auth.getUser API.
 *
 * On success: attaches `request.userId`.
 * On failure: returns a standardized 401 error.
 */
export async function authGuard(request: FastifyRequest, reply: FastifyReply) {
  const header = request.headers.authorization;

  if (!header?.startsWith('Bearer ')) {
    return reply.code(401).send({
      error: {
        code: 'UNAUTHENTICATED',
        message: 'Missing or malformed Authorization header',
      },
    });
  }

  const token = header.slice(7);

  try {
    const { data, error } = await supabaseAdmin.auth.getUser(token);
    if (error || !data.user) {
      return reply.code(401).send({
        error: {
          code: 'INVALID_TOKEN',
          message: error?.message || 'Token is invalid or expired',
        },
      });
    }
    request.userId = data.user.id;
  } catch (err: any) {
    return reply.code(401).send({
      error: {
        code: 'INVALID_TOKEN',
        message: err.message || 'Token is invalid or expired',
      },
    });
  }
}

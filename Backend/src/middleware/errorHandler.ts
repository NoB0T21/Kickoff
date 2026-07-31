import { FastifyInstance, FastifyError, FastifyRequest, FastifyReply } from 'fastify';

/**
 * Standardized error envelope — every non-2xx response uses this shape.
 * Maps known error types (Postgres codes, Fastify validation, custom AppErrors)
 * to structured responses. Never leaks raw DB/stack errors to the client.
 */

interface ErrorEnvelope {
  error: {
    code: string;
    message: string;
    details?: unknown;
  };
}

// Custom application error for use in services/controllers
export class AppError extends Error {
  constructor(
    public statusCode: number,
    public code: string,
    message: string,
    public details?: unknown,
  ) {
    super(message);
    this.name = 'AppError';
  }
}

// Postgres error codes we handle specifically
const PG_ERROR_MAP: Record<string, { status: number; code: string; message: string }> = {
  '23505': { status: 409, code: 'USERNAME_TAKEN', message: 'That username is already in use.' },
  '23503': { status: 400, code: 'FOREIGN_KEY_VIOLATION', message: 'Referenced resource does not exist.' },
  '23514': { status: 400, code: 'CHECK_VIOLATION', message: 'Data constraint violated.' },
};

export function registerErrorHandler(server: FastifyInstance) {
  server.setErrorHandler((error: FastifyError, request: FastifyRequest, reply: FastifyReply) => {
    const envelope: ErrorEnvelope = {
      error: {
        code: 'INTERNAL_ERROR',
        message: 'An unexpected error occurred.',
        details: null,
      },
    };

    // 1. Custom AppError
    if (error instanceof AppError) {
      envelope.error.code = error.code;
      envelope.error.message = error.message;
      envelope.error.details = error.details ?? null;
      return reply.code(error.statusCode).send(envelope);
    }

    // 2. Fastify validation errors (from TypeBox schemas)
    if (error.validation) {
      envelope.error.code = 'VALIDATION_ERROR';
      envelope.error.message = 'Request validation failed.';
      envelope.error.details = error.validation;
      return reply.code(400).send(envelope);
    }

    // 3. Postgres errors (from pg driver — error.code is the Postgres SQLSTATE)
    const pgError = (error as any).code as string | undefined;
    if (pgError && PG_ERROR_MAP[pgError]) {
      const mapped = PG_ERROR_MAP[pgError];

      // Refine USERNAME_TAKEN: only apply when it's actually the username constraint
      if (pgError === '23505') {
        const detail = (error as any).detail as string | undefined;
        if (detail && detail.includes('username')) {
          mapped.message = 'That username is already in use.';
          mapped.code = 'USERNAME_TAKEN';
        } else if (detail && detail.includes('follower_id')) {
          mapped.message = 'You are already following this user.';
          mapped.code = 'ALREADY_FOLLOWING';
        }
      }

      // Refine CHECK_VIOLATION for self-follow
      if (pgError === '23514') {
        const constraint = (error as any).constraint as string | undefined;
        if (constraint === 'chk_no_self_follow') {
          mapped.message = 'You cannot follow yourself.';
          mapped.code = 'SELF_FOLLOW';
        }
      }

      envelope.error.code = mapped.code;
      envelope.error.message = mapped.message;
      return reply.code(mapped.status).send(envelope);
    }

    // 4. Rate limit errors
    if (error.statusCode === 429) {
      envelope.error.code = 'RATE_LIMITED';
      envelope.error.message = 'Too many requests. Please try again later.';
      return reply.code(429).send(envelope);
    }

    // 5. Fallback — log full error, return generic message
    request.log.error(error);
    return reply.code(error.statusCode || 500).send(envelope);
  });
}

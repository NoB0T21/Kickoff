import { FastifyInstance, FastifyRequest } from 'fastify';
import { authGuard } from '../middleware/authGuard.js';
import { eventService } from '../services/eventService.js';
import { supabaseAdmin } from '../config/supabase.js';
import { env } from '../config/env.js';
import {
  CreateEventBody,
  CreateEventBodyType,
  GetEventsQuery,
  GetEventsQueryType,
  EventIdParams,
  EventIdParamsType,
  InviteTokenParams,
  InviteTokenParamsType,
  AddGuestBody,
  AddGuestBodyType,
  EventMemberParams,
  EventMemberParamsType,
  AssignTeamBody,
  AssignTeamBodyType,
  UpdateEventBody,
  UpdateEventBodyType,
  CheckInBody,
  CheckInBodyType,
} from '../schemas/eventSchemas.js';

// Helper to extract optional auth token
async function getOptionalUserId(request: FastifyRequest): Promise<string | undefined> {
  const header = request.headers.authorization;
  if (header?.startsWith('Bearer ')) {
    const token = header.slice(7);
    try {
      const { data } = await supabaseAdmin.auth.getUser(token);
      return data?.user?.id ?? undefined;
    } catch {
      return undefined;
    }
  }
  return undefined;
}

function handleError(error: any, reply: any) {
  const msg = error.message;
  if (msg === 'EVENT_NOT_FOUND') {
    return reply.code(404).send({
      error: {
        code: 'EVENT_NOT_FOUND',
        message: 'The requested event was not found.',
      },
    });
  }
  if (msg === 'PRIVATE_EVENT') {
    return reply.code(403).send({
      error: {
        code: 'PRIVATE_EVENT',
        message: 'This event is private.',
      },
    });
  }
  if (msg === 'EVENT_ALREADY_EXISTS') {
    return reply.code(409).send({
      error: {
        code: 'EVENT_ALREADY_EXISTS',
        message: 'An event has already been created for this booking.',
      },
    });
  }
  if (msg === 'BOOKING_NOT_CONFIRMED') {
    return reply.code(409).send({
      error: {
        code: 'BOOKING_NOT_CONFIRMED',
        message: 'You can only host events for confirmed bookings.',
      },
    });
  }
  if (msg === 'BOOKING_NOT_FOUND') {
    return reply.code(404).send({
      error: {
        code: 'BOOKING_NOT_FOUND',
        message: 'The requested booking was not found.',
      },
    });
  }
  if (msg === 'FORBIDDEN') {
    return reply.code(403).send({
      error: {
        code: 'FORBIDDEN',
        message: 'You do not have permission to perform this action.',
      },
    });
  }
  if (msg === 'INVALID_CAPACITY') {
    return reply.code(400).send({
      error: {
        code: 'INVALID_CAPACITY',
        message: 'The requested capacity is out of allowed bounds for this sport.',
      },
    });
  }
  if (msg === 'SPORT_NOT_SUPPORTED') {
    return reply.code(400).send({
      error: {
        code: 'SPORT_NOT_SUPPORTED',
        message: 'The specified sport is not supported.',
      },
    });
  }
  if (msg === 'EVENT_NOT_JOINABLE') {
    return reply.code(409).send({
      error: {
        code: 'EVENT_NOT_JOINABLE',
        message: 'This event is not open for joining.',
      },
    });
  }
  if (msg === 'EVENT_FULL') {
    return reply.code(409).send({
      error: {
        code: 'EVENT_FULL',
        message: "This event's roster is already full.",
      },
    });
  }
  if (msg === 'ALREADY_JOINED') {
    return reply.code(409).send({
      error: {
        code: 'ALREADY_JOINED',
        message: 'You have already joined this event.',
      },
    });
  }
  if (msg === 'TIME_CONFLICT') {
    return reply.code(409).send({
      error: {
        code: 'TIME_CONFLICT',
        message: 'You have already joined or hosted another match at this timing.',
      },
    });
  }
  if (msg === 'HOST_CANNOT_LEAVE') {
    return reply.code(403).send({
      error: {
        code: 'HOST_CANNOT_LEAVE',
        message: 'The host cannot leave their own event. Cancel it instead.',
      },
    });
  }
  if (msg === 'NOT_A_MEMBER') {
    return reply.code(404).send({
      error: {
        code: 'NOT_A_MEMBER',
        message: 'The user is not a member of this event.',
      },
    });
  }
  if (msg === 'MEMBER_NOT_FOUND') {
    return reply.code(404).send({
      error: {
        code: 'MEMBER_NOT_FOUND',
        message: 'The requested roster member was not found.',
      },
    });
  }
  if (msg === 'EVENT_NOT_EDITABLE') {
    return reply.code(409).send({
      error: {
        code: 'EVENT_NOT_EDITABLE',
        message: 'Only scheduled events can be edited.',
      },
    });
  }
  if (msg === 'CAPACITY_BELOW_ROSTER') {
    return reply.code(409).send({
      error: {
        code: 'CAPACITY_BELOW_ROSTER',
        message: 'New capacity cannot be lower than the current roster count.',
      },
    });
  }
  if (msg === 'INVALID_QR_CODE') {
    return reply.code(400).send({
      error: {
        code: 'INVALID_QR_CODE',
        message: 'The provided check-in QR code is invalid.',
      },
    });
  }

  // fallback
  throw error;
}

export async function eventRoutes(server: FastifyInstance) {
  /**
   * POST /api/events
   * Authenticated, rate-limited: 5/min/user
   */
  server.post<{ Body: CreateEventBodyType }>(
    '/api/events',
    {
      onRequest: [authGuard],
      schema: {
        body: CreateEventBody,
      },
      config: {
        rateLimit: {
          max: 5,
          timeWindow: '1 minute',
        },
      },
    },
    async (request, reply) => {
      try {
        const event = await eventService.createEvent(request.userId, request.body);
        return reply.code(201).send(event);
      } catch (error) {
        return handleError(error, reply);
      }
    }
  );

  /**
   * GET /api/events
   * Public feed, cursor-paginated, optional auth to see private events from followed hosts
   */
  server.get<{ Querystring: GetEventsQueryType }>(
    '/api/events',
    {
      schema: {
        querystring: GetEventsQuery,
      },
    },
    async (request, reply) => {
      const userId = await getOptionalUserId(request);
      const { sport, status = 'scheduled', cursor, limit = 20 } = request.query;

      try {
        const result = await eventService.listEvents({ sport, status, cursor, limit }, userId);
        return reply.code(200).send(result);
      } catch (error) {
        return handleError(error, reply);
      }
    }
  );

  /**
   * GET /api/events/invite/:token
   * Public resolution of private event by invite token
   */
  server.get<{ Params: InviteTokenParamsType }>(
    '/api/events/invite/:token',
    {
      schema: {
        params: InviteTokenParams,
      },
    },
    async (request, reply) => {
      const { token } = request.params;
      try {
        const event = await eventService.resolveInvite(token);
        return reply.code(200).send(event);
      } catch (error) {
        return handleError(error, reply);
      }
    }
  );

  /**
   * GET /api/events/:id
   * Public/conditional event lookup
   */
  server.get<{ Params: EventIdParamsType }>(
    '/api/events/:id',
    {
      schema: {
        params: EventIdParams,
      },
    },
    async (request, reply) => {
      const { id } = request.params;
      const userId = await getOptionalUserId(request);

      try {
        const event = await eventService.getEvent(id, userId);
        return reply.code(200).send(event);
      } catch (error) {
        return handleError(error, reply);
      }
    }
  );

  /**
   * GET /api/events/:id/roster
   * Public/conditional roster lookup
   */
  server.get<{ Params: EventIdParamsType }>(
    '/api/events/:id/roster',
    {
      schema: {
        params: EventIdParams,
      },
    },
    async (request, reply) => {
      const { id } = request.params;
      const userId = await getOptionalUserId(request);

      try {
        const roster = await eventService.getEventMembers(id, userId);
        return reply.code(200).send(roster);
      } catch (error) {
        return handleError(error, reply);
      }
    }
  );

  /**
   * POST /api/events/:id/join
   * Authenticated, rate-limited: 10/min/user
   */
  server.post<{ Params: EventIdParamsType }>(
    '/api/events/:id/join',
    {
      onRequest: [authGuard],
      schema: {
        params: EventIdParams,
      },
      config: {
        rateLimit: {
          max: 10,
          timeWindow: '1 minute',
        },
      },
    },
    async (request, reply) => {
      const { id } = request.params;
      try {
        const member = await eventService.joinEvent(request.userId, id);
        return reply.code(200).send({ success: true, member });
      } catch (error) {
        return handleError(error, reply);
      }
    }
  );

  /**
   * POST /api/events/:id/leave
   * Authenticated
   */
  server.post<{ Params: EventIdParamsType }>(
    '/api/events/:id/leave',
    {
      onRequest: [authGuard],
      schema: {
        params: EventIdParams,
      },
    },
    async (request, reply) => {
      const { id } = request.params;
      try {
        await eventService.leaveEvent(request.userId, id);
        return reply.code(200).send({ success: true });
      } catch (error) {
        return handleError(error, reply);
      }
    }
  );

  /**
   * POST /api/events/:id/roster/guest
   * Authenticated (host-only checked in service), rate-limited: 20/min/user
   */
  server.post<{ Params: EventIdParamsType; Body: AddGuestBodyType }>(
    '/api/events/:id/roster/guest',
    {
      onRequest: [authGuard],
      schema: {
        params: EventIdParams,
        body: AddGuestBody,
      },
      config: {
        rateLimit: {
          max: 20,
          timeWindow: '1 minute',
        },
      },
    },
    async (request, reply) => {
      const { id } = request.params;
      const { guest_name } = request.body;
      try {
        const guest = await eventService.addGuest(request.userId, id, guest_name);
        return reply.code(201).send(guest);
      } catch (error) {
        return handleError(error, reply);
      }
    }
  );

  /**
   * DELETE /api/events/:id/roster/:member_id
   * Authenticated (host-only checked in service)
   */
  server.delete<{ Params: EventMemberParamsType }>(
    '/api/events/:id/roster/:member_id',
    {
      onRequest: [authGuard],
      schema: {
        params: EventMemberParams,
      },
    },
    async (request, reply) => {
      const { id, member_id } = request.params;
      try {
        await eventService.deleteMember(request.userId, id, member_id);
        return reply.code(200).send({ success: true });
      } catch (error) {
        return handleError(error, reply);
      }
    }
  );

  /**
   * PATCH /api/events/:id/roster/:member_id/team
   * Authenticated (host-only checked in service)
   */
  server.patch<{ Params: EventMemberParamsType; Body: AssignTeamBodyType }>(
    '/api/events/:id/roster/:member_id/team',
    {
      onRequest: [authGuard],
      schema: {
        params: EventMemberParams,
        body: AssignTeamBody,
      },
    },
    async (request, reply) => {
      const { id, member_id } = request.params;
      const { team } = request.body;
      try {
        const member = await eventService.assignTeam(request.userId, id, member_id, team);
        return reply.code(200).send(member);
      } catch (error) {
        return handleError(error, reply);
      }
    }
  );

  /**
   * PATCH /api/events/:id
   * Authenticated (host-only checked in service)
   */
  server.patch<{ Params: EventIdParamsType; Body: UpdateEventBodyType }>(
    '/api/events/:id',
    {
      onRequest: [authGuard],
      schema: {
        params: EventIdParams,
        body: UpdateEventBody,
      },
    },
    async (request, reply) => {
      const { id } = request.params;
      try {
        const event = await eventService.updateEvent(request.userId, id, request.body);
        return reply.code(200).send(event);
      } catch (error) {
        return handleError(error, reply);
      }
    }
  );

  /**
   * POST /api/events/:id/cancel
   * Authenticated (host-only checked in service)
   */
  server.post<{ Params: EventIdParamsType }>(
    '/api/events/:id/cancel',
    {
      onRequest: [authGuard],
      schema: {
        params: EventIdParams,
      },
    },
    async (request, reply) => {
      const { id } = request.params;
      try {
        const event = await eventService.cancelEvent(request.userId, id);
        return reply.code(200).send(event);
      } catch (error) {
        return handleError(error, reply);
      }
    }
  );

  /**
   * POST /api/events/:id/check-in
   * Turf-owner-app credential check
   */
  server.post<{ Params: EventIdParamsType; Body: CheckInBodyType }>(
    '/api/events/:id/check-in',
    {
      schema: {
        params: EventIdParams,
        body: CheckInBody,
      },
    },
    async (request, reply) => {
      const authHeader = request.headers.authorization;
      if (!authHeader?.startsWith('Bearer ') || authHeader.slice(7) !== env.SUPABASE_SERVICE_ROLE_KEY) {
        return reply.code(401).send({
          error: {
            code: 'UNAUTHORIZED_CHECK_IN',
            message: 'Invalid turf-owner-app credential token.',
          },
        });
      }

      const { id } = request.params;
      const { qr_check_in_code, qr_code } = request.body;
      const code = qr_check_in_code || qr_code;

      if (!code) {
        return reply.code(400).send({
          error: {
            code: 'MISSING_QR_CODE',
            message: 'Please provide qr_check_in_code in the request body.',
          },
        });
      }

      try {
        const event = await eventService.checkIn(id, code);
        return reply.code(200).send(event);
      } catch (error) {
        return handleError(error, reply);
      }
    }
  );
}

import { FastifyInstance } from 'fastify';
import { Readable } from 'stream';
import { authGuard } from '../middleware/authGuard.js';
import { bookingService } from '../services/bookingService.js';
import { bookingRepository } from '../repositories/bookingRepository.js';
import { env } from '../config/env.js';
import {
  LockSlotsBody,
  LockSlotsBodyType,
  CheckoutSessionBody,
  CheckoutSessionBodyType,
  BookingIdParams,
  BookingIdParamsType,
} from '../schemas/bookingSchemas.js';

export async function bookingRoutes(server: FastifyInstance) {
  /**
   * POST /api/bookings/lock
   * Authenticated — Acquire a 5-minute temporary lock on slots.
   */
  server.post<{ Body: LockSlotsBodyType }>(
    '/api/bookings/lock',
    {
      onRequest: [authGuard],
      schema: {
        body: LockSlotsBody,
      },
      config: {
        rateLimit: {
          max: 10,
          timeWindow: '1 minute',
        },
      },
    },
    async (request, reply) => {
      const { slot_ids } = request.body;

      try {
        const lockedSlots = await bookingService.lockSlots(request.userId, slot_ids);
        
        // Calculate lock expiry from the first slot
        const lockExpiresAt = lockedSlots[0]?.locked_until;
        const totalPrice = lockedSlots.reduce((sum, slot) => sum + parseFloat(slot.price), 0).toFixed(2);

        return reply.code(200).send({
          success: true,
          lock_expires_at: lockExpiresAt,
          total_price: totalPrice,
        });
      } catch (error: any) {
        if (error.message === 'ACTIVE_LOCK_EXISTS') {
          return reply.code(409).send({
            error: {
              code: 'ACTIVE_LOCK_EXISTS',
              message: 'You already have an active slot lock session. Please complete or cancel checkout first.',
            },
          });
        }
        if (error.message === 'SLOT_NOT_AVAILABLE') {
          return reply.code(409).send({
            error: {
              code: 'SLOT_NOT_AVAILABLE',
              message: 'One or more of the selected slots are no longer available.',
            },
          });
        }
        throw error;
      }
    }
  );

  /**
   * DELETE /api/bookings/lock
   * Authenticated — Cancel/release active locks early.
   */
  server.delete(
    '/api/bookings/lock',
    {
      onRequest: [authGuard],
    },
    async (request, reply) => {
      await bookingService.releaseActiveLocks(request.userId);
      return reply.code(200).send({ success: true });
    }
  );

  /**
   * POST /api/bookings/checkout-session
   * Authenticated — Generate Cashfree session order from active locks.
   */
  server.post<{ Body: CheckoutSessionBodyType }>(
    '/api/bookings/checkout-session',
    {
      onRequest: [authGuard],
      schema: {
        body: CheckoutSessionBody,
      },
      config: {
        rateLimit: {
          max: 5,
          timeWindow: '1 minute',
        },
      },
    },
    async (request, reply) => {
      const idempotencyKey = request.headers['idempotency-key'];
      if (!idempotencyKey || typeof idempotencyKey !== 'string') {
        return reply.code(400).send({
          error: {
            code: 'MISSING_IDEMPOTENCY_KEY',
            message: 'Idempotency-Key header is required.',
          },
        });
      }

      const { slot_ids } = request.body;

      try {
        const booking = await bookingService.createCheckoutSession(
          request.userId,
          slot_ids,
          idempotencyKey
        );

        const isSandbox = env.CASHFREE_BASE_URL.includes('sandbox');

        return reply.code(201).send({
          booking_id: booking.id,
          cf_order_id: booking.cf_order_id,
          payment_session_id: booking.payment_session_id,
          status: booking.status,
          is_sandbox: isSandbox,
        });
      } catch (error: any) {
        if (
          error.message === 'LOCK_EXPIRED_OR_INVALID' ||
          error.message === 'SLOT_NOT_FOUND' ||
          error.message === 'MULTIPLE_TURFS_NOT_ALLOWED'
        ) {
          return reply.code(400).send({
            error: {
              code: 'CHECKOUT_SESSION_INVALID',
              message: error.message,
            },
          });
        }
        throw error;
      }
    }
  );

  /**
   * POST /api/webhooks/cashfree
   * Public — Ingests Cashfree payment success/failure webhooks with signature checks.
   */
  server.post(
    '/api/webhooks/cashfree',
    {
      // Custom preParsing hook to extract raw string body for signature verification
      preParsing: async (request, reply, payload) => {
        let body = '';
        for await (const chunk of payload) {
          body += chunk;
        }
        // Save the raw body on request object
        (request as any).rawBody = body;
        // Re-yield the stream so JSON parser still runs
        return Readable.from([body]);
      },
    },
    async (request, reply) => {
      const rawBody = (request as any).rawBody || '';
      
      try {
        const result = await bookingService.processCashfreeWebhook(request.headers, rawBody);
        return reply.code(200).send(result);
      } catch (error: any) {
        if (error.message === 'INVALID_SIGNATURE') {
          return reply.code(401).send({
            error: {
              code: 'INVALID_SIGNATURE',
              message: 'Webhook signature verification failed.',
            },
          });
        }
        server.log.error(error);
        return reply.code(500).send({ error: error.message });
      }
    }
  );

  /**
   * GET /api/bookings/:id/status
   * Authenticated — Retrieve current booking status.
   */
  server.get<{ Params: BookingIdParamsType }>(
    '/api/bookings/:id/status',
    {
      onRequest: [authGuard],
      schema: {
        params: BookingIdParams,
      },
    },
    async (request, reply) => {
      const { id } = request.params;
      
      try {
        const booking = await bookingService.getBookingStatus(request.userId, id);
        return reply.code(200).send({ status: booking.status });
      } catch (error: any) {
        if (error.message === 'BOOKING_NOT_FOUND') {
          return reply.code(404).send({
            error: {
              code: 'BOOKING_NOT_FOUND',
              message: 'The requested booking was not found.',
            },
          });
        }
        if (error.message === 'FORBIDDEN') {
          return reply.code(403).send({
            error: {
              code: 'FORBIDDEN',
              message: 'You do not own this booking.',
            },
          });
        }
        throw error;
      }
    }
  );

  /**
   * POST /api/bookings/:id/cancel
   * Authenticated — Cancel slot booking (enforces 5-hour window).
   */
  server.post<{ Params: BookingIdParamsType }>(
    '/api/bookings/:id/cancel',
    {
      onRequest: [authGuard],
      schema: {
        params: BookingIdParams,
      },
    },
    async (request, reply) => {
      const { id } = request.params;

      try {
        const booking = await bookingService.cancelBooking(request.userId, id);
        return reply.code(200).send({ status: booking.status });
      } catch (error: any) {
        if (error.message === 'BOOKING_NOT_FOUND') {
          return reply.code(404).send({
            error: {
              code: 'BOOKING_NOT_FOUND',
              message: 'The requested booking was not found.',
            },
          });
        }
        if (error.message === 'FORBIDDEN') {
          return reply.code(403).send({
            error: {
              code: 'FORBIDDEN',
              message: 'You do not own this booking.',
            },
          });
        }
        if (error.message === 'CANCELLATION_WINDOW_EXPIRED') {
          return reply.code(400).send({
            error: {
              code: 'CANCELLATION_WINDOW_EXPIRED',
              message: 'Bookings can only be cancelled up to 5 hours before the scheduled slot starts.',
            },
          });
        }
        throw error;
      }
    }
  );

  /**
   * GET /api/bookings
   * Authenticated — Retrieve user bookings.
   */
  server.get(
    '/api/bookings',
    {
      onRequest: [authGuard],
    },
    async (request, reply) => {
      const bookings = await bookingRepository.findByUserId(request.userId);
      return reply.code(200).send(bookings);
    }
  );

  /**
   * GET /api/bookings/:id
   * Authenticated — Retrieve details of a single booking (including turfs).
   */
  server.get<{ Params: BookingIdParamsType }>(
    '/api/bookings/:id',
    {
      onRequest: [authGuard],
      schema: {
        params: BookingIdParams,
      },
    },
    async (request, reply) => {
      const { id } = request.params;
      const booking = await bookingRepository.findByIdWithTurf(id);
      if (!booking) {
        return reply.code(404).send({
          error: {
            code: 'BOOKING_NOT_FOUND',
            message: 'The requested booking was not found.',
          },
        });
      }
      if (booking.user_id !== request.userId) {
        return reply.code(403).send({
          error: {
            code: 'FORBIDDEN',
            message: 'You do not own this booking.',
          },
        });
      }
      return reply.code(200).send(booking);
    }
  );
}

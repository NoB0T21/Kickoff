import { FastifyInstance } from 'fastify';
import { turfService } from '../services/turfService.js';
import {
  TurfSearchQuery,
  TurfSearchQueryType,
  TurfSlotsQuery,
  TurfSlotsQueryType,
  TurfIdParams,
  TurfIdParamsType,
} from '../schemas/turfSchemas.js';

export async function turfRoutes(server: FastifyInstance) {
  /**
   * GET /api/turfs
   * Public — Discover turfs by coordinates, sports, and cursor pagination.
   */
  server.get<{ Querystring: TurfSearchQueryType }>(
    '/api/turfs',
    {
      schema: {
        querystring: TurfSearchQuery,
      },
    },
    async (request, reply) => {
      const { lat, lng, sport, date, cursor, limit } = request.query;
      const parsedLimit = limit ?? 20;

      const result = await turfService.searchTurfs({
        lat,
        lng,
        sport,
        date,
        cursor,
        limit: parsedLimit,
      });

      return reply.code(200).send(result);
    }
  );

  /**
   * GET /api/turfs/:id/slots
   * Public — Retrieve hourly slot statuses for a specific turf and date.
   */
  server.get<{ Params: TurfIdParamsType; Querystring: TurfSlotsQueryType }>(
    '/api/turfs/:id/slots',
    {
      schema: {
        params: TurfIdParams,
        querystring: TurfSlotsQuery,
      },
    },
    async (request, reply) => {
      const { id } = request.params;
      const { date } = request.query;

      const slots = await turfService.getSlotsForTurfAndDate(id, date);
      return reply.code(200).send(slots);
    }
  );
}

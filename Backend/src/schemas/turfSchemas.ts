import { Type, Static } from '@sinclair/typebox';

export const TurfSearchQuery = Type.Object({
  lat: Type.Number({ minimum: -90, maximum: 90 }),
  lng: Type.Number({ minimum: -180, maximum: 180 }),
  sport: Type.Optional(Type.String()),
  date: Type.Optional(Type.String({ pattern: '^\\d{4}-\\d{2}-\\d{2}$' })), // YYYY-MM-DD
  cursor: Type.Optional(Type.String()),
  limit: Type.Optional(Type.Integer({ minimum: 1, maximum: 50, default: 20 })),
});

export type TurfSearchQueryType = Static<typeof TurfSearchQuery>;

export const TurfSlotsQuery = Type.Object({
  date: Type.String({ pattern: '^\\d{4}-\\d{2}-\\d{2}$' }),
});

export type TurfSlotsQueryType = Static<typeof TurfSlotsQuery>;

export const TurfIdParams = Type.Object({
  id: Type.String({ format: 'uuid' }),
});

export type TurfIdParamsType = Static<typeof TurfIdParams>;

import { Type, Static } from '@sinclair/typebox';

export const LockSlotsBody = Type.Object({
  slot_ids: Type.Array(Type.String({ format: 'uuid' }), { minItems: 1 }),
});

export type LockSlotsBodyType = Static<typeof LockSlotsBody>;

export const CheckoutSessionBody = Type.Object({
  slot_ids: Type.Array(Type.String({ format: 'uuid' }), { minItems: 1 }),
});

export type CheckoutSessionBodyType = Static<typeof CheckoutSessionBody>;

export const BookingIdParams = Type.Object({
  id: Type.String({ format: 'uuid' }),
});

export type BookingIdParamsType = Static<typeof BookingIdParams>;

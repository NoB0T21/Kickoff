import { pool } from '../config/db.js';
import { SlotRow } from './turfRepository.js';

export interface BookingRow {
  id: string;
  user_id: string;
  turf_id: string;
  slot_ids: string[];
  slot_date: string;
  hours: number[];
  total_price: string;
  status: 'pending_payment' | 'confirmed' | 'failed' | 'cancelled' | 'refund_pending' | 'refunded';
  cf_order_id: string | null;
  payment_session_id: string | null;
  transaction_id: string | null;
  idempotency_key: string | null;
  created_at: string;
  updated_at: string;
}

export interface CreateBookingData {
  user_id: string;
  turf_id: string;
  slot_ids: string[];
  slot_date: string;
  hours: number[];
  total_price: number;
  idempotency_key: string;
  cf_order_id: string;
  payment_session_id: string;
}

export const bookingRepository = {
  /**
   * Lock slots using the RPC function, passing auth.uid context using PG set_config.
   */
  async lockSlots(userId: string, slotIds: string[]): Promise<SlotRow[]> {
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      await client.query(`SELECT set_config('request.jwt.claim.sub', $1, true)`, [userId]);
      const result = await client.query('SELECT * FROM public.lock_slots($1)', [slotIds]);
      await client.query('COMMIT');
      return result.rows as SlotRow[];
    } catch (error: any) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  },

  /**
   * Early release of locked slots for a user.
   */
  async releaseActiveLocks(userId: string): Promise<void> {
    await pool.query(
      `UPDATE public.slots
       SET status = 'available', locked_by = NULL, locked_until = NULL
       WHERE locked_by = $1 AND status = 'locked'`,
      [userId]
    );
  },

  /**
   * Find booking by ID.
   */
  async findById(id: string): Promise<BookingRow | null> {
    const result = await pool.query(
      `SELECT id, user_id, turf_id, slot_ids, slot_date::text, hours, total_price, status, cf_order_id, payment_session_id, transaction_id, idempotency_key, created_at, updated_at
       FROM public.bookings WHERE id = $1`,
      [id]
    );
    return result.rows[0] ?? null;
  },

  /**
   * Find booking by Idempotency Key.
   */
  async findByIdempotencyKey(key: string): Promise<BookingRow | null> {
    const result = await pool.query(
      `SELECT id, user_id, turf_id, slot_ids, slot_date::text, hours, total_price, status, cf_order_id, payment_session_id, transaction_id, idempotency_key, created_at, updated_at
       FROM public.bookings WHERE idempotency_key = $1`,
      [key]
    );
    return result.rows[0] ?? null;
  },

  /**
   * Find booking by Cashfree Order ID.
   */
  async findByCfOrderId(cfOrderId: string): Promise<BookingRow | null> {
    const result = await pool.query(
      `SELECT id, user_id, turf_id, slot_ids, slot_date::text, hours, total_price, status, cf_order_id, payment_session_id, transaction_id, idempotency_key, created_at, updated_at
       FROM public.bookings WHERE cf_order_id = $1`,
      [cfOrderId]
    );
    return result.rows[0] ?? null;
  },

  /**
   * Create a booking row.
   */
  async createBooking(data: CreateBookingData): Promise<BookingRow> {
    const result = await pool.query(
      `INSERT INTO public.bookings (user_id, turf_id, slot_ids, slot_date, hours, total_price, status, cf_order_id, payment_session_id, idempotency_key)
       VALUES ($1, $2, $3, $4, $5, $6, 'pending_payment', $7, $8, $9)
       RETURNING id, user_id, turf_id, slot_ids, slot_date::text, hours, total_price, status, cf_order_id, payment_session_id, transaction_id, idempotency_key, created_at, updated_at`,
      [
        data.user_id,
        data.turf_id,
        data.slot_ids,
        data.slot_date,
        data.hours,
        data.total_price,
        data.cf_order_id,
        data.payment_session_id,
        data.idempotency_key,
      ]
    );
    return result.rows[0];
  },

  /**
   * Webhook: Confirm booking and mark slots booked inside a single transaction.
   */
  async confirmBooking(cfOrderId: string, transactionId: string, payload: any): Promise<BookingRow | null> {
    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      // Fetch booking
      const bookingRes = await client.query(
        `SELECT id, slot_ids, status FROM public.bookings WHERE cf_order_id = $1 FOR UPDATE`,
        [cfOrderId]
      );
      
      if (bookingRes.rows.length === 0) {
        await client.query('ROLLBACK');
        return null;
      }
      
      const booking = bookingRes.rows[0];
      
      // If already processed, short-circuit (idempotent)
      if (booking.status === 'confirmed') {
        await client.query('COMMIT');
        return this.findByCfOrderId(cfOrderId);
      }

      // Update Booking
      const updatedBookingRes = await client.query(
        `UPDATE public.bookings
         SET status = 'confirmed', transaction_id = $1, updated_at = NOW()
         WHERE cf_order_id = $2
         RETURNING id, user_id, turf_id, slot_ids, slot_date::text, hours, total_price, status, cf_order_id, payment_session_id, transaction_id, idempotency_key, created_at, updated_at`,
        [transactionId, cfOrderId]
      );

      // Update Slots
      await client.query(
        `UPDATE public.slots
         SET status = 'booked', locked_by = NULL, locked_until = NULL
         WHERE id = ANY($1)`,
        [booking.slot_ids]
      );

      // Log webhook event (deduplicated by cf_order_id, event_type)
      await client.query(
        `INSERT INTO public.webhook_events (cf_order_id, event_type, payload)
         VALUES ($1, 'PAYMENT_SUCCESS', $2)
         ON CONFLICT (cf_order_id, event_type) DO NOTHING`,
        [cfOrderId, JSON.stringify(payload)]
      );

      await client.query('COMMIT');
      return updatedBookingRes.rows[0];
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  },

  /**
   * Webhook: Fail booking and release slots inside a single transaction.
   */
  async failBooking(cfOrderId: string, payload: any): Promise<BookingRow | null> {
    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      // Fetch booking
      const bookingRes = await client.query(
        `SELECT id, slot_ids, status FROM public.bookings WHERE cf_order_id = $1 FOR UPDATE`,
        [cfOrderId]
      );
      
      if (bookingRes.rows.length === 0) {
        await client.query('ROLLBACK');
        return null;
      }
      
      const booking = bookingRes.rows[0];

      if (booking.status === 'failed') {
        await client.query('COMMIT');
        return this.findByCfOrderId(cfOrderId);
      }

      // Update Booking
      const updatedBookingRes = await client.query(
        `UPDATE public.bookings
         SET status = 'failed', updated_at = NOW()
         WHERE cf_order_id = $1
         RETURNING id, user_id, turf_id, slot_ids, slot_date::text, hours, total_price, status, cf_order_id, payment_session_id, transaction_id, idempotency_key, created_at, updated_at`,
        [cfOrderId]
      );

      // Release Slots
      await client.query(
        `UPDATE public.slots
         SET status = 'available', locked_by = NULL, locked_until = NULL
         WHERE id = ANY($1) AND status = 'locked'`,
        [booking.slot_ids]
      );

      // Log webhook event
      await client.query(
        `INSERT INTO public.webhook_events (cf_order_id, event_type, payload)
         VALUES ($1, 'PAYMENT_FAILED', $2)
         ON CONFLICT (cf_order_id, event_type) DO NOTHING`,
        [cfOrderId, JSON.stringify(payload)]
      );

      await client.query('COMMIT');
      return updatedBookingRes.rows[0];
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  },

  /**
   * Set refund pending status.
   */
  async refundPendingBooking(bookingId: string): Promise<BookingRow> {
    const result = await pool.query(
      `UPDATE public.bookings
       SET status = 'refund_pending', updated_at = NOW()
       WHERE id = $1
       RETURNING id, user_id, turf_id, slot_ids, slot_date::text, hours, total_price, status, cf_order_id, payment_session_id, transaction_id, idempotency_key, created_at, updated_at`,
      [bookingId]
    );
    return result.rows[0];
  },

  /**
   * Finalize refund: mark booking refunded and slots available.
   */
  async refundBooking(cfOrderId: string, payload: any): Promise<BookingRow | null> {
    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      const bookingRes = await client.query(
        `SELECT id, slot_ids, status FROM public.bookings WHERE cf_order_id = $1 FOR UPDATE`,
        [cfOrderId]
      );

      if (bookingRes.rows.length === 0) {
        await client.query('ROLLBACK');
        return null;
      }

      const booking = bookingRes.rows[0];

      const updatedBookingRes = await client.query(
        `UPDATE public.bookings
         SET status = 'refunded', updated_at = NOW()
         WHERE cf_order_id = $1
         RETURNING id, user_id, turf_id, slot_ids, slot_date::text, hours, total_price, status, cf_order_id, payment_session_id, transaction_id, idempotency_key, created_at, updated_at`,
        [cfOrderId]
      );

      // Release Slots
      await client.query(
        `UPDATE public.slots
         SET status = 'available', locked_by = NULL, locked_until = NULL
         WHERE id = ANY($1)`,
        [booking.slot_ids]
      );

      // Log webhook event
      await client.query(
        `INSERT INTO public.webhook_events (cf_order_id, event_type, payload)
         VALUES ($1, 'REFUND_SUCCESS', $2)
         ON CONFLICT (cf_order_id, event_type) DO NOTHING`,
        [cfOrderId, JSON.stringify(payload)]
      );

      await client.query('COMMIT');
      return updatedBookingRes.rows[0];
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  },

  /**
   * Find bookings that are in pending_payment status older than a threshold (in minutes).
   */
  async getExpiredPendingBookings(olderThanMinutes: number): Promise<BookingRow[]> {
    const result = await pool.query(
      `SELECT id, user_id, turf_id, slot_ids, slot_date::text, hours, total_price, status, cf_order_id, payment_session_id, transaction_id, idempotency_key, created_at, updated_at
       FROM public.bookings
       WHERE status = 'pending_payment' AND created_at < NOW() - ($1 * INTERVAL '1 minute')`,
      [olderThanMinutes]
    );
    return result.rows as BookingRow[];
  },

  /**
   * Lock sweeping helper (fallback Node.js worker sweep).
   */
  async sweepExpiredLocks(): Promise<number> {
    const result = await pool.query(
      `UPDATE public.slots
       SET status = 'available', locked_by = NULL, locked_until = NULL
       WHERE status = 'locked' AND locked_until < NOW()`
    );
    return result.rowCount ?? 0;
  }
};

import { bookingRepository, BookingRow } from '../repositories/bookingRepository.js';
import { cashfreeService } from './cashfreeService.js';
import { supabaseAdmin } from '../config/supabase.js';
import { pool } from '../config/db.js';
import { SlotRow } from '../repositories/turfRepository.js';

class BookingService {
  async lockSlots(userId: string, slotIds: string[]): Promise<SlotRow[]> {
    return bookingRepository.lockSlots(userId, slotIds);
  }

  async releaseActiveLocks(userId: string): Promise<void> {
    return bookingRepository.releaseActiveLocks(userId);
  }

  /**
   * Creates a booking and corresponding Cashfree PG order.
   */
  async createCheckoutSession(
    userId: string,
    slotIds: string[],
    idempotencyKey: string
  ): Promise<BookingRow> {
    // 1. Check if booking already exists with this idempotency key (cached response)
    const existing = await bookingRepository.findByIdempotencyKey(idempotencyKey);
    if (existing) {
      console.log(`[BookingService] Returning cached booking for idempotency key ${idempotencyKey}`);
      return existing;
    }

    // 2. Fetch locked slots to verify they are locked by this user and not expired
    const result = await pool.query(
      `SELECT id, turf_id, slot_date::text, start_hour, price, status, locked_by, locked_until
       FROM public.slots
       WHERE id = ANY($1)`,
      [slotIds]
    );
    const slots = result.rows;

    if (slots.length !== slotIds.length) {
      throw new Error('SLOT_NOT_FOUND');
    }

    const turfId = slots[0].turf_id;
    const slotDate = slots[0].slot_date;
    const hours: number[] = [];
    let totalPrice = 0;

    for (const slot of slots) {
      if (slot.turf_id !== turfId) {
        throw new Error('MULTIPLE_TURFS_NOT_ALLOWED');
      }
      if (slot.status !== 'locked' || slot.locked_by !== userId || new Date(slot.locked_until) < new Date()) {
        throw new Error('LOCK_EXPIRED_OR_INVALID');
      }
      hours.push(slot.start_hour);
      totalPrice += parseFloat(slot.price);
    }

    // Sort hours to ensure chronological order
    hours.sort((a, b) => a - b);

    // 3. Fetch user details from Supabase Auth admin
    const { data: userData, error: userError } = await supabaseAdmin.auth.admin.getUserById(userId);
    if (userError || !userData?.user) {
      throw new Error(`Failed to retrieve user: ${userError?.message || 'User not found'}`);
    }

    const email = userData.user.email || '';
    const phone = userData.user.phone || '';

    // Generate cf_order_id using a placeholder format
    const tempBookingId = crypto.randomUUID();
    const cfOrderId = `cf_order_${tempBookingId.split('-')[0]}_${Date.now()}`;

    // 4. Create Cashfree PG Order
    console.log(`[BookingService] Dispatching order to Cashfree for user ${userId}`);
    const cfOrder = await cashfreeService.createOrder(
      cfOrderId,
      totalPrice,
      userId,
      email,
      phone
    );

    // 5. Save booking row
    const booking = await bookingRepository.createBooking({
      user_id: userId,
      turf_id: turfId,
      slot_ids: slotIds,
      slot_date: slotDate,
      hours,
      total_price: totalPrice,
      idempotency_key: idempotencyKey,
      cf_order_id: cfOrder.order_id,
      payment_session_id: cfOrder.payment_session_id,
    });

    return booking;
  }

  /**
   * Processes webhook events from Cashfree.
   */
  async processCashfreeWebhook(headers: Record<string, string | string[] | undefined>, rawBody: string): Promise<any> {
    // 1. Verify webhook signature
    const isValid = cashfreeService.verifyWebhookSignature(headers, rawBody);
    if (!isValid) {
      throw new Error('INVALID_SIGNATURE');
    }

    const payload = JSON.parse(rawBody);
    const eventType = payload.event;
    
    console.log(`[BookingService] Webhook received: ${eventType} for order ${payload.data?.order?.order_id}`);

    if (!payload.data?.order) {
      return { success: false, message: 'Invalid payload structure' };
    }

    const cfOrderId = payload.data.order.order_id;
    const transactionId = payload.data.payment?.cf_payment_id || '';

    // Handle payment events
    if (eventType === 'ORDER_PAID') {
      const booking = await bookingRepository.confirmBooking(cfOrderId, String(transactionId), payload);
      return { success: true, status: 'confirmed', booking };
    } else if (eventType === 'ORDER_FAILED' || eventType === 'PAYMENT_FAILED') {
      const booking = await bookingRepository.failBooking(cfOrderId, payload);
      return { success: true, status: 'failed', booking };
    } else if (eventType === 'REFUND_SUCCESS') {
      const booking = await bookingRepository.refundBooking(cfOrderId, payload);
      return { success: true, status: 'refunded', booking };
    }

    return { success: true, message: 'Event not handled' };
  }

  /**
   * Retrieve current booking status.
   */
  async getBookingStatus(userId: string, bookingId: string): Promise<BookingRow> {
    const booking = await bookingRepository.findById(bookingId);
    if (!booking) {
      throw new Error('BOOKING_NOT_FOUND');
    }
    if (booking.user_id !== userId) {
      throw new Error('FORBIDDEN');
    }

    // Direct poll check with Cashfree if still pending_payment (useful for local development/webhooks delay)
    if (booking.status === 'pending_payment' && booking.cf_order_id) {
      try {
        const cfOrder = await cashfreeService.getOrderStatus(booking.cf_order_id);
        if (cfOrder.order_status === 'PAID') {
          const confirmed = await bookingRepository.confirmBooking(booking.cf_order_id, 'DIRECT_POLL', cfOrder);
          if (confirmed) return confirmed;
        } else if (cfOrder.order_status === 'FAILED') {
          const failed = await bookingRepository.failBooking(booking.cf_order_id, cfOrder);
          if (failed) return failed;
        }
      } catch (err) {
        console.error(`[BookingService] Error checking status directly with Cashfree for booking ${bookingId}:`, err);
      }
    }

    return booking;
  }

  /**
   * Cancel booking & issue refund (validates 5-hour policy).
   */
  async cancelBooking(userId: string, bookingId: string): Promise<BookingRow> {
    const booking = await bookingRepository.findById(bookingId);
    if (!booking) {
      throw new Error('BOOKING_NOT_FOUND');
    }
    if (booking.user_id !== userId) {
      throw new Error('FORBIDDEN');
    }
    if (booking.status !== 'confirmed') {
      throw new Error('CANNOT_CANCEL_UNCONFIRMED_BOOKING');
    }

    // Validate 5-hour cancellation window
    const startTimeStr = `${booking.slot_date}T${String(booking.hours[0]).padStart(2, '0')}:00:00+05:30`;
    const startTime = new Date(startTimeStr);
    const now = new Date();
    
    const diffMs = startTime.getTime() - now.getTime();
    const diffHours = diffMs / (1000 * 60 * 60);

    if (diffHours < 5) {
      throw new Error('CANCELLATION_WINDOW_EXPIRED');
    }

    // Mark as refund pending in DB
    const updatedBooking = await bookingRepository.refundPendingBooking(bookingId);

    // Call Cashfree Refund API
    const refundId = `ref_${bookingId.split('-')[0]}_${Date.now()}`;
    await cashfreeService.initiateRefund(
      booking.cf_order_id!,
      refundId,
      parseFloat(booking.total_price),
      'User requested cancellation through App'
    );

    return updatedBooking;
  }

  /**
   * Reconciliation job to sweep stale pending payment sessions.
   */
  async reconcilePendingPayments(): Promise<void> {
    console.log('[BookingService] Running pending payments reconciliation...');
    // Find bookings pending payment older than 6 minutes
    const staleBookings = await bookingRepository.getExpiredPendingBookings(6);
    
    for (const booking of staleBookings) {
      try {
        console.log(`[BookingService] Reconciling booking ${booking.id} (${booking.cf_order_id})`);
        const cfOrder = await cashfreeService.getOrderStatus(booking.cf_order_id!);
        
        if (cfOrder.order_status === 'PAID') {
          await bookingRepository.confirmBooking(booking.cf_order_id!, 'RECONCILIATION_SYNC', cfOrder);
          console.log(`[BookingService] Reconciled: Marked confirmed (paid on gateway)`);
        } else {
          // If not paid on gateway after 6 mins, release slots and fail booking
          await bookingRepository.failBooking(booking.cf_order_id!, { status: 'reconciliation_timeout' });
          console.log(`[BookingService] Reconciled: Marked failed (unpaid after timeout)`);
        }
      } catch (err) {
        console.error(`[BookingService] Error reconciling booking ${booking.id}:`, err);
      }
    }
  }

  /**
   * Sweeps expired slot locks.
   */
  async sweepExpiredLocks(): Promise<number> {
    return bookingRepository.sweepExpiredLocks();
  }
}

export const bookingService = new BookingService();

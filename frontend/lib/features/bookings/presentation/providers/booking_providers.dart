import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:kickoff/core/network/api_exceptions.dart';
import 'package:kickoff/features/auth/presentation/providers/auth_providers.dart';
import 'package:kickoff/features/bookings/domain/booking_model.dart';

// (rest of code)
class LockResult {
  final bool success;
  final String? lockExpiresAt;
  final double totalPrice;
  final String? error;

  LockResult({
    required this.success,
    this.lockExpiresAt,
    this.totalPrice = 0.0,
    this.error,
  });
}

class CheckoutResult {
  final String? bookingId;
  final String? cfOrderId;
  final String? paymentSessionId;
  final bool? isSandbox;
  final String? error;

  CheckoutResult({
    this.bookingId,
    this.cfOrderId,
    this.paymentSessionId,
    this.isSandbox,
    this.error,
  });
}

class BookingNotifier extends StateNotifier<AsyncValue<BookingModel?>> {
  final Ref _ref;

  BookingNotifier(this._ref) : super(const AsyncValue.data(null));

  /**
   * Acquire slot lock session.
   */
  Future<LockResult> lockSlots(List<String> slotIds) async {
    final apiClient = _ref.read(apiClientProvider);
    try {
      final response = await apiClient.post('/api/bookings/lock', data: {
        'slot_ids': slotIds,
      });

      final data = response.data as Map<String, dynamic>;
      return LockResult(
        success: data['success'] as bool,
        lockExpiresAt: data['lock_expires_at'] as String?,
        totalPrice: double.parse(data['total_price'].toString()),
      );
    } catch (e) {
      String? errorMessage;
      if (e is DioException && e.error is ApiException) {
        errorMessage = e.error.toString();
      }
      return LockResult(
        success: false,
        error: errorMessage ?? e.toString(),
      );
    }
  }

  /**
   * Cancel/release active locks early.
   */
  Future<void> releaseActiveLocks() async {
    final apiClient = _ref.read(apiClientProvider);
    try {
      await apiClient.delete('/api/bookings/lock');
    } catch (e) {
      print('[releaseActiveLocks] Error releasing locks: $e');
    }
  }

  /**
   * Create Cashfree PG Checkout session.
   */
  Future<CheckoutResult> createCheckoutSession(List<String> slotIds, String idempotencyKey) async {
    final apiClient = _ref.read(apiClientProvider);
    try {
      final response = await apiClient.dio.post(
        '/api/bookings/checkout-session',
        data: {'slot_ids': slotIds},
        options: Options(
          headers: {'idempotency-key': idempotencyKey},
        ),
      );

      final data = response.data as Map<String, dynamic>;
      return CheckoutResult(
        bookingId: data['booking_id'] as String?,
        cfOrderId: data['cf_order_id'] as String?,
        paymentSessionId: data['payment_session_id'] as String?,
        isSandbox: data['is_sandbox'] as bool?,
      );
    } catch (e) {
      return CheckoutResult(
        error: e.toString(),
      );
    }
  }

  /**
   * Poll booking status.
   */
  Future<BookingStatus> getBookingStatus(String bookingId) async {
    final apiClient = _ref.read(apiClientProvider);
    final response = await apiClient.get('/api/bookings/$bookingId/status');
    final data = response.data as Map<String, dynamic>;
    final statusStr = data['status'] as String;

    if (statusStr == 'confirmed') return BookingStatus.confirmed;
    if (statusStr == 'failed') return BookingStatus.failed;
    if (statusStr == 'cancelled') return BookingStatus.cancelled;
    if (statusStr == 'refund_pending') return BookingStatus.refundPending;
    if (statusStr == 'refunded') return BookingStatus.refunded;
    return BookingStatus.pendingPayment;
  }

  /**
   * Cancel booking (issues refund).
   */
  Future<bool> cancelBooking(String bookingId) async {
    final apiClient = _ref.read(apiClientProvider);
    try {
      await apiClient.post('/api/bookings/$bookingId/cancel');
      return true;
    } catch (e) {
      return false;
    }
  }
}

final bookingProvider = StateNotifierProvider<BookingNotifier, AsyncValue<BookingModel?>>((ref) {
  return BookingNotifier(ref);
});

// Fetch user's bookings directly via Supabase client (leveraging RLS)
final userBookingsProvider = FutureProvider.autoDispose<List<BookingModel>>((ref) async {
  final supabase = Supabase.instance.client;
  
  // Joins bookings with turfs details
  final response = await supabase
      .from('bookings')
      .select('*, turfs(*)')
      .order('created_at', ascending: false);

  final List<dynamic> list = response as List<dynamic>;
  return list.map((item) => BookingModel.fromJson(item)).toList();
});

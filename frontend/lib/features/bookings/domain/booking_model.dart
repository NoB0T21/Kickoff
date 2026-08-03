import 'package:kickoff/features/turfs/domain/turf_model.dart';

enum BookingStatus { pendingPayment, confirmed, failed, cancelled, refundPending, refunded }

class BookingModel {
  final String id;
  final String userId;
  final String turfId;
  final List<String> slotIds;
  final String slotDate;
  final List<int> hours;
  final double totalPrice;
  final BookingStatus status;
  final String? cfOrderId;
  final String? paymentSessionId;
  final String? transactionId;
  final String? idempotencyKey;
  final DateTime createdAt;
  final TurfModel? turf;

  BookingModel({
    required this.id,
    required this.userId,
    required this.turfId,
    required this.slotIds,
    required this.slotDate,
    required this.hours,
    required this.totalPrice,
    required this.status,
    this.cfOrderId,
    this.paymentSessionId,
    this.transactionId,
    this.idempotencyKey,
    required this.createdAt,
    this.turf,
  });

  factory BookingModel.fromJson(Map<String, dynamic> json) {
    BookingStatus status = BookingStatus.pendingPayment;
    final statusStr = json['status'] as String;
    if (statusStr == 'confirmed') {
      status = BookingStatus.confirmed;
    } else if (statusStr == 'failed') {
      status = BookingStatus.failed;
    } else if (statusStr == 'cancelled') {
      status = BookingStatus.cancelled;
    } else if (statusStr == 'refund_pending') {
      status = BookingStatus.refundPending;
    } else if (statusStr == 'refunded') {
      status = BookingStatus.refunded;
    }

    return BookingModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      turfId: json['turf_id'] as String,
      slotIds: List<String>.from(json['slot_ids'] ?? []),
      slotDate: json['slot_date'] as String,
      hours: List<int>.from(json['hours'] ?? []),
      totalPrice: double.parse(json['total_price'].toString()),
      status: status,
      cfOrderId: json['cf_order_id'] as String?,
      paymentSessionId: json['payment_session_id'] as String?,
      transactionId: json['transaction_id'] as String?,
      idempotencyKey: json['idempotency_key'] as String?,
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      turf: json['turfs'] != null ? TurfModel.fromJson(json['turfs'] as Map<String, dynamic>) : null,
    );
  }
}

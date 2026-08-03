import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kickoff/features/bookings/presentation/providers/booking_providers.dart';
import 'package:kickoff/features/bookings/domain/booking_model.dart';
import 'package:kickoff/features/turfs/domain/turf_model.dart';
import 'package:kickoff/core/theme/app_theme.dart';

class MyBookingsScreen extends ConsumerWidget {
  const MyBookingsScreen({super.key});

  // Helper to format hours array (e.g. [13, 14] -> "13:00 - 15:00")
  String _formatHours(List<int> hours) {
    if (hours.isEmpty) return '';
    final start = hours.first;
    final end = hours.last + 1;
    return "${start.toString().padLeft(2, '0')}:00 - ${end.toString().padLeft(2, '0')}:00";
  }

  // Get status color
  Color _getStatusColor(BookingStatus status) {
    switch (status) {
      case BookingStatus.confirmed:
        return AppTheme.accentGreen;
      case BookingStatus.pendingPayment:
        return Colors.orange;
      case BookingStatus.cancelled:
      case BookingStatus.refunded:
        return Colors.grey;
      case BookingStatus.refundPending:
        return Colors.blue;
      case BookingStatus.failed:
        return Colors.red;
    }
  }

  // Format status label
  String _getStatusLabel(BookingStatus status) {
    switch (status) {
      case BookingStatus.confirmed:
        return 'Confirmed';
      case BookingStatus.pendingPayment:
        return 'Pending Payment';
      case BookingStatus.cancelled:
        return 'Cancelled';
      case BookingStatus.refundPending:
        return 'Refund Pending';
      case BookingStatus.refunded:
        return 'Refunded';
      case BookingStatus.failed:
        return 'Failed';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingsAsync = ref.watch(userBookingsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'MY BOOKINGS',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5),
        ),
      ),
      body: bookingsAsync.when(
        data: (bookings) {
          if (bookings.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.confirmation_num_outlined, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  const Text(
                    'No Bookings Yet',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  const Text('Your bookings will appear here.', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => ref.refresh(userBookingsProvider.future),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: bookings.length,
              itemBuilder: (context, index) {
                final booking = bookings[index];
                final turf = booking.turf;
                // Check if slot is expired (in the past)
                bool isExpired = false;
                try {
                  final startHour = booking.hours[0];
                  final startTime = DateTime.parse("${booking.slotDate}T${startHour.toString().padLeft(2, '0')}:00:00Z");
                  final now = DateTime.now().toUtc();
                  isExpired = now.isAfter(startTime);
                } catch (e) {
                  isExpired = false;
                }

                // Check if cancellation is allowed (> 5h)
                bool canCancel = false;
                if (!isExpired && booking.status == BookingStatus.confirmed) {
                  try {
                    final startHour = booking.hours[0];
                    final startTime = DateTime.parse("${booking.slotDate}T${startHour.toString().padLeft(2, '0')}:00:00Z");
                    final now = DateTime.now().toUtc();
                    canCancel = startTime.difference(now).inHours >= 5;
                  } catch (e) {
                    canCancel = false;
                  }
                }

                final statusColor = isExpired && booking.status == BookingStatus.confirmed
                    ? Colors.grey
                    : _getStatusColor(booking.status);

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header: Turf Name and Status
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                turf?.name ?? 'Kickoff Turf',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.primaryGreen,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                isExpired && booking.status == BookingStatus.confirmed
                                    ? 'Expired'
                                    : _getStatusLabel(booking.status),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: statusColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        // Details: Date, Time, Price
                        Row(
                          children: [
                            Icon(Icons.calendar_today_outlined, size: 16, color: Colors.grey.shade600),
                            const SizedBox(width: 8),
                            Text(
                              booking.slotDate,
                              style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade800),
                            ),
                            const Spacer(),
                            Text(
                              '₹${booking.totalPrice.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                color: AppTheme.primaryGreen,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.access_time_outlined, size: 16, color: Colors.grey.shade600),
                            const SizedBox(width: 8),
                            Text(
                              _formatHours(booking.hours),
                              style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade800),
                            ),
                          ],
                        ),
                        if (turf != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.location_on_outlined, size: 16, color: Colors.grey.shade600),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  turf.locationName,
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                        // Action Bar: Host Match and Cancel Booking
                        if (!isExpired && booking.status == BookingStatus.confirmed) ...[
                          const Divider(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (canCancel) ...[
                                OutlinedButton.icon(
                                  onPressed: () => _confirmCancelBooking(context, ref, booking.id),
                                  icon: const Icon(Icons.cancel_outlined, size: 16, color: Colors.red),
                                  label: const Text(
                                    'Cancel Booking',
                                    style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Colors.red),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                                const SizedBox(width: 12),
                              ],
                              if (booking.eventId != null) ...[
                                ElevatedButton.icon(
                                  onPressed: () {
                                    context.go('/events/${booking.eventId}');
                                  },
                                  icon: const Icon(Icons.edit, size: 16, color: Colors.white),
                                  label: const Text(
                                    'Edit Match',
                                    style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue.shade700,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ] else ...[
                                ElevatedButton.icon(
                                  onPressed: () {
                                    context.go('/events/new?booking_id=${booking.id}');
                                  },
                                  icon: const Icon(Icons.sports_soccer, size: 16, color: Colors.white),
                                  label: const Text(
                                    'Host Match',
                                    style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primaryGreen,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ] else if (!isExpired && canCancel) ...[
                          const Divider(height: 24),
                          Align(
                            alignment: Alignment.centerRight,
                            child: OutlinedButton.icon(
                              onPressed: () => _confirmCancelBooking(context, ref, booking.id),
                              icon: const Icon(Icons.cancel_outlined, size: 16, color: Colors.red),
                              label: const Text(
                                'Cancel Booking',
                                style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.red),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen)),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                const Text('Failed to load bookings', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(err.toString(), textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmCancelBooking(BuildContext context, WidgetRef ref, String bookingId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Booking'),
        content: const Text(
          'Are you sure you want to cancel this booking? A refund will be initiated to your payment source.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No, Keep It'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              // Show loading SnackBar
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Processing cancellation...'), duration: Duration(days: 1)),
              );

              final success = await ref.read(bookingProvider.notifier).cancelBooking(bookingId);

              ScaffoldMessenger.of(context).clearSnackBars();
              if (success) {
                ref.refresh(userBookingsProvider.future);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Booking cancelled successfully and refund initiated!')),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Failed to cancel booking. Please try again.')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Yes, Cancel Booking'),
          ),
        ],
      ),
    );
  }
}

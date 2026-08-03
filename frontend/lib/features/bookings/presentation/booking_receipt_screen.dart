import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kickoff/features/bookings/presentation/providers/booking_providers.dart';
import 'package:kickoff/features/bookings/domain/booking_model.dart';
import 'package:kickoff/core/theme/app_theme.dart';

class BookingReceiptScreen extends ConsumerWidget {
  final Map<String, dynamic> receiptData;

  const BookingReceiptScreen({super.key, required this.receiptData});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final bookingId = receiptData['booking_id'] as String;

    return Scaffold(
      body: FutureBuilder<BookingStatus>(
        future: ref.read(bookingProvider.notifier).getBookingStatus(bookingId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryGreen),
            );
          }

          final status = snapshot.data ?? BookingStatus.pendingPayment;
          final isSuccess = status == BookingStatus.confirmed;

          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Icon Status Indicator
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: isSuccess ? Colors.green.shade50 : Colors.red.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isSuccess ? Icons.check_circle : Icons.cancel,
                      color: isSuccess ? Colors.green.shade700 : Colors.red.shade700,
                      size: 80,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Title
                  Text(
                    isSuccess ? 'Booking Confirmed!' : 'Payment Failed',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: isSuccess ? Colors.green.shade800 : Colors.red.shade800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Description
                  Text(
                    isSuccess
                        ? 'Your turf reservation is secured. You can view details in your bookings tab.'
                        : 'The payment transaction could not be processed. If money was debited, it will be refunded.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600], height: 1.5, fontSize: 14),
                  ),
                  const SizedBox(height: 36),

                  // Invoice Details
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
                      ],
                      border: Border.all(color: Colors.grey.shade100),
                    ),
                    child: Column(
                      children: [
                        _buildRow('Booking ID', bookingId.split('-')[0].toUpperCase()),
                        const SizedBox(height: 12),
                        _buildRow('Status', isSuccess ? 'PAID' : 'FAILED', valueColor: isSuccess ? Colors.green : Colors.red),
                        const SizedBox(height: 12),
                        _buildRow('Platform', 'Kickoff App'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 48),

                  // Action buttons
                  if (isSuccess) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () {
                          context.go('/events/new?booking_id=$bookingId');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryGreen,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text(
                          'Host a Match / Event',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton(
                        onPressed: () {
                          ref.refresh(userBookingsProvider.future);
                          context.go('/');
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppTheme.primaryGreen, width: 2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text(
                          'Back to Dashboard',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryGreen),
                        ),
                      ),
                    ),
                  ] else ...[
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () {
                          ref.refresh(userBookingsProvider.future);
                          context.go('/');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryGreen,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text(
                          'Back to Dashboard',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
  }

  Widget _buildRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.grey, fontSize: 14),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 14,
            color: valueColor ?? Colors.black87,
          ),
        ),
      ],
    );
  }
}

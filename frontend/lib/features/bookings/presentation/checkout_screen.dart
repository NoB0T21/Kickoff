import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';
import 'dart:math';
import 'package:kickoff/features/bookings/presentation/providers/booking_providers.dart';
import 'package:kickoff/core/theme/app_theme.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> checkoutData;

  const CheckoutScreen({super.key, required this.checkoutData});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  Timer? _timer;
  Duration _timeLeft = const Duration(minutes: 5);
  late DateTime _expiryTime;
  bool _isExpired = false;

  @override
  void initState() {
    super.initState();
    _initTimer();
  }

  void _initTimer() {
    final expiryStr = widget.checkoutData['lock_expires_at'] as String?;
    if (expiryStr != null) {
      _expiryTime = DateTime.parse(expiryStr).toLocal();
      _calculateTimeLeft();
      
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        _calculateTimeLeft();
      });
    } else {
      // Default fallback
      _expiryTime = DateTime.now().add(const Duration(minutes: 5));
    }
  }

  void _calculateTimeLeft() {
    final now = DateTime.now();
    final difference = _expiryTime.difference(now);

    if (difference.isNegative || difference.inSeconds <= 0) {
      setState(() {
        _timeLeft = Duration.zero;
        _isExpired = true;
      });
      _timer?.cancel();
      _handleLockExpired();
    } else {
      setState(() {
        _timeLeft = difference;
      });
    }
  }

  void _handleLockExpired() {
    // Release locks early on API
    ref.read(bookingProvider.notifier).releaseActiveLocks();
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Session Expired'),
        content: const Text(
          'Your temporary lock on these slots has expired. Please select the slots again.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Dismiss dialog
              context.pop(); // Go back to slots detail screen
            },
            child: const Text('Back to Slots'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // Format duration to mm:ss
  String _formatDuration(Duration duration) {
    String minutes = duration.inMinutes.toString().padLeft(2, '0');
    String seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final turfName = widget.checkoutData['turf_name'] as String;
    final slotDate = widget.checkoutData['slot_date'] as String;
    final slotIds = widget.checkoutData['slot_ids'] as List<String>;
    final totalPrice = widget.checkoutData['total_price'] as double;

    return WillPopScope(
      onWillPop: () async {
        // Release locks early when user clicks back
        await ref.read(bookingProvider.notifier).releaseActiveLocks();
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'CHECKOUT',
            style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              await ref.read(bookingProvider.notifier).releaseActiveLocks();
              if (context.mounted) {
                context.pop();
              }
            },
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Countdown Expiry Card ──
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _isExpired ? Colors.red.shade50 : Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _isExpired ? Colors.red.shade200 : Colors.amber.shade300,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isExpired ? Icons.error_outline : Icons.alarm,
                      color: _isExpired ? Colors.red : Colors.amber.shade900,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isExpired ? 'Session Expired' : 'Complete payment in:',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _isExpired ? Colors.red : Colors.amber.shade900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _formatDuration(_timeLeft),
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: _isExpired ? Colors.red : Colors.amber.shade900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // ── Booking Summary Card ──
              Text('Booking Summary', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: AppTheme.primaryGreen)),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      turfName,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.primaryGreen),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined, size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text(slotDate, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.timer_outlined, size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text('${slotIds.length} hour(s) selected', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // ── Price Breakdown ──
              Text('Price Breakdown', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: AppTheme.primaryGreen)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3)),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Court Rental (${slotIds.length} hrs)', style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
                        Text('₹${totalPrice.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Convenience Fee', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
                        Text('₹0.00', style: TextStyle(fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Amount Payable', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppTheme.primaryGreen)),
                        Text(
                          '₹${totalPrice.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppTheme.accentGreen),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Spacer(),

              // ── Action Pay Button ──
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isExpired ? null : _proceedToPayment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentGreen,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text(
                    'Proceed to Payment',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 0.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _proceedToPayment() async {
    // Show launching overlay
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(color: AppTheme.primaryGreen),
            SizedBox(width: 24),
            Text('Creating payment session...', style: TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );

    // Generate unique idempotency key
    final rand = Random();
    final idempotencyKey = "idemp_${DateTime.now().millisecondsSinceEpoch}_${rand.nextInt(100000)}";
    final slotIds = widget.checkoutData['slot_ids'] as List<String>;

    final result = await ref.read(bookingProvider.notifier).createCheckoutSession(
      slotIds,
      idempotencyKey,
    );

    // Dismiss overlay
    if (mounted) Navigator.pop(context);

    if (result.error != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to initiate payment: ${result.error}'), backgroundColor: Colors.red),
        );
      }
    } else {
      if (mounted) {
        // Navigate to payment Webview
        context.push('/checkout/pay', extra: {
          'booking_id': result.bookingId,
          'cf_order_id': result.cfOrderId,
          'payment_session_id': result.paymentSessionId,
          'is_sandbox': result.isSandbox,
        });
      }
    }
  }
}

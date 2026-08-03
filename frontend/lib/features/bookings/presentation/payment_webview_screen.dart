import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:async';
import 'package:kickoff/features/bookings/presentation/providers/booking_providers.dart';
import 'package:kickoff/features/bookings/domain/booking_model.dart';
import 'package:kickoff/core/theme/app_theme.dart';
import 'package:kickoff/core/constants/constants.dart';

class PaymentWebviewScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> paymentData;

  const PaymentWebviewScreen({super.key, required this.paymentData});

  @override
  ConsumerState<PaymentWebviewScreen> createState() => _PaymentWebviewScreenState();
}

class _PaymentWebviewScreenState extends ConsumerState<PaymentWebviewScreen> {
  late final WebViewController _controller;
  Timer? _statusTimer;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initWebview();
    _startStatusPolling();
  }

  void _initWebview() {
    final sessionToken = widget.paymentData['payment_session_id'] as String;
    final isSandbox = widget.paymentData['is_sandbox'] as bool? ?? true;
    final mode = isSandbox ? "sandbox" : "production";
    final baseUrl = isSandbox ? "https://payments-test.cashfree.com" : "https://payments.cashfree.com";

    final htmlContent = """
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <script src="https://sdk.cashfree.com/js/v3/cashfree.js"></script>
  <style>
    body {
      margin: 0;
      padding: 0;
      display: flex;
      justify-content: center;
      align-items: center;
      height: 100vh;
      background-color: #ffffff;
    }
    .loader {
      border: 4px solid #f3f3f3;
      border-top: 4px solid #1E4D2B;
      border-radius: 50%;
      width: 40px;
      height: 40px;
      animation: spin 1s linear infinite;
    }
    @keyframes spin {
      0% { transform: rotate(0deg); }
      100% { transform: rotate(360deg); }
    }
  </style>
</head>
<body>
  <div class="loader"></div>
  <script>
    document.addEventListener("DOMContentLoaded", function() {
      try {
        const cashfree = Cashfree({ mode: "$mode" });
        cashfree.checkout({
          paymentSessionId: "$sessionToken",
          redirectTarget: "_self"
        });
      } catch (e) {
        document.body.innerHTML = "<div style='color: red; font-weight: bold; font-family: sans-serif; text-align: center; padding: 20px;'>Initialization Error: " + e.message + "</div>";
      }
    });
  </script>
</body>
</html>
""";

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint("Webview Error: ${error.description}");
          },
          onNavigationRequest: (NavigationRequest request) {
            final url = request.url;
            if (url.contains('api/v2/payment/status') || url.contains('kickoff.local/payment-callback')) {
              _statusTimer?.cancel();
              final bookingId = widget.paymentData['booking_id'] as String;
              if (mounted) {
                context.go('/checkout/receipt', extra: {
                  'booking_id': bookingId,
                  'status': 'confirmed', // receipt page will check the DB status to display the actual results
                });
              }
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadHtmlString(htmlContent, baseUrl: baseUrl);
  }

  void _startStatusPolling() {
    final bookingId = widget.paymentData['booking_id'] as String;
    
    // Poll booking status every 3 seconds
    _statusTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      try {
        final status = await ref.read(bookingProvider.notifier).getBookingStatus(bookingId);
        
        if (status == BookingStatus.confirmed || status == BookingStatus.failed) {
          _statusTimer?.cancel();
          if (mounted) {
            context.go('/checkout/receipt', extra: {
              'booking_id': bookingId,
              'status': status.name,
            });
          }
        }
      } catch (e) {
        // Ignore check error during webview navigation
      }
    });
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PAYMENT GATEWAY'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            // Confirm early exit
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Cancel Payment?'),
                content: const Text(
                  'If you go back now, your payment session might be interrupted. Are you sure?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Stay'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context); // Dismiss dialog
                      _statusTimer?.cancel();
                      context.go('/'); // Go back to home dashboard
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    child: const Text('Exit'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryGreen),
            ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/domain/auth_state.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/signup_screen.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/otp_screen.dart';
import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/profile/presentation/onboarding_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/dashboard/presentation/main_navigation_screen.dart';
import '../../features/turfs/presentation/turf_detail_screen.dart';
import '../../features/bookings/presentation/checkout_screen.dart';
import '../../features/bookings/presentation/payment_webview_screen.dart';
import '../../features/bookings/presentation/booking_receipt_screen.dart';

class RouterRefreshListenable extends ChangeNotifier {
  RouterRefreshListenable(Ref ref) {
    ref.listen<AuthState>(
      authStateProvider,
      (previous, next) {
        if (previous?.status != next.status) {
          notifyListeners();
        }
      },
    );
  }
}

final routerRefreshListenableProvider = Provider<RouterRefreshListenable>((ref) {
  return RouterRefreshListenable(ref);
});

/// GoRouter configuration with auth-aware redirects.
final routerProvider = Provider<GoRouter>((ref) {
  final listenable = ref.watch(routerRefreshListenableProvider);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: listenable,
    redirect: (context, state) {
      final authState = ref.read(authStateProvider);
      final path = state.uri.path;

      // While auth is loading, stay on splash
      if (authState.status == AuthStatus.initial) {
        return path == '/splash' ? null : '/splash';
      }

      // Unauthenticated: only allow auth routes
      if (authState.status == AuthStatus.unauthenticated) {
        if (path == '/login' || path == '/signup' || path == '/forgot-password' || path == '/otp') {
          return null;
        }
        return '/login';
      }

      // Needs onboarding
      if (authState.status == AuthStatus.onboarding) {
        if (path == '/onboarding') return null;
        return '/onboarding';
      }

      // Authenticated: redirect away from auth routes
      if (authState.status == AuthStatus.authenticated) {
        if (path == '/login' || path == '/signup' || path == '/onboarding' || path == '/splash') {
          return '/';
        }
        return null;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const _SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => LoginScreen(
          onSignUpTap: () => context.go('/signup'),
          onForgotPasswordTap: () => context.go('/forgot-password'),
        ),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => SignUpScreen(
          onSignInTap: () => context.go('/login'),
        ),
      ),
      GoRoute(
        path: '/otp',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final email = extra?['email'] as String? ?? '';
          final password = extra?['password'] as String? ?? '';
          return OtpScreen(email: email, password: password);
        },
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => ForgotPasswordScreen(
          onBackToLogin: () => context.go('/login'),
        ),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const MainNavigationScreen(),
      ),
      GoRoute(
        path: '/profile/:id',
        builder: (context, state) => ProfileScreen(
          userId: state.pathParameters['id'],
        ),
      ),
      GoRoute(
        path: '/turfs/:id',
        builder: (context, state) => TurfDetailScreen(
          turfId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/checkout',
        builder: (context, state) => CheckoutScreen(
          checkoutData: state.extra as Map<String, dynamic>,
        ),
      ),
      GoRoute(
        path: '/checkout/pay',
        builder: (context, state) => PaymentWebviewScreen(
          paymentData: state.extra as Map<String, dynamic>,
        ),
      ),
      GoRoute(
        path: '/checkout/receipt',
        builder: (context, state) => BookingReceiptScreen(
          receiptData: state.extra as Map<String, dynamic>,
        ),
      ),
    ],
  );
});

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sports_soccer, size: 64, color: Color(0xFF1E4D2B)),
            SizedBox(height: 16),
            CircularProgressIndicator(color: Color(0xFF1E4D2B)),
          ],
        ),
      ),
    );
  }
}

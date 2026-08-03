import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kickoff/core/network/api_client.dart';
import 'package:kickoff/core/network/api_exceptions.dart';
import 'package:kickoff/features/auth/data/auth_repository.dart';
import 'package:kickoff/features/auth/domain/auth_state.dart' as app;
import 'package:kickoff/features/profile/presentation/providers/profile_providers.dart';

// ── Singletons ──

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(apiClient: ref.watch(apiClientProvider));
});

// ── Auth State Notifier ──

final authStateProvider =
    StateNotifierProvider<AuthNotifier, app.AuthState>((ref) {
  return AuthNotifier(ref);
});

class AuthNotifier extends StateNotifier<app.AuthState> {
  final Ref _ref;
  StreamSubscription? _authSubscription;

  AuthNotifier(this._ref) : super(const app.AuthState()) {
    _init();
  }

  void _init() {
    // Listen to backend-brokered auth state changes
    _authSubscription =
        _ref.read(authRepositoryProvider).authStateChanges.listen((event) {
      _handleAuthChange(event);
    });

    // Check initial session
    _ref.read(authRepositoryProvider).currentSession.then((session) {
      if (session != null) {
        _checkOnboardingStatus();
      } else {
        state = state.copyWith(status: app.AuthStatus.unauthenticated);
      }
    });
  }

  Future<void> _handleAuthChange(AuthStateChangeEvent event) async {
    switch (event.event) {
      case AuthChangeEvent.signedIn:
      case AuthChangeEvent.tokenRefreshed:
      case AuthChangeEvent.initialSession:
        await _checkOnboardingStatus();
        break;
      case AuthChangeEvent.signedOut:
        state = state.copyWith(
          status: app.AuthStatus.unauthenticated,
          errorMessage: null,
        );
        break;
      default:
        break;
    }
  }

  Future<void> _checkOnboardingStatus() async {
    try {
      final profileNotifier = _ref.read(profileProvider.notifier);
      await profileNotifier.loadMyProfile();
      final profile = _ref.read(profileProvider).profile;

      if (profile != null && profile.hasCompletedOnboarding) {
        state = state.copyWith(status: app.AuthStatus.authenticated, errorMessage: null);
      } else {
        state = state.copyWith(status: app.AuthStatus.onboarding, errorMessage: null);
      }
    } catch (e, stackTrace) {
      print('[AuthNotifier] Check onboarding status failed: $e\n$stackTrace');
      
      ApiException? apiException;
      if (e is DioException && e.error is ApiException) {
        apiException = e.error as ApiException;
      } else if (e is ApiException) {
        apiException = e;
      }

      if (apiException is ProfileNotFoundException) {
        state = state.copyWith(status: app.AuthStatus.onboarding, errorMessage: null);
      } else if (apiException is UnauthenticatedException) {
        state = state.copyWith(status: app.AuthStatus.unauthenticated, errorMessage: null);
        _ref.read(authRepositoryProvider).signOut();
      } else {
        // Unexpected error (e.g. server down, offline) — default to onboarding setup
        state = state.copyWith(status: app.AuthStatus.onboarding, errorMessage: null);
      }
    }
  }

  Future<bool> signUpWithEmail(String email, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _ref.read(authRepositoryProvider).signUpWithEmail(email, password);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e, stackTrace) {
      state = state.copyWith(isLoading: false, errorMessage: _friendlyError(e));
      return false;
    }
  }

  Future<bool> verifyOtp(String email, String password, String token) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _ref.read(authRepositoryProvider).verifyOtp(
            email: email,
            password: password,
            token: token,
          );
      // Auto sign-in client side after successful backend confirmation
      await _ref.read(authRepositoryProvider).signInWithEmail(email, password);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e, stackTrace) {
      print('[AuthNotifier] Verify OTP failed: $e\n$stackTrace');
      state = state.copyWith(isLoading: false, errorMessage: _friendlyError(e));
      return false;
    }
  }

  Future<void> signInWithEmail(String email, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _ref.read(authRepositoryProvider).signInWithEmail(email, password);
      state = state.copyWith(isLoading: false);
    } catch (e, stackTrace) {
      print('[AuthNotifier] Sign in with email failed: $e\n$stackTrace');
      state = state.copyWith(isLoading: false, errorMessage: _friendlyError(e));
    }
  }

  Future<void> signInWithGoogle() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _ref.read(authRepositoryProvider).signInWithGoogle();
      state = state.copyWith(isLoading: false);
    } catch (e, stackTrace) {
      print(stackTrace);
      print('[AuthNotifier] Google Sign-in failed: $e\n$stackTrace');
      state = state.copyWith(isLoading: false, errorMessage: _friendlyError(e));
    }
  }

  Future<void> signInWithApple() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _ref.read(authRepositoryProvider).signInWithApple();
      state = state.copyWith(isLoading: false);
    } catch (e, stackTrace) {
      print('[AuthNotifier] Apple Sign-in failed: $e\n$stackTrace');
      state = state.copyWith(isLoading: false, errorMessage: _friendlyError(e));
    }
  }

  Future<void> forgotPassword(String email) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _ref.read(authRepositoryProvider).forgotPassword(email);
      state = state.copyWith(isLoading: false);
    } catch (e, stackTrace) {
      print('[AuthNotifier] Forgot password request failed: $e\n$stackTrace');
      state = state.copyWith(isLoading: false, errorMessage: _friendlyError(e));
    }
  }

  Future<void> signOut() async {
    try {
      await _ref.read(authRepositoryProvider).signOut();
    } catch (e, stackTrace) {
      print('[AuthNotifier] Sign out failed: $e\n$stackTrace');
    }
  }

  /// After onboarding completes, refresh the auth status.
  Future<void> onOnboardingComplete() async {
    state = state.copyWith(status: app.AuthStatus.authenticated);
  }

  String _friendlyError(Object e) {
    final msg = e.toString();
    if (msg.contains('Invalid credentials') || msg.contains('Invalid login credentials')) {
      return 'Invalid email or password.';
    }
    if (msg.contains('User already registered')) {
      return 'An account with this email already exists.';
    }
    if (msg.contains('cancelled') || msg.contains('cancelled.')) {
      return 'Sign-in was cancelled.';
    }
    if (msg.contains('Failed to get Google ID token')) {
      return 'Google ID token missing. Verify GOOGLE_WEB_CLIENT_ID configuration.';
    }
    if (msg.contains('DioException') || msg.contains('SocketException') || msg.contains('connection timeout')) {
      return 'Connection timed out. Verify backend is running and accessible.';
    }
    return 'Something went wrong. Please try again.';
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}

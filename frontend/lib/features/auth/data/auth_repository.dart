import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:kickoff/core/network/api_client.dart';

/// Auth repository — handles all authentication operations.
/// Uses Supabase Auth directly for login/signup/OAuth/token management.
/// Uses the backend API for password reset (for consistent error shaping).
class AuthRepository {
  final ApiClient _apiClient;
  final SupabaseClient _supabase;

  AuthRepository({required ApiClient apiClient})
    : _apiClient = apiClient,
      _supabase = Supabase.instance.client;

  /// Sign up with email and password via backend custom OTP.
  Future<void> signUpWithEmail(String email, String password) async {
    await _apiClient.post(
      '/api/auth/signup-otp',
      data: {'email': email, 'password': password},
    );
  }

  /// Verify OTP code via backend.
  Future<void> verifyOtp({
    required String email,
    required String password,
    required String token,
  }) async {
    await _apiClient.post(
      '/api/auth/verify-signup-otp',
      data: {'email': email, 'password': password, 'token': token},
    );
  }

  /// Sign in with email and password.
  Future<AuthResponse> signInWithEmail(String email, String password) async {
    return await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  /// Sign in with Google (native SDK + Supabase token exchange).
  Future<AuthResponse> signInWithGoogle() async {
    print("GOOGLE_WEB_CLIENT_ID");

    const webClientId = String.fromEnvironment(
      'GOOGLE_WEB_CLIENT_ID',
      defaultValue:
          '926469762744-lpgtasm8r746isahbpnjrn3kjjjpd0a8.apps.googleusercontent.com',
    );

    final googleSignIn = GoogleSignIn(
      serverClientId: webClientId.isNotEmpty ? webClientId : null,
    );

    
    final googleUser = await googleSignIn.signIn();
    print(webClientId);
    print(googleUser);
    if (googleUser == null) {
      throw Exception('Google sign-in was cancelled.');
    }

    final googleAuth = await googleUser.authentication;
    print("googleAuth: $googleAuth");
    final idToken = googleAuth.idToken;
    final accessToken = googleAuth.accessToken;

    if (idToken == null) {
      throw Exception('Failed to get Google ID token.');
    }

    return await _supabase.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: accessToken,
    );
  }

  /// Sign in with Apple (iOS only).
  Future<bool> signInWithApple() async {
    return await _supabase.auth.signInWithOAuth(
      OAuthProvider.apple,
      redirectTo: 'io.supabase.kickoff://login-callback/',
    );
  }

  /// Request a password reset email via the backend API (enumeration-safe).
  Future<void> forgotPassword(String email) async {
    await _apiClient.post('/api/auth/forgot-password', data: {'email': email});
  }

  /// Sign out.
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  /// Get the current session (nullable).
  Session? get currentSession => _supabase.auth.currentSession;

  /// Get the current user (nullable).
  User? get currentUser => _supabase.auth.currentUser;

  /// Stream of auth state changes.
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;
}

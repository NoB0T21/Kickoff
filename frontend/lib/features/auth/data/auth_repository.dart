import 'dart:async';
import 'dart:convert';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kickoff/core/network/api_client.dart';

enum AuthChangeEvent {
  initialSession,
  signedIn,
  signedOut,
  tokenRefreshed,
}

class AuthStateChangeEvent {
  final AuthChangeEvent event;
  final Session? session;

  AuthStateChangeEvent(this.event, this.session);
}

class User {
  final String id;
  final String email;
  final Map<String, dynamic>? userMetadata;

  User({required this.id, required this.email, this.userMetadata});
}

class Session {
  final String accessToken;
  final String refreshToken;
  final User user;

  Session({required this.accessToken, required this.refreshToken, required this.user});
}

/// Auth repository — handles all authentication operations.
/// All authentication calls are proxied through the backend API.
class AuthRepository {
  final ApiClient _apiClient;
  final _authStateController = StreamController<AuthStateChangeEvent>.broadcast();

  AuthRepository({required ApiClient apiClient}) : _apiClient = apiClient {
    // Check initial session and emit auth state change
    Timer(const Duration(milliseconds: 100), () async {
      final session = await currentSession;
      if (session != null) {
        _authStateController.add(AuthStateChangeEvent(AuthChangeEvent.initialSession, session));
      } else {
        _authStateController.add(AuthStateChangeEvent(AuthChangeEvent.signedOut, null));
      }
    });
  }

  /// Stream of auth state changes.
  Stream<AuthStateChangeEvent> get authStateChanges => _authStateController.stream;

  /// Get the current session (nullable).
  Future<Session?> get currentSession async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('access_token');
    final refreshToken = prefs.getString('refresh_token');
    if (accessToken == null || refreshToken == null) return null;
    final user = _parseUserFromToken(accessToken);
    if (user == null) return null;
    return Session(accessToken: accessToken, refreshToken: refreshToken, user: user);
  }

  /// Get the current user (nullable).
  Future<User?> get currentUser async {
    final session = await currentSession;
    return session?.user;
  }

  User? _parseUserFromToken(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final payload = parts[1];
      var normalized = base64Url.normalize(payload);
      final resp = utf8.decode(base64Url.decode(normalized));
      final map = json.decode(resp) as Map<String, dynamic>;
      final id = map['sub'] as String;
      final email = map['email'] as String? ?? '';
      final meta = map['user_metadata'] as Map<String, dynamic>?;
      return User(id: id, email: email, userMetadata: meta);
    } catch (e) {
      print('[AuthRepository] Error parsing user from token: $e');
    }
    return null;
  }

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
  Future<Session> signInWithEmail(String email, String password) async {
    final response = await _apiClient.post(
      '/api/auth/login',
      data: {'email': email, 'password': password},
    );

    final data = response.data as Map<String, dynamic>;
    final sessionData = data['session'] as Map<String, dynamic>;
    final accessToken = sessionData['access_token'] as String;
    final refreshToken = sessionData['refresh_token'] as String;
    final user = _parseUserFromToken(accessToken)!;

    final session = Session(accessToken: accessToken, refreshToken: refreshToken, user: user);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', accessToken);
    await prefs.setString('refresh_token', refreshToken);

    _authStateController.add(AuthStateChangeEvent(AuthChangeEvent.signedIn, session));
    return session;
  }

  /// Sign in with Google (native SDK + backend token exchange).
  Future<Session> signInWithGoogle() async {
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

    final response = await _apiClient.post(
      '/api/auth/google-login',
      data: {
        'id_token': idToken,
        'access_token': accessToken,
      },
    );

    final data = response.data as Map<String, dynamic>;
    final sessionData = data['session'] as Map<String, dynamic>;
    final returnedAccessToken = sessionData['access_token'] as String;
    final returnedRefreshToken = sessionData['refresh_token'] as String;
    final user = _parseUserFromToken(returnedAccessToken)!;

    final session = Session(accessToken: returnedAccessToken, refreshToken: returnedRefreshToken, user: user);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', returnedAccessToken);
    await prefs.setString('refresh_token', returnedRefreshToken);

    _authStateController.add(AuthStateChangeEvent(AuthChangeEvent.signedIn, session));
    return session;
  }

  /// Sign in with Apple (iOS only).
  Future<bool> signInWithApple() async {
    // Apple login will be implemented as OAuth exchange in a future iteration
    throw Exception('Apple Sign-in is not supported on this platform.');
  }

  /// Request a password reset email via the backend API (enumeration-safe).
  Future<void> forgotPassword(String email) async {
    await _apiClient.post('/api/auth/forgot-password', data: {'email': email});
  }

  /// Sign out.
  Future<void> signOut() async {
    try {
      await _apiClient.post('/api/auth/logout');
    } catch (e) {
      print('[AuthRepository] Logout backend request failed: $e');
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');

    _authStateController.add(AuthStateChangeEvent(AuthChangeEvent.signedOut, null));
  }
}

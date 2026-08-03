import 'package:dio/dio.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/constants.dart';
import 'api_exceptions.dart';

bool isTokenExpired(String token) {
  try {
    final parts = token.split('.');
    if (parts.length != 3) return true;
    final payload = parts[1];
    var normalized = base64Url.normalize(payload);
    final resp = utf8.decode(base64Url.decode(normalized));
    final map = json.decode(resp) as Map<String, dynamic>;
    if (map.containsKey('exp')) {
      final exp = map['exp'] as int;
      final expiryDate = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      return expiryDate.isBefore(DateTime.now().add(const Duration(seconds: 60)));
    }
  } catch (e) {
    print('[isTokenExpired] Error parsing JWT: $e');
  }
  return true;
}

/// Dio HTTP client configured for the Fastify backend API.
/// Auto-attaches the JWT token to every request.
class ApiClient {
  late final Dio _dio;

  ApiClient() {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.apiBaseUrl,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // Interceptor: auto-attach JWT token
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (options.path == '/api/auth/refresh' ||
              options.path == '/api/auth/login' ||
              options.path == '/api/auth/signup-otp' ||
              options.path == '/api/auth/verify-signup-otp') {
            return handler.next(options);
          }

          final prefs = await SharedPreferences.getInstance();
          var accessToken = prefs.getString('access_token');
          final refreshToken = prefs.getString('refresh_token');

          if (accessToken != null) {
            if (isTokenExpired(accessToken) && refreshToken != null) {
              try {
                final refreshDio = Dio(BaseOptions(baseUrl: AppConstants.apiBaseUrl));
                final refreshResponse = await refreshDio.post(
                  '/api/auth/refresh',
                  data: {'refresh_token': refreshToken},
                );

                final data = refreshResponse.data as Map<String, dynamic>;
                final session = data['session'] as Map<String, dynamic>;
                accessToken = session['access_token'] as String;
                final newRefreshToken = session['refresh_token'] as String;

                await prefs.setString('access_token', accessToken);
                await prefs.setString('refresh_token', newRefreshToken);
              } catch (e) {
                print('[api_client] Auto-refresh failed: $e');
                await prefs.remove('access_token');
                await prefs.remove('refresh_token');
                accessToken = null;
              }
            }

            if (accessToken != null) {
              options.headers['Authorization'] = 'Bearer $accessToken';
            }
          }
          return handler.next(options);
        },
        onError: (error, handler) {
          final data = error.response?.data;

          if (data is Map<String, dynamic>) {
            final err = data['error'];

            if (err is Map<String, dynamic>) {
              handler.reject(
                DioException(
                  requestOptions: error.requestOptions,
                  response: error.response,
                  type: error.type,
                  error: ApiException.fromCode(
                    code: err['code'] ?? 'UNKNOWN_ERROR',
                    message: err['message'] ?? 'Unknown error',
                    statusCode: error.response?.statusCode ?? 500,
                  ),
                ),
              );
              return;
            }
          }

          handler.next(error);
        },
      ),
    );
  }

  Dio get dio => _dio;

  // ── Convenience methods ──

  Future<Response> get(String path, {Map<String, dynamic>? queryParameters}) {
    return _dio.get(path, queryParameters: queryParameters);
  }

  Future<Response> post(String path, {Object? data}) {
    return _dio.post(path, data: data);
  }

  Future<Response> put(String path, {Object? data}) {
    return _dio.put(path, data: data);
  }

  Future<Response> delete(String path) {
    return _dio.delete(path);
  }
}

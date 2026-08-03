import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/constants.dart';
import 'api_exceptions.dart';

/// Dio HTTP client configured for the Fastify backend API.
/// Auto-attaches the Supabase JWT token to every request.
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

    // Interceptor: auto-attach JWT token from Supabase Auth session
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          var session = Supabase.instance.client.auth.currentSession;
          if (session != null) {
            if (session.isExpired) {
              try {
                final response = await Supabase.instance.client.auth.refreshSession();
                session = response.session;
              } catch (_) {
                // If refresh fails, let it proceed with the old token to get 401
              }
            }
            if (session != null) {
              options.headers['Authorization'] = 'Bearer ${session.accessToken}';
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

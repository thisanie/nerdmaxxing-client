import 'package:dio/dio.dart';
import 'token_storage.dart';

/// Thrown for any non-2xx API response, carrying the server's `detail` message.
class ApiException implements Exception {
  final int? statusCode;
  final String message;
  ApiException(this.statusCode, this.message);

  @override
  String toString() => message;
}

/// Wraps Dio with base URL, auth header injection, and automatic token refresh.
class ApiClient {
  static const String baseUrl = String.fromEnvironment(
    'NM_API_BASE_URL',
    defaultValue: 'https://nerdmaxxing-server-seven.vercel.app/api/v1',
  );

  final Dio _dio;
  final TokenStorage tokenStorage;

  /// Called when a refresh attempt fails, so the app can force a sign-out.
  void Function()? onSessionExpired;

  ApiClient({required this.tokenStorage})
      : _dio = Dio(BaseOptions(baseUrl: baseUrl, connectTimeout: const Duration(seconds: 15))) {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        if (options.extra['skipAuth'] != true) {
          final token = await tokenStorage.accessToken;
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        final isAuthCall = error.requestOptions.path.contains('/auth/');
        if (error.response?.statusCode == 401 && !isAuthCall) {
          final refreshed = await _tryRefresh();
          if (refreshed) {
            try {
              final clone = await _dio.fetch(error.requestOptions);
              return handler.resolve(clone);
            } catch (_) {
              // fall through to original error
            }
          } else {
            onSessionExpired?.call();
          }
        }
        handler.next(error);
      },
    ));
  }

  bool _refreshing = false;

  Future<bool> _tryRefresh() async {
    if (_refreshing) return false;
    _refreshing = true;
    try {
      final refreshToken = await tokenStorage.refreshToken;
      if (refreshToken == null) return false;
      final response = await _dio.post(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
        options: Options(extra: {'skipAuth': true}),
      );
      final data = response.data as Map<String, dynamic>;
      final userId = await tokenStorage.userId ?? '';
      await tokenStorage.saveTokens(
        accessToken: data['access_token'],
        refreshToken: data['refresh_token'],
        userId: userId,
      );
      return true;
    } catch (_) {
      return false;
    } finally {
      _refreshing = false;
    }
  }

  Future<dynamic> _unwrap(Future<Response> Function() request) async {
    try {
      final response = await request();
      return response.data;
    } on DioException catch (e) {
      final data = e.response?.data;
      String message = 'Something went wrong. Please try again.';
      if (data is Map && data['detail'] != null) {
        final detail = data['detail'];
        if (detail is String) {
          message = detail;
        } else if (detail is List && detail.isNotEmpty) {
          message = detail.map((d) => d['msg'] ?? d.toString()).join('\n');
        }
      } else if (e.response == null) {
        // No response reached the app: connection refused, timeout, or a
        // CORS-blocked request on web all surface this way.
        message = 'Could not reach the server. Check your connection or CORS configuration.';
      }
      throw ApiException(e.response?.statusCode, message);
    }
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? query, bool skipAuth = false}) {
    return _unwrap(() => _dio.get(path,
        queryParameters: query, options: Options(extra: {'skipAuth': skipAuth})));
  }

  Future<dynamic> post(String path, {Object? data, bool skipAuth = false}) {
    return _unwrap(
        () => _dio.post(path, data: data, options: Options(extra: {'skipAuth': skipAuth})));
  }

  Future<dynamic> patch(String path, {Object? data, bool skipAuth = false}) {
    return _unwrap(
        () => _dio.patch(path, data: data, options: Options(extra: {'skipAuth': skipAuth})));
  }
}

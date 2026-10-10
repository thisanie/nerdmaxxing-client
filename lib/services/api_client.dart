import 'dart:developer' as developer;

import 'package:dio/dio.dart';

import 'token_storage.dart';

/// Thrown for any non-2xx API response (or a request that never got one).
///
/// `statusCode` and `message` keep their original meaning and the positional
/// constructor is unchanged, so existing `ApiException(404, 'x')` call sites
/// and `e.message` reads keep working. The extra fields are optional and
/// exist so the UI can classify errors without sniffing message strings.
class ApiException implements Exception {
  final int? statusCode;
  final String message;

  /// No response was received because the device couldn't reach the server
  /// (offline, DNS failure, connection refused, connect timeout).
  final bool isNetworkError;

  /// The request timed out (connect, send or receive).
  final bool isTimeout;

  /// Server-issued request id (`x-request-id` / `x-vercel-id`), for logs.
  final String? requestId;
  final String? method;
  final String? path;

  ApiException(
    this.statusCode,
    this.message, {
    this.isNetworkError = false,
    this.isTimeout = false,
    this.requestId,
    this.method,
    this.path,
  });

  bool get isServerError => (statusCode ?? 0) >= 500;
  bool get isNotFound => statusCode == 404;
  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => message;
}

enum _RefreshOutcome {
  /// New tokens saved.
  ok,

  /// The server rejected the refresh token (or there is none): session is over.
  rejected,

  /// Couldn't tell (offline, timeout, 5xx). Do NOT sign the user out.
  unavailable,
}

/// Wraps Dio with base URL, auth header injection, and automatic token refresh.
class ApiClient {
  static const String _configuredBaseUrl = String.fromEnvironment(
    'NM_API_BASE_URL',
    defaultValue: 'https://nerdmaxxing-server-seven.vercel.app/api/v1',
  );
  // 'https://nerdmaxxing-server-seven.vercel.app/api/v1'
  

  static String get baseUrl {
    final value = _configuredBaseUrl.replaceFirst(RegExp(r'/+$'), '');
    final uri = Uri.tryParse(value);
    if (uri == null || uri.path.isEmpty || uri.path == '/') {
      return '$value/api/v1';
    }
    return value;
  }

  final Dio _dio;
  final TokenStorage tokenStorage;

  /// Called when a refresh attempt is rejected, so the app can force a sign-out.
  void Function()? onSessionExpired;

  /// Optional hook for crash/analytics reporting. Called for network failures,
  /// timeouts and 5xx responses (never for 4xx the user can fix).
  void Function(ApiException error)? onApiError;

  ApiClient({required this.tokenStorage})
    : _dio = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 15),
          // Without this a stalled response hangs forever and the UI never
          // gets a chance to show an error.
          receiveTimeout: const Duration(seconds: 45),
        ),
      ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
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
          final options = error.requestOptions;
          final isAuthCall = options.path.contains('/auth/');
          // `retried` stops a request that keeps returning 401 from looping
          // through refresh -> retry -> refresh forever.
          final alreadyRetried = options.extra['retried'] == true;
          if (error.response?.statusCode == 401 &&
              !isAuthCall &&
              !alreadyRetried) {
            final outcome = await _tryRefresh();
            if (outcome == _RefreshOutcome.ok) {
              options.extra['retried'] = true;
              try {
                final clone = await _dio.fetch(options);
                return handler.resolve(clone);
              } on DioException catch (retryError) {
                // Surface what actually went wrong on the retry (404, 5xx,
                // offline...) instead of the stale 401.
                return handler.next(retryError);
              } catch (_) {
                // fall through to original error
              }
            } else if (outcome == _RefreshOutcome.rejected) {
              onSessionExpired?.call();
            }
            // `unavailable`: keep the user signed in, pass the error along.
          }
          handler.next(error);
        },
      ),
    );
  }

  Future<_RefreshOutcome>? _refreshFuture;

  Future<_RefreshOutcome> _tryRefresh() async {
    final existingRefresh = _refreshFuture;
    if (existingRefresh != null) return existingRefresh;

    final refresh = _refreshTokens();
    _refreshFuture = refresh;
    try {
      return await refresh;
    } finally {
      if (identical(_refreshFuture, refresh)) {
        _refreshFuture = null;
      }
    }
  }

  Future<_RefreshOutcome> _refreshTokens() async {
    try {
      final refreshToken = await tokenStorage.refreshToken;
      if (refreshToken == null) return _RefreshOutcome.rejected;
      final response = await _dio.post(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
        options: Options(extra: {'skipAuth': true}),
      );
      final data = response.data as Map<String, dynamic>;
      final userId = await tokenStorage.userId ?? '';
      await tokenStorage.saveTokens(
        accessToken: data['access_token'] as String,
        refreshToken: data['refresh_token'] as String,
        userId: userId,
      );
      return _RefreshOutcome.ok;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      // Being offline or hitting a flaky server is not the same as an expired
      // session, so don't sign the user out for it.
      if (status == null || status >= 500 || status == 408 || status == 429) {
        return _RefreshOutcome.unavailable;
      }
      return _RefreshOutcome.rejected;
    } catch (_) {
      return _RefreshOutcome.rejected;
    }
  }

  static bool _looksLikeSocketFailure(Object? error) {
    final value = error?.toString().toLowerCase() ?? '';
    return value.contains('socketexception') ||
        value.contains('failed host lookup') ||
        value.contains('network is unreachable') ||
        value.contains('connection refused') ||
        value.contains('connection reset') ||
        value.contains('connection closed') ||
        value.contains('xmlhttprequest');
  }

  static String? _header(Response? response, String name) {
    final values = response?.headers[name];
    if (values == null || values.isEmpty) return null;
    return values.first;
  }

  void _report(ApiException e) {
    if (!(e.isServerError || e.isNetworkError || e.isTimeout)) return;
    // Internal diagnostics only; users never see status codes.
    developer.log(
      '${e.statusCode ?? 'NO_RESPONSE'} ${e.method ?? ''} ${e.path ?? ''} '
      'req=${e.requestId ?? '-'} :: ${e.message}',
      name: 'nerdmaxxing.api',
      level: 1000,
    );
    onApiError?.call(e);
  }

  Future<dynamic> _unwrap(Future<Response> Function() request) async {
    try {
      final response = await request();
      return response.data;
    } on DioException catch (e) {
      final response = e.response;
      final data = response?.data;
      String message = 'Something went wrong. Please try again.';
      if (data is Map && data['detail'] != null) {
        final detail = data['detail'];
        if (detail is String) {
          message = detail;
        } else if (detail is List && detail.isNotEmpty) {
          message = detail
              .map(
                (d) => d is Map && d['loc'] != null
                    ? '${(d['loc'] as List).join('.')}: ${d['msg'] ?? 'Invalid value'}'
                    : d.toString(),
              )
              .join('\n');
        }
      } else if (response == null) {
        message = switch (e.type) {
          DioExceptionType.connectionTimeout ||
          DioExceptionType.sendTimeout ||
          DioExceptionType.receiveTimeout =>
            'The request timed out. Please try again.',
          DioExceptionType.connectionError =>
            'We could not connect. Check your internet connection and try again.',
          _ => 'We could not reach the server. Please try again.',
        };
      }

      final noResponse = response == null;
      final isTimeout =
          noResponse &&
          (e.type == DioExceptionType.connectionTimeout ||
              e.type == DioExceptionType.sendTimeout ||
              e.type == DioExceptionType.receiveTimeout);
      final isNetwork =
          noResponse &&
          (e.type == DioExceptionType.connectionError ||
              e.type == DioExceptionType.connectionTimeout ||
              (e.type == DioExceptionType.unknown &&
                  _looksLikeSocketFailure(e.error)));

      final exception = ApiException(
        response?.statusCode,
        message,
        isNetworkError: isNetwork,
        isTimeout: isTimeout,
        requestId:
            _header(response, 'x-request-id') ??
            _header(response, 'x-vercel-id'),
        method: e.requestOptions.method,
        path: e.requestOptions.path,
      );
      _report(exception);
      throw exception;
    }
  }

  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? query,
    bool skipAuth = false,
  }) {
    return _unwrap(
      () => _dio.get(
        path,
        queryParameters: query,
        options: Options(extra: {'skipAuth': skipAuth}),
      ),
    );
  }

  Future<dynamic> post(String path, {Object? data, bool skipAuth = false}) {
    return _unwrap(
      () => _dio.post(
        path,
        data: data,
        options: Options(extra: {'skipAuth': skipAuth}),
      ),
    );
  }

  Future<dynamic> patch(String path, {Object? data, bool skipAuth = false}) {
    return _unwrap(
      () => _dio.patch(
        path,
        data: data,
        options: Options(extra: {'skipAuth': skipAuth}),
      ),
    );
  }

  Future<dynamic> delete(String path, {bool skipAuth = false}) {
    return _unwrap(
      () => _dio.delete(path, options: Options(extra: {'skipAuth': skipAuth})),
    );
  }
}
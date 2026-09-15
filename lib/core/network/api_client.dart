import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../config/app_config.dart';
import '../storage/secure_storage_service.dart';
import 'socket_service.dart';

// ---------------------------------------------------------------------------
// ApiException — public error surface for all callers.
// ---------------------------------------------------------------------------

class ApiException implements Exception {
  const ApiException(this.message);
  final String message;

  @override
  String toString() => 'ApiException: $message';
}

// ---------------------------------------------------------------------------
// ApiClient — lazy singleton, no async readiness step.
// ---------------------------------------------------------------------------

class ApiClient {
  ApiClient._() {
    _setUp();
  }

  // ── Singleton ─────────────────────────────────────────────────────────────

  static final ApiClient instance = ApiClient._();

  // ── Forced-logout signal ──────────────────────────────────────────────────
  //
  // Emits `true` whenever a 401 on a non-auth endpoint triggers a forced
  // logout.  Wire this up in your widget tree (e.g. in MccgEocApp.initState
  // or via a listener added immediately after runApp) to navigate to the
  // login screen:
  //
  //   ApiClient.instance.onForcedLogout.addListener(() {
  //     if (ApiClient.instance.onForcedLogout.value) {
  //       navigatorKey.currentState?.pushAndRemoveUntil(
  //         MaterialPageRoute(builder: (_) => const LoginScreen()),
  //         (_) => false,
  //       );
  //       ApiClient.instance.onForcedLogout.value = false; // reset
  //     }
  //   });
  //
  final ValueNotifier<bool> onForcedLogout = ValueNotifier(false);

  // ── Internal state ────────────────────────────────────────────────────────

  late final Dio _dio;

  /// The resolved base URL — read from [AppConfig.apiUrl].
  /// Kept as a public field so [SocketService] and [HistoryRepository] can
  /// continue to read it without needing their own imports of AppConfig.
  final String baseUrl = AppConfig.apiUrl;

  static bool _isLoggingOut = false;

  // ── Setup ─────────────────────────────────────────────────────────────────

  void _setUp() {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await SecureStorageService.instance.getToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException e, handler) {
          final response = e.response;

          if (response != null) {
            final isAuthEndpoint = e.requestOptions.path.contains('/auth/');
            if (response.statusCode == 401 && !isAuthEndpoint) {
              _forceLogout();
            }

            final data = response.data;
            final String msg;
            if (data is Map<String, dynamic> && data['error'] is String) {
              msg = data['error'] as String;
            } else if (data is Map<String, dynamic> &&
                data['message'] is String) {
              msg = data['message'] as String;
            } else {
              msg = 'Server error (${response.statusCode})';
            }
            return handler.reject(
              DioException(
                requestOptions: e.requestOptions,
                error: ApiException(msg),
                type: DioExceptionType.badResponse,
                response: response,
              ),
            );
          }

          return handler.reject(
            DioException(
              requestOptions: e.requestOptions,
              error: ApiException(
                'Could not reach the server at $baseUrl. Check network/ADB connection.',
              ),
              type: e.type,
            ),
          );
        },
      ),
    );
  }

  // ── Forced logout (no navigation — emits onForcedLogout) ──────────────────

  Future<void> _forceLogout() async {
    if (_isLoggingOut) return;
    _isLoggingOut = true;
    try {
      SocketService.instance.disconnect();
      await SecureStorageService.instance.clearAll();
      // Signal the UI layer — whoever is listening navigates to login.
      onForcedLogout.value = true;
    } finally {
      _isLoggingOut = false;
    }
  }

  // ── Private request helper — single try/catch for all verbs ───────────────

  Future<Response<dynamic>> _request(
    Future<Response<dynamic>> Function() call,
  ) async {
    try {
      return await call();
    } on DioException catch (e) {
      throw e.error is ApiException
          ? e.error as ApiException
          : ApiException(e.message ?? 'Unknown error');
    }
  }

  // ── Public HTTP verbs ─────────────────────────────────────────────────────

  Future<Response<dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) => _request(
    () => _dio.get(path, queryParameters: queryParameters, options: options),
  );

  Future<Response<dynamic>> post(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) => _request(
    () => _dio.post(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    ),
  );

  Future<Response<dynamic>> put(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) => _request(
    () => _dio.put(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    ),
  );

  Future<Response<dynamic>> patch(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) => _request(
    () => _dio.patch(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    ),
  );

  Future<Response<dynamic>> delete(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) => _request(
    () => _dio.delete(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    ),
  );
}

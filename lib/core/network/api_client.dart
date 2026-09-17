import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../config/app_config.dart';
import '../storage/secure_storage_service.dart';
import 'socket_service.dart';

class ApiException implements Exception {
  const ApiException(this.message);
  final String message;

  @override
  String toString() => 'ApiException: $message';
}

class ApiClient {
  ApiClient._() {
    _setUp();
  }

  static final ApiClient instance = ApiClient._();

  /// Emits `true` when a 401 on a non-auth endpoint forces a logout. The UI
  /// layer listens and navigates; this class never touches navigation.
  final ValueNotifier<bool> onForcedLogout = ValueNotifier(false);

  /// Runs before the session is cleared on a forced logout, while the Bearer
  /// token is still valid. Used to release the FCM token server-side so a
  /// signed-out handset stops receiving dispatch alerts.
  Future<void> Function()? onBeforeForcedLogout;

  late final Dio _dio;

  Dio get dio => _dio;

  final String baseUrl = AppConfig.apiUrl;

  static bool _isLoggingOut = false;

  void _setUp() {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: AppConfig.connectTimeout,
        receiveTimeout: AppConfig.receiveTimeout,
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
              error: const ApiException(
                'No connection to the dispatch server. Check your signal and try again.',
              ),
              type: e.type,
            ),
          );
        },
      ),
    );
  }

  Future<void> _forceLogout() async {
    if (_isLoggingOut) return;
    _isLoggingOut = true;
    try {
      try {
        await onBeforeForcedLogout?.call();
      } catch (e) {
        if (kDebugMode) debugPrint('[ApiClient] pre-logout hook failed: $e');
      }
      SocketService.instance.disconnect();
      await SecureStorageService.instance.clearAll();
      onForcedLogout.value = true;
    } finally {
      _isLoggingOut = false;
    }
  }

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

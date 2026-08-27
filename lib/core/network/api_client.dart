import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../storage/secure_storage_service.dart';
import 'socket_service.dart';
import '../../main.dart' show navigatorKey;
import '../../features/auth/login_screen.dart';

class ApiException implements Exception {
  const ApiException(this.message);
  final String message;

  @override
  String toString() => 'ApiException: $message';
}

const List<String> _candidateBaseUrls = [
  'http://192.168.100.12:3000',  // active LAN IP (physical devices)
  'http://10.0.2.2:3000',        // Android emulator → host loopback
  'http://127.0.0.1:3000',
  'http://localhost:3000',
];

const _probeTimeout = Duration(seconds: 3);

class ApiClient {
  ApiClient._();

  static ApiClient? _instance;

  static ApiClient get instance {
    assert(_instance != null,
        'ApiClient.init() must be called before accessing ApiClient.instance');
    return _instance!;
  }

  late final Dio _dio;
  late final String baseUrl;
  static bool _isLoggingOut = false;

  static Future<void> init() async {
    final winningUrl = await _probeBaseUrl() ?? _candidateBaseUrls.first;
    debugPrint('[ApiClient] Configured active base URL: $winningUrl');
    _instance = ApiClient._().._setUp(winningUrl);
  }

  void _setUp(String url) {
    baseUrl = url;
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
    ));

    _dio.interceptors.add(InterceptorsWrapper(
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
          if (response.statusCode == 401) {
            _forceLogout();
          }

          final data = response.data;
          String msg;
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
                'Could not reach the server at $baseUrl. Check network/ADB connection.'),
            type: e.type,
          ),
        );
      },
    ));
  }

  static Future<void> _forceLogout() async {
    if (_isLoggingOut) return;
    _isLoggingOut = true;

    try {
      SocketService.instance.disconnect();
      await SecureStorageService.instance.clearAll();
      navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    } finally {
      _isLoggingOut = false;
    }
  }

  Future<Response<dynamic>> post(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.post(path,
          data: data, queryParameters: queryParameters, options: options);
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
  }) async {
    try {
      return await _dio.get(path, queryParameters: queryParameters, options: options);
    } on DioException catch (e) {
      throw e.error is ApiException
          ? e.error as ApiException
          : ApiException(e.message ?? 'Unknown error');
    }
  }

  Future<Response<dynamic>> delete(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.delete(path,
          data: data, queryParameters: queryParameters, options: options);
    } on DioException catch (e) {
      throw e.error is ApiException
          ? e.error as ApiException
          : ApiException(e.message ?? 'Unknown error');
    }
  }

  Future<Response<dynamic>> patch(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.patch(path,
          data: data, queryParameters: queryParameters, options: options);
    } on DioException catch (e) {
      throw e.error is ApiException
          ? e.error as ApiException
          : ApiException(e.message ?? 'Unknown error');
    }
  }
}

Future<String?> _probeBaseUrl() async {
  final probe = Dio(BaseOptions(
    connectTimeout: _probeTimeout,
    receiveTimeout: _probeTimeout,
    validateStatus: (status) => status != null && status < 500,
  ));

  for (final url in _candidateBaseUrls) {
    try {
      debugPrint('[ApiClient] Probing $url ...');
      final res = await probe.get('$url/');
      if (res.statusCode != null && res.statusCode! < 500) {
        debugPrint('[ApiClient] Probe SUCCESS for $url (${res.statusCode})');
        return url;
      }
    } catch (e) {
      debugPrint('[ApiClient] Probe failed for $url: $e');
      continue;
    }
  }
  return null;
}

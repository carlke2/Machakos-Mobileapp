import 'package:dio/dio.dart';
import 'models.dart';

/// Mirrors `backend/src/modules/notifications/notifications.routes.ts`.
class NotificationsApi {
  final Dio _dio;

  NotificationsApi(this._dio);

  Future<void> registerToken(PushTokenRegistration registration) async {
    final res = await _dio.post(
      '/notifications/token',
      data: registration.toJson(),
    );
    _assertOk(res, 'Token registration');
  }

  Future<void> unregisterToken() async {
    final res = await _dio.delete('/notifications/token');
    _assertOk(res, 'Token unregistration');
  }

  void _assertOk(Response<dynamic> res, String action) {
    final body = res.data;
    if (body is Map<String, dynamic> && body['ok'] == true) return;
    throw DioException(
      requestOptions: res.requestOptions,
      response: res,
      error: '$action did not return ok=true',
    );
  }
}

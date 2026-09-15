import 'package:dio/dio.dart';
import 'models.dart';

/// Mirrors backend/src/modules/notifications/notifications.routes.ts.
/// These two endpoints are the ENTIRE mobile-facing notifications API —
/// per the audit there is no GET endpoint for a notification list/inbox
/// on mobile; that only exists as a client-only store on the web app.
///
/// Both routes require an authenticated Bearer JWT (app.authenticate) —
/// same as every other authenticated call, so no special auth handling
/// needed here beyond whatever interceptor your Dio instance already has.
class NotificationsApi {
  final Dio _dio;

  NotificationsApi(this._dio);

  /// POST /notifications/token
  /// Registers/updates this device's FCM token against the signed-in
  /// user (saved server-side to User.fcmToken — one token per user, so
  /// registering on a second device overwrites the first, per the
  /// schema: fcmToken is a single nullable String, not a list).
  ///
  /// Response is { ok: true, message: "Push token registered" } — no
  /// data payload to parse, so this returns void and throws on ok=false.
  Future<void> registerToken(PushTokenRegistration registration) async {
    final res = await _dio.post(
      '/notifications/token',
      data: registration.toJson(),
    );
    final body = res.data as Map<String, dynamic>;
    if (body['ok'] != true) {
      throw DioException(
        requestOptions: res.requestOptions,
        response: res,
        error: 'Token registration returned ok=false',
      );
    }
  }

  /// DELETE /notifications/token
  /// Clears User.fcmToken server-side (sets to null). Call this on
  /// logout / token revocation so a signed-out device stops receiving
  /// pushes meant for the account that was signed in on it.
  Future<void> unregisterToken() async {
    final res = await _dio.delete('/notifications/token');
    final body = res.data as Map<String, dynamic>;
    if (body['ok'] != true) {
      throw DioException(
        requestOptions: res.requestOptions,
        response: res,
        error: 'Token unregistration returned ok=false',
      );
    }
  }
}

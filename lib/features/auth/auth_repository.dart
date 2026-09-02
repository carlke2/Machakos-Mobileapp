import 'package:mobileapp/core/network/api_client.dart';
import 'package:mobileapp/core/services/notification_service.dart';
import 'package:mobileapp/core/storage/secure_storage_service.dart';

const _allowedRoles = {'DRIVER', 'EMT', 'NURSE'};

/// Authentication payload result.
class AuthResult {
  const AuthResult({
    required this.token,
    required this.userId,
    required this.name,
    required this.phone,
    required this.role,
    required this.agencyId,
  });

  final String token;
  final String userId;
  final String name;
  final String phone;
  final String role;
  final String agencyId;
}

/// OTP request payload result.
class OtpRequestResult {
  const OtpRequestResult({
    required this.phone,
    required this.expiresInSeconds,
  });

  final String phone;
  final int expiresInSeconds;
}

/// Handles responder authentication via OTP and credential storage.
class AuthRepository {
  AuthRepository();

  final _storage = SecureStorageService.instance;

  /// Request a 6-digit OTP code to the responder's phone number.
  Future<OtpRequestResult> requestOtp(String phone) async {
    final response = await ApiClient.instance.post(
      '/auth/otp/request',
      data: {'phone': phone},
    );

    final body = response.data as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>;
    final phoneResp = data['phone'] as String? ?? phone;
    final expiresInSeconds = (data['expiresInSeconds'] as num?)?.toInt() ?? 300;

    return OtpRequestResult(
      phone: phoneResp,
      expiresInSeconds: expiresInSeconds,
    );
  }

  /// Verify the 6-digit OTP code and complete sign-in.
  Future<AuthResult> verifyOtp(String phone, String code) async {
    final response = await ApiClient.instance.post(
      '/auth/otp/verify',
      data: {'phone': phone, 'code': code},
    );

    final body = response.data as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>;
    final token = data['token'] as String;
    final user = data['user'] as Map<String, dynamic>;
    final role = user['role'] as String? ?? '';

    if (!_allowedRoles.contains(role)) {
      await _storage.clearAll();
      throw const ApiException(
        'This app is for field responders only (Driver, EMT, Nurse).',
      );
    }

    await Future.wait([
      _storage.saveToken(token),
      _storage.saveUser(user),
    ]);

    // Register FCM token for push notifications
    NotificationService.instance.registerToken();

    return AuthResult(
      token: token,
      userId: user['id'] as String? ?? '',
      name: user['name'] as String? ?? '',
      phone: user['phone'] as String? ?? phone,
      role: role,
      agencyId: user['agencyId'] as String? ?? '',
    );
  }

  Future<void> logout() async {
    await NotificationService.instance.clearToken();
    await _storage.clearAll();
  }
}


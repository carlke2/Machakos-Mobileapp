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
    required this.email,
    required this.role,
    required this.agencyId,
  });

  final String token;
  final String userId;
  final String name;
  final String email;
  final String role;
  final String agencyId;
}

/// Handles responder authentication and credential storage.
class AuthRepository {
  AuthRepository();

  final _storage = SecureStorageService.instance;

  Future<AuthResult> login(String email, String password) async {
    final response = await ApiClient.instance.post(
      '/auth/login',
      data: {'email': email, 'passwordRaw': password},
    );

    final body = response.data as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>;
    final token = data['token'] as String;
    final user = data['user'] as Map<String, dynamic>;
    final role = user['role'] as String;

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
      userId: user['id'] as String,
      name: user['name'] as String,
      email: user['email'] as String,
      role: role,
      agencyId: user['agencyId'] as String,
    );
  }

  Future<void> logout() async {
    await NotificationService.instance.clearToken();
    await _storage.clearAll();
  }
}

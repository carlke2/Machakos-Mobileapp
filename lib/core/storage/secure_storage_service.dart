import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure storage service for persisting authentication state.
class SecureStorageService {
  SecureStorageService._();

  static final SecureStorageService instance = SecureStorageService._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _keyToken = 'eoc_jwt_token';
  static const _keyUser = 'eoc_user_json';

  String? _cachedToken;
  Map<String, dynamic>? _cachedUser;

  Future<void> saveToken(String token) {
    _cachedToken = token;
    return _storage.write(key: _keyToken, value: token);
  }

  Future<String?> getToken({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedToken != null) return _cachedToken;
    _cachedToken = await _storage.read(key: _keyToken);
    return _cachedToken;
  }

  Future<void> deleteToken() {
    _cachedToken = null;
    return _storage.delete(key: _keyToken);
  }

  Future<void> saveUser(Map<String, dynamic> user) {
    _cachedUser = user;
    return _storage.write(key: _keyUser, value: jsonEncode(user));
  }

  Future<Map<String, dynamic>?> getUser({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedUser != null) return _cachedUser;
    final raw = await _storage.read(key: _keyUser);
    if (raw == null) {
      _cachedUser = null;
      return null;
    }
    _cachedUser = jsonDecode(raw) as Map<String, dynamic>;
    return _cachedUser;
  }

  Future<void> deleteUser() {
    _cachedUser = null;
    return _storage.delete(key: _keyUser);
  }

  Future<void> clearAll() async {
    _cachedToken = null;
    _cachedUser = null;
    await Future.wait([
      _storage.delete(key: _keyToken),
      _storage.delete(key: _keyUser),
    ]);
  }
}

class AppConfig {
  AppConfig._();

  /// REST base URL, no trailing slash. In production nginx proxies `/api/`
  static const String apiUrl = String.fromEnvironment(
    'API_URL',
    // Physical LAN default for this machine. Emulator still needs 10.0.2.2.
    defaultValue: 'http://192.168.100.92:3000',
  );

  static const String _socketUrlOverride = String.fromEnvironment('SOCKET_URL');

  
  /// namespace and silently never connect. Always hand it the bare origin.
  static String get socketUrl {
    if (_socketUrlOverride.isNotEmpty) return _socketUrlOverride;
    final uri = Uri.parse(apiUrl);
    return Uri(scheme: uri.scheme, host: uri.host, port: uri.hasPort ? uri.port : null).toString();
  }

  /// Connect timeout. Deliberately short: a responder holding a phone in a
  /// moving ambulance needs a failure surfaced fast, not a long hang.
  static const Duration connectTimeout = Duration(seconds: 6);

  static const Duration receiveTimeout = Duration(seconds: 15);
}

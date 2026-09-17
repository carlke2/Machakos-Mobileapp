/// Build-time configuration, injected with `--dart-define`.
///
///   Production (default):  flutter build apk --release
///   Android emulator:      flutter run --dart-define=API_URL=http://10.0.2.2:3000
///   iOS simulator:         flutter run --dart-define=API_URL=http://127.0.0.1:3000
///   Physical LAN device:   flutter run --dart-define=API_URL=http://192.168.x.x:3000
class AppConfig {
  AppConfig._();

  /// REST base URL, no trailing slash. In production nginx proxies `/api/`
  /// through to the Fastify backend on 127.0.0.1:3000.
  static const String apiUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'https://machakos.brighton.co.ke/api',
  );

  static const String _socketUrlOverride = String.fromEnvironment('SOCKET_URL');

  /// Socket.IO endpoint. Socket.IO reads any path on the URI as a namespace,
  /// so connecting to the REST base URL would ask for the non-existent `/api`
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

/// Build-time configuration, injected with `--dart-define`.
///
/// Full connection notes (endpoints, auth, LAN IP): BACKEND_CONNECTION.md
/// Backend lives at: C:\Users\USER\machakos-web\backend  (.\dev.cmd → :3000)
///
///   Android emulator:  flutter run --dart-define=API_URL=http://10.0.2.2:3000
///   iOS simulator:     flutter run --dart-define=API_URL=http://127.0.0.1:3000
///   Physical LAN:      flutter run --dart-define=API_URL=http://192.168.100.184:3000
///   Production APK:    flutter build apk --release
///                      --dart-define=API_URL=https://machakos.brighton.co.ke/api
///                      --dart-define=SOCKET_URL=https://machakos.brighton.co.ke
///
/// Local Fastify has NO /api prefix. Do not use …/api against :3000.
class AppConfig {
  AppConfig._();

  /// REST base URL, no trailing slash. In production nginx proxies `/api/`
  /// through to the Fastify backend on 127.0.0.1:3000.
  static const String apiUrl = String.fromEnvironment(
    'API_URL',
    // Physical LAN default for this machine. Emulator still needs 10.0.2.2.
    defaultValue: 'http://192.168.100.184:3000',
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

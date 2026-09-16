/// Application-wide compile-time configuration.
///
/// Values are injected at build/run time via `--dart-define`:
///
///   Android Emulator:             flutter run --dart-define=API_URL=http://10.0.2.2:3000
///   iOS Simulator / ADB Reverse:  flutter run --dart-define=API_URL=http://127.0.0.1:3000
///   Physical LAN Device:          flutter run --dart-define=API_URL=http://YOUR_COMPUTER_IP:3000
///
class AppConfig {
  AppConfig._();

  /// The backend base URL (no trailing slash).
  static const String apiUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://127.0.0.1:3000',
  );
}



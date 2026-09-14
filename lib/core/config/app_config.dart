/// Application-wide compile-time configuration.
///
/// Values are injected at build/run time via `--dart-define`:
///
///   flutter run --dart-define=API_URL=http://192.168.100.100:3000
///   flutter build apk --dart-define=API_URL=https://eoc.example.com
///
/// The default value is the most common development LAN IP.  Change it
/// here if your local setup differs, but prefer passing `--dart-define`
/// so the source file stays clean.
class AppConfig {
  AppConfig._();

  /// The backend base URL (no trailing slash).
  static const String apiUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://192.168.100.100:3000',
  );
}

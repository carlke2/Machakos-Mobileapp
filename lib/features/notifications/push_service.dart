import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'notifications_api.dart';
import 'models.dart';

/// Must be a TOP-LEVEL (or static) function — FCM invokes this in a
/// separate isolate when a data message arrives while the app is fully
/// terminated or backgrounded on Android. Register it in main() BEFORE
/// runApp(), not inside PushService.initialize():
///
///   void main() async {
///     WidgetsFlutterBinding.ensureInitialized();
///     await Firebase.initializeApp();
///     FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
///     runApp(const MyApp());
///   }
///
/// Per the audit, every send carries a `notification` block, so the OS
/// already renders a tray notification in this state on its own — this
/// handler exists for any future backend change to a data-only payload,
/// and as a hook if you later want to do local work (e.g. pre-fetch the
/// case) before the user taps it. Keep it minimal; heavy work here can
/// get the isolate killed before it finishes.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Intentionally minimal — see comment above.
}

/// Owns the full FCM lifecycle for this app: permission request, token
/// registration/refresh against POST /notifications/token, and the three
/// message-receipt states FCM distinguishes (foreground / background-tap
/// / terminated-cold-start), each parsed against the exact `data` shape
/// confirmed in the audit:
///
///   TASK_ASSIGNED:       { type, caseNumber }
///   TASK_STATUS_CHANGED: { type, caseNumber, status }
///
/// There is no per-user notification history endpoint on mobile (see
/// models.dart) — this service is the entire notifications surface
/// for the app. If you want an in-app inbox akin to the web drawer, it
/// would need to be a purely local/session list built from messages this
/// service receives — there's nothing to fetch on screen mount.
class PushService {
  PushService._();
  static final PushService instance = PushService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  NotificationsApi? _api;

  /// Called whenever a push is tapped (from background OR a cold start)
  /// with the parsed deep-link target. Wire this to your app's router —
  /// e.g. `PushService.instance.onDeepLink = (payload) =>
  /// navigatorKey.currentState?.pushNamed('/tasks/by-case',
  /// arguments: payload.caseNumber);`
  ///
  /// Both TASK_ASSIGNED and TASK_STATUS_CHANGED route to the same place
  /// per the audit ("deep-link directly to the incident/assignment
  /// screen for that caseNumber") — `status` on TASK_STATUS_CHANGED is
  /// available if you want to show a toast/banner on arrival rather than
  /// changing where you navigate.
  void Function(PushDataPayload payload)? onDeepLink;

  static const _androidChannel = AndroidNotificationChannel(
    'high_importance_channel',
    'Task & dispatch alerts',
    description: 'Assignment and status-change notifications for crew.',
    importance: Importance.high,
  );

  /// Call once, after login (so NotificationsApi has a valid auth
  /// session to register the token against) and after
  /// Firebase.initializeApp() has already run in main().
  Future<void> initialize(NotificationsApi api) async {
    _api = api;

    await _setupLocalNotifications();

    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (kDebugMode) {
      debugPrint('Push permission status: ${settings.authorizationStatus}');
    }

    await _registerCurrentToken();
    _messaging.onTokenRefresh.listen((_) => _registerCurrentToken());

    // Foreground: FCM does NOT auto-display anything while the app is
    // open, so build the banner ourselves from the `notification` block.
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // App was backgrounded (not terminated) and the user tapped the
    // system tray notification.
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    // App was fully terminated and launched BY tapping a notification.
    // Must be checked explicitly — onMessageOpenedApp does not fire for
    // this case.
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleMessageOpenedApp(initialMessage);
    }
  }

  Future<void> _setupLocalNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await _localNotifications.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: (response) {
        final caseNumber = response.payload;
        if (caseNumber == null) return;
        // Local-notification tap while app is already in foreground —
        // route the same way as a real FCM tap. We don't have `type`
        // here (only caseNumber was stashed as the payload string), but
        // per the audit both known types route identically.
        onDeepLink?.call(
          PushDataPayload(
            type: PushNotificationType.unknown,
            caseNumber: caseNumber,
            status: null,
          ),
        );
      },
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_androidChannel);
  }

  Future<void> _registerCurrentToken() async {
    final api = _api;
    if (api == null) return;
    try {
      final token = await _messaging.getToken();
      if (token == null || token.isEmpty) return;
      await api.registerToken(PushTokenRegistration(fcmToken: token));
    } catch (e) {
      // Registration failure shouldn't crash startup — the user just
      // won't receive push until the next successful attempt (e.g. next
      // onTokenRefresh, or next app launch's initialize() call).
      if (kDebugMode) debugPrint('FCM token registration failed: $e');
    }
  }

  /// Call on logout, before clearing the auth session, so the call still
  /// carries a valid Bearer token.
  Future<void> unregister() async {
    try {
      await _api?.unregisterToken();
    } catch (e) {
      if (kDebugMode) debugPrint('FCM token unregistration failed: $e');
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final content = PushNotificationContent(
      title: message.notification?.title,
      body: message.notification?.body,
    );
    final dataPayload = PushDataPayload.fromMap(message.data);

    _localNotifications.show(
      message.hashCode,
      content.title,
      content.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      // Stash caseNumber as the payload so a tap on THIS local
      // notification (foreground) can still deep-link — see
      // onDidReceiveNotificationResponse above.
      payload: dataPayload.caseNumber,
    );
  }

  void _handleMessageOpenedApp(RemoteMessage message) {
    final payload = PushDataPayload.fromMap(message.data);
    onDeepLink?.call(payload);
  }
}

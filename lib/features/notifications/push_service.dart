import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'notifications_api.dart';
import 'models.dart';

/// Runs in its own isolate when a message arrives while the app is
/// backgrounded or terminated. Every send carries a `notification` block, so
/// the OS already draws the tray entry; this exists only as the required
/// registration target and a hook for future data-only payloads. Heavy work
/// here risks the isolate being killed before it completes.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

/// A push that arrived while this session was running, kept in memory so the
/// crew can re-read an alert they missed or dismissed.
class ReceivedAlert {
  ReceivedAlert({
    required this.title,
    required this.body,
    required this.payload,
    required this.receivedAt,
  });

  final String? title;
  final String? body;
  final PushDataPayload payload;
  final DateTime receivedAt;
}

/// Owns the FCM lifecycle: permission, token registration and refresh against
/// `/notifications/token`, and the three receipt states FCM distinguishes
/// (foreground, background tap, terminated cold start).
class PushService {
  PushService._();
  static final PushService instance = PushService._();

  // Resolved lazily. Reading FirebaseMessaging.instance throws when Firebase
  // failed to initialize (a missing google-services.json, for one), and this
  // singleton is touched on startup paths that must survive that.
  FirebaseMessaging? _messagingInstance;
  FirebaseMessaging get _messaging =>
      _messagingInstance ??= FirebaseMessaging.instance;

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  NotificationsApi? _api;
  bool _listenersAttached = false;
  bool _channelCreated = false;
  Timer? _tokenRetryTimer;
  int _tokenAttempts = 0;

  /// In-session alert history, newest first. Drives the header bell.
  final ValueNotifier<List<ReceivedAlert>> alerts = ValueNotifier(const []);

  /// Invoked when a push is tapped, from background or from a cold start.
  void Function(PushDataPayload payload)? onDeepLink;

  static const _maxTokenAttempts = 5;

  static const _androidChannel = AndroidNotificationChannel(
    'high_importance_channel',
    'Task & dispatch alerts',
    description: 'Assignment and status-change notifications for crew.',
    importance: Importance.max,
    enableVibration: true,
    playSound: true,
  );

  /// Safe to call more than once — listeners attach only on the first call, so
  /// a login following a cold start does not double-register handlers.
  Future<void> initialize(NotificationsApi api) async {
    _api = api;

    await _setupLocalNotifications();

    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (kDebugMode) {
      debugPrint('Push permission: ${settings.authorizationStatus}');
    }

    _tokenAttempts = 0;
    await _registerCurrentToken();

    if (_listenersAttached) return;
    _listenersAttached = true;

    _messaging.onTokenRefresh.listen((_) {
      _tokenAttempts = 0;
      _registerCurrentToken();
    });

    // FCM does not draw anything while the app is open, so build the banner.
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    // onMessageOpenedApp does not fire for a launch-by-tap from terminated.
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleMessageOpenedApp(initialMessage);
    }
  }

  Future<void> _setupLocalNotifications() async {
    if (_channelCreated) return;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await _localNotifications.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: (response) {
        final raw = response.payload;
        if (raw == null || raw.isEmpty) return;
        onDeepLink?.call(_decodeTapPayload(raw));
      },
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_androidChannel);

    _channelCreated = true;
  }

  Future<void> _registerCurrentToken() async {
    final api = _api;
    if (api == null) return;

    _tokenRetryTimer?.cancel();
    _tokenAttempts++;

    try {
      final token = await _messaging.getToken();
      if (token == null || token.isEmpty) {
        _scheduleTokenRetry('FCM token not ready');
        return;
      }
      await api.registerToken(PushTokenRegistration(fcmToken: token));
      _tokenAttempts = 0;
    } catch (e) {
      _scheduleTokenRetry('$e');
    }
  }

  /// Google Play Services can take a few seconds after a cold install to mint
  /// a token. Without this retry the handset silently receives no dispatch
  /// alerts until the next app launch.
  void _scheduleTokenRetry(String reason) {
    if (_tokenAttempts >= _maxTokenAttempts) {
      if (kDebugMode) {
        debugPrint('FCM token registration gave up after $_tokenAttempts: $reason');
      }
      return;
    }
    final delay = Duration(seconds: 2 * _tokenAttempts);
    if (kDebugMode) {
      debugPrint('FCM token registration retry in ${delay.inSeconds}s: $reason');
    }
    _tokenRetryTimer = Timer(delay, _registerCurrentToken);
  }

  /// Call on logout while the Bearer token is still valid.
  Future<void> unregister() async {
    _tokenRetryTimer?.cancel();
    _tokenAttempts = 0;
    alerts.value = const [];
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
    final payload = PushDataPayload.fromMap(message.data);

    _recordAlert(content, payload);

    _localNotifications.show(
      message.hashCode,
      content.title,
      content.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          importance: Importance.max,
          priority: Priority.high,
          category: AndroidNotificationCategory.call,
        ),
        iOS: const DarwinNotificationDetails(
          interruptionLevel: InterruptionLevel.timeSensitive,
        ),
      ),
      payload: _encodeTapPayload(payload),
    );
  }

  void _handleMessageOpenedApp(RemoteMessage message) {
    final payload = PushDataPayload.fromMap(message.data);
    _recordAlert(
      PushNotificationContent(
        title: message.notification?.title,
        body: message.notification?.body,
      ),
      payload,
    );
    onDeepLink?.call(payload);
  }

  void _recordAlert(PushNotificationContent content, PushDataPayload payload) {
    alerts.value = [
      ReceivedAlert(
        title: content.title,
        body: content.body,
        payload: payload,
        receivedAt: DateTime.now(),
      ),
      ...alerts.value,
    ].take(50).toList(growable: false);
  }

  // flutter_local_notifications carries a single string through a tap, so the
  // routing fields are packed into it and unpacked on the way back.
  static String _encodeTapPayload(PushDataPayload payload) =>
      [payload.taskId ?? '', payload.caseNumber ?? ''].join('|');

  static PushDataPayload _decodeTapPayload(String raw) {
    final parts = raw.split('|');
    return PushDataPayload(
      type: PushNotificationType.unknown,
      taskId: parts.isNotEmpty && parts[0].isNotEmpty ? parts[0] : null,
      caseNumber: parts.length > 1 && parts[1].isNotEmpty ? parts[1] : null,
      status: null,
    );
  }
}

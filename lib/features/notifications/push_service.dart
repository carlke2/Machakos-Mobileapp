import 'dart:async';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

import 'notifications_api.dart';
import 'models.dart';

/// Runs in its own isolate when a message arrives while the app is
/// backgrounded or terminated. Every send carries a `notification` block, so
/// the OS already draws the tray entry; this exists only as the required
/// registration target and a hook for future data-only payloads.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Keep lightweight — the isolate can be killed. System tray already shows
  // the notification payload from FCM.
  if (kDebugMode) {
    debugPrint('[FCM bg] ${message.messageId} type=${message.data['type']}');
  }
}

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

  /// Set from [main] after [Firebase.initializeApp]. When false, [initialize]
  /// is a no-op so login never throws on a missing google-services.json.
  static bool firebaseAvailable = false;

  FirebaseMessaging? _messagingInstance;
  FirebaseMessaging? get _messagingOrNull {
    if (!firebaseAvailable) return null;
    try {
      return _messagingInstance ??= FirebaseMessaging.instance;
    } catch (e) {
      if (kDebugMode) debugPrint('[Push] FirebaseMessaging unavailable: $e');
      return null;
    }
  }

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  NotificationsApi? _api;
  bool _listenersAttached = false;
  bool _channelCreated = false;
  bool _initializing = false;
  Timer? _tokenRetryTimer;
  int _tokenAttempts = 0;

  /// In-session alert history, newest first.
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

  /// Safe to call more than once — listeners attach only on the first call.
  Future<void> initialize(NotificationsApi api) async {
    _api = api;

    if (!firebaseAvailable) {
      if (kDebugMode) {
        debugPrint('[Push] Skipping init — Firebase not available');
      }
      return;
    }
    if (_initializing) return;
    _initializing = true;

    try {
      await _setupLocalNotifications();
      await _requestPermissions();

      final messaging = _messagingOrNull;
      if (messaging == null) return;

      _tokenAttempts = 0;
      await _registerCurrentToken();

      if (_listenersAttached) return;
      _listenersAttached = true;

      messaging.onTokenRefresh.listen((_) {
        _tokenAttempts = 0;
        _registerCurrentToken();
      });

      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleMessageOpenedApp(initialMessage);
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[Push] initialize failed: $e\n$st');
      }
    } finally {
      _initializing = false;
    }
  }

  Future<void> _requestPermissions() async {
    // Android 13+ needs a runtime POST_NOTIFICATIONS grant.
    if (Platform.isAndroid) {
      final status = await Permission.notification.status;
      if (!status.isGranted) {
        final result = await Permission.notification.request();
        if (kDebugMode) {
          debugPrint('[Push] Android notification permission: $result');
        }
      }
    }

    final messaging = _messagingOrNull;
    if (messaging == null) return;

    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    if (kDebugMode) {
      debugPrint('[Push] FCM permission: ${settings.authorizationStatus}');
    }
  }

  Future<void> _setupLocalNotifications() async {
    if (_channelCreated) return;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _localNotifications.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: (response) {
        final raw = response.payload;
        if (raw == null || raw.isEmpty) return;
        onDeepLink?.call(PushDataPayload.decodeTapPayload(raw));
      },
    );

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(_androidChannel);
    // Extra Android 13+ prompt via the local-notifications plugin (idempotent).
    await androidPlugin?.requestNotificationsPermission();

    _channelCreated = true;
  }

  Future<void> _registerCurrentToken() async {
    final api = _api;
    final messaging = _messagingOrNull;
    if (api == null || messaging == null) return;

    _tokenRetryTimer?.cancel();
    _tokenAttempts++;

    try {
      final token = await messaging.getToken();
      if (token == null || token.isEmpty) {
        _scheduleTokenRetry('FCM token not ready');
        return;
      }
      await api.registerToken(PushTokenRegistration(fcmToken: token));
      _tokenAttempts = 0;
      if (kDebugMode) {
        debugPrint('[Push] Token registered (${token.length} chars)');
      }
    } catch (e) {
      _scheduleTokenRetry('$e');
    }
  }

  void _scheduleTokenRetry(String reason) {
    if (_tokenAttempts >= _maxTokenAttempts) {
      if (kDebugMode) {
        debugPrint(
          '[Push] Token registration gave up after $_tokenAttempts: $reason',
        );
      }
      return;
    }
    final delay = Duration(seconds: 2 * _tokenAttempts);
    if (kDebugMode) {
      debugPrint(
        '[Push] Token registration retry in ${delay.inSeconds}s: $reason',
      );
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
      if (kDebugMode) debugPrint('[Push] Token unregistration failed: $e');
    }
    try {
      await _messagingOrNull?.deleteToken();
    } catch (e) {
      if (kDebugMode) debugPrint('[Push] deleteToken failed: $e');
    }
  }

  /// Asks the backend to send a test notification to this device's token.
  Future<void> requestSelfTest() async {
    final api = _api;
    if (api == null) throw StateError('PushService not initialized');
    await api.sendTestPush();
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
      content.title ?? 'NMS EOC',
      content.body ?? '',
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
      payload: payload.encodeTapPayload(),
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
}

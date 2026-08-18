import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:mobileapp/core/network/api_client.dart';
import 'package:mobileapp/core/storage/secure_storage_service.dart';
import 'package:mobileapp/features/home/main_shell.dart';
import 'package:mobileapp/main.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('Handling background FCM message: ${message.messageId}');
}

/// Service managing Firebase Cloud Messaging (FCM) push notifications.
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _androidChannel =
      AndroidNotificationChannel(
    'high_importance_channel',
    'High Importance Notifications',
    description: 'This channel is used for emergency dispatch notifications.',
    importance: Importance.high,
  );

  bool _isInitialized = false;

  /// Initializes FCM listeners and local notification display settings.
  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    // Register background message handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Request notification permission (Android 13+ & iOS)
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    debugPrint('FCM Authorization status: ${settings.authorizationStatus}');

    // Local notifications setup for foreground banner display
    const androidInitSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinInitSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidInitSettings,
      iOS: darwinInitSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        _handleLocalNotificationTap(response);
      },
    );

    // Create high-importance Android channel for heads-up alerts
    final androidImplementation = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation != null) {
      await androidImplementation.createNotificationChannel(_androidChannel);
    }

    // Foreground notification presentation options
    await _fcm.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Foreground message handler — FCM won't auto-display banners while open
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showForegroundNotification(message);
    });

    // Handle notification tap when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleNotificationTap(message);
    });

    // Handle notification tap when app launched from killed state
    final initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }

    // Listen for FCM token updates
    _fcm.onTokenRefresh.listen((newToken) {
      registerToken(overrideToken: newToken);
    });
  }

  /// Manually displays a local heads-up notification for foreground messages.
  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    final title =
        notification?.title ?? message.data['title'] ?? 'Emergency Notification';
    final body = notification?.body ?? message.data['body'] ?? '';

    final androidDetails = AndroidNotificationDetails(
      _androidChannel.id,
      _androidChannel.name,
      channelDescription: _androidChannel.description,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      message.hashCode,
      title,
      body,
      notificationDetails,
      payload: message.data.isNotEmpty ? message.data.toString() : null,
    );
  }

  /// Navigates to active task / main screen when notification is tapped.
  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('FCM Notification tapped with payload: ${message.data}');
    _navigateToTargetScreen();
  }

  void _handleLocalNotificationTap(NotificationResponse response) {
    debugPrint('Local Notification tapped with payload: ${response.payload}');
    _navigateToTargetScreen();
  }

  void _navigateToTargetScreen() {
    final nav = navigatorKey.currentState;
    if (nav != null) {
      nav.pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const MainShell()),
        (_) => false,
      );
    }
  }

  /// Registers the current device's FCM token with POST /notifications/token.
  Future<void> registerToken({String? overrideToken}) async {
    try {
      final token = await SecureStorageService.instance.getToken();
      if (token == null || token.isEmpty) return;

      final fcmToken = overrideToken ?? await _fcm.getToken();
      if (fcmToken == null || fcmToken.isEmpty) return;

      debugPrint('Registering FCM token: $fcmToken');
      await ApiClient.instance.post(
        '/notifications/token',
        data: {'token': fcmToken},
      );
      debugPrint('FCM token registered successfully');
    } catch (e) {
      debugPrint('Failed to register FCM token with backend: $e');
    }
  }

  /// Unregisters the current device's FCM token via DELETE /notifications/token.
  Future<void> clearToken() async {
    try {
      final token = await SecureStorageService.instance.getToken();
      if (token == null || token.isEmpty) return;

      final fcmToken = await _fcm.getToken();

      debugPrint('Clearing FCM token from backend...');
      await ApiClient.instance.delete(
        '/notifications/token',
        data: fcmToken != null ? {'token': fcmToken} : null,
      );
      debugPrint('FCM token cleared successfully');
    } catch (e) {
      debugPrint('Failed to clear FCM token from backend: $e');
    }
  }
}

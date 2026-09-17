import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'core/app_events.dart';
import 'core/network/api_client.dart';
import 'core/storage/secure_storage_service.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/login_screen.dart';
import 'features/home/main_shell.dart';
import 'features/notifications/models.dart';
import 'features/notifications/notifications_api.dart';
import 'features/notifications/push_service.dart';

/// Lets the [ApiClient] forced-logout listener navigate without a context.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// A deep link that arrived before the Navigator was mounted. Cold-start taps
/// race MaterialApp's first build, so buffer rather than drop.
PushDataPayload? _pendingDeepLink;

const _allowedRoles = {'DRIVER', 'EMT', 'NURSE'};

Future<void> main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // Nothing before login needs Firebase, so it runs alongside the session
  // read instead of gating the first frame behind it.
  final firebaseReady = _initFirebase();
  final initialHome = await _resolveInitialScreen();

  runApp(MccgEocApp(initialHome: initialHome));

  ApiClient.instance.onBeforeForcedLogout = PushService.instance.unregister;

  ApiClient.instance.onForcedLogout.addListener(() {
    if (!ApiClient.instance.onForcedLogout.value) return;
    ApiClient.instance.onForcedLogout.value = false;
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  });

  if (initialHome is MainShell) {
    _silentVerifySession();
    firebaseReady.then((ok) {
      if (ok) {
        PushService.instance.initialize(NotificationsApi(ApiClient.instance.dio));
      }
    });
  }
}

Future<bool> _initFirebase() async {
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    return true;
  } catch (e) {
    // A missing google-services.json lands here. The app stays usable; the
    // handset simply receives no push until the config is shipped.
    debugPrint('[main] Firebase initialization failed: $e');
    return false;
  }
}

/// Offline session validation, so a returning responder sees their assignment
/// without waiting on the network.
Future<Widget> _resolveInitialScreen() async {
  try {
    final storage = SecureStorageService.instance;
    final results = await Future.wait([
      storage.getToken(),
      storage.getUser(),
    ]);

    final token = results[0] as String?;
    final user = results[1] as Map<String, dynamic>?;

    if (token == null || token.isEmpty) {
      return const LoginScreen();
    }

    if (storage.isTokenExpired(token)) {
      await storage.clearAll();
      return const LoginScreen();
    }

    final role = user?['role'] as String? ?? '';
    if (user != null && !_allowedRoles.contains(role)) {
      await storage.clearAll();
      return const LoginScreen();
    }

    return const MainShell();
  } catch (e) {
    debugPrint('[Auth] Error resolving startup session: $e');
    return const LoginScreen();
  }
}

void _silentVerifySession() {
  ApiClient.instance.get('/auth/me').then((response) {
    final body = response.data as Map<String, dynamic>;
    final remoteUser = body['data'] as Map<String, dynamic>;
    final remoteRole = remoteUser['role'] as String? ?? '';

    if (!_allowedRoles.contains(remoteRole)) {
      SecureStorageService.instance.clearAll().then((_) {
        navigatorKey.currentState?.pushAndRemoveUntil(
          MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      });
      return;
    }

    SecureStorageService.instance.saveUser(remoteUser);
  }).catchError((e) {
    // A 401 is handled by the ApiClient interceptor, which forces logout.
    debugPrint('[Auth] Silent revalidation error: $e');
  });
}

class MccgEocApp extends StatefulWidget {
  const MccgEocApp({
    super.key,
    this.initialHome = const LoginScreen(),
  });

  final Widget initialHome;

  @override
  State<MccgEocApp> createState() => _MccgEocAppState();
}

class _MccgEocAppState extends State<MccgEocApp> {
  @override
  void initState() {
    super.initState();
    PushService.instance.onDeepLink = _handleDeepLink;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FlutterNativeSplash.remove();
      _flushPendingDeepLink();
    });
  }

  void _handleDeepLink(PushDataPayload payload) {
    if (navigatorKey.currentState == null) {
      _pendingDeepLink = payload;
      return;
    }
    _navigateTo(payload);
  }

  void _flushPendingDeepLink() {
    final pending = _pendingDeepLink;
    if (pending != null) {
      _pendingDeepLink = null;
      _navigateTo(pending);
    }
  }

  void _navigateTo(PushDataPayload payload) {
    if (payload.isEmpty) return;
    AppEvents.focusAssignment();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MCCG EOC',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: widget.initialHome,
    );
  }
}

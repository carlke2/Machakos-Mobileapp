import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'core/network/api_client.dart';
import 'core/storage/secure_storage_service.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/login_screen.dart';
import 'features/home/main_shell.dart';
import 'features/notifications/models.dart';
import 'features/notifications/notifications_api.dart';
import 'features/notifications/push_service.dart';

/// Global navigator key — passed to [MaterialApp] so the [ApiClient]
/// forced-logout listener can navigate without a BuildContext.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// A deep link that arrived before the Navigator was mounted. Cold-start
/// taps race MaterialApp's build — buffer instead of dropping.
PushDataPayload? _pendingDeepLink;

const _allowedRoles = {'DRIVER', 'EMT', 'NURSE'};

Future<void> main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  } catch (e) {
    debugPrint('[main] Firebase initialization error: $e');
  }

  // Fast offline auth resolution (~15-30ms) directly behind preserved native splash:
  final initialHome = await _resolveInitialScreen();

  runApp(MccgEocApp(initialHome: initialHome));

  // Wire up the forced-logout signal from ApiClient.
  ApiClient.instance.onForcedLogout.addListener(() {
    if (!ApiClient.instance.onForcedLogout.value) return;
    ApiClient.instance.onForcedLogout.value = false; // reset before navigating
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  });

  // Dismiss native splash once the initial screen is mounted:
  FlutterNativeSplash.remove();
}

/// Instantaneous offline session validation before rendering target screen.
Future<Widget> _resolveInitialScreen() async {
  try {
    final storage = SecureStorageService.instance;
    final results = await Future.wait([
      storage.getToken(),
      storage.getUser(),
    ]);

    final token = results[0] as String?;
    final user = results[1] as Map<String, dynamic>?;

    // 1. Missing token -> immediate login
    if (token == null || token.isEmpty) {
      return const LoginScreen();
    }

    // 2. Offline JWT exp claim check -> immediate login if expired
    if (storage.isTokenExpired(token)) {
      debugPrint('[Auth] Stored JWT expired. Clearing session.');
      await storage.clearAll();
      return const LoginScreen();
    }

    // 3. Verify responder role on stored user data
    final role = user?['role'] as String? ?? '';
    if (user != null && !_allowedRoles.contains(role)) {
      debugPrint('[Auth] User role $role not authorized.');
      await storage.clearAll();
      return const LoginScreen();
    }

    // 4. Valid session -> trigger silent non-blocking server verification & FCM registration
    _silentVerifyAndRegister();

    return const MainShell();
  } catch (e) {
    debugPrint('[Auth] Error resolving startup session: $e');
    return const LoginScreen();
  }
}

void _silentVerifyAndRegister() {
  final api = NotificationsApi(ApiClient.instance.dio);
  PushService.instance.initialize(api);

  // Non-blocking server validation post-launch:
  ApiClient.instance.get('/auth/me').then((response) {
    final body = response.data as Map<String, dynamic>;
    final remoteUser = body['data'] as Map<String, dynamic>;
    final remoteRole = remoteUser['role'] as String? ?? '';

    if (!_allowedRoles.contains(remoteRole)) {
      debugPrint('[Auth] Remote user role revoked: $remoteRole');
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
    // 401 is automatically caught by ApiClient interceptor which forces logout
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
    WidgetsBinding.instance.addPostFrameCallback((_) => _flushPendingDeepLink());
  }

  void _handleDeepLink(PushDataPayload payload) {
    final nav = navigatorKey.currentState;
    if (nav == null) {
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
    final caseNumber = payload.caseNumber;
    if (caseNumber == null) return;
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const MainShell()),
      (_) => false,
    );
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


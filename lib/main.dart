import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'components/shared/brand_splash.dart';
import 'core/network/api_client.dart';
import 'core/services/notification_service.dart';
import 'core/storage/secure_storage_service.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/login_screen.dart';
import 'features/home/main_shell.dart';

/// Global navigator key used by [ApiClient] to redirect on 401.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

const _allowedRoles = {'DRIVER', 'EMT', 'NURSE'};

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Decoupled non-blocking background initializations:
  ApiClient.ensureReady();
  Firebase.initializeApp().then((_) {
    NotificationService.instance.initialize();
  }).catchError((e) {
    debugPrint('[main] Firebase initialization error: $e');
  });

  runApp(const MachakosEocApp());
}

class MachakosEocApp extends StatelessWidget {
  const MachakosEocApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Machakos EOC',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const _AuthGate(),
    );
  }
}

/// Fast startup auth gate matching Malteser-NMS architecture.
/// Reads local session with instant offline JWT exp check, then transitions
/// immediately while performing silent background token verification.
class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    final storage = SecureStorageService.instance;
    final results = await Future.wait([
      storage.getToken(),
      storage.getUser(),
    ]);

    final token = results[0] as String?;
    final user = results[1] as Map<String, dynamic>?;

    // 1. Missing token -> immediate login
    if (token == null || token.isEmpty) {
      _goToLogin();
      return;
    }

    // 2. Offline JWT exp claim check -> immediate login if expired
    if (storage.isTokenExpired(token)) {
      debugPrint('[AuthGate] Stored JWT expired. Clearing session.');
      await storage.clearAll();
      _goToLogin();
      return;
    }

    // 3. Verify responder role on stored user data
    final role = user?['role'] as String? ?? '';
    if (user != null && !_allowedRoles.contains(role)) {
      debugPrint('[AuthGate] User role $role not authorized.');
      await storage.clearAll();
      _goToLogin();
      return;
    }

    // 4. Valid session -> immediate transition to MainShell!
    _goToMainShell();

    // 5. Silent non-blocking server verification & FCM registration
    _silentVerifyAndRegister();
  }

  void _silentVerifyAndRegister() {
    NotificationService.instance.registerToken();

    // Non-blocking server validation post-launch:
    ApiClient.instance.get('/auth/me').then((response) {
      final body = response.data as Map<String, dynamic>;
      final remoteUser = body['data'] as Map<String, dynamic>;
      final remoteRole = remoteUser['role'] as String? ?? '';

      if (!_allowedRoles.contains(remoteRole)) {
        debugPrint('[AuthGate] Remote user role revoked: $remoteRole');
        SecureStorageService.instance.clearAll().then((_) => _goToLogin());
        return;
      }

      SecureStorageService.instance.saveUser(remoteUser);
    }).catchError((e) {
      // 401 is automatically caught by ApiClient interceptor which forces logout
      debugPrint('[AuthGate] Silent revalidation error: $e');
    });
  }

  void _goToLogin() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
    );
  }

  void _goToMainShell() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const MainShell()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const BrandSplash(showSpinner: true);
  }
}


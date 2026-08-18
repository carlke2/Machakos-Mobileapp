import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'core/network/api_client.dart';
import 'core/services/notification_service.dart';
import 'core/storage/secure_storage_service.dart';
import 'core/theme/app_colors.dart';
import 'features/auth/login_screen.dart';
import 'features/home/main_shell.dart';

/// Global navigator key used by [ApiClient] to redirect on 401.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

const _allowedRoles = {'DRIVER', 'EMT', 'NURSE'};

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await ApiClient.init();
  await NotificationService.instance.initialize();
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
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          surface: AppColors.surface,
        ),
        inputDecorationTheme: const InputDecorationTheme(isDense: true),
      ),
      home: const _AuthGate(),
    );
  }
}

/// Checks for a stored JWT on launch and routes accordingly.
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
    final token = await storage.getToken();

    if (token == null || token.isEmpty) {
      _goToLogin();
      return;
    }

    // Validate token + re-check role via GET /auth/me.
    try {
      final response = await ApiClient.instance.get('/auth/me');
      final body = response.data as Map<String, dynamic>;
      final user = body['data'] as Map<String, dynamic>;
      final role = user['role'] as String? ?? '';

      if (!_allowedRoles.contains(role)) {
        await storage.clearAll();
        _goToLogin();
        return;
      }

      // Token valid, role OK — persist refreshed user data and proceed.
      await storage.saveUser(user);
      NotificationService.instance.registerToken();
      _goToMainShell();
    } catch (_) {
      // Token expired / network error — clear and show login.
      await storage.clearAll();
      _goToLogin();
    }
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
    return const Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );
  }
}

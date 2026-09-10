import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobileapp/core/theme/app_theme.dart';
import 'package:mobileapp/features/auth/login_screen.dart';

void main() {
  testWidgets('Login screen smoke test — renders Sign In button',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const LoginScreen(),
      ),
    );
    await tester.pump();

    // Verify core Phone+OTP login UI elements are present.
    expect(find.text('MCCG Emergency Operations'), findsOneWidget);
    expect(find.text('Phone number'), findsOneWidget);
    expect(find.text('Send code'), findsOneWidget);
  });
}

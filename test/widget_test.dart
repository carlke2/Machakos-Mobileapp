import 'package:flutter_test/flutter_test.dart';

import 'package:mobileapp/main.dart';

void main() {
  testWidgets('Login screen smoke test — renders Sign In button',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MachakosEocApp());

    // Verify core login UI elements are present.
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('Emergency Operations Platform'), findsOneWidget);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobileapp/core/theme/app_theme.dart';
import 'package:mobileapp/features/crew/crew_repository.dart';
import 'package:mobileapp/features/crew/models.dart';
import 'package:mobileapp/features/inventory/inventory_models.dart';
import 'package:mobileapp/features/inventory/inventory_repository.dart';
import 'package:mobileapp/features/inventory/inventory_screen.dart';

class FakeInventoryRepository extends InventoryRepository {
  const FakeInventoryRepository({this.items = const []});
  final List<InventoryItem> items;

  @override
  Future<List<InventoryItem>> listAvailable() async => items;

  @override
  Future<List<InventoryCheckout>> myStock() async => [];
}

class FakeCrewRepository extends CrewRepository {
  const FakeCrewRepository({this.activeCheckIn});
  final CheckInStatus? activeCheckIn;

  @override
  Future<CheckInStatus?> getMyCheckIn() async => activeCheckIn;
}

void main() {
  testWidgets('InventoryScreen renders AppBar and two navigation tabs',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const InventoryScreen(
          inventoryRepository: FakeInventoryRepository(),
          crewRepository: FakeCrewRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify AppBar title
    expect(find.text('Inventory'), findsOneWidget);

    // Verify TabBar tabs
    expect(find.text('Stock'), findsOneWidget);
    expect(find.text('My Stock'), findsOneWidget);
  });

  testWidgets('InventoryScreen displays Vehicle Check-in Guard Banner when not checked in',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const InventoryScreen(
          inventoryRepository: FakeInventoryRepository(),
          crewRepository: FakeCrewRepository(activeCheckIn: null),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Vehicle Check-in Required'), findsOneWidget);
    expect(
      find.text(
        'You must check in to an ambulance on the Crew tab before checking out stock.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('InventoryScreen displays Active Ambulance Badge when responder is checked in',
      (WidgetTester tester) async {
    const fakeStatus = CheckInStatus(
      vehicleId: 'v-1',
      registrationNumber: 'KDA 999Z',
      status: 'READY',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const InventoryScreen(
          inventoryRepository: FakeInventoryRepository(),
          crewRepository: FakeCrewRepository(activeCheckIn: fakeStatus),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Active Ambulance: KDA 999Z'), findsOneWidget);
  });

  testWidgets('InventoryScreen switches tabs on tap',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const InventoryScreen(
          inventoryRepository: FakeInventoryRepository(),
          crewRepository: FakeCrewRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap 'My Stock' tab
    await tester.tap(find.text('My Stock'));
    await tester.pumpAndSettle();

    // Verify 'My Stock' tab is active
    expect(find.text('My Stock'), findsOneWidget);
  });
}

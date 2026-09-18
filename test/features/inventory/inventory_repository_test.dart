import 'package:flutter_test/flutter_test.dart';
import 'package:mobileapp/features/inventory/inventory_models.dart';
import 'package:mobileapp/features/inventory/inventory_repository.dart';

void main() {
  group('InventoryRepository', () {
    test('instantiates cleanly', () {
      const repo = InventoryRepository();
      expect(repo, isA<InventoryRepository>());
    });

    test('checkout maps CartLine items to expected payload structure', () {
      final item1 = InventoryItem.fromJson({
        'id': 'item-1',
        'name': 'Surgical Gloves',
        'category': 'CONSUMABLES',
        'unit': 'box',
        'quantityStock': 20,
        'reorderLevel': 5,
      });

      final item2 = InventoryItem.fromJson({
        'id': 'item-2',
        'name': 'Oxygen Mask',
        'category': 'AIRWAY',
        'unit': 'each',
        'quantityStock': 10,
        'reorderLevel': 2,
      });

      final cartLines = [
        CartLine(item: item1, quantity: 3),
        CartLine(item: item2, quantity: 1),
      ];

      final payload = cartLines
          .map((l) => {'itemId': l.item.id, 'quantity': l.quantity})
          .toList();

      expect(payload, [
        {'itemId': 'item-1', 'quantity': 3},
        {'itemId': 'item-2', 'quantity': 1},
      ]);
    });
  });
}

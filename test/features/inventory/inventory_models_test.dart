import 'package:flutter_test/flutter_test.dart';
import 'package:mobileapp/features/inventory/inventory_models.dart';

void main() {
  group('InventoryItem', () {
    test('fromJson parses complete json correctly', () {
      final json = {
        'id': 'item-101',
        'name': 'N95 Respirator Mask',
        'category': 'CONSUMABLES',
        'unit': 'box',
        'quantityStock': 45,
        'reorderLevel': 10,
        'notes': 'Box of 20 pieces',
        'isActive': true,
      };

      final item = InventoryItem.fromJson(json);

      expect(item.id, 'item-101');
      expect(item.name, 'N95 Respirator Mask');
      expect(item.category, 'CONSUMABLES');
      expect(item.unit, 'box');
      expect(item.quantityStock, 45);
      expect(item.reorderLevel, 10);
      expect(item.notes, 'Box of 20 pieces');
      expect(item.isActive, isTrue);
      expect(item.isLowStock, isFalse);
    });

    test('fromJson uses defaults for missing optional fields', () {
      final json = {
        'id': 'item-102',
        'name': 'Oxygen Cylinder (10L)',
        'category': 'AIRWAY',
      };

      final item = InventoryItem.fromJson(json);

      expect(item.unit, 'each');
      expect(item.quantityStock, 0);
      expect(item.reorderLevel, 0);
      expect(item.notes, isNull);
      expect(item.isActive, isTrue);
    });

    test('isLowStock returns true when stock is equal to or less than reorderLevel', () {
      final lowStockItem = InventoryItem.fromJson({
        'id': 'item-103',
        'name': 'Sterile Gauze',
        'category': 'WOUND_CARE',
        'unit': 'pack',
        'quantityStock': 5,
        'reorderLevel': 5,
      });

      final outOfStockItem = InventoryItem.fromJson({
        'id': 'item-104',
        'name': 'Adrenaline 1mg',
        'category': 'MEDICATION',
        'unit': 'ampoule',
        'quantityStock': 0,
        'reorderLevel': 10,
      });

      expect(lowStockItem.isLowStock, isTrue);
      expect(outOfStockItem.isLowStock, isTrue);
    });
  });

  group('CheckoutUser', () {
    test('fromJson parses slim user correctly', () {
      final json = {
        'id': 'user-1',
        'name': 'John Kiprop',
        'role': 'DRIVER',
      };

      final user = CheckoutUser.fromJson(json);

      expect(user.id, 'user-1');
      expect(user.name, 'John Kiprop');
      expect(user.role, 'DRIVER');
    });
  });

  group('InventoryCheckout', () {
    test('fromJson parses checkout record correctly', () {
      final json = {
        'id': 'co-501',
        'quantity': 10,
        'returnedQuantity': 3,
        'status': 'CHECKED_OUT',
        'checkedOutAt': '2026-09-15T08:00:00Z',
        'returnedAt': null,
        'item': {
          'id': 'item-101',
          'name': 'N95 Respirator Mask',
          'category': 'CONSUMABLES',
          'unit': 'box',
          'quantityStock': 45,
          'reorderLevel': 10,
          'isActive': true,
        },
        'user': {
          'id': 'user-1',
          'name': 'John Kiprop',
          'role': 'DRIVER',
        },
      };

      final checkout = InventoryCheckout.fromJson(json);

      expect(checkout.id, 'co-501');
      expect(checkout.quantity, 10);
      expect(checkout.returnedQuantity, 3);
      expect(checkout.status, 'CHECKED_OUT');
      expect(checkout.outstanding, 7);
      expect(checkout.isFullyReturned, isFalse);
      expect(checkout.item.name, 'N95 Respirator Mask');
      expect(checkout.user.name, 'John Kiprop');
    });

    test('isFullyReturned returns true when status is RETURNED', () {
      final json = {
        'id': 'co-502',
        'quantity': 5,
        'returnedQuantity': 5,
        'status': 'RETURNED',
        'checkedOutAt': '2026-09-15T07:00:00Z',
        'returnedAt': '2026-09-15T08:30:00Z',
        'item': {
          'id': 'item-105',
          'name': 'Pulse Oximeter',
          'category': 'VITALS',
          'unit': 'unit',
          'quantityStock': 12,
          'reorderLevel': 2,
          'isActive': true,
        },
        'user': {
          'id': 'user-2',
          'name': 'Mary Wanjiku',
          'role': 'NURSE',
        },
      };

      final checkout = InventoryCheckout.fromJson(json);

      expect(checkout.outstanding, 0);
      expect(checkout.isFullyReturned, isTrue);
      expect(checkout.returnedAt, '2026-09-15T08:30:00Z');
    });
  });

  group('CartLine', () {
    test('creates line and updates quantity', () {
      final item = InventoryItem.fromJson({
        'id': 'item-1',
        'name': 'BP Cuff',
        'category': 'VITALS',
        'unit': 'piece',
        'quantityStock': 10,
        'reorderLevel': 2,
        'isActive': true,
      });

      final line = CartLine(item: item, quantity: 2);

      expect(line.item.id, 'item-1');
      expect(line.quantity, 2);

      line.quantity = 5;
      expect(line.quantity, 5);
    });
  });
}

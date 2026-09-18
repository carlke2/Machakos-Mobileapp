library;

class InventoryItem {
  const InventoryItem({
    required this.id,
    required this.name,
    required this.category,
    required this.unit,
    required this.quantityStock,
    required this.reorderLevel,
    this.notes,
    required this.isActive,
  });

  final String id;
  final String name;

  /// VITALS | CONSUMABLES | MEDICATION | AIRWAY | WOUND_CARE | OTHER
  final String category;

  /// Unit of measure, e.g. "each", "box", "pack", "litre", "set".
  final String unit;

  final int quantityStock;
  final int reorderLevel;
  final String? notes;
  final bool isActive;

  bool get isLowStock => quantityStock <= reorderLevel;

  factory InventoryItem.fromJson(Map<String, dynamic> json) => InventoryItem(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? 'Unnamed Item',
        category: json['category']?.toString() ?? 'MEDICAL',
        unit: json['unit']?.toString() ?? 'each',
        quantityStock: (json['quantityStock'] as num?)?.toInt() ?? 0,
        reorderLevel: (json['reorderLevel'] as num?)?.toInt() ?? 0,
        notes: json['notes']?.toString(),
        isActive: json['isActive'] as bool? ?? true,
      );
}

class CheckoutUser {
  const CheckoutUser({
    required this.id,
    required this.name,
    required this.role,
  });

  final String id;
  final String name;
  final String role;

  factory CheckoutUser.fromJson(Map<String, dynamic>? json) => CheckoutUser(
        id: json?['id']?.toString() ?? '',
        name: json?['name']?.toString() ?? 'Responder',
        role: json?['role']?.toString() ?? 'CREW',
      );
}

/// Stock drawn from central inventory onto an ambulance.
class InventoryCheckout {
  const InventoryCheckout({
    required this.id,
    required this.quantity,
    required this.returnedQuantity,
    required this.status,
    required this.checkedOutAt,
    this.returnedAt,
    required this.item,
    required this.user,
  });

  final String id;
  final int quantity;
  final int returnedQuantity;

  /// CHECKED_OUT | RETURNED
  final String status;

  final String checkedOutAt;
  final String? returnedAt;

  final InventoryItem item;
  final CheckoutUser user;

  int get outstanding => quantity - returnedQuantity;

  bool get isFullyReturned => status == 'RETURNED';

  factory InventoryCheckout.fromJson(Map<String, dynamic> json) =>
      InventoryCheckout(
        id: json['id']?.toString() ?? '',
        quantity: (json['quantity'] as num?)?.toInt() ?? 0,
        returnedQuantity: (json['returnedQuantity'] as num?)?.toInt() ?? 0,
        status: json['status']?.toString() ?? 'CHECKED_OUT',
        checkedOutAt: json['checkedOutAt']?.toString() ?? DateTime.now().toIso8601String(),
        returnedAt: json['returnedAt']?.toString(),
        item: json['item'] is Map<String, dynamic>
            ? InventoryItem.fromJson(json['item'] as Map<String, dynamic>)
            : const InventoryItem(
                id: '',
                name: 'Item',
                category: 'MEDICAL',
                unit: 'each',
                quantityStock: 0,
                reorderLevel: 0,
                isActive: true,
              ),
        user: CheckoutUser.fromJson(json['user'] as Map<String, dynamic>?),
      );
}

/// A line in the local cart, before checkout is posted.
class CartLine {
  CartLine({required this.item, required this.quantity});

  final InventoryItem item;
  int quantity;
}

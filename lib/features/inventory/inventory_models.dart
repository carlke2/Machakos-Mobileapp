/// Data models for the Inventory feature.
///
/// Mirrors the backend Prisma models:
///   - InventoryItem   (central stock)
///   - InventoryCheckout (crew onboard stock)
library;

// ─────────────────────────────────────────────────────────────────────────────
// InventoryItem
// ─────────────────────────────────────────────────────────────────────────────

/// A central stock item (e.g. a box of gloves, an oxygen cylinder).
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

  /// Human-readable name, e.g. "Surgical Gloves (Large)".
  final String name;

  /// One of: VITALS | CONSUMABLES | MEDICATION | AIRWAY | WOUND_CARE | OTHER
  final String category;

  /// Unit of measure, e.g. "each", "box", "pack", "litre", "set".
  final String unit;

  /// Current units in central stock.
  final int quantityStock;

  /// When stock falls to or below this level a low-stock warning is shown.
  final int reorderLevel;

  final String? notes;
  final bool isActive;

  /// True when central stock is at or below the configured reorder level.
  bool get isLowStock => quantityStock <= reorderLevel;

  factory InventoryItem.fromJson(Map<String, dynamic> json) => InventoryItem(
        id: json['id'] as String,
        name: json['name'] as String,
        category: json['category'] as String,
        unit: json['unit'] as String? ?? 'each',
        quantityStock: (json['quantityStock'] as num?)?.toInt() ?? 0,
        reorderLevel: (json['reorderLevel'] as num?)?.toInt() ?? 0,
        notes: json['notes'] as String?,
        isActive: json['isActive'] as bool? ?? true,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// CheckoutUser  (slim user embedded in InventoryCheckout responses)
// ─────────────────────────────────────────────────────────────────────────────

class CheckoutUser {
  const CheckoutUser({
    required this.id,
    required this.name,
    required this.role,
  });

  final String id;
  final String name;
  final String role;

  factory CheckoutUser.fromJson(Map<String, dynamic> json) => CheckoutUser(
        id: json['id'] as String,
        name: json['name'] as String,
        role: json['role'] as String,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// InventoryCheckout
// ─────────────────────────────────────────────────────────────────────────────

/// A record of stock drawn from central inventory onto an ambulance.
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

  /// Original quantity taken.
  final int quantity;

  /// How many units have already been returned.
  final int returnedQuantity;

  /// "CHECKED_OUT" or "RETURNED".
  final String status;

  final String checkedOutAt;
  final String? returnedAt;

  final InventoryItem item;
  final CheckoutUser user;

  /// Units still outstanding (not yet returned).
  int get outstanding => quantity - returnedQuantity;

  bool get isFullyReturned => status == 'RETURNED';

  factory InventoryCheckout.fromJson(Map<String, dynamic> json) =>
      InventoryCheckout(
        id: json['id'] as String,
        quantity: (json['quantity'] as num).toInt(),
        returnedQuantity: (json['returnedQuantity'] as num?)?.toInt() ?? 0,
        status: json['status'] as String? ?? 'CHECKED_OUT',
        checkedOutAt: json['checkedOutAt'] as String,
        returnedAt: json['returnedAt'] as String?,
        item: InventoryItem.fromJson(json['item'] as Map<String, dynamic>),
        user: CheckoutUser.fromJson(json['user'] as Map<String, dynamic>),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// CartLine  (local-only — used by the checkout cart in the UI)
// ─────────────────────────────────────────────────────────────────────────────

/// A single line in the local in-memory cart before it is posted to the API.
class CartLine {
  CartLine({required this.item, required this.quantity});

  final InventoryItem item;
  int quantity;
}

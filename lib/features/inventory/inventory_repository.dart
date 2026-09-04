import 'package:mobileapp/core/network/api_client.dart';
import 'inventory_models.dart';

/// Repository that maps the four backend inventory endpoints to typed
/// Dart methods.
///
/// Endpoints (all require DRIVER | EMT | NURSE role):
///   GET  /inventory                       → [listAvailable]
///   POST /inventory/checkout              → [checkout]
///   GET  /inventory/my                    → [myStock]
///   POST /inventory/checkouts/:id/return  → [returnItem]
class InventoryRepository {
  const InventoryRepository();

  // ── Browse ──────────────────────────────────────────────────────────────

  /// Returns all active central-stock items, ordered by category then name.
  Future<List<InventoryItem>> listAvailable() async {
    final response = await ApiClient.instance.get('/inventory');
    final body = response.data as Map<String, dynamic>;
    final data = body['data'] as List<dynamic>;
    return data
        .map((e) => InventoryItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Checkout ─────────────────────────────────────────────────────────────

  /// Posts a cart of items to the API, drawing them from central stock onto
  /// the ambulance the caller is currently checked into.
  ///
  /// [lines] must not be empty.
  Future<List<InventoryCheckout>> checkout(List<CartLine> lines) async {
    final items = lines
        .map((l) => {'itemId': l.item.id, 'quantity': l.quantity})
        .toList();

    final response = await ApiClient.instance.post(
      '/inventory/checkout',
      data: {'items': items},
    );

    final body = response.data as Map<String, dynamic>;
    final data = body['data'] as List<dynamic>;
    return data
        .map((e) => InventoryCheckout.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── My Stock ─────────────────────────────────────────────────────────────

  /// Returns all CHECKED_OUT records for the ambulance the caller is on.
  /// The vehicle is resolved server-side from the caller's current check-in.
  Future<List<InventoryCheckout>> myStock() async {
    final response = await ApiClient.instance.get('/inventory/my');
    final body = response.data as Map<String, dynamic>;
    final data = body['data'] as List<dynamic>;
    return data
        .map((e) => InventoryCheckout.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Return ────────────────────────────────────────────────────────────────

  /// Returns [quantity] units of a checkout back to central stock.
  ///
  /// The server validates that [quantity] does not exceed the outstanding
  /// amount. Throws [ApiException] on validation failure.
  Future<InventoryCheckout> returnItem(
    String checkoutId,
    int quantity,
  ) async {
    final response = await ApiClient.instance.post(
      '/inventory/checkouts/$checkoutId/return',
      data: {'quantity': quantity},
    );

    final body = response.data as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>;
    return InventoryCheckout.fromJson(data);
  }
}

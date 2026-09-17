import 'package:mobileapp/core/network/api_client.dart';
import 'inventory_models.dart';

/// All endpoints require the DRIVER, EMT or NURSE role.
class InventoryRepository {
  const InventoryRepository();

  Future<List<InventoryItem>> listAvailable() async {
    final response = await ApiClient.instance.get('/inventory');
    final body = response.data as Map<String, dynamic>;
    final data = body['data'] as List<dynamic>;
    return data
        .map((e) => InventoryItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Draws [lines] from central stock onto the ambulance the caller is
  /// currently checked into. [lines] must not be empty.
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

  /// Outstanding checkouts for the caller's ambulance. The vehicle is resolved
  /// server-side from their current check-in.
  Future<List<InventoryCheckout>> myStock() async {
    final response = await ApiClient.instance.get('/inventory/my');
    final body = response.data as Map<String, dynamic>;
    final data = body['data'] as List<dynamic>;
    return data
        .map((e) => InventoryCheckout.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Throws [ApiException] if [quantity] exceeds the outstanding amount.
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

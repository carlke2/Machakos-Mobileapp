import 'package:flutter/material.dart';
import 'package:mobileapp/core/network/api_client.dart';
import 'package:mobileapp/core/theme/app_colors.dart';
import 'inventory_models.dart';
import 'inventory_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// InventoryScreen  (two-tab: Stock & My Stock)
// ─────────────────────────────────────────────────────────────────────────────

class InventoryScreen extends StatelessWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.brandNavy,
          foregroundColor: AppColors.onPrimary,
          title: const Text(
            'Inventory',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
          ),
          bottom: const TabBar(
            indicatorColor: AppColors.accent,
            labelColor: AppColors.onPrimary,
            unselectedLabelColor: Color(0xFF90AAC4),
            tabs: [
              Tab(text: 'Stock'),
              Tab(text: 'My Stock'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _StockTab(),
            _MyStockTab(),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Returns a display-friendly label for the raw backend category string.
String _categoryLabel(String category) {
  switch (category) {
    case 'VITALS':
      return 'Vitals Equipment';
    case 'CONSUMABLES':
      return 'Consumables';
    case 'MEDICATION':
      return 'Medication';
    case 'AIRWAY':
      return 'Airway Management';
    case 'WOUND_CARE':
      return 'Wound Care';
    default:
      return 'Other';
  }
}

/// Returns an icon appropriate for each inventory category.
IconData _categoryIcon(String category) {
  switch (category) {
    case 'VITALS':
      return Icons.monitor_heart_outlined;
    case 'CONSUMABLES':
      return Icons.local_hospital_outlined;
    case 'MEDICATION':
      return Icons.medication_outlined;
    case 'AIRWAY':
      return Icons.air_outlined;
    case 'WOUND_CARE':
      return Icons.healing_outlined;
    default:
      return Icons.inventory_2_outlined;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 1 – Stock (Browse & Checkout)
// ─────────────────────────────────────────────────────────────────────────────

class _StockTab extends StatefulWidget {
  const _StockTab();

  @override
  State<_StockTab> createState() => _StockTabState();
}

class _StockTabState extends State<_StockTab>
    with AutomaticKeepAliveClientMixin {
  final _repo = const InventoryRepository();

  bool _loading = true;
  String? _error;
  List<InventoryItem> _items = [];

  /// itemId → CartLine (local cart, not yet sent to the API).
  final Map<String, CartLine> _cart = {};

  bool _checkingOut = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _repo.listAvailable();
      if (mounted) setState(() => _items = items);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Failed to load inventory');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int get _cartTotal =>
      _cart.values.fold(0, (sum, l) => sum + l.quantity);

  void _setQty(InventoryItem item, int delta) {
    setState(() {
      final line = _cart[item.id];
      final current = line?.quantity ?? 0;
      final next = (current + delta).clamp(0, item.quantityStock);
      if (next == 0) {
        _cart.remove(item.id);
      } else {
        if (line != null) {
          line.quantity = next;
        } else {
          _cart[item.id] = CartLine(item: item, quantity: next);
        }
      }
    });
  }

  Future<void> _checkout() async {
    if (_cart.isEmpty) return;
    setState(() => _checkingOut = true);
    try {
      await _repo.checkout(_cart.values.toList());
      if (!mounted) return;
      setState(() => _cart.clear());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Items checked out onto your ambulance'),
          backgroundColor: AppColors.primary,
        ),
      );
      // Switch to My Stock tab to let the crew see onboard items immediately.
      DefaultTabController.of(context).animateTo(1);
      // Refresh available stock so counts are accurate.
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: AppColors.danger,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Checkout failed. Please try again.'),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _checkingOut = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _ErrorView(message: _error!, onRetry: _load);
    }

    if (_items.isEmpty) {
      return const _EmptyView(message: 'No inventory items found');
    }

    // Group by category — preserve the backend sort order (category asc, name asc).
    final grouped = <String, List<InventoryItem>>{};
    for (final item in _items) {
      (grouped[item.category] ??= []).add(item);
    }

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _load,
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 96),
            itemCount: grouped.entries.length,
            itemBuilder: (context, i) {
              final entry = grouped.entries.elementAt(i);
              return _CategorySection(
                category: entry.key,
                items: entry.value,
                cart: _cart,
                onSetQty: _setQty,
              );
            },
          ),
        ),

        // Floating Checkout button
        if (_cart.isNotEmpty)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: SafeArea(
              child: FilledButton.icon(
                onPressed: _checkingOut ? null : _checkout,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: _checkingOut
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.onPrimary,
                        ),
                      )
                    : const Icon(Icons.shopping_cart_checkout),
                label: Text(
                  _checkingOut
                      ? 'Checking out…'
                      : 'Checkout ($_cartTotal item${_cartTotal == 1 ? '' : 's'})',
                  style: const TextStyle(fontSize: 15),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ── Category section ──────────────────────────────────────────────────────────

class _CategorySection extends StatelessWidget {
  const _CategorySection({
    required this.category,
    required this.items,
    required this.cart,
    required this.onSetQty,
  });

  final String category;
  final List<InventoryItem> items;
  final Map<String, CartLine> cart;
  final void Function(InventoryItem, int) onSetQty;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
          child: Row(
            children: [
              Icon(_categoryIcon(category),
                  size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                _categoryLabel(category).toUpperCase(),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        ...items.map((item) => _StockItemRow(
              item: item,
              cartQty: cart[item.id]?.quantity ?? 0,
              onSetQty: onSetQty,
            )),
      ],
    );
  }
}

// ── Stock item row ────────────────────────────────────────────────────────────

class _StockItemRow extends StatelessWidget {
  const _StockItemRow({
    required this.item,
    required this.cartQty,
    required this.onSetQty,
  });

  final InventoryItem item;
  final int cartQty;
  final void Function(InventoryItem, int) onSetQty;

  @override
  Widget build(BuildContext context) {
    final outOfStock = item.quantityStock == 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: item.isLowStock && !outOfStock
              ? Colors.orange.shade200
              : AppColors.border,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            // Name + badges
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: outOfStock
                          ? AppColors.textMuted
                          : AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      _Badge(
                        label: '${item.quantityStock} ${item.unit}',
                        color: outOfStock
                            ? AppColors.danger
                            : item.isLowStock
                                ? Colors.orange.shade700
                                : AppColors.primary,
                      ),
                      if (item.isLowStock && !outOfStock) ...[
                        const SizedBox(width: 5),
                        _Badge(
                          label: 'Low stock',
                          color: Colors.orange.shade700,
                          outlined: true,
                        ),
                      ],
                      if (outOfStock) ...[
                        const SizedBox(width: 5),
                        _Badge(
                          label: 'Out of stock',
                          color: AppColors.danger,
                          outlined: true,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Stepper
            if (!outOfStock)
              _QtyStepper(
                value: cartQty,
                max: item.quantityStock,
                onDecrement: () => onSetQty(item, -1),
                onIncrement: () => onSetQty(item, 1),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 2 – My Stock (Onboard / Return)
// ─────────────────────────────────────────────────────────────────────────────

class _MyStockTab extends StatefulWidget {
  const _MyStockTab();

  @override
  State<_MyStockTab> createState() => _MyStockTabState();
}

class _MyStockTabState extends State<_MyStockTab>
    with AutomaticKeepAliveClientMixin {
  final _repo = const InventoryRepository();

  bool _loading = true;
  String? _error;
  List<InventoryCheckout> _checkouts = [];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final checkouts = await _repo.myStock();
      if (mounted) setState(() => _checkouts = checkouts);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Failed to load onboard stock');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openReturnSheet(InventoryCheckout checkout) async {
    final confirmed = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _ReturnSheet(checkout: checkout),
    );

    if (confirmed == null || confirmed <= 0) return;

    try {
      await _repo.returnItem(checkout.id, confirmed);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Returned $confirmed ${checkout.item.unit} of ${checkout.item.name}',
          ),
          backgroundColor: AppColors.primary,
        ),
      );
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _ErrorView(message: _error!, onRetry: _load);
    }

    if (_checkouts.isEmpty) {
      return const _EmptyView(
        message: 'No items checked out on your ambulance',
        icon: Icons.inventory_2_outlined,
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _checkouts.length,
        itemBuilder: (context, i) {
          final co = _checkouts[i];
          return _CheckoutRow(
            checkout: co,
            onReturn: co.isFullyReturned ? null : () => _openReturnSheet(co),
          );
        },
      ),
    );
  }
}

// ── Checkout row ──────────────────────────────────────────────────────────────

class _CheckoutRow extends StatelessWidget {
  const _CheckoutRow({required this.checkout, this.onReturn});

  final InventoryCheckout checkout;
  final VoidCallback? onReturn;

  @override
  Widget build(BuildContext context) {
    final co = checkout;
    final returned = co.isFullyReturned;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: returned ? AppColors.border : AppColors.border,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    co.item.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: returned
                          ? AppColors.textMuted
                          : AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _Badge(
                        label: returned
                            ? 'Returned'
                            : '${co.outstanding} ${co.item.unit} outstanding',
                        color: returned
                            ? AppColors.textMuted
                            : AppColors.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'by ${co.user.name}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  if (co.returnedQuantity > 0 && !returned)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        '${co.returnedQuantity} of ${co.quantity} returned',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Return button
            if (!returned)
              TextButton(
                onPressed: onReturn,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
                child: const Text('Return'),
              )
            else
              const Icon(Icons.check_circle_outline,
                  color: AppColors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Return bottom sheet
// ─────────────────────────────────────────────────────────────────────────────

class _ReturnSheet extends StatefulWidget {
  const _ReturnSheet({required this.checkout});
  final InventoryCheckout checkout;

  @override
  State<_ReturnSheet> createState() => _ReturnSheetState();
}

class _ReturnSheetState extends State<_ReturnSheet> {
  late int _qty;

  @override
  void initState() {
    super.initState();
    _qty = widget.checkout.outstanding; // default to returning all
  }

  @override
  Widget build(BuildContext context) {
    final co = widget.checkout;
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Return – ${co.item.name}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${co.outstanding} ${co.item.unit} outstanding',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 20),

          // Quantity stepper (centered)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _QtyStepper(
                value: _qty,
                max: co.outstanding,
                onDecrement: () =>
                    setState(() => _qty = (_qty - 1).clamp(1, co.outstanding)),
                onIncrement: () =>
                    setState(() => _qty = (_qty + 1).clamp(1, co.outstanding)),
              ),
            ],
          ),
          const SizedBox(height: 20),

          FilledButton(
            onPressed: () => Navigator.of(context).pop(_qty),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              minimumSize: const Size.fromHeight(46),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text('Return $_qty ${co.item.unit}'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared small widgets
// ─────────────────────────────────────────────────────────────────────────────

class _QtyStepper extends StatelessWidget {
  const _QtyStepper({
    required this.value,
    required this.max,
    required this.onDecrement,
    required this.onIncrement,
  });

  final int value;
  final int max;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepBtn(
          icon: Icons.remove,
          enabled: value > 0,
          onTap: onDecrement,
        ),
        SizedBox(
          width: 34,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
          ),
        ),
        _StepBtn(
          icon: Icons.add,
          enabled: value < max,
          onTap: onIncrement,
        ),
      ],
    );
  }
}

class _StepBtn extends StatelessWidget {
  const _StepBtn({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          color:
              enabled ? AppColors.primary.withValues(alpha: 0.1) : AppColors.border,
        ),
        child: Icon(
          icon,
          size: 16,
          color: enabled ? AppColors.primary : AppColors.textMuted,
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    required this.color,
    this.outlined = false,
  });
  final String label;
  final Color color;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: outlined ? Colors.transparent : color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: outlined ? Border.all(color: color.withValues(alpha: 0.5)) : null,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppColors.danger, size: 40),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.message, this.icon});
  final String message;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon ?? Icons.inventory_2_outlined,
              color: AppColors.textMuted,
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

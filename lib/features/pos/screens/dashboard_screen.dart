import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../database/database.dart';
import '../../auth/providers/auth_provider.dart';
import '../../hardware/screens/printer_settings_screen.dart';
import '../../kitchen/screens/kitchen_screen.dart';
import '../../shifts/providers/shift_provider.dart';
import '../../shifts/screens/close_shift_screen.dart';
import '../../shifts/screens/open_shift_dialog.dart';
import '../../sync/providers/sync_queue_provider.dart';
import '../../tables/screens/floor_plan_screen.dart';
import '../providers/menu_provider.dart';
import '../providers/cart_provider.dart';
import '../models/product_customization.dart';
import '../models/cart_item.dart';


final readyOrdersCountProvider = StreamProvider<int>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.orders)..where((o) => o.status.equals('READY'))).watch().map(
        (rows) => rows.length,
      );
});

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _lastReadyCount = 0;
  @override
  void initState() {
    super.initState();
    // Schedule the check for after the first frame build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndEnforceShift();
    });
  }

  Future<void> _checkAndEnforceShift() async {
    final userId = ref.read(authControllerProvider).userId;
    if (userId == null) return;

    final shiftService = ref.read(shiftServiceProvider);

    // 1. Check if we already have an ID in memory state
    if (ref.read(activeShiftIdProvider) != null) return;

    // 2. Check Database for an existing open shift for this user
    final existingShiftId = await shiftService.getActiveShift(userId);

    if (existingShiftId != null) {
      // Restore the shift
      ref.read(activeShiftIdProvider.notifier).state = existingShiftId;
    } else {
      // 3. Force Open Shift
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false, // User must open shift or logout
          builder: (context) => OpenShiftDialog(userId: userId),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userRole = ref.watch(authControllerProvider).role;

    // UI GUARDRAILS
    final isAdmin = userRole == 'OWNER' || userRole == 'MANAGER';
    final canManageCash = isAdmin || userRole == 'CASHIER';

    final syncQueue = ref.watch(syncQueueProvider);
    final readyOrdersCount = ref.watch(readyOrdersCountProvider).value ?? 0;

    ref.listen<AsyncValue<int>>(readyOrdersCountProvider, (previous, next) {
      next.whenData((count) async {
        if (count > _lastReadyCount && mounted) {
          await SystemSound.play(SystemSoundType.alert);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$count order(s) ready for service.')),
          );
        }
        _lastReadyCount = count;
      });
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text("Qristal POS - Cashier"),
        backgroundColor: AppTheme.surface,
        actions: [
          // Shift Indicator
          Consumer(
            builder: (context, ref, _) {
              final shiftId = ref.watch(activeShiftIdProvider);
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Chip(
                  label: Text(shiftId != null ? "SHIFT OPEN" : "NO SHIFT"),
                  backgroundColor: shiftId != null
                      ? Colors.green.withOpacity(0.2)
                      : Colors.red.withOpacity(0.2),
                  labelStyle: TextStyle(
                    color: shiftId != null ? Colors.green : Colors.red,
                    fontSize: 10,
                  ),
                ),
              );
            },
          ),

          if (canManageCash)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'close_shift') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CloseShiftScreen()),
                  );
                }
              },
              itemBuilder: (BuildContext context) {
                return [
                  const PopupMenuItem(
                    value: 'close_shift',
                    child: Row(
                      children: [
                        Icon(Icons.assignment_turned_in, color: Colors.black),
                        SizedBox(width: 8),
                        Text(
                          'End Shift / Z-Report',
                          style: TextStyle(color: Colors.black),
                        ),
                      ],
                    ),
                  ),
                ];
              },
            ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                if (syncQueue.pendingOrders > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      "${syncQueue.pendingOrders} Pending",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                const SizedBox(width: 8),
                _buildSyncIcon(syncQueue.status),
                const SizedBox(width: 8),
                if (readyOrdersCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.emerald,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$readyOrdersCount Ready',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
          ),
          // Navigation to Kitchen Display System
          IconButton(
            icon: const Icon(Icons.soup_kitchen),
            tooltip: 'Kitchen Display',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const KitchenScreen()),
              );
            },
          ),
          // Navigation to Printer Settings
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.print),
              tooltip: 'Printer Settings',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PrinterSettingsScreen(),
                  ),
                );
              },
            ),

          const SizedBox(width: 20),
        ],
      ),
      body: Row(
        children: [
          // 1. LEFT COLUMN: Categories
          Expanded(
            flex: 2,
            child: Container(
              color: AppTheme.surface,
              child: const CategoryListWidget(),
            ),
          ),

          // 2. MIDDLE COLUMN: Products Grid
          Expanded(
            flex: 5,
            child: Container(
              color: AppTheme.background,
              padding: const EdgeInsets.all(8),
              child: const ProductGridWidget(),
            ),
          ),

          // 3. RIGHT COLUMN: Cart / Ticket
          Expanded(
            flex: 3,
            child: Container(color: Colors.white, child: const CartWidget()),
          ),
        ],
      ),
    );
  }
}

// --- WIDGETS ---

Widget _buildSyncIcon(ConnectionStatus status) {
  switch (status) {
    case ConnectionStatus.syncing:
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          color: AppTheme.qristalBlue,
          strokeWidth: 2,
        ),
      );
    case ConnectionStatus.offline:
      return const Icon(Icons.cloud_off, color: Colors.grey);
    case ConnectionStatus.error:
      return const Icon(Icons.error_outline, color: AppTheme.error);
    case ConnectionStatus.online:
      return const Icon(Icons.cloud_done, color: AppTheme.emerald);
  }
}

class CategoryListWidget extends ConsumerWidget {
  const CategoryListWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesStreamProvider);
    final selectedId = ref.watch(selectedCategoryProvider);

    return categoriesAsync.when(
      data: (categories) => ListView.builder(
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final cat = categories[index];
          final isSelected = cat.id == selectedId;

          return InkWell(
            onTap: () =>
                ref.read(selectedCategoryProvider.notifier).state = cat.id,
            child: Container(
              height: 80,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              color: isSelected ? AppTheme.qristalBlue.withOpacity(0.2) : null,
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 80,
                    color: hexToColor(cat.colorHex) ?? Colors.grey,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    cat.name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isSelected ? AppTheme.qristalBlue : Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
    );
  }

  Color? hexToColor(String? hex) {
    if (hex == null) return null;
    return Color(int.parse(hex.replaceFirst('#', '0xFF')));
  }
}

class ProductGridWidget extends ConsumerWidget {
  const ProductGridWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(productsStreamProvider);
    final customizationAsync = ref.watch(productCustomizationProvider);

    return productsAsync.when(
      data: (products) => GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 1.2,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: products.length,
        itemBuilder: (context, index) {
          final product = products[index];
          final customization = customizationAsync.maybeWhen(
            data: (mapping) => mapping[product.id],
            orElse: () => null,
          );

          return Card(
            color: AppTheme.surface,
            elevation: 2,
            child: InkWell(
              onTap: () async {
                if (customization == null || !customization.hasOptions) {
                  ref.read(cartProvider.notifier).addToCart(
                        product,
                        routeTo: customization?.productRouteTo,
                      );
                  return;
                }

                await showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: AppTheme.surface,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  builder: (_) => _ProductCustomizationSheet(
                    product: product,
                    customization: customization,
                  ),
                );
              },
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "UGX ${product.price.toStringAsFixed(0)}",
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.emerald,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (customization?.hasOptions == true)
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Chip(
                        label: Text('Customizable', style: TextStyle(fontSize: 11)),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
    );
  }
}

class _ProductCustomizationSheet extends ConsumerStatefulWidget {
  final Product product;
  final ProductCustomization customization;

  const _ProductCustomizationSheet({
    required this.product,
    required this.customization,
  });

  @override
  ConsumerState<_ProductCustomizationSheet> createState() =>
      _ProductCustomizationSheetState();
}

class _ProductCustomizationSheetState
    extends ConsumerState<_ProductCustomizationSheet> {
  final Map<String, Set<String>> _selectedModifierIdsByGroup = {};
  final Set<String> _selectedSideIds = {};

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.of(context).viewInsets.bottom;
    final sideById = {for (final side in widget.customization.sides) side.id: side};

    double optionsTotal = 0;
    for (final group in widget.customization.modifierGroups) {
      final selected = _selectedModifierIdsByGroup[group.id] ?? <String>{};
      for (final modifier in group.modifiers.where((m) => selected.contains(m.id))) {
        optionsTotal += modifier.priceDelta;
      }
    }
    for (final sideId in _selectedSideIds) {
      optionsTotal += sideById[sideId]?.priceDelta ?? 0;
    }

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + insets),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.product.name,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Text(
                    'UGX ${(widget.product.price + optionsTotal).toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 18,
                      color: AppTheme.emerald,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...widget.customization.modifierGroups.map((group) {
                final selected = _selectedModifierIdsByGroup[group.id] ?? <String>{};
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          group.name,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        if (group.isRequired)
                          const Padding(
                            padding: EdgeInsets.only(left: 8),
                            child: Chip(
                              label: Text('Required', style: TextStyle(fontSize: 11)),
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                      ],
                    ),
                    if (group.maxSelect != null || group.minSelect > 0)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          'Select ${group.minSelect}${group.maxSelect != null ? ' - ${group.maxSelect}' : '+'}',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ),
                    ...group.modifiers.map((modifier) {
                      final isChecked = selected.contains(modifier.id);
                      return CheckboxListTile(
                        value: isChecked,
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text(modifier.name),
                        subtitle: modifier.priceDelta != 0
                            ? Text('UGX ${modifier.priceDelta.toStringAsFixed(0)}')
                            : null,
                        onChanged: (value) {
                          final next = {...selected};
                          if (value == true) {
                            final max = group.maxSelect;
                            if (max != null && next.length >= max) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Maximum ${group.maxSelect} selections for ${group.name}.')),
                              );
                              return;
                            }
                            next.add(modifier.id);
                          } else {
                            next.remove(modifier.id);
                          }

                          setState(() {
                            _selectedModifierIdsByGroup[group.id] = next;
                          });
                        },
                      );
                    }),
                    const Divider(height: 20),
                  ],
                );
              }),
              if (widget.customization.sides.isNotEmpty) ...[
                const Text(
                  'Sides',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: widget.customization.sides.map((side) {
                    final selected = _selectedSideIds.contains(side.id);
                    return FilterChip(
                      selected: selected,
                      showCheckmark: false,
                      label: Text(
                        '${side.name}${side.priceDelta > 0 ? ' (+UGX ${side.priceDelta.toStringAsFixed(0)})' : ''}',
                      ),
                      onSelected: (value) {
                        setState(() {
                          if (value) {
                            _selectedSideIds.add(side.id);
                          } else {
                            _selectedSideIds.remove(side.id);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
              ],
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: AppTheme.qristalBlue,
                  ),
                  onPressed: () {
                    for (final group in widget.customization.modifierGroups) {
                      final count = _selectedModifierIdsByGroup[group.id]?.length ?? 0;
                      if (group.isRequired && count < (group.minSelect == 0 ? 1 : group.minSelect)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Please choose required options for ${group.name}.')),
                        );
                        return;
                      }
                      if (count < group.minSelect) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Select at least ${group.minSelect} option(s) for ${group.name}.')),
                        );
                        return;
                      }
                    }

                    final selectedModifiers = <CartModifier>[];
                    for (final group in widget.customization.modifierGroups) {
                      final selectedIds = _selectedModifierIdsByGroup[group.id] ?? const <String>{};
                      for (final modifier in group.modifiers) {
                        if (selectedIds.contains(modifier.id)) {
                          selectedModifiers.add(
                            CartModifier(
                              name: modifier.name,
                              priceDelta: modifier.priceDelta,
                              routeTo: modifier.routeTo,
                            ),
                          );
                        }
                      }
                    }

                    final selectedSides = _selectedSideIds
                        .map((id) => sideById[id])
                        .whereType<SideOption>()
                        .map(
                          (side) => CartSide(
                            name: side.name,
                            quantity: 1,
                            priceDelta: side.priceDelta,
                            routeTo: side.routeTo,
                          ),
                        )
                        .toList();

                    ref.read(cartProvider.notifier).addToCart(
                          widget.product,
                          routeTo: widget.customization.productRouteTo,
                          modifiers: selectedModifiers,
                          sides: selectedSides,
                        );

                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.add_shopping_cart),
                  label: const Text(
                    'Add to Order',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CartWidget extends ConsumerWidget {
  const CartWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartItems = ref.watch(cartProvider);
    final cartNotifier = ref.read(cartProvider.notifier);
    final activeTableId = ref.watch(activeTableIdProvider);

    // Check role for Checkout Button Guardrails
    final userRole = ref.watch(authControllerProvider).role;
    final canCheckout =
        userRole == 'OWNER' || userRole == 'MANAGER' || userRole == 'CASHIER';

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey[100],
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text("Current Order",
                      style: TextStyle(
                          color: Colors.black,
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.delete_sweep, color: Colors.red),
                    onPressed: () => cartNotifier.clearCart(),
                  ),
                ],
              ),
              Text(
                activeTableId == null ? 'Table: Walk-in' : 'Table: $activeTableId',
                style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        Expanded(
          child: cartItems.isEmpty
              ? const Center(
                  child: Text(
                    "Cart is empty",
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(8),
                  itemCount: cartItems.length,
                  separatorBuilder: (ctx, i) => const Divider(),
                  itemBuilder: (context, index) {
                    final item = cartItems[index];
                    return ListTile(
                      title: Text(item.product.name,
                          style: const TextStyle(color: Colors.black87)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "UGX ${item.perItemTotal.toStringAsFixed(0)} x ${item.quantity}",
                            style: const TextStyle(color: Colors.black54),
                          ),
                          if (item.modifiers.isNotEmpty)
                            Text(
                              'Mods: ${item.modifiers.map((m) => m.name).join(', ')}',
                              style: const TextStyle(color: Colors.black54, fontSize: 12),
                            ),
                          if (item.sides.isNotEmpty)
                            Text(
                              'Sides: ${item.sides.map((s) => s.name).join(', ')}',
                              style: const TextStyle(color: Colors.black54, fontSize: 12),
                            ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "UGX ${item.total.toStringAsFixed(0)}",
                            style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.remove_circle_outline,
                              color: Colors.red,
                            ),
                            onPressed: () =>
                                cartNotifier.removeFromCart(item.product),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey[200],
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "TOTAL",
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    "UGX ${cartNotifier.totalAmount.toStringAsFixed(0)}",
                    style: const TextStyle(
                      color: AppTheme.emerald,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  // FIRE TO KITCHEN BUTTON (Available to all, mostly Waiters)
                  Expanded(
                    child: SizedBox(
                      height: 60,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: cartItems.isEmpty
                            ? null
                            : () async {
                                await cartNotifier.sendToKitchen();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("Order sent to kitchen! 🍽️"),
                                  ),
                                );
                              },
                        child: const Text(
                          "SEND TO KITCHEN",
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),
                  Expanded(
                    child: SizedBox(
                      height: 60,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueGrey,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: cartItems.isEmpty
                            ? null
                            : () async {
                                final message = await cartNotifier
                                    .printBillCheck();
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      message ?? 'Bill printed successfully.',
                                    ),
                                  ),
                                );
                              },
                        child: const Text(
                          "PRINT BILL",
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),

                  // PAY/CHECKOUT BUTTON (Only Cashiers/Managers/Owners)
                  if (canCheckout) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: SizedBox(
                        height: 60,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.emerald,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: cartItems.isEmpty
                              ? null
                              : () async {
                                  await cartNotifier.checkout(context);
                                },
                          child: const Text(
                            "PAY & CLOSE",
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

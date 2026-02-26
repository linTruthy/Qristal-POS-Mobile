import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../database/database.dart';
import '../models/cart_item.dart';
import '../../auth/providers/auth_provider.dart';
import '../../hardware/screens/printer_settings_screen.dart';
import '../../kitchen/screens/kitchen_screen.dart';
import '../../shifts/providers/shift_provider.dart';
import '../../shifts/screens/close_shift_screen.dart';
import '../../shifts/screens/open_shift_dialog.dart';
import '../../sync/providers/sync_queue_provider.dart';
import '../providers/menu_provider.dart';
import '../providers/cart_provider.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
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

    return Scaffold(
      appBar: AppBar(
        title: const Text("Qristal POS - Cashier"),
        backgroundColor: AppTheme.surface,
        actions: [
          // Shift Indicator
          Consumer(builder: (context, ref, _) {
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
                      fontSize: 10),
                ));
          }),

          if (canManageCash)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'close_shift') {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const CloseShiftScreen()));
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
                        Text('End Shift / Z-Report',
                            style: TextStyle(color: Colors.black)),
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
          return Card(
            color: AppTheme.surface,
            elevation: 2,
            child: InkWell(
              onTap: () async {
                final config = await showModalBottomSheet<_ProductCustomizationResult>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => _ProductCustomizationSheet(product: product),
                );

                if (config == null || !context.mounted) return;

                ref.read(cartProvider.notifier).addToCart(
                      product,
                      routeTo: config.routeTo,
                      modifiers: config.modifiers,
                      sides: config.sides,
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
                  const SizedBox(height: 10),
                  const Text(
                    'Tap to customize',
                    style: TextStyle(fontSize: 12, color: Colors.white70),
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

class CartWidget extends ConsumerWidget {
  const CartWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartItems = ref.watch(cartProvider);
    final cartNotifier = ref.read(cartProvider.notifier);

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
          child: Row(
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
        ),
        Expanded(
          child: cartItems.isEmpty
              ? const Center(
                  child: Text("Cart is empty",
                      style: TextStyle(color: Colors.grey)))
              : ListView.separated(
                  padding: const EdgeInsets.all(8),
                  itemCount: cartItems.length,
                  separatorBuilder: (ctx, i) => const Divider(),
                  itemBuilder: (context, index) {
                    final item = cartItems[index];
                    return Card(
                      color: Colors.white,
                      child: ListTile(
                        onTap: () async {
                          final updated = await showModalBottomSheet<CartItem>(
                            context: context,
                            isScrollControlled: true,
                            builder: (_) => _EditCartItemSheet(initialItem: item),
                          );
                          if (updated != null) {
                            await cartNotifier.updateCartItem(item, updated);
                          }
                        },
                        title: Text(item.product.name,
                            style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w700)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "UGX ${item.perItemTotal.toStringAsFixed(0)} x ${item.quantity}",
                              style: const TextStyle(color: Colors.black54),
                            ),
                            if ((item.routeTo ?? '').isNotEmpty)
                              Text('Route: ${item.routeTo}', style: const TextStyle(fontSize: 12, color: Colors.deepOrange)),
                            if (item.modifiers.isNotEmpty)
                              Text('Modifiers: ${item.modifiers.map((m) => m.name).join(', ')}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                            if (item.sides.isNotEmpty)
                              Text('Sides: ${item.sides.map((s) => '${s.name} x${s.quantity}').join(', ')}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                              onPressed: () => cartNotifier.decreaseQuantity(item),
                            ),
                            Text('${item.quantity}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline, color: Colors.green),
                              onPressed: () => cartNotifier.increaseQuantity(item),
                            ),
                            const SizedBox(width: 8),
                            Text("UGX ${item.total.toStringAsFixed(0)}",
                                style: const TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold)),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () => cartNotifier.removeCartItem(item),
                            ),
                          ],
                        ),
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
                  const Text("TOTAL",
                      style: TextStyle(
                          color: Colors.black,
                          fontSize: 24,
                          fontWeight: FontWeight.bold)),
                  Text("UGX ${cartNotifier.totalAmount.toStringAsFixed(0)}",
                      style: const TextStyle(
                          color: AppTheme.emerald,
                          fontSize: 28,
                          fontWeight: FontWeight.bold)),
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
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: cartItems.isEmpty
                            ? null
                            : () async {
                                await cartNotifier.sendToKitchen();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content:
                                          Text("Order sent to kitchen! 🍽️")),
                                );
                              },
                        child: const Text(
                          "SEND TO KITCHEN",
                          style: TextStyle(
                              fontSize: 16,
                              color: Colors.white,
                              fontWeight: FontWeight.bold),
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
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: cartItems.isEmpty
                            ? null
                            : () async {
                                final message =
                                    await cartNotifier.printBillCheck();
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      message ?? 'Bill printed successfully.',
                                    ),
                                  ),
                                );
                              },
                        child: const Text("PRINT BILL",
                            style: TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center),
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
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: cartItems.isEmpty
                              ? null
                              : () async {
                                  await cartNotifier.checkout(context);
                                },
                          child: const Text("PAY & CLOSE",
                              style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center),
                        ),
                      ),
                    ),
                  ]
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProductCustomizationResult {
  final String? routeTo;
  final List<CartModifier> modifiers;
  final List<CartSide> sides;

  const _ProductCustomizationResult({
    this.routeTo,
    this.modifiers = const [],
    this.sides = const [],
  });
}

class _ProductCustomizationSheet extends StatefulWidget {
  final Product product;

  const _ProductCustomizationSheet({required this.product});

  @override
  State<_ProductCustomizationSheet> createState() =>
      _ProductCustomizationSheetState();
}

class _ProductCustomizationSheetState extends State<_ProductCustomizationSheet> {
  static const _routes = ['BAR', 'GRILL', 'FRYER', 'PASTRY', 'COLD'];
  static const Map<String, List<String>> _modifierGroupPresets = {
    'Shots': ['Single', 'Double', 'Triple'],
    'Strength': ['Mild', 'Medium', 'Strong'],
    'Sugar': ['None', 'Less', 'Normal', 'Extra'],
  };

  String? _routeTo;
  String _selectedModifierGroup = 'Shots';
  String _selectedModifierOption = 'Single';

  final _customModifierGroupController = TextEditingController();
  final _customModifierOptionController = TextEditingController();
  final _modifierPriceController = TextEditingController(text: '0');
  final _sideNameController = TextEditingController();
  final _sideQtyController = TextEditingController(text: '1');
  final _sidePriceController = TextEditingController(text: '0');
  List<CartModifier> _modifiers = [];
  List<CartSide> _sides = [];

  @override
  void dispose() {
    _customModifierGroupController.dispose();
    _customModifierOptionController.dispose();
    _modifierPriceController.dispose();
    _sideNameController.dispose();
    _sideQtyController.dispose();
    _sidePriceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeOptions = _modifierGroupPresets[_selectedModifierGroup] ?? const [];

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.product.name,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'UGX ${widget.product.price.toStringAsFixed(0)}',
              style: const TextStyle(color: AppTheme.emerald),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _routeTo,
              decoration:
                  const InputDecoration(labelText: 'Route to production lane'),
              items: _routes
                  .map((route) => DropdownMenuItem(value: route, child: Text(route)))
                  .toList(),
              onChanged: (value) => setState(() => _routeTo = value),
            ),
            const SizedBox(height: 16),
            const Text('Modifier groups',
                style: TextStyle(fontWeight: FontWeight.w700)),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedModifierGroup,
                    decoration: const InputDecoration(labelText: 'Group'),
                    items: _modifierGroupPresets.keys
                        .map((group) => DropdownMenuItem(value: group, child: Text(group)))
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      final firstOption =
                          (_modifierGroupPresets[value] ?? const ['Default']).first;
                      setState(() {
                        _selectedModifierGroup = value;
                        _selectedModifierOption = firstOption;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: activeOptions.contains(_selectedModifierOption)
                        ? _selectedModifierOption
                        : activeOptions.first,
                    decoration: const InputDecoration(labelText: 'Option'),
                    items: activeOptions
                        .map((opt) => DropdownMenuItem(value: opt, child: Text(opt)))
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _selectedModifierOption = value);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 90,
                  child: TextField(
                    controller: _modifierPriceController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Δ Price'),
                  ),
                ),
                IconButton(
                  onPressed: _addSelectedModifier,
                  icon: const Icon(Icons.add_circle, color: AppTheme.qristalBlue),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text('Custom modifier (editable group + option)',
                style: TextStyle(fontSize: 12, color: Colors.black54)),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _customModifierGroupController,
                    decoration: const InputDecoration(hintText: 'Group e.g. Milk'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _customModifierOptionController,
                    decoration:
                        const InputDecoration(hintText: 'Option e.g. Oat'),
                  ),
                ),
                IconButton(
                  onPressed: _addCustomModifier,
                  icon: const Icon(Icons.add_circle_outline,
                      color: AppTheme.qristalBlue),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _modifiers
                  .map(
                    (m) => Chip(
                      label: Text(
                          '${m.name}${m.priceDelta == 0 ? '' : ' (+${m.priceDelta.toStringAsFixed(0)})'}'),
                      onDeleted: () =>
                          setState(() => _modifiers = _modifiers.where((x) => x != m).toList()),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 12),
            const Text('Sides', style: TextStyle(fontWeight: FontWeight.w700)),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _sideNameController,
                    decoration: const InputDecoration(hintText: 'Side name'),
                  ),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  width: 70,
                  child: TextField(
                    controller: _sideQtyController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(hintText: 'Qty'),
                  ),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  width: 90,
                  child: TextField(
                    controller: _sidePriceController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(hintText: 'Price'),
                  ),
                ),
                IconButton(
                  onPressed: _addSide,
                  icon: const Icon(Icons.add_circle, color: AppTheme.qristalBlue),
                ),
              ],
            ),
            Wrap(
              spacing: 6,
              children: _sides
                  .map(
                    (s) => Chip(
                      label: Text(
                          '${s.name} x${s.quantity} (+${s.priceDelta.toStringAsFixed(0)})'),
                      onDeleted: () =>
                          setState(() => _sides = _sides.where((x) => x != s).toList()),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(
                  context,
                  _ProductCustomizationResult(
                    routeTo: _routeTo,
                    modifiers: _modifiers,
                    sides: _sides,
                  ),
                ),
                child: const Text('Add to order'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _addSelectedModifier() {
    final price = double.tryParse(_modifierPriceController.text.trim()) ?? 0;
    _addOrReplaceGroupModifier(
      group: _selectedModifierGroup,
      option: _selectedModifierOption,
      priceDelta: price,
    );
  }

  void _addCustomModifier() {
    final group = _customModifierGroupController.text.trim();
    final option = _customModifierOptionController.text.trim();
    final price = double.tryParse(_modifierPriceController.text.trim()) ?? 0;
    if (group.isEmpty || option.isEmpty) return;

    _addOrReplaceGroupModifier(group: group, option: option, priceDelta: price);
    _customModifierGroupController.clear();
    _customModifierOptionController.clear();
  }

  void _addOrReplaceGroupModifier({
    required String group,
    required String option,
    required double priceDelta,
  }) {
    final normalizedGroup = group.trim().toLowerCase();
    final modifierName = '${group.trim()}: ${option.trim()}';

    setState(() {
      _modifiers = [
        ..._modifiers
            .where((m) => !m.name.toLowerCase().startsWith('$normalizedGroup:')),
        CartModifier(name: modifierName, priceDelta: priceDelta, routeTo: _routeTo),
      ];
      _modifierPriceController.text = '0';
    });
  }

  void _addSide() {
    final name = _sideNameController.text.trim();
    final qty = int.tryParse(_sideQtyController.text.trim()) ?? 1;
    final price = double.tryParse(_sidePriceController.text.trim()) ?? 0;
    if (name.isEmpty) return;
    setState(() {
      _sides = [
        ..._sides,
        CartSide(name: name, quantity: qty, priceDelta: price, routeTo: _routeTo),
      ];
      _sideNameController.clear();
      _sideQtyController.text = '1';
      _sidePriceController.text = '0';
    });
  }
}

class _EditCartItemSheet extends StatefulWidget {
  final CartItem initialItem;

  const _EditCartItemSheet({required this.initialItem});

  @override
  State<_EditCartItemSheet> createState() => _EditCartItemSheetState();
}

class _EditCartItemSheetState extends State<_EditCartItemSheet> {
  static const _routes = ['BAR', 'GRILL', 'FRYER', 'PASTRY', 'COLD'];

  late TextEditingController _notesController;
  late TextEditingController _modifierNameController;
  late TextEditingController _sideNameController;

  late String? _routeTo;
  late List<CartModifier> _modifiers;
  late List<CartSide> _sides;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController(text: widget.initialItem.notes);
    _modifierNameController = TextEditingController();
    _sideNameController = TextEditingController();
    _routeTo = widget.initialItem.routeTo;
    _modifiers = [...widget.initialItem.modifiers];
    _sides = [...widget.initialItem.sides];
  }

  @override
  void dispose() {
    _notesController.dispose();
    _modifierNameController.dispose();
    _sideNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Edit ${widget.initialItem.product.name}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _routeTo,
              decoration:
                  const InputDecoration(labelText: 'Route to production lane'),
              items: _routes
                  .map((route) => DropdownMenuItem(value: route, child: Text(route)))
                  .toList(),
              onChanged: (value) => setState(() => _routeTo = value),
            ),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(labelText: 'Kitchen notes'),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            const Text('Modifiers', style: TextStyle(fontWeight: FontWeight.w700)),
            Wrap(
              spacing: 6,
              children: _modifiers
                  .map(
                    (m) => Chip(
                      label: Text(m.name),
                      onDeleted: () =>
                          setState(() => _modifiers = _modifiers.where((x) => x != m).toList()),
                    ),
                  )
                  .toList(),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _modifierNameController,
                    decoration: const InputDecoration(
                      hintText: 'Add/replace modifier (e.g. Shots: Double)',
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _addOrReplaceModifier,
                  icon: const Icon(Icons.add_circle_outline,
                      color: AppTheme.qristalBlue),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text('Sides', style: TextStyle(fontWeight: FontWeight.w700)),
            Wrap(
              spacing: 6,
              children: _sides
                  .map(
                    (s) => Chip(
                      label: Text('${s.name} x${s.quantity}'),
                      onDeleted: () =>
                          setState(() => _sides = _sides.where((x) => x != s).toList()),
                    ),
                  )
                  .toList(),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _sideNameController,
                    decoration:
                        const InputDecoration(hintText: 'Add side (name only)'),
                  ),
                ),
                IconButton(
                  onPressed: _addSide,
                  icon: const Icon(Icons.add_circle_outline,
                      color: AppTheme.qristalBlue),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(
                    context,
                    widget.initialItem.copyWith(
                      notes: _notesController.text.trim(),
                      routeTo: _routeTo,
                      modifiers: _modifiers,
                      sides: _sides,
                    ),
                  );
                },
                child: const Text('Save changes'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _addOrReplaceModifier() {
    final value = _modifierNameController.text.trim();
    if (value.isEmpty) return;

    final groupPrefix = value.contains(':') ? value.split(':').first.trim().toLowerCase() : null;
    setState(() {
      if (groupPrefix != null && groupPrefix.isNotEmpty) {
        _modifiers = _modifiers
            .where((m) => !m.name.toLowerCase().startsWith('$groupPrefix:'))
            .toList();
      }
      _modifiers = [..._modifiers, CartModifier(name: value, routeTo: _routeTo)];
      _modifierNameController.clear();
    });
  }

  void _addSide() {
    final value = _sideNameController.text.trim();
    if (value.isEmpty) return;

    setState(() {
      _sides = [..._sides, CartSide(name: value, quantity: 1, routeTo: _routeTo)];
      _sideNameController.clear();
    });
  }
}

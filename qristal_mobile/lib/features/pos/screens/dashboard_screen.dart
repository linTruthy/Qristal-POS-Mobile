import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../hardware/screens/printer_settings_screen.dart';
import '../../kitchen/screens/kitchen_screen.dart';
import '../../sync/providers/sync_queue_provider.dart';
import '../providers/menu_provider.dart';
import '../providers/cart_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch sync state to show loading indicator if needed

    final syncQueue = ref.watch(syncQueueProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text("Qristal POS - Cashier"),
        backgroundColor: AppTheme.surface,
        actions: [
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
              child: const CategoryList(),
            ),
          ),

          // 2. MIDDLE COLUMN: Products Grid
          Expanded(
            flex: 5,
            child: Container(
              color: AppTheme.background,
              padding: const EdgeInsets.all(8),
              child: const ProductGrid(),
            ),
          ),

          // 3. RIGHT COLUMN: Cart / Ticket
          Expanded(
            flex: 3,
            child: Container(color: Colors.white, child: const CartView()),
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

class CategoryList extends ConsumerWidget {
  const CategoryList({super.key});

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

class ProductGrid extends ConsumerWidget {
  const ProductGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(productsStreamProvider);

    return productsAsync.when(
      data: (products) => GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, // 3 Columns of products
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
              onTap: () {
                // ADD TO CART ACTION
                ref.read(cartProvider.notifier).addToCart(product);
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

class CartView extends ConsumerWidget {
  const CartView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartItems = ref.watch(cartProvider);
    final cartNotifier = ref.read(cartProvider.notifier);

    return Column(
      children: [
        // Ticket Header
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey[100],
          width: double.infinity,
          child: Row(
            children: [
              const Text(
                "Current Order",
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_sweep, color: Colors.red),
                onPressed: () {
                  // Clear Cart
                  cartNotifier.clearCart();
                },
              ),
            ],
          ),
        ),

        // Cart List
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
                      title: Text(
                        item.product.name,
                        style: const TextStyle(color: Colors.black87),
                      ),
                      subtitle: Text(
                        "UGX ${item.product.price.toStringAsFixed(0)} x ${item.quantity}",
                        style: const TextStyle(color: Colors.black54),
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
                            onPressed: () {
                              cartNotifier.removeFromCart(item.product);
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),

        // Total & Checkout
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
              SizedBox(
                width: double.infinity,
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
                          // 1. Get current user (you might need a UserProvider to store the logged-in ID)
                          // For MVP, we can grab it from SecureStorage or pass it down.
                          // Let's assume we have a simple provider for current user ID:
                          //  const userId =
                          //      "YOUR_LOGGED_IN_USER_ID"; // Replace this with actual state later

                          // 2. Save to Local DB (Instant)
                          // await ref
                          //     .read(orderServiceProvider)
                          //     .placeOrder(cartItems: cartItems, userId: userId);
                          await ref.read(cartProvider.notifier).sendToKitchen();

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Order sent to kitchen! 🍽️")),
                          );
                        },
                  child: const Text("SEND TO KITCHEN", style: TextStyle(fontSize: 20)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

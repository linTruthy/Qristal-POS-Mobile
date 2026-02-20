import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../sync/providers/sync_provider.dart';
import '../providers/menu_provider.dart';
import '../providers/cart_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch sync state to show loading indicator if needed
    final syncState = ref.watch(syncControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Qristal POS"),
        actions: [
          // Manual Sync Button
          IconButton(
            icon: syncState.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.sync),
            onPressed: () {
              ref.read(syncControllerProvider.notifier).performSync();
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
            child: Container(
              color: Colors.white,
              child: const CartView(),
            ),
          ),
        ],
      ),
    );
  }
}

// --- WIDGETS ---

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
                      color: hexToColor(cat.colorHex) ?? Colors.grey),
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
                        fontSize: 18, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "\$${product.price.toStringAsFixed(2)}",
                    style:
                        const TextStyle(color: AppTheme.emerald, fontSize: 16),
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
    final total = ref.read(cartProvider.notifier).totalAmount;

    return Column(
      children: [
        // Ticket Header
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey[100],
          width: double.infinity,
          child: const Text(
            "Current Order",
            style: TextStyle(
                color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),

        // Cart List
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(8),
            itemCount: cartItems.length,
            separatorBuilder: (ctx, i) => const Divider(),
            itemBuilder: (context, index) {
              final item = cartItems[index];
              return ListTile(
                title: Text(item.product.name,
                    style: const TextStyle(color: Colors.black)),
                subtitle: Text("x${item.quantity}",
                    style: const TextStyle(color: Colors.grey)),
                trailing: Text(
                  "\$${item.total.toStringAsFixed(2)}",
                  style: const TextStyle(
                      color: Colors.black, fontWeight: FontWeight.bold),
                ),
                onLongPress: () {
                  ref.read(cartProvider.notifier).removeFromCart(item.product);
                },
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
                  const Text("TOTAL",
                      style: TextStyle(
                          color: Colors.black,
                          fontSize: 24,
                          fontWeight: FontWeight.bold)),
                  Text(
                    "\$${total.toStringAsFixed(2)}",
                    style: const TextStyle(
                        color: AppTheme.emerald,
                        fontSize: 28,
                        fontWeight: FontWeight.bold),
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
                          borderRadius: BorderRadius.circular(8))),
                  onPressed: cartItems.isEmpty
                      ? null
                      : () async {
                          // 1. Get current user (you might need a UserProvider to store the logged-in ID)
                          // For MVP, we can grab it from SecureStorage or pass it down.
                          // Let's assume we have a simple provider for current user ID:
                          final userId =
                              "YOUR_LOGGED_IN_USER_ID"; // Replace this with actual state later

                          // 2. Save to Local DB (Instant)
                          await ref
                              .read(orderServiceProvider)
                              .placeOrder(cartItems: cartItems, userId: userId);

                          // 3. Clear UI
                          ref.read(cartProvider.notifier).clearCart();

                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text("Order Saved Locally! 🚀")));

                          // 4. Trigger Background Sync to Cloud
                          // We don't await this because we want the UI to be unblocked immediately
                          ref
                              .read(syncControllerProvider.notifier)
                              .performSync();
                        },
                  child: const Text("CHARGE", style: TextStyle(fontSize: 24)),
                ),
              )
            ],
          ),
        )
      ],
    );
  }
}

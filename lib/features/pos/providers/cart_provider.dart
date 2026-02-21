import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/providers/database_provider.dart';
import '../../../database/database.dart';
import '../../sync/providers/sync_provider.dart';
import '../models/cart_item.dart';
import '../services/order_service.dart';

class CartNotifier extends StateNotifier<List<CartItem>> {
  final AppDatabase db;
  final String? userId;
  final Ref ref; // To trigger sync

  CartNotifier(this.db, this.userId, this.ref) : super([]);

  void addToCart(Product product) {
    final existingIndex = state.indexWhere(
      (item) => item.product.id == product.id,
    );

    if (existingIndex >= 0) {
      // Item exists, increment quantity
      final existingItem = state[existingIndex];
      final updatedItem = existingItem.copyWith(
        quantity: existingItem.quantity + 1,
      );

      // Update state immutably
      state = [
        ...state.sublist(0, existingIndex),
        updatedItem,
        ...state.sublist(existingIndex + 1),
      ];
    } else {
      // Add new item
      state = [...state, CartItem(product: product)];
    }
  }

  void removeFromCart(Product product) {
    state = state.where((item) => item.product.id != product.id).toList();
  }

  void clearCart() {
    state = [];
  }

  double get totalAmount => state.fold(0, (sum, item) => sum + item.total);

  Future<void> placeOrder() async {
    if (state.isEmpty || userId == null) return;

    final orderId = const Uuid().v4();
    final total = totalAmount; // using the getter
    final now = DateTime.now();

    // 1. Transaction to save Order + Items safely
    await db.transaction(() async {
      // Create Header
      await db
          .into(db.orders)
          .insert(
            OrdersCompanion(
              id: Value(orderId),
              receiptNumber: Value(
                orderId.substring(0, 8).toUpperCase(),
              ), // Simple receipt #
              userId: Value(userId!),
              totalAmount: Value(total),
              status: const Value('KITCHEN'), // Send straight to kitchen
              createdAt: Value(now),
              updatedAt: Value(now),
              isSynced: const Value(false),
            ),
          );

      // Create Items
      for (var cartItem in state) {
        await db
            .into(db.orderItems)
            .insert(
              OrderItemsCompanion(
                id: Value(const Uuid().v4()),
                orderId: Value(orderId),
                productId: Value(cartItem.product.id),
                quantity: Value(cartItem.quantity),
                priceAtTimeOfOrder: Value(cartItem.product.price),
                notes: Value(cartItem.notes),
              ),
            );
      }
    });

    // 2. Clear UI
    state = [];

    // 3. Trigger Background Sync immediately so Kitchen sees it
    ref.read(syncControllerProvider.notifier).performSync();
  }
}

final cartProvider = StateNotifierProvider<CartNotifier, List<CartItem>>((ref) {
  final db = ref.watch(databaseProvider);

  // In a real app, store the user ID in a dedicated UserProvider upon login
  // For now, we will grab it from storage or assume a static one if logged in
  // Ideally: final user = ref.watch(currentUserProvider);
  const tempUserId = "temp-user-id"; // Replace this with actual logic later

  return CartNotifier(db, tempUserId, ref);
});
// Add a Provider for OrderService
final orderServiceProvider = Provider(
  (ref) => OrderService(ref.watch(databaseProvider)),
);
// Update the Cart Controller to handle checkout
final checkoutProvider = FutureProvider.family<void, String>((
  ref,
  userId,
) async {
  final cart = ref.read(cartProvider);
  if (cart.isEmpty) return;

  final orderService = ref.read(orderServiceProvider);

  // Place the order locally
  await orderService.placeOrder(
    cartItems: cart,
    userId: userId,
    // tableId: null for now (Takeaway)
  );

  // Clear cart UI
  ref.read(cartProvider.notifier).clearCart();
});

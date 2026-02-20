import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/database_provider.dart';
import '../../../database/database.dart';
import '../models/cart_item.dart';
import '../services/order_service.dart';

class CartNotifier extends StateNotifier<List<CartItem>> {
  CartNotifier() : super([]);

  void addToCart(Product product) {
    final existingIndex =
        state.indexWhere((item) => item.product.id == product.id);

    if (existingIndex >= 0) {
      // Item exists, increment quantity
      final existingItem = state[existingIndex];
      final updatedItem =
          existingItem.copyWith(quantity: existingItem.quantity + 1);

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
}

final cartProvider = StateNotifierProvider<CartNotifier, List<CartItem>>((ref) {
  return CartNotifier();
});
// Add a Provider for OrderService
final orderServiceProvider =
    Provider((ref) => OrderService(ref.watch(databaseProvider)));
// Update the Cart Controller to handle checkout
final checkoutProvider =
    FutureProvider.family<void, String>((ref, userId) async {
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

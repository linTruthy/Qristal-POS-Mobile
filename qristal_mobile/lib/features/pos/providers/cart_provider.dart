import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/providers/database_provider.dart';
import '../../../database/database.dart';
import '../../hardware/services/printer_service.dart';
import '../../sync/providers/sync_provider.dart';
import '../../tables/screens/floor_plan_screen.dart';
import '../models/cart_item.dart';
import '../services/order_service.dart';
import '../widgets/payment_modal.dart';

class CartNotifier extends StateNotifier<List<CartItem>> {
  final AppDatabase db;
  final String? userId;
  final String userName;
  final PrinterService printerService; // <--- ADD THIS
  final Ref ref;

  CartNotifier(
    this.db,
    this.userId,
    this.userName,
    this.printerService,
    this.ref,
  ) : super([]);

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

  // Future<void> placeOrder() async {
  //   if (state.isEmpty || userId == null) return;

  //   final orderId = const Uuid().v4();
  //   final total = totalAmount; // using the getter
  //   final now = DateTime.now();

  //   // 1. Transaction to save Order + Items safely
  //   await db.transaction(() async {
  //     // Create Header
  //     await db
  //         .into(db.orders)
  //         .insert(
  //           OrdersCompanion(
  //             id: Value(orderId),
  //             receiptNumber: Value(
  //               orderId.substring(0, 8).toUpperCase(),
  //             ), // Simple receipt #
  //             userId: Value(userId!),
  //             totalAmount: Value(total),
  //             status: const Value('KITCHEN'), // Send straight to kitchen
  //             createdAt: Value(now),
  //             updatedAt: Value(now),
  //             isSynced: const Value(false),
  //           ),
  //         );

  //     // Create Items
  //     for (var cartItem in state) {
  //       await db
  //           .into(db.orderItems)
  //           .insert(
  //             OrderItemsCompanion(
  //               id: Value(const Uuid().v4()),
  //               orderId: Value(orderId),
  //               productId: Value(cartItem.product.id),
  //               quantity: Value(cartItem.quantity),
  //               priceAtTimeOfOrder: Value(cartItem.product.price),
  //               notes: Value(cartItem.notes),
  //             ),
  //           );
  //     }
  //   });

  //   // 2. Clear UI
  //   state = [];

  //   // 3. Trigger Background Sync immediately so Kitchen sees it
  //   ref.read(syncControllerProvider.notifier).performSync();
  // }

  Future<void> checkout(BuildContext context) async {
    if (state.isEmpty || userId == null) return;

    final total = totalAmount;

    // Show the Dialog
    showDialog(
      context: context,
      builder: (_) => PaymentModal(
        totalAmount: total,
        onConfirmed: (method, tendered, refCode) async {
          await _finalizeOrder(total, method, tendered, refCode);
        },
      ),
    );
  }

  Future<void> _finalizeOrder(
    double total,
    String method,
    double tendered,
    String? refCode,
  ) async {
    final orderId = const Uuid().v4();
    final now = DateTime.now();
    final tableId = ref.read(activeTableIdProvider);

    await db.transaction(() async {
      // 1. Order
      await db
          .into(db.orders)
          .insert(
            OrdersCompanion(
              id: Value(orderId),
              receiptNumber: Value(
                orderId.substring(0, 4).toUpperCase(),
              ), // Short code
              userId: Value(userId!),
              tableId: Value(tableId),
              totalAmount: Value(total),
              status: const Value('CLOSED'), // Closed because it is paid
              isSynced: const Value(false),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
      //If a table was selected, update its status to OCCUPIED locally
      if (tableId != null) {
        await (db.update(db.seatingTables)..where((t) => t.id.equals(tableId)))
            .write(SeatingTablesCompanion(status: const Value('OCCUPIED')));
      }
      // 2. Items
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
              ),
            );
      }

      // 3. Payment
      await db
          .into(db.payments)
          .insert(
            PaymentsCompanion(
              id: Value(const Uuid().v4()),
              orderId: Value(orderId),
              method: Value(method),
              amount: Value(total), // We record the bill amount, not tendered
              reference: Value(refCode),
              createdAt: Value(now),
            ),
          );
    });

    // 2. Trigger Print
    try {
      await printerService.printReceipt(
        orderId: orderId,
        items: state, // The current cart items
        total: total,
        tendered: tendered,
        paymentMethod: method,
        cashierName: userName,
      );
    } catch (e) {
      if (kDebugMode) {
        print("Printing failed (Device might not be connected): $e");
      }
    }

    // 3. Clear State & Sync
    state = [];
    ref.read(syncControllerProvider.notifier).performSync();
  }
}

final cartProvider = StateNotifierProvider<CartNotifier, List<CartItem>>((ref) {
  final db = ref.watch(databaseProvider);
  final printerService = ref.watch(
    printerServiceProvider,
  ); // <--- INJECT PRINTER SERVICE

  // Assuming a temporary user ID for MVP
  const tempUserId = "USER-123";
  const tempUserName = "Admin";

  return CartNotifier(db, tempUserId, tempUserName, printerService, ref);
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

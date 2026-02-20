import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../../database/database.dart';
import '../models/cart_item.dart';

class OrderService {
  final AppDatabase db;
  final Uuid uuid = const Uuid();

  OrderService(this.db);

  Future<void> placeOrder({
    required List<CartItem> cartItems,
    required String userId,
    String? tableId,
  }) async {
    final orderId = uuid.v4();
    final totalAmount = cartItems.fold(0.0, (sum, item) => sum + item.total);

    await db.transaction(() async {
      // 1. Create the Order Header
      await db.into(db.orders).insert(OrdersCompanion(
        id: Value(orderId),
        userId: Value(userId),
        tableId: Value(tableId),
        receiptNumber: Value(orderId.substring(0, 8).toUpperCase()), // Simple receipt ID for now
        totalAmount: Value(totalAmount),
        status: const Value('OPEN'),
        isSynced: const Value(false), // Mark as unsynced!
        createdAt: Value(DateTime.now()),
      ));

      // 2. Create Order Items
      for (final item in cartItems) {
        await db.into(db.orderItems).insert(OrderItemsCompanion(
          id: Value(uuid.v4()),
          orderId: Value(orderId),
          productId: Value(item.product.id),
          quantity: Value(item.quantity),
          priceAtTimeOfOrder: Value(item.product.price),
          notes: Value(item.notes),
        ));
      }
    });
  }
}
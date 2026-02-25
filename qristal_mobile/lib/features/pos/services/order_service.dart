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
        receiptNumber: Value(orderId.substring(0, 4).toUpperCase()), // Simple receipt ID
        totalAmount: Value(totalAmount),
        status: const Value('KITCHEN'), // Default status
        isSynced: const Value(false), // Mark as unsynced!
        createdAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
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

      // 3. Update Seating Table Status if applicable
      if (tableId != null) {
        await (db.update(db.seatingTables)..where((t) => t.id.equals(tableId)))
            .write(const SeatingTablesCompanion(
              status: Value('OCCUPIED'),
              isSynced: Value(true),
        ));
      }
    });
  }

  Future<void> closeOrder(String orderId, double totalAmount, List<Payment> payments) async {
    await db.transaction(() async {
      // 1. Get the order to find the tableId
      final order = await (db.select(db.orders)..where((t) => t.id.equals(orderId))).getSingleOrNull();

      if (order == null) {
        return;
      }
      
      // 2. Update order status
      await (db.update(db.orders)..where((t) => t.id.equals(orderId)))
          .write(OrdersCompanion(
        status: const Value('CLOSED'),
        totalAmount: Value(totalAmount),
        isSynced: const Value(false), // Mark for sync again!
        updatedAt: Value(DateTime.now()),
      ));

      // 3. Insert payments
      for (final payment in payments) {
        await db.into(db.payments).insert(payment.toCompanion(true));
      }
      
      // 4. Update Seating Table Status to 'FREE'
      if (order.tableId != null) {
        await (db.update(db.seatingTables)..where((t) => t.id.equals(order.tableId!)))
          .write(const SeatingTablesCompanion(
            status: Value('FREE'),
            isSynced: Value(true),
          ));
      }
    });
  }
}
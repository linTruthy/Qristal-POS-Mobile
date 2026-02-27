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
    required String shiftId,
    String? tableId,
  }) async {
    final orderId = uuid.v4();
    final totalAmount = cartItems.fold(0.0, (sum, item) => sum + item.total);

    await db.transaction(() async {
      await db.into(db.orders).insert(
            OrdersCompanion(
              id: Value(orderId),
              userId: Value(userId),
              shiftId: Value(shiftId),
              tableId: Value(tableId),
              receiptNumber: Value(orderId.substring(0, 4).toUpperCase()),
              totalAmount: Value(totalAmount),
              status: const Value('KITCHEN'),
              isSynced: const Value(false),
              createdAt: Value(DateTime.now()),
              updatedAt: Value(DateTime.now()),
            ),
          );

      for (final item in cartItems) {
        final orderItemId = uuid.v4();
        await db.into(db.orderItems).insert(
              OrderItemsCompanion(
                id: Value(orderItemId),
                orderId: Value(orderId),
                productId: Value(item.product.id),
                quantity: Value(item.quantity),
                priceAtTimeOfOrder: Value(item.product.price),
                routeTo: Value(item.routeTo),
                notes: Value(item.notes.isEmpty ? null : item.notes),
              ),
            );

        for (final modifier in item.modifiers) {
          await db.into(db.orderItemModifiers).insert(
                OrderItemModifiersCompanion(
                  id: Value(uuid.v4()),
                  orderItemId: Value(orderItemId),
                  name: Value(modifier.name),
                  priceDelta: Value(modifier.priceDelta),
                  routeTo: Value(modifier.routeTo),
                ),
              );
        }

        for (final side in item.sides) {
          await db.into(db.orderItemSides).insert(
                OrderItemSidesCompanion(
                  id: Value(uuid.v4()),
                  orderItemId: Value(orderItemId),
                  name: Value(side.name),
                  quantity: Value(side.quantity),
                  priceDelta: Value(side.priceDelta),
                  routeTo: Value(side.routeTo),
                ),
              );
        }
      }

      if (tableId != null) {
        await (db.update(db.seatingTables)..where((t) => t.id.equals(tableId)))
            .write(const SeatingTablesCompanion(
          status: Value('OCCUPIED'),
          isSynced: Value(true),
        ));
      }
    });
  }

  Future<void> closeOrder(
      String orderId, double totalAmount, List<Payment> payments) async {
    await db.transaction(() async {
      final order =
          await (db.select(db.orders)..where((t) => t.id.equals(orderId)))
              .getSingleOrNull();

      if (order == null) {
        return;
      }

      await (db.update(db.orders)..where((t) => t.id.equals(orderId))).write(
        OrdersCompanion(
          status: const Value('CLOSED'),
          totalAmount: Value(totalAmount),
          isSynced: const Value(false),
          updatedAt: Value(DateTime.now()),
        ),
      );

      for (final payment in payments) {
        await db.into(db.payments).insert(payment.toCompanion(true));
      }

      if (order.tableId != null) {
        await (db.update(db.seatingTables)
              ..where((t) => t.id.equals(order.tableId!)))
            .write(const SeatingTablesCompanion(
          status: Value('FREE'),
          isSynced: Value(true),
        ));
      }
    });
  }
}

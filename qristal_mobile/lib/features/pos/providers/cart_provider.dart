import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/providers/database_provider.dart';
import '../../../database/database.dart';
import '../../auth/providers/auth_provider.dart';
import '../../sync/providers/sync_provider.dart';
import '../../tables/screens/floor_plan_screen.dart';
import '../models/cart_item.dart';
import '../services/order_service.dart';

class CartNotifier extends StateNotifier<List<CartItem>> {
  final AppDatabase db;
  final String? userId;
  final String userName;
  final Ref ref;

  String? _activeOrderId;
  final Map<String, int> _baselineQuantities = {};

  CartNotifier(
    this.db,
    this.userId,
    this.userName,
    this.ref,
  ) : super([]);

  void addToCart(Product product) {
    final existingIndex = state.indexWhere((item) => item.product.id == product.id);

    if (existingIndex >= 0) {
      final existingItem = state[existingIndex];
      final updatedItem = existingItem.copyWith(quantity: existingItem.quantity + 1);
      state = [
        ...state.sublist(0, existingIndex),
        updatedItem,
        ...state.sublist(existingIndex + 1),
      ];
    } else {
      state = [...state, CartItem(product: product)];
    }
  }

  void removeFromCart(Product product) {
    state = state.where((item) => item.product.id != product.id).toList();
  }

  void clearCart() {
    state = [];
    _activeOrderId = null;
    _baselineQuantities.clear();
  }

  double get totalAmount => state.fold(0, (sum, item) => sum + item.total);

  Future<void> loadTableCart(String? tableId) async {
    if (tableId == null) {
      clearCart();
      return;
    }

    final existingOrder = await (db.select(db.orders)
          ..where(
            (o) =>
                o.tableId.equals(tableId) &
                o.status.isIn(const ['KITCHEN', 'PREPARING']),
          )
          ..orderBy([(o) => OrderingTerm.desc(o.createdAt)])
          ..limit(1))
        .getSingleOrNull();

    if (existingOrder == null) {
      clearCart();
      return;
    }

    final typedItems = await db.getOrderItems(existingOrder.id);
    final recalled = typedItems
        .map(
          (row) => CartItem(
            product: row.product,
            quantity: row.item.quantity,
            notes: row.item.notes ?? '',
          ),
        )
        .toList();

    _activeOrderId = existingOrder.id;
    _baselineQuantities
      ..clear()
      ..addAll(_toQuantityMap(recalled));
    state = recalled;
  }

  Future<void> sendToKitchen() async {
    if (state.isEmpty || userId == null) return;

    final now = DateTime.now();
    final tableId = ref.read(activeTableIdProvider);
    final currentQuantities = _toQuantityMap(state);

    if (_activeOrderId == null) {
      final orderId = const Uuid().v4();
      await db.transaction(() async {
        await db.into(db.orders).insert(
              OrdersCompanion(
                id: Value(orderId),
                receiptNumber: Value(_buildOrderNumber(tableId, now)),
                userId: Value(userId!),
                tableId: Value(tableId),
                totalAmount: Value(totalAmount),
                status: const Value('KITCHEN'),
                isSynced: const Value(false),
                createdAt: Value(now),
                updatedAt: Value(now),
              ),
            );

        if (tableId != null) {
          await (db.update(db.seatingTables)..where((t) => t.id.equals(tableId)))
              .write(SeatingTablesCompanion(status: const Value('OCCUPIED')));
        }

        for (final cartItem in state) {
          await db.into(db.orderItems).insert(
                OrderItemsCompanion(
                  id: Value(const Uuid().v4()),
                  orderId: Value(orderId),
                  productId: Value(cartItem.product.id),
                  quantity: Value(cartItem.quantity),
                  priceAtTimeOfOrder: Value(cartItem.product.price),
                  notes: Value(cartItem.notes.isEmpty ? null : cartItem.notes),
                ),
              );
        }
      });

      _activeOrderId = orderId;
      _baselineQuantities
        ..clear()
        ..addAll(currentQuantities);
      state = [];
      ref.read(syncControllerProvider.notifier).performSync();
      return;
    }

    final newItems = <CartItem>[];
    for (final item in state) {
      final key = _cartKey(item.product.id, item.notes);
      final baseline = _baselineQuantities[key] ?? 0;
      final delta = item.quantity - baseline;
      if (delta > 0) {
        newItems.add(item.copyWith(quantity: delta));
      }
    }

    if (newItems.isEmpty) {
      if (kDebugMode) {
        print('No new items to send for order $_activeOrderId');
      }
      return;
    }

    await db.transaction(() async {
      for (final item in newItems) {
        await db.into(db.orderItems).insert(
              OrderItemsCompanion(
                id: Value(const Uuid().v4()),
                orderId: Value(_activeOrderId!),
                productId: Value(item.product.id),
                quantity: Value(item.quantity),
                priceAtTimeOfOrder: Value(item.product.price),
                notes: Value(item.notes.isEmpty ? null : item.notes),
              ),
            );
      }

      await (db.update(db.orders)..where((o) => o.id.equals(_activeOrderId!))).write(
        OrdersCompanion(
          totalAmount: Value(totalAmount),
          updatedAt: Value(now),
          isSynced: const Value(false),
        ),
      );
    });

    _baselineQuantities
      ..clear()
      ..addAll(currentQuantities);

    state = [];
    ref.read(syncControllerProvider.notifier).performSync();
  }

  Map<String, int> _toQuantityMap(List<CartItem> items) {
    final map = <String, int>{};
    for (final item in items) {
      final key = _cartKey(item.product.id, item.notes);
      map[key] = (map[key] ?? 0) + item.quantity;
    }
    return map;
  }

  String _cartKey(String productId, String notes) => '$productId::${notes.trim()}';

  String _buildOrderNumber(String? tableId, DateTime now) {
    if (tableId != null && tableId.isNotEmpty) {
      return tableId.substring(0, 4).toUpperCase();
    }

    final suffix = (now.millisecondsSinceEpoch % 10000).toString().padLeft(4, '0');
    return 'TK$suffix';
  }
}

final cartProvider = StateNotifierProvider<CartNotifier, List<CartItem>>((ref) {
  final db = ref.watch(databaseProvider);
  final authState = ref.watch(authControllerProvider);

  final notifier = CartNotifier(
    db,
    authState.userId,
    authState.userId ?? 'Cashier',
    ref,
  );

  Future.microtask(() => notifier.loadTableCart(ref.read(activeTableIdProvider)));
  ref.listen<String?>(activeTableIdProvider, (previous, next) {
    unawaited(notifier.loadTableCart(next));
  });

  return notifier;
});

final orderServiceProvider = Provider((ref) => OrderService(ref.watch(databaseProvider)));

final checkoutProvider = FutureProvider.family<void, String>((ref, userId) async {
  final cart = ref.read(cartProvider);
  if (cart.isEmpty) return;

  final orderService = ref.read(orderServiceProvider);
  await orderService.placeOrder(
    cartItems: cart,
    userId: userId,
  );

  ref.read(cartProvider.notifier).clearCart();
});

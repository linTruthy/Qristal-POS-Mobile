import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/role_constants.dart';
import '../../../core/providers/database_provider.dart';
import '../../../database/database.dart';
import '../../auth/providers/auth_provider.dart';
import '../../hardware/services/printer_service.dart';
import '../../shifts/providers/shift_provider.dart';
import '../../sync/providers/sync_provider.dart';
import '../../tables/screens/floor_plan_screen.dart';
import '../models/cart_item.dart';
import '../services/order_service.dart';
import '../widgets/payment_modal.dart';

class CartNotifier extends StateNotifier<List<CartItem>> {
  final AppDatabase db;
  final String? userId;
  final String userName;
  final PrinterService printerService;
  final Ref ref;

  String? _activeOrderId;
  final Map<String, int> _baselineQuantities = {};
  int _orderRevision = 0;
  int _lastPrintedRevision = -1;
  int _printsForCurrentRevision = 0;

  CartNotifier(
    this.db,
    this.userId,
    this.userName,
    this.printerService,
    this.ref,
  ) : super([]);

  void addToCart(Product product, {
    String? routeTo,
    List<CartModifier> modifiers = const [],
    List<CartSide> sides = const [],
  }) {
    final probe = CartItem(
      product: product,
      routeTo: routeTo,
      modifiers: modifiers,
      sides: sides,
    );
    final existingIndex = state.indexWhere((item) => _cartKey(item) == _cartKey(probe));

    if (existingIndex >= 0) {
      final existingItem = state[existingIndex];
      final updatedItem =
          existingItem.copyWith(quantity: existingItem.quantity + 1);
      state = [
        ...state.sublist(0, existingIndex),
        updatedItem,
        ...state.sublist(existingIndex + 1),
      ];
    } else {
      state = [...state, CartItem(product: product, routeTo: routeTo, modifiers: modifiers, sides: sides)];
    }
    _markOrderModified();
  }

  Future<void> removeFromCart(Product product) async {
    final userRole = await ref.read(userRoleProvider.future);
    if (_activeOrderId != null &&
        (userRole != UserRole.MANAGER && userRole != UserRole.OWNER)) {
      return;
    }
    state = state.where((item) => item.product.id != product.id).toList();
    _markOrderModified();
  }

  Future<void> decreaseQuantity(CartItem item) async {
    final userRole = await ref.read(userRoleProvider.future);
    if (_activeOrderId != null &&
        (userRole != UserRole.MANAGER && userRole != UserRole.OWNER)) {
      final key = _cartKey(item);
      final baseline = _baselineQuantities[key] ?? 0;
      if ((item.quantity - 1) < baseline) {
        return;
      }
    }

    final existingIndex = state.indexWhere(
        (i) => i.product.id == item.product.id && i.notes == item.notes);

    if (existingIndex != -1) {
      if (state[existingIndex].quantity > 1) {
        final updatedItem = state[existingIndex]
            .copyWith(quantity: state[existingIndex].quantity - 1);
        state = [
          ...state.sublist(0, existingIndex),
          updatedItem,
          ...state.sublist(existingIndex + 1),
        ];
        _markOrderModified();
      } else {
        await removeFromCart(item.product);
      }
    }
  }

  void clearCart() {
    state = [];
    _activeOrderId = null;
    _baselineQuantities.clear();
    _orderRevision = 0;
    _lastPrintedRevision = -1;
    _printsForCurrentRevision = 0;
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
            routeTo: row.item.routeTo,
            modifiers: row.modifiers
                .map((m) => CartModifier(name: m.name, priceDelta: m.priceDelta, routeTo: m.routeTo))
                .toList(),
            sides: row.sides
                .map((side) => CartSide(name: side.name, quantity: side.quantity, priceDelta: side.priceDelta, routeTo: side.routeTo))
                .toList(),
          ),
        )
        .toList();

    _activeOrderId = existingOrder.id;
    _baselineQuantities
      ..clear()
      ..addAll(_toQuantityMap(recalled));
    _orderRevision = 0;
    _lastPrintedRevision = -1;
    _printsForCurrentRevision = 0;
    state = recalled;
  }

  Future<String?> printBillCheck() async {
    if (state.isEmpty || userId == null) {
      return 'Add items before printing a bill.';
    }

    final userRole = await ref.read(userRoleProvider.future);
    final maxPrints =
        (userRole == UserRole.MANAGER || userRole == UserRole.OWNER) ? 5 : 1;

    if (_lastPrintedRevision != _orderRevision) {
      _printsForCurrentRevision = 0;
    }

    if (_printsForCurrentRevision >= maxPrints) {
      return userRole == UserRole.MANAGER || userRole == UserRole.OWNER
          ? 'Bill already printed 5 times for this version of the order.'
          : 'Bill already printed once. Modify the order first to print again.';
    }

    final now = DateTime.now();
    final orderReference = _activeOrderId ??
        _buildOrderNumber(ref.read(activeTableIdProvider), now);

    try {
      await printerService.printReceipt(
        orderId: orderReference,
        items: state,
        total: totalAmount,
        tendered: 0,
        paymentMethod: 'BILL CHECK',
        cashierName: userName,
      );
      _lastPrintedRevision = _orderRevision;
      _printsForCurrentRevision += 1;
      return null;
    } catch (e) {
      return 'Printing failed: $e';
    }
  }

  Future<void> sendToKitchen() async {
    if (state.isEmpty || userId == null) return;

    final shiftId = ref.read(activeShiftIdProvider);
    if (shiftId == null) {
      throw Exception("No active shift found. Please clock in.");
    }

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
                shiftId: Value(shiftId), 
                totalAmount: Value(totalAmount),
                status: const Value('KITCHEN'),
                isSynced: const Value(false),
                createdAt: Value(now),
                updatedAt: Value(now),
              ),
            );

        if (tableId != null) {
          await (db.update(db.seatingTables)
                ..where((t) => t.id.equals(tableId)))
              .write(const SeatingTablesCompanion(status: Value('OCCUPIED')));
        }

        for (final cartItem in state) {
          final orderItemId = const Uuid().v4();
          await db.into(db.orderItems).insert(
                OrderItemsCompanion(
                  id: Value(orderItemId),
                  orderId: Value(orderId),
                  productId: Value(cartItem.product.id),
                  quantity: Value(cartItem.quantity),
                  priceAtTimeOfOrder: Value(cartItem.product.price),
                  routeTo: Value(cartItem.routeTo),
                  notes: Value(cartItem.notes.isEmpty ? null : cartItem.notes),
                ),
              );
          await _insertOrderItemRelations(cartItem, orderItemId);
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
      final key = _cartKey(item);
      final baseline = _baselineQuantities[key] ?? 0;
      final delta = item.quantity - baseline;
      if (delta > 0) {
        newItems.add(item.copyWith(quantity: delta));
      }
    }

    if (newItems.isEmpty) return;

    await db.transaction(() async {
      for (final item in newItems) {
        final orderItemId = const Uuid().v4();
        await db.into(db.orderItems).insert(
              OrderItemsCompanion(
                id: Value(orderItemId),
                orderId: Value(_activeOrderId!),
                productId: Value(item.product.id),
                quantity: Value(item.quantity),
                priceAtTimeOfOrder: Value(item.product.price),
                routeTo: Value(item.routeTo),
                notes: Value(item.notes.isEmpty ? null : item.notes),
              ),
            );
        await _insertOrderItemRelations(item, orderItemId);
      }

      await (db.update(db.orders)..where((o) => o.id.equals(_activeOrderId!)))
          .write(
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

  Future<void> checkout(BuildContext context) async {
    if (state.isEmpty || userId == null) return;

    final shiftId = ref.read(activeShiftIdProvider);
    if (shiftId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error: No active shift found.")));
      return;
    }

    final total = totalAmount;

    showDialog(
      context: context,
      builder: (_) => PaymentModal(
        totalAmount: total,
        onConfirmed: (method, tendered, refCode) async {
          await _finalizeOrder(total, method, tendered, refCode, shiftId);
        },
      ),
    );
  }

  Future<void> _finalizeOrder(
    double total,
    String method,
    double tendered,
    String? refCode,
    String shiftId,
  ) async {
    final orderId = const Uuid().v4();
    final now = DateTime.now();
    final tableId = ref.read(activeTableIdProvider);

    await db.transaction(() async {
      await db.into(db.orders).insert(
            OrdersCompanion(
              id: Value(orderId),
              receiptNumber: Value(orderId.substring(0, 4).toUpperCase()),
              userId: Value(userId!),
              tableId: Value(tableId),
              shiftId: Value(shiftId), 
              totalAmount: Value(total),
              status: const Value('CLOSED'),
              isSynced: const Value(false),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );

      if (tableId != null) {
        await (db.update(db.seatingTables)..where((t) => t.id.equals(tableId)))
            .write(const SeatingTablesCompanion(status: Value('FREE')));
      }

      for (var cartItem in state) {
        final orderItemId = const Uuid().v4();
        await db.into(db.orderItems).insert(
              OrderItemsCompanion(
                id: Value(orderItemId),
                orderId: Value(orderId),
                productId: Value(cartItem.product.id),
                quantity: Value(cartItem.quantity),
                priceAtTimeOfOrder: Value(cartItem.product.price),
                routeTo: Value(cartItem.routeTo),
                notes: Value(cartItem.notes.isEmpty ? null : cartItem.notes),
              ),
            );
        await _insertOrderItemRelations(cartItem, orderItemId);
      }

      await db.into(db.payments).insert(
            PaymentsCompanion(
              id: Value(const Uuid().v4()),
              orderId: Value(orderId),
              shiftId: Value(shiftId),
              method: Value(method),
              amount: Value(total),
              reference: Value(refCode),
              createdAt: Value(now),
            ),
          );
    });

    try {
      await printerService.printReceipt(
        orderId: orderId,
        items: state,
        total: total,
        tendered: tendered,
        paymentMethod: method,
        cashierName: userName,
      );
    } catch (e) {
      if (kDebugMode) print("Printing failed: $e");
    }

    clearCart();
    ref.read(syncControllerProvider.notifier).performSync();
  }

  void _markOrderModified() {
    _orderRevision += 1;
  }

  Map<String, int> _toQuantityMap(List<CartItem> items) {
    final map = <String, int>{};
    for (final item in items) {
      final key = _cartKey(item);
      map[key] = (map[key] ?? 0) + item.quantity;
    }
    return map;
  }

  String _cartKey(CartItem item) {
    final mods = item.modifiers
        .map((m) => '${m.name}:${m.priceDelta}:${m.routeTo ?? ''}')
        .join('|');
    final sides = item.sides
        .map((s) => '${s.name}:${s.quantity}:${s.priceDelta}:${s.routeTo ?? ''}')
        .join('|');
    return '${item.product.id}::${item.notes.trim()}::${item.routeTo ?? ''}::${mods}::${sides}';
  }

  Future<void> _insertOrderItemRelations(CartItem cartItem, String orderItemId) async {
    for (final modifier in cartItem.modifiers) {
      await db.into(db.orderItemModifiers).insert(
            OrderItemModifiersCompanion(
              id: Value(const Uuid().v4()),
              orderItemId: Value(orderItemId),
              name: Value(modifier.name),
              priceDelta: Value(modifier.priceDelta),
              routeTo: Value(modifier.routeTo),
            ),
          );
    }

    for (final side in cartItem.sides) {
      await db.into(db.orderItemSides).insert(
            OrderItemSidesCompanion(
              id: Value(const Uuid().v4()),
              orderItemId: Value(orderItemId),
              name: Value(side.name),
              quantity: Value(side.quantity),
              priceDelta: Value(side.priceDelta),
              routeTo: Value(side.routeTo),
            ),
          );
    }
  }

  String _buildOrderNumber(String? tableId, DateTime now) {
    if (tableId != null && tableId.isNotEmpty) {
      return tableId.substring(0, 4).toUpperCase();
    }

    final suffix =
        (now.millisecondsSinceEpoch % 10000).toString().padLeft(4, '0');
    return 'TK$suffix';
  }
}


final cartProvider = StateNotifierProvider<CartNotifier, List<CartItem>>((ref) {
  final db = ref.watch(databaseProvider);
  final authState = ref.watch(authControllerProvider);
  final printerService = ref.watch(printerServiceProvider);

  final notifier = CartNotifier(
    db,
    authState.userId,
    'Cashier', 
    printerService,
    ref,
  );

  final tableId = ref.watch(activeTableIdProvider);
  if (tableId != null) {
    Future.microtask(() => notifier.loadTableCart(tableId));
  }

  return notifier;
});

final orderServiceProvider =
    Provider((ref) => OrderService(ref.watch(databaseProvider)));

final checkoutProvider =
    FutureProvider.family<void, String>((ref, userId) async {
  final cart = ref.read(cartProvider);
  if (cart.isEmpty) return;

  final orderService = ref.read(orderServiceProvider);
  final shiftId = ref.read(activeShiftIdProvider);
  if (shiftId == null) return;

  await orderService.placeOrder(
    cartItems: cart,
    userId: userId,
    shiftId: shiftId,
  );

  ref.read(cartProvider.notifier).clearCart();
});

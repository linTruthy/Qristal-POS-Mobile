import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:drift/drift.dart' as drift;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/constants/api_constants.dart';
import '../../../database/database.dart';

class SyncService {
  final AppDatabase db;
  final _storage = const FlutterSecureStorage();

  SyncService(this.db);

  Future<void> syncData() async {
    final token = await _storage.read(key: 'jwt_token');
    if (token == null) throw Exception("Not Authenticated");

    // 1. PUSH local changes first (so server has latest sales)
    await _pushToWeb(token);

    // 2. PULL remote changes (menu updates)
    await pullFromWeb(token);
  }

  Future<void> pullFromWeb(String token) async {
    final prefs = await SharedPreferences.getInstance();
    final String? lastSync = prefs.getString('last_sync_timestamp');

    // 1. Prepare Query Params
    String url = '${ApiConstants.baseUrl}/sync/pull';
    if (lastSync != null) {
      url += '?lastSyncTimestamp=$lastSync';
    }

    try {
      // 2. Fetch Data
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Sync failed: ${response.body}');
      }

      final data = jsonDecode(response.body);
      final changes = data['changes'];
      final newTimestamp = data['timestamp'];

      // 3. Insert into SQLite (Batch Transaction for Performance)
      await db.batch((batch) {
        // --- Categories ---
        if (changes['categories'] != null) {
          for (var item in changes['categories']) {
            batch.insert(
              db.categories,
              CategoriesCompanion(
                id: drift.Value(item['id']),
                name: drift.Value(item['name']),
                colorHex: drift.Value(item['colorHex']),
                sortOrder: drift.Value(item['sortOrder']),
                updatedAt: drift.Value(DateTime.parse(item['updatedAt'])),
              ),
              mode: drift.InsertMode.insertOrReplace,
            );
          }
        }

        // --- Products ---
        if (changes['products'] != null) {
          for (var item in changes['products']) {
            // Ensure price is treated as double
            double price = double.tryParse(item['price'].toString()) ?? 0.0;

            batch.insert(
              db.products,
              ProductsCompanion(
                id: drift.Value(item['id']),
                categoryId: drift.Value(item['categoryId']),
                name: drift.Value(item['name']),
                price: drift.Value(price),
                isAvailable: drift.Value(item['isAvailable']),
                updatedAt: drift.Value(DateTime.parse(item['updatedAt'])),
              ),
              mode: drift.InsertMode.insertOrReplace,
            );
          }
        }

        // --- Users (Optional, for offline login check later) ---
        // You would handle users similarly here

        // --- Orders ---
        if (changes['orders'] != null) {
          for (var item in changes['orders']) {
            batch.insert(
              db.orders,
              OrdersCompanion(
                id: drift.Value(item['id']),
                receiptNumber: drift.Value(item['receiptNumber']),
                userId: drift.Value(item['userId']),
                tableId: drift.Value(item['tableId']),
                totalAmount: drift.Value(
                  double.tryParse(item['totalAmount'].toString()) ?? 0.0,
                ),
                status: drift.Value(item['status']),
                createdAt: drift.Value(DateTime.parse(item['createdAt'])),
                updatedAt: drift.Value(
                  DateTime.parse(item['updatedAt'] ?? item['createdAt']),
                ),
                isSynced: const drift.Value(true),
              ),
              mode: drift.InsertMode.insertOrReplace,
            );
          }
        }

        // --- Order Items ---
        if (changes['orderItems'] != null) {
          for (var item in changes['orderItems']) {
            batch.insert(
              db.orderItems,
              OrderItemsCompanion(
                id: drift.Value(item['id']),
                orderId: drift.Value(item['orderId']),
                productId: drift.Value(item['productId']),
                quantity: drift.Value(item['quantity']),
                priceAtTimeOfOrder: drift.Value(
                  double.tryParse(item['priceAtTimeOfOrder'].toString()) ?? 0.0,
                ),
                notes: drift.Value(item['notes']),
              ),
              mode: drift.InsertMode.insertOrReplace,
            );
          }
        }

        // --- Payments ---
        if (changes['payments'] != null) {
          for (var item in changes['payments']) {
            batch.insert(
              db.payments,
              PaymentsCompanion(
                id: drift.Value(item['id']),
                orderId: drift.Value(item['orderId']),
                method: drift.Value(item['method']),
                amount: drift.Value(
                  double.tryParse(item['amount'].toString()) ?? 0.0,
                ),
                reference: drift.Value(item['reference']),
                createdAt: drift.Value(DateTime.parse(item['createdAt'])),
              ),
              mode: drift.InsertMode.insertOrReplace,
            );
          }
        }

        // --- Tables ---
        if (changes['seatingTables'] != null) {
          // Ensure your backend API returns this key
          for (var item in changes['seatingTables']) {
            batch.insert(
              db.seatingTables,
              SeatingTablesCompanion(
                id: drift.Value(item['id']),
                name: drift.Value(item['name']),
                status: drift.Value(item['status']),
                floor: drift.Value(item['floor']),
                updatedAt: drift.Value(DateTime.parse(item['updatedAt'])),
              ),
              mode: drift.InsertMode.insertOrReplace,
            );
          }
        }
      });

      // 4. Save new timestamp
      await prefs.setString('last_sync_timestamp', newTimestamp);
      if (kDebugMode) {
        print("Sync Completed Successfully. Timestamp: $newTimestamp");
      }
    } catch (e) {
      if (kDebugMode) {
        print("Sync Error: $e");
      }
      rethrow;
    }
  }

  Future<void> _pushToWeb(String token) async {
    // 1. Find unsynced orders
    final unsyncedOrders = await (db.select(
      db.orders,
    )..where((t) => t.isSynced.equals(false)))
        .get();

    if (unsyncedOrders.isEmpty) return;

    if (kDebugMode) {
      print("Found ${unsyncedOrders.length} orders to push.");
    }

    List<Map<String, dynamic>> ordersPayload = [];
    List<Map<String, dynamic>> itemsPayload = [];
    List<Map<String, dynamic>> paymentsPayload = []; // -> ADDED FOR PAYMENTS

    final orderIds = unsyncedOrders.map((order) => order.id).toList();
    final relatedItems = await (db.select(
      db.orderItems,
    )..where((t) => t.orderId.isIn(orderIds)))
        .get();

    for (final item in relatedItems) {
      itemsPayload.add({
        'id': item.id,
        'orderId': item.orderId,
        'productId': item.productId,
        'quantity': item.quantity,
        'priceAtTimeOfOrder': item.priceAtTimeOfOrder,
        'notes': item.notes,
      });
    }

    for (final order in unsyncedOrders) {
      ordersPayload.add({
        'id': order.id,
        'receiptNumber': order.receiptNumber,
        'userId': order.userId,
        'tableId': order.tableId,
        'totalAmount': order.totalAmount,
        'status': order.status,
        'createdAt': order.createdAt.toIso8601String(),
      });

      // Fetch related payments -> ADDED FOR PAYMENTS
      final payments = await (db.select(
        db.payments,
      )..where((t) => t.orderId.equals(order.id)))
          .get();
      for (final pay in payments) {
        paymentsPayload.add({
          'id': pay.id,
          'orderId': pay.orderId,
          'method': pay.method,
          'amount': pay.amount,
          'reference': pay.reference,
          'createdAt': pay.createdAt.toIso8601String(),
        });
      }
    }
    final unsyncedShifts = await (db.select(db.shifts)
          ..where((t) => t.isSynced.equals(false)))
        .get();
    List<Map<String, dynamic>> shiftsPayload = [];

    for (final shift in unsyncedShifts) {
      shiftsPayload.add({
        'id': shift.id,
        'userId': shift.userId,
        'openingTime': shift.openingTime.toIso8601String(),
        'closingTime': shift.closingTime?.toIso8601String(),
        'startingCash': shift.startingCash,
        'expectedCash': shift.expectedCash,
        'actualCash': shift.actualCash,
        'notes': shift.notes,
      });
    }

    if (kDebugMode) {
      print(
        'Prepared sync payload: '
        '${ordersPayload.length} orders, '
        '${itemsPayload.length} orderItems, '
        '${paymentsPayload.length} payments.',
      );
    }

    try {
      final response = await http
          .post(
            Uri.parse(
                '${ApiConstants.baseUrl}${ApiConstants.syncPushEndpoint}'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            // Include payments in the payload!
            body: jsonEncode({
              'orders': ordersPayload,
              'orderItems': itemsPayload,
              'payments': paymentsPayload,
              'shifts': shiftsPayload
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 201 || response.statusCode == 200) {
        await db.transaction(() async {
          for (final order in unsyncedOrders) {
            await (db.update(db.orders)..where((t) => t.id.equals(order.id)))
                .write(const OrdersCompanion(isSynced: Value(true)));
          }
        });
        if (kDebugMode) print("✅ Sync Push Successful!");
      } else {
        if (kDebugMode) {
          print("❌ Push failed: ${response.statusCode} - ${response.body}");
        }
        throw Exception(
            'Push failed: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      if (kDebugMode) print("❌ Connection error during push: $e");
      rethrow;
    }
  }
}

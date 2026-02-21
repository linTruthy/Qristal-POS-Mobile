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
    await pullFromWeb(token); // (Your existing pull logic moves here)
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
    )..where((t) => t.isSynced.equals(false))).get();

    if (unsyncedOrders.isEmpty) return;

    if (kDebugMode) {
      print("Found ${unsyncedOrders.length} orders to push.");
    }

    // 2. Prepare Payload
    List<Map<String, dynamic>> ordersPayload = [];
    List<Map<String, dynamic>> itemsPayload = [];

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

      // Fetch related items (NOW WORKING because OrderItems table exists)
      final items = await (db.select(
        db.orderItems,
      )..where((t) => t.orderId.equals(order.id))).get();

      for (final item in items) {
        itemsPayload.add({
          'id': item.id,
          'orderId': item.orderId,
          'productId': item.productId,
          'quantity': item.quantity,
          'priceAtTimeOfOrder': item.priceAtTimeOfOrder,
          'notes': item.notes,
        });
      }
    }

    // 3. Send to API
    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.syncPushEndpoint}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'orders': ordersPayload, 'orderItems': itemsPayload}),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        // 4. Mark local orders as synced
        await db.transaction(() async {
          for (final order in unsyncedOrders) {
            await (db.update(db.orders)..where((t) => t.id.equals(order.id)))
                .write(const OrdersCompanion(isSynced: Value(true)));
          }
        });
        if (kDebugMode) {
          print("✅ Sync Push Successful!");
        }
      } else {
        if (kDebugMode) {
          print("❌ Push failed: ${response.statusCode} - ${response.body}");
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print("❌ Connection error during push: $e");
      }
    }
  }
}

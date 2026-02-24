import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:drift/drift.dart' as drift;
import 'package:sentry_flutter/sentry_flutter.dart';
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

      List<dynamic> _readChangeList(List<String> keys) {
        for (final key in keys) {
          final value = changes[key];
          if (value is List) return value;
        }
        return const [];
      }

      String? _readString(Map<String, dynamic> item, List<String> keys) {
        for (final key in keys) {
          final value = item[key];
          if (value != null) return value.toString();
        }
        return null;
      }

      double _readDouble(
        Map<String, dynamic> item,
        List<String> keys, {
        double fallback = 0.0,
      }) {
        final raw = _readString(item, keys);
        return double.tryParse(raw ?? '') ?? fallback;
      }

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
        final orders = _readChangeList(['orders']);
        for (final raw in orders) {
          final item = Map<String, dynamic>.from(raw as Map);
          final orderId = _readString(item, ['id']);
          final receiptNumber = _readString(item, [
            'receiptNumber',
            'receipt_number',
          ]);
          final userId = _readString(item, ['userId', 'user_id']);
          final createdAt = _readString(item, ['createdAt', 'created_at']);
          final shiftId = _readString(item, ['shiftId', 'shift_id']);
          if (orderId == null ||
              receiptNumber == null ||
              userId == null ||
              createdAt == null ||
              shiftId == null ||
              shiftId.isEmpty) {
            continue;
          }

          batch.insert(
            db.orders,
            OrdersCompanion(
              id: drift.Value(orderId),
              receiptNumber: drift.Value(receiptNumber),
              userId: drift.Value(userId),
              tableId: drift.Value(_readString(item, ['tableId', 'table_id'])),
              totalAmount: drift.Value(
                _readDouble(item, ['totalAmount', 'total_amount']),
              ),
              status: drift.Value(_readString(item, ['status']) ?? 'KITCHEN'),
              shiftId: drift.Value(shiftId),
              createdAt: drift.Value(DateTime.parse(createdAt)),
              updatedAt: drift.Value(
                DateTime.parse(
                  _readString(item, ['updatedAt', 'updated_at']) ?? createdAt,
                ),
              ),
              isSynced: const drift.Value(true),
            ),
            mode: drift.InsertMode.insertOrReplace,
          );
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
        final seatingTables = _readChangeList([
          'seatingTables',
          'seating_tables',
          'tables',
        ]);
        for (final raw in seatingTables) {
          final item = Map<String, dynamic>.from(raw as Map);
          final tableId = _readString(item, ['id']);
          final tableName = _readString(item, ['name']);
          final updatedAt = _readString(item, ['updatedAt', 'updated_at']);

          if (tableId == null || tableName == null || updatedAt == null) {
            continue;
          }

          batch.insert(
            db.seatingTables,
            SeatingTablesCompanion(
              id: drift.Value(tableId),
              name: drift.Value(tableName),
              status: drift.Value(_readString(item, ['status']) ?? 'FREE'),
              floor: drift.Value(_readString(item, ['floor']) ?? 'Main'),
              updatedAt: drift.Value(DateTime.parse(updatedAt)),
            ),
            mode: drift.InsertMode.insertOrReplace,
          );
        }
        
        // --- Shifts ---
        if (changes['shifts'] != null) {
          for (var item in changes['shifts']) {
            batch.insert(
              db.shifts,
              ShiftsCompanion(
                id: drift.Value(item['id']),
                userId: drift.Value(item['userId']),
                openingTime: drift.Value(DateTime.parse(item['openingTime'])),
                closingTime: drift.Value(item['closingTime'] != null ? DateTime.parse(item['closingTime']) : null),
                startingCash: drift.Value(double.tryParse(item['startingCash'].toString()) ?? 0.0),
                expectedCash: drift.Value(double.tryParse(item['expectedCash'].toString()) ?? 0.0),
                actualCash: drift.Value(double.tryParse(item['actualCash'].toString()) ?? 0.0),
                notes: drift.Value(item['notes']),
                isSynced: const drift.Value(true),
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
    } catch (exception, stackTrace) {
      await Sentry.captureException(exception, stackTrace: stackTrace);
      if (kDebugMode) {
        print("Sync Error: $exception");
      }
      rethrow;
    }
  }

  Future<void> _pushToWeb(String token) async {
    // 1. Find unsynced data
    final unsyncedOrders = await (db.select(db.orders)..where((t) => t.isSynced.equals(false))).get();
    final unsyncedShifts = await (db.select(db.shifts)..where((t) => t.isSynced.equals(false))).get();
    final unsyncedTables = await (db.select(db.seatingTables)..where((t) => t.isSynced.equals(false))).get();

    if (unsyncedOrders.isEmpty && unsyncedShifts.isEmpty && unsyncedTables.isEmpty) return;

    if (kDebugMode) {
      print("Found ${unsyncedOrders.length} orders, ${unsyncedShifts.length} shifts, and ${unsyncedTables.length} tables to push.");
    }

    List<Map<String, dynamic>> ordersPayload = [];
    List<Map<String, dynamic>> itemsPayload = [];
    List<Map<String, dynamic>> paymentsPayload = [];
    List<Map<String, dynamic>> shiftsPayload = [];
    List<Map<String, dynamic>> tablesPayload = [];

    if (unsyncedOrders.isNotEmpty) {
      final orderIds = unsyncedOrders.map((order) => order.id).toList();
      final relatedItems = await (db.select(db.orderItems)..where((t) => t.orderId.isIn(orderIds))).get();

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
          'updatedAt': order.updatedAt.toIso8601String(),
        });

        final payments = await (db.select(db.payments)..where((t) => t.orderId.equals(order.id))).get();
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
    }

    if (unsyncedShifts.isNotEmpty) {
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
    }

    if (unsyncedTables.isNotEmpty) {
      for (final table in unsyncedTables) {
        tablesPayload.add({
          'id': table.id,
          'name': table.name,
          'status': table.status,
          'floor': table.floor,
          'updatedAt': table.updatedAt?.toIso8601String(),
        });
      }
    }

    if (kDebugMode) {
      print(
        'Prepared sync payload: '
        '${ordersPayload.length} orders, '
        '${itemsPayload.length} orderItems, '
        '${paymentsPayload.length} payments, '
        '${shiftsPayload.length} shifts, '
        '${tablesPayload.length} tables.'
      );
    }

    try {
      final response = await http
          .post(
            Uri.parse('${ApiConstants.baseUrl}${ApiConstants.syncPushEndpoint}'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'orders': ordersPayload,
              'orderItems': itemsPayload,
              'payments': paymentsPayload,
              'shifts': shiftsPayload,
              'seatingTables': tablesPayload,
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 201 || response.statusCode == 200) {
        await db.transaction(() async {
          for (final order in unsyncedOrders) {
            await (db.update(db.orders)..where((t) => t.id.equals(order.id)))
                .write(const OrdersCompanion(isSynced: Value(true)));
          }
          for (final shift in unsyncedShifts) {
            await (db.update(db.shifts)..where((t) => t.id.equals(shift.id)))
                .write(const ShiftsCompanion(isSynced: Value(true)));
          }
           for (final table in unsyncedTables) {
            await (db.update(db.seatingTables)..where((t) => t.id.equals(table.id)))
                .write(const SeatingTablesCompanion(isSynced: Value(true)));
          }
        });
        if (kDebugMode) print("✅ Sync Push Successful!");
      } else {
        if (kDebugMode) {
          print("❌ Push failed: ${response.statusCode} - ${response.body}");
        }
        throw Exception(
          'Push failed: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e, stackTrace) {
      await Sentry.captureException(e, stackTrace: stackTrace);
      if (kDebugMode) print("❌ Connection error during push: $e");
      rethrow;
    }
  }
}

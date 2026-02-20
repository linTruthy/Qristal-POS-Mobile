import 'dart:convert';
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
    final prefs = await SharedPreferences.getInstance();
    final String? lastSync = prefs.getString('last_sync_timestamp');
    final String? token = await _storage.read(key: 'jwt_token');

    if (token == null) throw Exception("Not Authenticated");

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
      });

      // 4. Save new timestamp
      await prefs.setString('last_sync_timestamp', newTimestamp);
      print("Sync Completed Successfully. Timestamp: $newTimestamp");

    } catch (e) {
      print("Sync Error: $e");
      rethrow;
    }
  }
}
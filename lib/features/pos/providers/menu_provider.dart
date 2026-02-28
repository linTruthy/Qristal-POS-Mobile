import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/constants/api_constants.dart';
import '../../../core/providers/database_provider.dart';
import '../../../database/database.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/product_customization.dart';

final selectedCategoryProvider = StateProvider<String?>((ref) => null);

final categoriesStreamProvider = StreamProvider<List<Category>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.categories).watch();
});

final productsStreamProvider = StreamProvider<List<Product>>((ref) {
  final db = ref.watch(databaseProvider);
  final selectedCatId = ref.watch(selectedCategoryProvider);

  if (selectedCatId == null) {
    return db.select(db.products).watch();
  }

  return (db.select(db.products)..where((tbl) => tbl.categoryId.equals(selectedCatId)))
      .watch();
});

final productCustomizationProvider =
    FutureProvider<Map<String, ProductCustomization>>((ref) async {
  final token = await ref.read(authServiceProvider).getToken();
  if (token == null) return const {};

  final headers = {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  };

  final responses = await Future.wait([
    http.get(Uri.parse('${ApiConstants.baseUrl}/products'), headers: headers),
    http.get(Uri.parse('${ApiConstants.baseUrl}/modifier-groups'), headers: headers),
    http.get(Uri.parse('${ApiConstants.baseUrl}/sides'), headers: headers),
  ]);

  final productsRaw = _toList(responses[0]);
  final groupsRaw = _toList(responses[1]);
  final sidesRaw = _toList(responses[2]);

  final modifierGroupById = <String, ModifierGroupOption>{};
  for (final raw in groupsRaw) {
    final group = Map<String, dynamic>.from(raw as Map);
    final groupId = group['id']?.toString();
    if (groupId == null || groupId.isEmpty) continue;

    final modifiersRaw = group['modifiers'];
    final modifiers = (modifiersRaw is List ? modifiersRaw : const <dynamic>[])
        .map((entry) => Map<String, dynamic>.from(entry as Map))
        .map(
          (item) => ModifierOption(
            id: item['id']?.toString() ?? '',
            name: item['name']?.toString() ?? 'Modifier',
            priceDelta: _toDouble(item['priceDelta']),
            routeTo: item['productionArea']?.toString(),
          ),
        )
        .where((item) => item.id.isNotEmpty)
        .toList();

    modifierGroupById[groupId] = ModifierGroupOption(
      id: groupId,
      name: group['name']?.toString() ?? 'Options',
      minSelect: _toInt(group['minSelect']),
      maxSelect: group['maxSelect'] == null ? null : _toInt(group['maxSelect']),
      isRequired: group['isRequired'] == true,
      modifiers: modifiers,
    );
  }

  final sidesById = <String, SideOption>{};
  for (final raw in sidesRaw) {
    final side = Map<String, dynamic>.from(raw as Map);
    final sideId = side['id']?.toString();
    if (sideId == null || sideId.isEmpty) continue;

    sidesById[sideId] = SideOption(
      id: sideId,
      name: side['name']?.toString() ?? 'Side',
      priceDelta: _toDouble(side['priceDelta']),
      routeTo: side['productionArea']?.toString(),
    );
  }

  final mapping = <String, ProductCustomization>{};

  for (final raw in productsRaw) {
    final product = Map<String, dynamic>.from(raw as Map);
    final productId = product['id']?.toString();
    if (productId == null || productId.isEmpty) continue;

    final productGroupsRaw = product['productModifierGroups'];
    final productSidesRaw = product['productSides'];

    final selectedGroups = <ModifierGroupOption>[];
    if (productGroupsRaw is List) {
      for (final entry in productGroupsRaw) {
        final relation = Map<String, dynamic>.from(entry as Map);
        final groupId = relation['modifierGroupId']?.toString();

        if (groupId != null && modifierGroupById.containsKey(groupId)) {
          selectedGroups.add(modifierGroupById[groupId]!);
          continue;
        }

        final embeddedGroup = relation['modifierGroup'];
        if (embeddedGroup is Map) {
          final normalized = Map<String, dynamic>.from(embeddedGroup);
          final id = normalized['id']?.toString();
          if (id != null && id.isNotEmpty && modifierGroupById.containsKey(id)) {
            selectedGroups.add(modifierGroupById[id]!);
          }
        }
      }
    }

    final selectedSides = <SideOption>[];
    if (productSidesRaw is List) {
      for (final entry in productSidesRaw) {
        final relation = Map<String, dynamic>.from(entry as Map);
        final sideId = relation['sideId']?.toString();

        if (sideId != null && sidesById.containsKey(sideId)) {
          selectedSides.add(sidesById[sideId]!);
          continue;
        }

        final embeddedSide = relation['side'];
        if (embeddedSide is Map) {
          final normalized = Map<String, dynamic>.from(embeddedSide);
          final id = normalized['id']?.toString();
          if (id != null && id.isNotEmpty && sidesById.containsKey(id)) {
            selectedSides.add(sidesById[id]!);
          }
        }
      }
    }

    mapping[productId] = ProductCustomization(
      productId: productId,
      productRouteTo: product['productionArea']?.toString(),
      modifierGroups: selectedGroups,
      sides: selectedSides,
    );
  }

  return mapping;
});

List<dynamic> _toList(http.Response response) {
  if (response.statusCode < 200 || response.statusCode >= 300) return const [];
  try {
    final decoded = jsonDecode(response.body);
    if (decoded is List) return decoded;
  } catch (_) {
    return const [];
  }
  return const [];
}

double _toDouble(dynamic raw) {
  if (raw is num) return raw.toDouble();
  return double.tryParse(raw?.toString() ?? '') ?? 0;
}

int _toInt(dynamic raw) {
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  return int.tryParse(raw?.toString() ?? '') ?? 0;
}

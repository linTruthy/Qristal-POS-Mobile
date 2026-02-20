import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/database_provider.dart';
import '../../../database/database.dart';


// Tracks which category is currently selected in the UI
final selectedCategoryProvider = StateProvider<String?>((ref) => null);

// Watches all categories from DB
final categoriesStreamProvider = StreamProvider<List<Category>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.categories).watch();
});

// Watches products, filtered by the selected category
final productsStreamProvider = StreamProvider<List<Product>>((ref) {
  final db = ref.watch(databaseProvider);
  final selectedCatId = ref.watch(selectedCategoryProvider);

  if (selectedCatId == null) {
    // If no category selected, return all (or none, depending on preference)
    return db.select(db.products).watch();
  }
  
  return (db.select(db.products)
    ..where((tbl) => tbl.categoryId.equals(selectedCatId)))
    .watch();
});
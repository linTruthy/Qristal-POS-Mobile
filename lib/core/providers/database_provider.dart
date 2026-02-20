import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../database/database.dart';

// The single instance of our local SQLite database
final databaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase();
});
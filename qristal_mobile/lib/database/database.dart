import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

part 'database.g.dart';

// 1. Categories Table
class Categories extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get colorHex => text().nullable()();
  // Fixed: .defaultValue -> .withDefault
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// 2. Products Table
class Products extends Table {
  TextColumn get id => text()();
  TextColumn get categoryId => text().references(Categories, #id)();
  TextColumn get name => text()();
  RealColumn get price => real()();
  BoolColumn get isAvailable => boolean().withDefault(const Constant(true))();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// 3. Orders Table
class Orders extends Table {
  TextColumn get id => text()();
  TextColumn get receiptNumber => text()();
  TextColumn get userId => text()();
  TextColumn get tableId => text().nullable()();
  RealColumn get totalAmount => real()();
  TextColumn get status => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  // Local-only flag to track what needs to be uploaded
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

// 4. OrderItems Table (This was missing!)
class OrderItems extends Table {
  TextColumn get id => text()();
  TextColumn get orderId => text().references(Orders, #id)();
  TextColumn get productId => text().references(Products, #id)();
  IntColumn get quantity => integer()();
  RealColumn get priceAtTimeOfOrder => real()();
  TextColumn get notes => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Payments extends Table {
  TextColumn get id => text()();
  TextColumn get orderId => text().references(Orders, #id)();
  TextColumn get method => text()(); // 'CASH', 'MOBILE_MONEY', etc.
  RealColumn get amount => real()();
  TextColumn get reference => text().nullable()(); // Trans ID
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class SeatingTables extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get status => text().withDefault(const Constant('FREE'))();
  TextColumn get floor => text().withDefault(const Constant('Main'))();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// Database Registry
@DriftDatabase(tables: [Categories, Products, Orders, OrderItems, Payments, SeatingTables])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 3; // Bump version

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 3) {
          await m.createTable(seatingTables);
        }
      },
    );
  }


  Stream<List<Order>> watchKitchenOrders() {
    return (select(orders)
          ..where((t) => t.status.isIn(['KITCHEN', 'PREPARING']))
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]))
        .watch();
  }

  // 2. Get Items for a specific Order (Joined with Product info)
  Future<List<TypedOrderItem>> getOrderItems(String orderId) async {
    final query = select(orderItems).join([
      innerJoin(products, products.id.equalsExp(orderItems.productId)),
    ])..where(orderItems.orderId.equals(orderId));

    final rows = await query.get();

    return rows.map((row) {
      return TypedOrderItem(
        item: row.readTable(orderItems),
        product: row.readTable(products),
      );
    }).toList();
  }

  // 3. Update Order Status
  Future<void> updateOrderStatus(String id, String newStatus) async {
    await (update(orders)..where((t) => t.id.equals(id))).write(
      OrdersCompanion(
        status: Value(newStatus),
        updatedAt: Value(DateTime.now()), // Important for Sync!
        isSynced: const Value(false), // Mark as dirty so it syncs up
      ),
    );
  }
}

// Helper class to hold joined data
class TypedOrderItem {
  final OrderItem item;
  final Product product;
  TypedOrderItem({required this.item, required this.product});
}



LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    // 1. Get the folder
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'db.sqlite'));

    // 2. FOR ANDROID: Load the native library specifically
    if (Platform.isAndroid) {
      await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();

      // Optional: Explicitly tell sqlite3 where to look if the workaround fails,
      // though the line above usually fixes it.
      final cachebase = (await getTemporaryDirectory()).path;
      sqlite3.tempDirectory = cachebase;
    }

    // 3. Create the database
    return NativeDatabase.createInBackground(file);
  });
}

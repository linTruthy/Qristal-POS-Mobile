import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

part 'database.g.dart';

class Categories extends Table {
  TextColumn get id => text()();
  TextColumn get branchId => text().withDefault(const Constant('BRANCH-01'))();
  TextColumn get name => text()();
  TextColumn get colorHex => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Products extends Table {
  TextColumn get id => text()();
  TextColumn get branchId => text().withDefault(const Constant('BRANCH-01'))();
  TextColumn get categoryId => text().references(Categories, #id)();
  TextColumn get name => text()();
  RealColumn get price => real()();
  BoolColumn get isAvailable => boolean().withDefault(const Constant(true))();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Orders extends Table {
  TextColumn get id => text()();
  TextColumn get branchId => text().withDefault(const Constant('BRANCH-01'))();
  TextColumn get receiptNumber => text()();
  TextColumn get userId => text()();
  TextColumn get tableId => text().nullable()();
  RealColumn get totalAmount => real()();
  TextColumn get status => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  TextColumn get shiftId => text().references(Shifts, #id)();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class OrderItems extends Table {
  TextColumn get id => text()();
  TextColumn get orderId => text().references(Orders, #id)();
  TextColumn get productId => text().references(Products, #id)();
  IntColumn get quantity => integer()();
  RealColumn get priceAtTimeOfOrder => real()();
  TextColumn get routeTo => text().nullable()();
  TextColumn get notes => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class OrderItemModifiers extends Table {
  TextColumn get id => text()();
  TextColumn get orderItemId => text().references(OrderItems, #id)();
  TextColumn get name => text()();
  RealColumn get priceDelta => real().withDefault(const Constant(0))();
  TextColumn get routeTo => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class OrderItemSides extends Table {
  TextColumn get id => text()();
  TextColumn get orderItemId => text().references(OrderItems, #id)();
  TextColumn get name => text()();
  IntColumn get quantity => integer().withDefault(const Constant(1))();
  RealColumn get priceDelta => real().withDefault(const Constant(0))();
  TextColumn get routeTo => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Payments extends Table {
  TextColumn get id => text()();
  TextColumn get branchId => text().withDefault(const Constant('BRANCH-01'))();
  TextColumn get orderId => text().references(Orders, #id)();
  TextColumn get shiftId => text().references(Shifts, #id)();
  TextColumn get method => text()();
  RealColumn get amount => real()();
  TextColumn get reference => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class SeatingTables extends Table {
  TextColumn get id => text()();
  TextColumn get branchId => text().withDefault(const Constant('BRANCH-01'))();
  TextColumn get name => text()();
  TextColumn get status => text().withDefault(const Constant('FREE'))();
  TextColumn get floor => text().withDefault(const Constant('Main'))();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class Shifts extends Table {
  TextColumn get id => text()();
  TextColumn get branchId => text().withDefault(const Constant('BRANCH-01'))();
  TextColumn get userId => text()();
  DateTimeColumn get openingTime => dateTime()();
  DateTimeColumn get closingTime => dateTime().nullable()();
  RealColumn get startingCash => real().withDefault(const Constant(0.0))();
  RealColumn get expectedCash => real().nullable()();
  RealColumn get actualCash => real().nullable()();
  TextColumn get notes => text().nullable()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(
  tables: [
    Categories,
    Products,
    Orders,
    OrderItems,
    OrderItemModifiers,
    OrderItemSides,
    Payments,
    SeatingTables,
    Shifts,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 3) {
          await m.createTable(seatingTables);
        }
        if (from < 5) {
          await m.addColumn(orderItems, orderItems.routeTo);
          await m.createTable(orderItemModifiers);
          await m.createTable(orderItemSides);
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

  Future<List<TypedOrderItem>> getOrderItems(String orderId) async {
    final query = select(orderItems).join([
      innerJoin(products, products.id.equalsExp(orderItems.productId)),
    ])..where(orderItems.orderId.equals(orderId));

    final rows = await query.get();
    final typedRows = <TypedOrderItem>[];

    for (final row in rows) {
      final item = row.readTable(orderItems);
      final modifierRows = await (select(orderItemModifiers)
            ..where((m) => m.orderItemId.equals(item.id)))
          .get();
      final sideRows =
          await (select(orderItemSides)..where((s) => s.orderItemId.equals(item.id)))
              .get();

      typedRows.add(
        TypedOrderItem(
          item: item,
          product: row.readTable(products),
          modifiers: modifierRows,
          sides: sideRows,
        ),
      );
    }

    return typedRows;
  }

  Future<void> updateOrderStatus(String id, String newStatus) async {
    await (update(orders)..where((t) => t.id.equals(id))).write(
      OrdersCompanion(
        status: Value(newStatus),
        updatedAt: Value(DateTime.now()),
        isSynced: const Value(false),
      ),
    );
  }
}

class TypedOrderItem {
  final OrderItem item;
  final Product product;
  final List<OrderItemModifier> modifiers;
  final List<OrderItemSide> sides;

  TypedOrderItem({
    required this.item,
    required this.product,
    this.modifiers = const [],
    this.sides = const [],
  });
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'db.sqlite'));

    if (Platform.isAndroid) {
      await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
      final cachebase = (await getTemporaryDirectory()).path;
      sqlite3.tempDirectory = cachebase;
    }

    return NativeDatabase.createInBackground(file);
  });
}

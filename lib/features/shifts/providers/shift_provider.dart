import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart';
import '../../../core/providers/database_provider.dart';
import '../../../database/database.dart';
import '../../auth/providers/auth_provider.dart';

// Holds the currently active Shift ID
final activeShiftIdProvider = StateProvider<String?>((ref) => null);

class ShiftService {
  final AppDatabase db;
  
  ShiftService(this.db);

  // Check if user has an open shift
  Future<String?> getActiveShift(String userId) async {
    final shift = await (db.select(db.shifts)
      ..where((t) => t.userId.equals(userId) & t.closingTime.isNull()))
      .getSingleOrNull();
      
    return shift?.id;
  }

  // Open a new shift
  Future<String> openShift(String userId, double startingCash) async {
    final shiftId = const Uuid().v4();
    await db.into(db.shifts).insert(ShiftsCompanion(
      id: Value(shiftId),
      userId: Value(userId),
      openingTime: Value(DateTime.now()),
      startingCash: Value(startingCash),
      isSynced: const Value(false),
    ));
    return shiftId;
  }

  // Close shift (calculate totals)
  Future<void> closeShift(String shiftId, double actualCash) async {
    // 1. Calculate expected cash (Starting Cash + Cash Payments)
    final shift = await (db.select(db.shifts)..where((t) => t.id.equals(shiftId))).getSingle();
    
    final payments = await (db.select(db.payments)
      ..join([innerJoin(db.orders, db.orders.id.equalsExp(db.payments.orderId))])
      ..where((t) => db.orders.shiftId.equals(shiftId) & db.payments.method.equals('CASH'))
    ).get();

    double cashSales = payments.fold(0, (sum, p) => sum + p.amount);
    double expected = shift.startingCash + cashSales;

    // 2. Update the shift
    await (db.update(db.shifts)..where((t) => t.id.equals(shiftId))).write(
      ShiftsCompanion(
        closingTime: Value(DateTime.now()),
        expectedCash: Value(expected),
        actualCash: Value(actualCash),
        isSynced: const Value(false),
      )
    );
  }
}

final shiftServiceProvider = Provider((ref) => ShiftService(ref.watch(databaseProvider)));
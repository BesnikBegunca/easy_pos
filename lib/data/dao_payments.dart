import 'db.dart';

import 'package:sqflite_common/sqlite_api.dart';

class PaymentRow {
  final int id;
  final int tableId;
  final int totalCents;
  final String method; // cash/card/mixed
  final int paidAt;
  final int paidBy;

  PaymentRow({
    required this.id,
    required this.tableId,
    required this.totalCents,
    required this.method,
    required this.paidAt,
    required this.paidBy,
  });
}

class PaymentsDao {
  PaymentsDao._();
  static final PaymentsDao I = PaymentsDao._();

  /// ✅ Create payment using existing DB executor (txn or db)
  Future<int> createPayment({
    required DatabaseExecutor ex,
    required int tableId,
    required int totalCents,
    required String method, // cash/card/mixed
    required int paidBy,
  }) async {
    return ex.insert('payments', {
      'table_id': tableId,
      'total_cents': totalCents,
      'method': method,
      'paid_at': DateTime.now().millisecondsSinceEpoch,
      'paid_by': paidBy,
    });
  }

  Future<int> sumCashPayments(DateTime date) async {
    final db = await AppDb.I.db;
    final startOfDay = DateTime(
      date.year,
      date.month,
      date.day,
    ).millisecondsSinceEpoch;
    final endOfDay = DateTime(
      date.year,
      date.month,
      date.day,
      23,
      59,
      59,
      999,
    ).millisecondsSinceEpoch;

    final result = await db.rawQuery(
      '''
      SELECT SUM(total_cents) as total
      FROM payments
      WHERE method = 'cash' AND paid_at >= ? AND paid_at <= ?
    ''',
      [startOfDay, endOfDay],
    );

    return (result.first['total'] as int?) ?? 0;
  }

  Future<int> sumCardPayments(DateTime date) async {
    final db = await AppDb.I.db;
    final startOfDay = DateTime(
      date.year,
      date.month,
      date.day,
    ).millisecondsSinceEpoch;
    final endOfDay = DateTime(
      date.year,
      date.month,
      date.day,
      23,
      59,
      59,
      999,
    ).millisecondsSinceEpoch;

    final result = await db.rawQuery(
      '''
      SELECT SUM(total_cents) as total
      FROM payments
      WHERE method = 'card' AND paid_at >= ? AND paid_at <= ?
    ''',
      [startOfDay, endOfDay],
    );

    return (result.first['total'] as int?) ?? 0;
  }

  Future<int> sumCashPaymentsByWaiter({
    required int waiterId,
    required int startMs,
    required int endMs,
  }) async {
    final db = await AppDb.I.db;
    final result = await db.rawQuery(
      '''
      SELECT SUM(total_cents) as total
      FROM payments
      WHERE method = 'cash' AND paid_at >= ? AND paid_at <= ? AND paid_by = ?
    ''',
      [startMs, endMs, waiterId],
    );

    return (result.first['total'] as int?) ?? 0;
  }

  Future<int> sumCardPaymentsByWaiter({
    required int waiterId,
    required int startMs,
    required int endMs,
  }) async {
    final db = await AppDb.I.db;
    final result = await db.rawQuery(
      '''
      SELECT SUM(total_cents) as total
      FROM payments
      WHERE method = 'card' AND paid_at >= ? AND paid_at <= ? AND paid_by = ?
    ''',
      [startMs, endMs, waiterId],
    );

    return (result.first['total'] as int?) ?? 0;
  }
}

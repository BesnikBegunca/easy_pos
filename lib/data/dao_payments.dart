import 'package:sqflite_common/sqlite_api.dart';
import 'db.dart';

class PaymentRow {
  final int id;
  final int tableId;
  final int? orderId;
  final int totalCents;
  final String method; // cash/card/mixed
  final int paidAt;
  final int paidBy;

  PaymentRow({
    required this.id,
    required this.tableId,
    required this.orderId,
    required this.totalCents,
    required this.method,
    required this.paidAt,
    required this.paidBy,
  });
}

class PaymentsDao {
  PaymentsDao._();
  static final PaymentsDao I = PaymentsDao._();

  /// ✅ Insert payment (supports transactions via [ex])
  Future<int> createPayment({
    DatabaseExecutor? ex,
    required int tableId,
    required int orderId,
    required int totalCents,
    required String method, // cash/card/mixed
    required int paidBy,
  }) async {
    final db = ex ?? await AppDb.I.db;

    final m = method.trim().toLowerCase();
    final safeMethod = (m == 'cash' || m == 'card' || m == 'mixed')
        ? m
        : 'cash';

    return db.insert('payments', {
      'table_id': tableId,
      'order_id': orderId, // ✅ THIS FIXES SETTLEMENT JOIN
      'total_cents': totalCents,
      'method': safeMethod,
      'paid_at': DateTime.now().millisecondsSinceEpoch,
      'paid_by': paidBy,
    });
  }

  /// Helpers to compute day range
  int _dayStartMs(DateTime d) {
    final s = DateTime(d.year, d.month, d.day);
    return s.millisecondsSinceEpoch;
  }

  int _dayEndMs(DateTime d) {
    final e = DateTime(d.year, d.month, d.day, 23, 59, 59, 999);
    return e.millisecondsSinceEpoch;
  }

  /// ✅ Sum of CASH payments for a given day
  Future<int> sumCashPayments(DateTime day) async {
    return sumByMethodInRange(
      startMs: _dayStartMs(day),
      endMs: _dayEndMs(day),
      method: 'cash',
    );
  }

  /// ✅ Sum of CARD payments for a given day
  Future<int> sumCardPayments(DateTime day) async {
    return sumByMethodInRange(
      startMs: _dayStartMs(day),
      endMs: _dayEndMs(day),
      method: 'card',
    );
  }

  /// ✅ Generic sum by method in range
  /// Note: mixed is NOT included unless you call with method='mixed'
  Future<int> sumByMethodInRange({
    required int startMs,
    required int endMs,
    required String method, // cash/card/mixed
  }) async {
    final db = await AppDb.I.db;
    final m = method.trim().toLowerCase();

    final rows = await db.rawQuery(
      '''
SELECT COALESCE(SUM(total_cents),0) AS s
FROM payments
WHERE method = ?
  AND paid_at >= ?
  AND paid_at <= ?
''',
      [m, startMs, endMs],
    );

    return (rows.first['s'] as int?) ?? 0;
  }

  /// ✅ Recent payments list
  Future<List<PaymentRow>> listRecent({int limit = 50}) async {
    final db = await AppDb.I.db;
    final rows = await db.query(
      'payments',
      orderBy: 'paid_at DESC',
      limit: limit,
    );

    return rows.map((r) {
      return PaymentRow(
        id: r['id'] as int,
        tableId: r['table_id'] as int,
        orderId: r['order_id'] as int?,
        totalCents: r['total_cents'] as int,
        method: (r['method'] as String?) ?? 'cash',
        paidAt: r['paid_at'] as int,
        paidBy: r['paid_by'] as int,
      );
    }).toList();
  }
}

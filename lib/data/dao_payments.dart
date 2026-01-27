import 'db.dart';

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

  Future<int> createPayment({
    required int tableId,
    required int totalCents,
    required String method,
    required int paidBy,
  }) async {
    final db = await AppDb.I.db;
    return db.insert('payments', {
      'table_id': tableId,
      'total_cents': totalCents,
      'method': method,
      'paid_at': DateTime.now().millisecondsSinceEpoch,
      'paid_by': paidBy,
    });
  }

  Future<List<PaymentRow>> getPaymentsForTable(int tableId) async {
    final db = await AppDb.I.db;
    final rows = await db.query(
      'payments',
      where: 'table_id=?',
      whereArgs: [tableId],
      orderBy: 'paid_at DESC',
    );
    return rows
        .map(
          (e) => PaymentRow(
            id: e['id'] as int,
            tableId: e['table_id'] as int,
            totalCents: e['total_cents'] as int,
            method: e['method'] as String,
            paidAt: e['paid_at'] as int,
            paidBy: e['paid_by'] as int,
          ),
        )
        .toList();
  }

  Future<int> sumCashPayments(DateTime date) async {
    final db = await AppDb.I.db;
    final start = DateTime(
      date.year,
      date.month,
      date.day,
    ).millisecondsSinceEpoch;
    final end = DateTime(
      date.year,
      date.month,
      date.day + 1,
    ).millisecondsSinceEpoch;
    final rows = await db.rawQuery(
      'SELECT COALESCE(SUM(total_cents),0) AS s FROM payments WHERE method IN ("cash","mixed") AND paid_at >= ? AND paid_at < ?',
      [start, end],
    );
    return (rows.first['s'] as int?) ?? 0;
  }

  Future<int> sumCardPayments(DateTime date) async {
    final db = await AppDb.I.db;
    final start = DateTime(
      date.year,
      date.month,
      date.day,
    ).millisecondsSinceEpoch;
    final end = DateTime(
      date.year,
      date.month,
      date.day + 1,
    ).millisecondsSinceEpoch;
    final rows = await db.rawQuery(
      'SELECT COALESCE(SUM(total_cents),0) AS s FROM payments WHERE method IN ("card","mixed") AND paid_at >= ? AND paid_at < ?',
      [start, end],
    );
    return (rows.first['s'] as int?) ?? 0;
  }
}

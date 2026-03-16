import 'db.dart';

class PrintedSaleRow {
  final int id;
  final int waiterId;
  final int orderId;
  final int tableId;
  final int amountCents;
  final int printedAt;
  final int? settledId;

  PrintedSaleRow({
    required this.id,
    required this.waiterId,
    required this.orderId,
    required this.tableId,
    required this.amountCents,
    required this.printedAt,
    this.settledId,
  });
}

class PrintedSalesDao {
  PrintedSalesDao._();
  static final PrintedSalesDao I = PrintedSalesDao._();

  Future<int> addPrintedSale({
    required int waiterId,
    required int orderId,
    required int tableId,
    required int amountCents,
  }) async {
    final db = await AppDb.I.db;
    return db.insert('printed_sales', {
      'waiter_id': waiterId,
      'order_id': orderId,
      'table_id': tableId,
      'amount_cents': amountCents,
      'printed_at': DateTime.now().millisecondsSinceEpoch,
      'settled_id': null,
    });
  }

  Future<Map<String, int>> getUnsettledTotals({
    required int waiterId,
    required int startMs,
    required int endMs,
  }) async {
    final db = await AppDb.I.db;

    final rows = await db.rawQuery(
      '''
SELECT amount_cents
FROM printed_sales
WHERE waiter_id = ?
  AND printed_at >= ?
  AND printed_at < ?
  AND (settled_id IS NULL OR settled_id = 0)
''',
      [waiterId, startMs, endMs],
    );

    int total = 0;
    for (final row in rows) {
      total += (row['amount_cents'] as int?) ?? 0;
    }

    return {'total': total, 'cash': total, 'card': 0, 'expectedCash': total};
  }

  Future<void> markSettled({
    required int waiterId,
    required int startMs,
    required int endMs,
    required int settlementId,
  }) async {
    final db = await AppDb.I.db;

    await db.update(
      'printed_sales',
      {'settled_id': settlementId},
      where:
          'waiter_id = ? AND printed_at >= ? AND printed_at < ? AND (settled_id IS NULL OR settled_id = 0)',
      whereArgs: [waiterId, startMs, endMs],
    );
  }

  Future<List<PrintedSaleRow>> listByWaiter({required int waiterId}) async {
    final db = await AppDb.I.db;

    final rows = await db.query(
      'printed_sales',
      where: 'waiter_id = ?',
      whereArgs: [waiterId],
      orderBy: 'printed_at DESC',
    );

    return rows
        .map(
          (r) => PrintedSaleRow(
            id: r['id'] as int,
            waiterId: r['waiter_id'] as int,
            orderId: r['order_id'] as int,
            tableId: r['table_id'] as int,
            amountCents: r['amount_cents'] as int,
            printedAt: r['printed_at'] as int,
            settledId: r['settled_id'] as int?,
          ),
        )
        .toList();
  }
}

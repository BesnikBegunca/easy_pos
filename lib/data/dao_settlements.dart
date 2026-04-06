import 'db.dart';
import 'dao_printed_sales.dart';

class SettlementRow {
  final int id;
  final int waiterId;
  final int totalCents;
  final int cashCents;
  final int cardCents;
  final int expectedCashCents;
  final int differenceCents;
  final int startMs;
  final int endMs;
  final String? notes;
  final int settledBy;
  final int settledAt;

  SettlementRow({
    required this.id,
    required this.waiterId,
    required this.totalCents,
    required this.cashCents,
    required this.cardCents,
    required this.expectedCashCents,
    required this.differenceCents,
    required this.startMs,
    required this.endMs,
    this.notes,
    required this.settledBy,
    required this.settledAt,
  });
}

class SettlementsDao {
  SettlementsDao._();
  static final SettlementsDao I = SettlementsDao._();

  Future<int> createSettlement({
    required int waiterId,
    required int totalCents,
    required int cashCents,
    required int cardCents,
    required int expectedCashCents,
    required int differenceCents,
    required int startMs,
    required int endMs,
    String? notes,
    required int settledBy,
  }) async {
    final db = await AppDb.I.db;
    return db.insert('settlements', {
      'waiter_id': waiterId,
      'total_cents': totalCents,
      'cash_cents': cashCents,
      'card_cents': cardCents,
      'expected_cash_cents': expectedCashCents,
      'difference_cents': differenceCents,
      'start_ms': startMs,
      'end_ms': endMs,
      'notes': notes,
      'settled_by': settledBy,
      'settled_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<List<SettlementRow>> listByWaiter(int waiterId) async {
    final db = await AppDb.I.db;
    final rows = await db.query(
      'settlements',
      where: 'waiter_id=?',
      whereArgs: [waiterId],
      orderBy: 'settled_at DESC',
    );

    return rows.map((r) {
      return SettlementRow(
        id: r['id'] as int,
        waiterId: r['waiter_id'] as int,
        totalCents: r['total_cents'] as int,
        cashCents: r['cash_cents'] as int,
        cardCents: r['card_cents'] as int,
        expectedCashCents: r['expected_cash_cents'] as int,
        differenceCents: r['difference_cents'] as int,
        startMs: r['start_ms'] as int,
        endMs: r['end_ms'] as int,
        notes: r['notes'] as String?,
        settledBy: r['settled_by'] as int,
        settledAt: r['settled_at'] as int,
      );
    }).toList();
  }

  Future<Map<String, int>> getUnsettledTotals({
    required int waiterId,
    required int startMs,
    required int endMs,
  }) async {
    return PrintedSalesDao.I.getUnsettledTotals(
      waiterId: waiterId,
      startMs: startMs,
      endMs: endMs,
    );
  }

  /// FIXED: Complete waiter settlement with atomic DB transaction.
  /// 1. Insert settlement record
  /// 2. Mark printed_sales as settled for the shift range (past prints)
  /// 3. Close ALL current open tables for waiter: status='free', waiter_id=null
  /// 4. For each table, mark open orders as 'paid', set final total_cents, settled_id, closed_at
  /// 5. Reset waiter shift_started_at for fresh start
  /// Now tables no longer appear open for waiter, totals start from 0.00.
  Future<void> settleWaiter({
    required int waiterId,
    required int startMs,
    required int endMs,
    required int totalCents,
    required int cashCents,
    required int cardCents,
    required int expectedCashCents,
    required int actualCashCents,
    String? notes,
    required int settledBy,
  }) async {
    final db = await AppDb.I.db;
    await db.transaction((txn) async {
      // 1. Create settlement record
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final settlementId = await txn.insert('settlements', {
        'waiter_id': waiterId,
        'total_cents': totalCents,
        'cash_cents': cashCents,
        'card_cents': cardCents,
        'expected_cash_cents': expectedCashCents,
        'difference_cents': actualCashCents - expectedCashCents,
        'start_ms': startMs,
        'end_ms': endMs,
        'notes': notes,
        'settled_by': settledBy,
        'settled_at': nowMs,
      });

      // 2. Mark past printed_sales as settled (by shift range)
      await txn.update(
        'printed_sales',
        {'settled_id': settlementId},
        where: 'waiter_id = ? AND printed_at >= ? AND printed_at < ? AND (settled_id IS NULL OR settled_id = 0)',
        whereArgs: [waiterId, startMs, endMs],
      );

      // 3. Close ALL open tables for this waiter
      final openTables = await txn.rawQuery(
        'SELECT id FROM dining_tables WHERE waiter_id = ? AND is_active = 1',
        [waiterId],
      );
      print('Closing ${openTables.length} open tables for waiter $waiterId during settlement');

      final nowClosedAt = nowMs; // consistent timestamp

      for (final tableRow in openTables) {
        final tableId = tableRow['id'] as int;

        // Close open orders for this table, set final totals and link to settlement
        final totalRows = await txn.rawQuery('''
          SELECT COALESCE(SUM(oi.line_total_cents), 0) AS total_cents
          FROM orders o
          LEFT JOIN order_items oi ON oi.order_id = o.id
          WHERE o.table_id = ? AND o.status = 'open' AND o.waiter_id = ?
        ''', [tableId, waiterId]);

        final orderTotalCents = (totalRows.first['total_cents'] as num?)?.toInt() ?? 0;

        // Update orders to 'paid' / settled
        await txn.update(
          'orders',
          {
            'status': 'paid',
            'total_cents': orderTotalCents,
            'closed_at': nowClosedAt,
            'settled_id': settlementId,
          },
          where: 'table_id = ? AND status = "open" AND waiter_id = ?',
          whereArgs: [tableId, waiterId],
        );

        // Free the table
        await txn.update(
          'dining_tables',
          {'status': 'free', 'waiter_id': null},
          where: 'id = ?',
          whereArgs: [tableId],
        );
      }

      // 4. Reset waiter shift for fresh start
      await txn.update(
        'users',
        {'shift_started_at': nowMs},
        where: 'id = ?',
        whereArgs: [waiterId],
      );
    });
  }
}


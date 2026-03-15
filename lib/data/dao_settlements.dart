import 'db.dart';

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

  /// ✅ totals for paid orders not yet settled
  Future<Map<String, int>> getUnsettledTotals({
    required int waiterId,
    required int startMs,
    required int endMs,
  }) async {
    final db = await AppDb.I.db;

    // LEFT JOIN so old payments without order_id don't nuke result set
    // If payment missing, we still count order total into total,
    // and classify method as 'cash' by default (safe fallback).
    final rows = await db.rawQuery(
      '''
SELECT 
  o.total_cents AS total_cents,
  COALESCE(p.method, 'cash') AS method
FROM orders o
LEFT JOIN payments p ON p.order_id = o.id
WHERE o.waiter_id = ?
  AND o.status = 'paid'
  AND o.closed_at IS NOT NULL
  AND o.closed_at >= ?
  AND o.closed_at < ?
  AND (o.settled_id IS NULL OR o.settled_id = 0)
''',
      [waiterId, startMs, endMs],
    );

    int total = 0;
    int cash = 0;
    int card = 0;

    for (final row in rows) {
      final orderTotal = (row['total_cents'] as int?) ?? 0;
      final method = (row['method'] as String?)?.toLowerCase() ?? 'cash';

      total += orderTotal;

      if (method == 'card') {
        card += orderTotal;
      } else if (method == 'mixed') {
        // mixed: for now count all in cash? (or split later)
        // safest: treat as cash expected by default
        cash += orderTotal;
      } else {
        cash += orderTotal;
      }
    }

    return {'total': total, 'cash': cash, 'card': card, 'expectedCash': cash};
  }

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

    final settlementId = await db.insert('settlements', {
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
      'settled_at': DateTime.now().millisecondsSinceEpoch,
    });

    await db.update(
      'orders',
      {'settled_id': settlementId},
      where:
          'waiter_id = ? AND status = ? AND closed_at >= ? AND closed_at < ? AND (settled_id IS NULL OR settled_id = 0)',
      whereArgs: [waiterId, 'paid', startMs, endMs],
    );

    // Reset DaySum by setting shift_started_at to null or current time
    await db.update(
      'users',
      {'shift_started_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [waiterId],
    );
  }
}

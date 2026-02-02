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
    final id = await db.insert('settlements', {
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

    return id;
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
}

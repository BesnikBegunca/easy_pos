import 'db.dart';

class DaySessionRow {
  final int id;
  final String date;
  final int openingCashCents;
  final int cashSalesCents;
  final int cardSalesCents;
  final int discountsCents;
  final int refundsCents;
  final int expectedCashCents;
  final int? actualCashCents;
  final int? differenceCents;
  final String? notes;
  final int? settledBy;
  final int? settledAt;

  DaySessionRow({
    required this.id,
    required this.date,
    required this.openingCashCents,
    required this.cashSalesCents,
    required this.cardSalesCents,
    required this.discountsCents,
    required this.refundsCents,
    required this.expectedCashCents,
    this.actualCashCents,
    this.differenceCents,
    this.notes,
    this.settledBy,
    this.settledAt,
  });
}

class DaySessionsDao {
  DaySessionsDao._();
  static final DaySessionsDao I = DaySessionsDao._();

  Future<DaySessionRow?> getSessionForDate(String date) async {
    final db = await AppDb.I.db;
    final rows = await db.query(
      'day_sessions',
      where: 'date=?',
      whereArgs: [date],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final e = rows.first;
    return DaySessionRow(
      id: e['id'] as int,
      date: e['date'] as String,
      openingCashCents: e['opening_cash_cents'] as int,
      cashSalesCents: e['cash_sales_cents'] as int,
      cardSalesCents: e['card_sales_cents'] as int,
      discountsCents: e['discounts_cents'] as int,
      refundsCents: e['refunds_cents'] as int,
      expectedCashCents: e['expected_cash_cents'] as int,
      actualCashCents: e['actual_cash_cents'] as int?,
      differenceCents: e['difference_cents'] as int?,
      notes: e['notes'] as String?,
      settledBy: e['settled_by'] as int?,
      settledAt: e['settled_at'] as int?,
    );
  }

  Future<int> createSession({
    required String date,
    required int openingCashCents,
  }) async {
    final db = await AppDb.I.db;
    return db.insert('day_sessions', {
      'date': date,
      'opening_cash_cents': openingCashCents,
      'cash_sales_cents': 0,
      'card_sales_cents': 0,
      'discounts_cents': 0,
      'refunds_cents': 0,
      'expected_cash_cents': openingCashCents,
    });
  }

  Future<void> updateSessionTotals({
    required String date,
    required int cashSalesCents,
    required int cardSalesCents,
    required int discountsCents,
    required int refundsCents,
  }) async {
    final db = await AppDb.I.db;
    final session = await getSessionForDate(date);
    if (session == null) return;

    final expectedCash =
        session.openingCashCents + cashSalesCents - refundsCents;

    await db.update(
      'day_sessions',
      {
        'cash_sales_cents': cashSalesCents,
        'card_sales_cents': cardSalesCents,
        'discounts_cents': discountsCents,
        'refunds_cents': refundsCents,
        'expected_cash_cents': expectedCash,
      },
      where: 'date=?',
      whereArgs: [date],
    );
  }

  Future<void> settleSession({
    required String date,
    required int actualCashCents,
    required int settledBy,
    String? notes,
  }) async {
    final db = await AppDb.I.db;
    final session = await getSessionForDate(date);
    if (session == null) return;

    final difference = actualCashCents - session.expectedCashCents;

    await db.update(
      'day_sessions',
      {
        'actual_cash_cents': actualCashCents,
        'difference_cents': difference,
        'notes': notes,
        'settled_by': settledBy,
        'settled_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'date=?',
      whereArgs: [date],
    );
  }
}

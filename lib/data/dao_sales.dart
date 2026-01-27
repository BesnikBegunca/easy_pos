import 'db.dart';

enum RangeKind { day, week, month, year }

class SalesDao {
  SalesDao._();
  static final SalesDao I = SalesDao._();

  Future<int> sumTotalCents({
    required RangeKind range,
    required DateTime anchor,
    int? waiterId, // null = all
  }) async {
    final db = await AppDb.I.db;
    final r = _range(range, anchor);

    final where = <String>[];
    final args = <Object?>[];

    where.add('created_at >= ? AND created_at < ?');
    args.add(r.$1);
    args.add(r.$2);

    if (waiterId != null) {
      where.add('waiter_id = ?');
      args.add(waiterId);
    }

    final rows = await db.rawQuery(
      'SELECT COALESCE(SUM(total_cents),0) AS s FROM sales WHERE ${where.join(" AND ")}',
      args,
    );
    return (rows.first['s'] as int?) ?? 0;
  }

  Future<List<WaiterTotalRow>> totalsByWaiter({
    required RangeKind range,
    required DateTime anchor,
  }) async {
    final db = await AppDb.I.db;
    final r = _range(range, anchor);

    final rows = await db.rawQuery(
      '''
SELECT 
  u.id AS waiter_id,
  u.full_name AS full_name,
  u.username AS username,
  COALESCE(SUM(s.total_cents),0) AS total_cents
FROM users u
LEFT JOIN sales s 
  ON s.waiter_id = u.id 
  AND s.created_at >= ? 
  AND s.created_at < ?
WHERE u.role = 'waiter' AND u.is_active=1
GROUP BY u.id
ORDER BY total_cents DESC, u.username ASC;
''',
      [r.$1, r.$2],
    );

    return rows.map((e) {
      return WaiterTotalRow(
        waiterId: e['waiter_id'] as int,
        username: (e['username'] as String?) ?? '',
        fullName: e['full_name'] as String?,
        totalCents: (e['total_cents'] as int?) ?? 0,
      );
    }).toList();
  }

  // ✅ për test: shto një "sale" manualisht
  Future<void> addSale({required int waiterId, required int totalCents}) async {
    final db = await AppDb.I.db;
    await db.insert('sales', {
      'waiter_id': waiterId,
      'total_cents': totalCents,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  (int startMs, int endMs) _range(RangeKind k, DateTime a) {
    final local = DateTime(a.year, a.month, a.day);

    if (k == RangeKind.day) {
      final start = DateTime(local.year, local.month, local.day);
      final end = start.add(const Duration(days: 1));
      return (start.millisecondsSinceEpoch, end.millisecondsSinceEpoch);
    }

    if (k == RangeKind.week) {
      // ISO-ish week starting Monday
      final weekday = local.weekday; // Mon=1..Sun=7
      final start = local.subtract(Duration(days: weekday - 1));
      final end = start.add(const Duration(days: 7));
      return (start.millisecondsSinceEpoch, end.millisecondsSinceEpoch);
    }

    if (k == RangeKind.month) {
      final start = DateTime(local.year, local.month, 1);
      final end = DateTime(local.year, local.month + 1, 1);
      return (start.millisecondsSinceEpoch, end.millisecondsSinceEpoch);
    }

    // year
    final start = DateTime(local.year, 1, 1);
    final end = DateTime(local.year + 1, 1, 1);
    return (start.millisecondsSinceEpoch, end.millisecondsSinceEpoch);
  }
}

class WaiterTotalRow {
  final int waiterId;
  final String username;
  final String? fullName;
  final int totalCents;

  WaiterTotalRow({
    required this.waiterId,
    required this.username,
    required this.fullName,
    required this.totalCents,
  });
}

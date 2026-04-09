import 'db.dart';

class ZReportRow {
  final int waiterId;
  final String name;
  final int totalCents;
  final int orderCount;

  ZReportRow({
    required this.waiterId,
    required this.name,
    required this.totalCents,
    required this.orderCount,
  });
}

class ZReportDao {
  ZReportDao._();
  static final ZReportDao I = ZReportDao._();

  /// Returns per-waiter totals for today (paid orders only).
  /// Includes waiters and managers; sorted by total desc.
  Future<List<ZReportRow>> todayByWaiter() async {
    final db = await AppDb.I.db;
    final now = DateTime.now();
    final startMs =
        DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final endMs = DateTime(now.year, now.month, now.day, 23, 59, 59, 999)
        .millisecondsSinceEpoch;

    final rows = await db.rawQuery(
      '''
SELECT
  u.id          AS waiter_id,
  COALESCE(u.full_name, u.username) AS name,
  COALESCE(SUM(o.total_cents), 0)   AS total_cents,
  COUNT(o.id)                        AS order_count
FROM users u
LEFT JOIN orders o
  ON  o.waiter_id = u.id
  AND o.status    = 'paid'
  AND o.closed_at >= ?
  AND o.closed_at <= ?
WHERE u.is_active = 1
  AND u.role IN ('waiter', 'manager')
GROUP BY u.id
ORDER BY total_cents DESC, u.username ASC
''',
      [startMs, endMs],
    );

    return rows
        .map(
          (r) => ZReportRow(
            waiterId: r['waiter_id'] as int,
            name: (r['name'] as String?) ?? '?',
            totalCents: (r['total_cents'] as int?) ?? 0,
            orderCount: (r['order_count'] as int?) ?? 0,
          ),
        )
        .toList();
  }
}

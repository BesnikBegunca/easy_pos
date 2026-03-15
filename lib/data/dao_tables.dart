import 'db.dart';

class _TableData {
  final String status;
  final int totalCents;

  _TableData({required this.status, required this.totalCents});
}

class DiningTableRow {
  final int id;
  final String name;
  final String status;
  final bool isActive;
  final int totalCents;

  DiningTableRow({
    required this.id,
    required this.name,
    required this.status,
    required this.isActive,
    required this.totalCents,
  });
}

class TablesDao {
  TablesDao._();
  static final TablesDao I = TablesDao._();

  Future<List<DiningTableRow>> listTables({int? waiterId}) async {
    final db = await AppDb.I.db;
    String whereClause = 'is_active=1';
    List<Object?> whereArgs = [];

    if (waiterId != null) {
      whereClause += ' AND waiter_id=?';
      whereArgs.add(waiterId);
    }

    final rows = await db.query(
      'dining_tables',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'id ASC',
    );

    // Get table statuses and totals based on orders
    final tableData = await _getTableData(waiterId: waiterId);

    return rows
        .map(
          (e) => DiningTableRow(
            id: e['id'] as int,
            name: e['name'] as String,
            status: tableData[e['id']]?.status ?? 'free',
            isActive: (e['is_active'] as int) == 1,
            totalCents: tableData[e['id']]?.totalCents ?? 0,
          ),
        )
        .toList();
  }

  Future<Map<int, _TableData>> _getTableData({int? waiterId}) async {
    final db = await AppDb.I.db;
    String whereClause = 'is_active=1';
    List<Object?> whereArgs = [];

    if (waiterId != null) {
      whereClause += ' AND waiter_id=?';
      whereArgs.add(waiterId);
    }

    final rows = await db.query(
      'dining_tables',
      where: whereClause,
      whereArgs: whereArgs,
    );
    final Map<int, _TableData> data = {};
    for (final row in rows) {
      final tableId = row['id'] as int;
      data[tableId] = _TableData(status: 'free', totalCents: 0);
    }

    // Get totals for open orders
    String orderWhere = 'o.status = \'open\'';
    List<Object?> orderArgs = [];

    if (waiterId != null) {
      orderWhere += ' AND o.waiter_id=?';
      orderArgs.add(waiterId);
    }

    final totalRows = await db.rawQuery('''
      SELECT o.table_id, SUM(oi.line_total_cents) AS total_cents
      FROM orders o
      JOIN order_items oi ON oi.order_id = o.id
      WHERE $orderWhere
      GROUP BY o.table_id
    ''', orderArgs);
    for (final row in totalRows) {
      final tableId = row['table_id'] as int;
      final totalCents = row['total_cents'] as int;
      if (data.containsKey(tableId)) {
        data[tableId] = _TableData(
          status: totalCents > 0 ? 'open' : 'free',
          totalCents: totalCents,
        );
      }
    }

    return data;
  }

  Future<int> addTable(String name, {int? waiterId}) async {
    final db = await AppDb.I.db;
    return db.insert('dining_tables', {
      'name': name.trim().isEmpty ? 'Tavolina' : name.trim(),
      'waiter_id': waiterId,
      'is_active': 1,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> assignTableToWaiter(int tableId, int waiterId) async {
    final db = await AppDb.I.db;
    await db.update(
      'dining_tables',
      {'waiter_id': waiterId},
      where: 'id=?',
      whereArgs: [tableId],
    );
  }

  Future<void> seedDefaultTables() async {
    final db = await AppDb.I.db;
    final now = DateTime.now().millisecondsSinceEpoch;
    for (int i = 1; i <= 10; i++) {
      final name = 'Tavolina $i';
      final existing = await db.query(
        'dining_tables',
        where: 'id=?',
        whereArgs: [i],
        limit: 1,
      );
      if (existing.isEmpty) {
        await db.insert('dining_tables', {
          'id': i,
          'name': name,
          'is_active': 1,
          'created_at': now,
        });
      } else {
        // Ensure it's active and has correct name
        await db.update(
          'dining_tables',
          {'is_active': 1, 'name': name},
          where: 'id=?',
          whereArgs: [i],
        );
      }
    }
  }

  Future<int> countTablesByWaiter(int waiterId) async {
    final db = await AppDb.I.db;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM dining_tables WHERE waiter_id = ? AND is_active = 1',
      [waiterId],
    );
    return (rows.first['c'] as int?) ?? 0;
  }
}

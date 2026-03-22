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
    final List<Object?> whereArgs = [];

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
    final List<Object?> whereArgs = [];

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

    String orderWhere = "o.status = 'open'";
    final List<Object?> orderArgs = [];

    if (waiterId != null) {
      orderWhere += ' AND o.waiter_id=?';
      orderArgs.add(waiterId);
    }

    final totalRows = await db.rawQuery('''
      SELECT o.table_id, COALESCE(SUM(oi.line_total_cents), 0) AS total_cents
      FROM orders o
      LEFT JOIN order_items oi ON oi.order_id = o.id
      WHERE $orderWhere
      GROUP BY o.table_id
      ''', orderArgs);

    for (final row in totalRows) {
      final tableId = row['table_id'] as int;
      final totalCents = (row['total_cents'] as num?)?.toInt() ?? 0;

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
        await db.update(
          'dining_tables',
          {'is_active': 1, 'name': name},
          where: 'id=?',
          whereArgs: [i],
        );
      }
    }
  }

  /// Kthen sa tavolina UNIKE i ka pas kamarieri të hapura gjatë shift-it aktual.
  ///
  /// Logjika:
  /// - e lexon shift_started_at nga tabela users
  /// - i numëron tavolinat DISTINCT nga orders
  /// - nëse s’ka shift_started_at, kthen 0
  Future<int> countTablesByWaiter(int waiterId) async {
    final db = await AppDb.I.db;

    final waiterRows = await db.query(
      'users',
      columns: ['shift_started_at'],
      where: 'id=?',
      whereArgs: [waiterId],
      limit: 1,
    );

    if (waiterRows.isEmpty) return 0;

    final shiftStartedAt = waiterRows.first['shift_started_at'] as int?;
    if (shiftStartedAt == null || shiftStartedAt <= 0) {
      return 0;
    }

    final rows = await db.rawQuery(
      '''
      SELECT COUNT(DISTINCT table_id) AS c
      FROM orders
      WHERE waiter_id = ?
        AND created_at >= ?
      ''',
      [waiterId, shiftStartedAt],
    );

    return (rows.first['c'] as num?)?.toInt() ?? 0;
  }

  /// Nëse don me dit sa HERË është hap një tavolinë gjatë shift-it
  /// (jo sa tavolina unike), përdore këtë.
  Future<int> countTableOpenEventsByWaiter(int waiterId) async {
    final db = await AppDb.I.db;

    final waiterRows = await db.query(
      'users',
      columns: ['shift_started_at'],
      where: 'id=?',
      whereArgs: [waiterId],
      limit: 1,
    );

    if (waiterRows.isEmpty) return 0;

    final shiftStartedAt = waiterRows.first['shift_started_at'] as int?;
    if (shiftStartedAt == null || shiftStartedAt <= 0) {
      return 0;
    }

    final rows = await db.rawQuery(
      '''
      SELECT COUNT(*) AS c
      FROM orders
      WHERE waiter_id = ?
        AND created_at >= ?
      ''',
      [waiterId, shiftStartedAt],
    );

    return (rows.first['c'] as num?)?.toInt() ?? 0;
  }
}

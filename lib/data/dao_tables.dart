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

  Future<List<DiningTableRow>> listTables() async {
    final db = await AppDb.I.db;
    final rows = await db.query(
      'dining_tables',
      where: 'is_active=1',
      orderBy: 'id ASC',
    );

    // Get table statuses and totals based on orders
    final tableData = await _getTableData();

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

  Future<Map<int, _TableData>> _getTableData() async {
    final db = await AppDb.I.db;
    final rows = await db.query('dining_tables', where: 'is_active=1');
    final Map<int, _TableData> data = {};
    for (final row in rows) {
      final tableId = row['id'] as int;
      final status = (row['status'] as String?) ?? 'free';
      data[tableId] = _TableData(status: status, totalCents: 0);
    }

    // Get totals for open orders
    final totalRows = await db.rawQuery('''
      SELECT o.table_id, SUM(oi.line_total_cents) AS total_cents
      FROM orders o
      JOIN order_items oi ON oi.order_id = o.id
      WHERE o.status = 'open'
      GROUP BY o.table_id
    ''');
    for (final row in totalRows) {
      final tableId = row['table_id'] as int;
      final totalCents = row['total_cents'] as int;
      if (data.containsKey(tableId)) {
        data[tableId] = _TableData(
          status: data[tableId]!.status,
          totalCents: totalCents,
        );
      }
    }

    return data;
  }

  Future<int> addTable(String name) async {
    final db = await AppDb.I.db;
    return db.insert('dining_tables', {
      'name': name.trim().isEmpty ? 'Tavolina' : name.trim(),
      'is_active': 1,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> seedDefaultTables() async {
    final db = await AppDb.I.db;
    for (int i = 1; i <= 10; i++) {
      await db.insert('dining_tables', {
        'name': 'Tavolina $i',
        'is_active': 1,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });
    }
  }
}

import 'db.dart';

class DiningTableRow {
  final int id;
  final String name;
  final bool isActive;

  DiningTableRow({required this.id, required this.name, required this.isActive});
}

class TablesDao {
  TablesDao._();
  static final TablesDao I = TablesDao._();

  Future<List<DiningTableRow>> listTables() async {
    final db = await AppDb.I.db;
    final rows = await db.query('dining_tables', where: 'is_active=1', orderBy: 'id ASC');
    return rows.map((e) => DiningTableRow(
      id: e['id'] as int,
      name: e['name'] as String,
      isActive: (e['is_active'] as int) == 1,
    )).toList();
  }

  Future<int> addTable(String name) async {
    final db = await AppDb.I.db;
    return db.insert('dining_tables', {
      'name': name.trim().isEmpty ? 'Tavolina' : name.trim(),
      'is_active': 1,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }
}

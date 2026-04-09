import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'db.dart';

class SettingsDao {
  SettingsDao._();
  static final SettingsDao I = SettingsDao._();

  static const String tableGridColumns = 'table_grid_columns';
  static const String productGridColumns = 'product_grid_columns';

  static const int defaultTableColumns = 7;
  static const int defaultProductColumns = 5;

  Future<int> getInt(String key, int defaultValue) async {
    final db = await AppDb.I.db;
    try {
      final rows = await db.query(
        'app_settings',
        where: 'key=?',
        whereArgs: [key],
        limit: 1,
      );
      if (rows.isEmpty) return defaultValue;
      return int.tryParse(rows.first['value'] as String? ?? '') ?? defaultValue;
    } catch (_) {
      return defaultValue;
    }
  }

  Future<void> setInt(String key, int value) async {
    final db = await AppDb.I.db;
    await db.insert(
      'app_settings',
      {'key': key, 'value': value.toString()},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}

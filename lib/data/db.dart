import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const int kDbVersion = 2;

class AppDb {
  AppDb._();
  static final AppDb I = AppDb._();

  Database? _db;

  Future<Database> get db async {
    if (_db != null) return _db!;
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'restaurant_pos.db');

    _db = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: kDbVersion,
        onCreate: (db, v) async {
          await _createAll(db);
          await _seedDefaults(db);
        },
        onUpgrade: (db, oldV, newV) async {
          // ✅ siguron që tabelat ekzistojnë edhe në DB të vjetër
          await _createAll(db);
          await _seedDefaults(db);
        },
      ),
    );

    return _db!;
  }

  Future<void> _createAll(Database db) async {
    // USERS
    await db.execute('''
CREATE TABLE IF NOT EXISTS users(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  username TEXT NOT NULL UNIQUE,
  pass_hash TEXT NOT NULL,
  role TEXT NOT NULL, -- admin/manager/waiter
  full_name TEXT,
  is_active INTEGER NOT NULL DEFAULT 1,
  created_at INTEGER NOT NULL
);
''');

    // SALES
    await db.execute('''
CREATE TABLE IF NOT EXISTS sales(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  waiter_id INTEGER NOT NULL,
  total_cents INTEGER NOT NULL,
  created_at INTEGER NOT NULL,
  FOREIGN KEY(waiter_id) REFERENCES users(id)
);
''');

    // TABLES
    await db.execute('''
CREATE TABLE IF NOT EXISTS dining_tables(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  is_active INTEGER NOT NULL DEFAULT 1,
  created_at INTEGER NOT NULL
);
''');

    // CATEGORIES
    await db.execute('''
CREATE TABLE IF NOT EXISTS categories(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL UNIQUE,
  sort_index INTEGER NOT NULL DEFAULT 0
);
''');

    // PRODUCTS
    await db.execute('''
CREATE TABLE IF NOT EXISTS products(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  category_id INTEGER,
  price_cents INTEGER NOT NULL,
  is_active INTEGER NOT NULL DEFAULT 1,
  created_at INTEGER NOT NULL,
  FOREIGN KEY(category_id) REFERENCES categories(id)
);
''');

    // ORDERS
    await db.execute('''
CREATE TABLE IF NOT EXISTS orders(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  table_id INTEGER NOT NULL,
  waiter_id INTEGER NOT NULL,
  status TEXT NOT NULL, -- open/paid/cancelled
  total_cents INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL,
  closed_at INTEGER,
  FOREIGN KEY(table_id) REFERENCES dining_tables(id),
  FOREIGN KEY(waiter_id) REFERENCES users(id)
);
''');

    // ORDER ITEMS
    await db.execute('''
CREATE TABLE IF NOT EXISTS order_items(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  order_id INTEGER NOT NULL,
  product_id INTEGER NOT NULL,
  qty INTEGER NOT NULL,
  unit_price_cents INTEGER NOT NULL,
  line_total_cents INTEGER NOT NULL,
  FOREIGN KEY(order_id) REFERENCES orders(id),
  FOREIGN KEY(product_id) REFERENCES products(id)
);
''');
  }

  Future<void> _seedDefaults(Database db) async {
    // ✅ Seed 10 tables vetëm nëse s’ka asnjë
    final tCountRows = await db.rawQuery('SELECT COUNT(*) AS c FROM dining_tables');
    final tCount = (tCountRows.first['c'] as int?) ?? 0;

    if (tCount == 0) {
      final now = DateTime.now().millisecondsSinceEpoch;
      for (int i = 1; i <= 10; i++) {
        await db.insert('dining_tables', {
          'name': 'Tavolina $i',
          'is_active': 1,
          'created_at': now,
        });
      }
    }

    // ✅ Seed categories nëse mungojnë
    Future<void> ensureCategory(String name, int sortIndex) async {
      final rows = await db.query('categories', where: 'name=?', whereArgs: [name], limit: 1);
      if (rows.isNotEmpty) return;
      await db.insert('categories', {'name': name, 'sort_index': sortIndex});
    }

    await ensureCategory('Pije', 1);
    await ensureCategory('Ushqim', 2);
  }
}

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const int kDbVersion = 5; // ✅ rrite versionin (ishte 4)

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
          // ✅ MIGRATIONS
          if (oldV < 4) {
            // Add status column to dining_tables if it doesn't exist
            try {
              await db.execute(
                "ALTER TABLE dining_tables ADD COLUMN status TEXT NOT NULL DEFAULT 'free'",
              );
            } catch (_) {}
          }

          if (oldV < 5) {
            // ✅ Add note column to order_items if it doesn't exist
            try {
              await db.execute("ALTER TABLE order_items ADD COLUMN note TEXT");
            } catch (_) {}
          }

          // Ensure all tables exist
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
  status TEXT NOT NULL DEFAULT 'free', -- free/open/paid
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
  note TEXT,
  FOREIGN KEY(order_id) REFERENCES orders(id),
  FOREIGN KEY(product_id) REFERENCES products(id)
);
''');

    // PAYMENTS
    await db.execute('''
CREATE TABLE IF NOT EXISTS payments(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  table_id INTEGER NOT NULL,
  total_cents INTEGER NOT NULL,
  method TEXT NOT NULL, -- cash/card/mixed
  paid_at INTEGER NOT NULL,
  paid_by INTEGER NOT NULL,
  FOREIGN KEY(table_id) REFERENCES dining_tables(id),
  FOREIGN KEY(paid_by) REFERENCES users(id)
);
''');

    // DAY SESSIONS
    await db.execute('''
CREATE TABLE IF NOT EXISTS day_sessions(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  date TEXT NOT NULL UNIQUE, -- YYYY-MM-DD
  opening_cash_cents INTEGER NOT NULL DEFAULT 0,
  cash_sales_cents INTEGER NOT NULL DEFAULT 0,
  card_sales_cents INTEGER NOT NULL DEFAULT 0,
  discounts_cents INTEGER NOT NULL DEFAULT 0,
  refunds_cents INTEGER NOT NULL DEFAULT 0,
  expected_cash_cents INTEGER NOT NULL DEFAULT 0,
  actual_cash_cents INTEGER,
  difference_cents INTEGER,
  notes TEXT,
  settled_by INTEGER,
  settled_at INTEGER,
  FOREIGN KEY(settled_by) REFERENCES users(id)
);
''');
  }

  Future<void> _seedDefaults(Database db) async {
    // ✅ Seed 10 tables vetëm nëse s’ka asnjë
    final tCountRows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM dining_tables',
    );
    final tCount = (tCountRows.first['c'] as int?) ?? 0;

    if (tCount == 0) {
      final now = DateTime.now().millisecondsSinceEpoch;
      for (int i = 1; i <= 10; i++) {
        await db.insert('dining_tables', {
          'name': 'Tavolina $i',
          'status': 'free',
          'is_active': 1,
          'created_at': now,
        });
      }
    }

    // ✅ Seed categories and products
    await _seedBasicData(db);
  }

  Future<void> _seedBasicData(Database db) async {
    // Seed basic categories
    final categories = [
      {'name': 'Pije', 'sort_index': 1},
      {'name': 'Ushqim', 'sort_index': 2},
      {'name': 'Kafe', 'sort_index': 3},
    ];

    for (final cat in categories) {
      final existing = await db.query(
        'categories',
        where: 'name=?',
        whereArgs: [cat['name']],
        limit: 1,
      );
      if (existing.isEmpty) {
        await db.insert('categories', cat);
      }
    }

    // Seed a few basic products
    final products = [
      {'name': 'Coca Cola', 'price_cents': 150, 'category_name': 'Pije'},
      {
        'name': 'Pizza Margherita',
        'price_cents': 800,
        'category_name': 'Ushqim',
      },
      {'name': 'Espresso', 'price_cents': 120, 'category_name': 'Kafe'},
    ];

    for (final prod in products) {
      final catRows = await db.query(
        'categories',
        where: 'name=?',
        whereArgs: [prod['category_name']],
        limit: 1,
      );
      if (catRows.isNotEmpty) {
        final catId = catRows.first['id'] as int;
        final existing = await db.query(
          'products',
          where: 'name=?',
          whereArgs: [prod['name']],
          limit: 1,
        );
        if (existing.isEmpty) {
          await db.insert('products', {
            'name': prod['name'],
            'price_cents': prod['price_cents'],
            'category_id': catId,
            'is_active': 1,
            'created_at': DateTime.now().millisecondsSinceEpoch,
          });
        }
      }
    }
  }
}

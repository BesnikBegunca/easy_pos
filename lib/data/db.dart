import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const int kDbVersion = 15; // audit_logs

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
          if (oldV < 4) {
            try {
              await db.execute(
                "ALTER TABLE dining_tables ADD COLUMN status TEXT NOT NULL DEFAULT 'free'",
              );
            } catch (_) {}
          }

          if (oldV < 5) {
            try {
              await db.execute("ALTER TABLE order_items ADD COLUMN note TEXT");
            } catch (_) {}
          }

          if (oldV < 6) {
            try {
              await db.execute(
                "ALTER TABLE users ADD COLUMN on_shift INTEGER NOT NULL DEFAULT 0",
              );
            } catch (_) {}

            try {
              await db.execute(
                "ALTER TABLE users ADD COLUMN shift_started_at INTEGER",
              );
            } catch (_) {}

            try {
              await db.execute('''
CREATE TABLE IF NOT EXISTS settlements(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  waiter_id INTEGER NOT NULL,
  total_cents INTEGER NOT NULL,
  cash_cents INTEGER NOT NULL,
  card_cents INTEGER NOT NULL,
  expected_cash_cents INTEGER NOT NULL,
  difference_cents INTEGER NOT NULL,
  start_ms INTEGER NOT NULL,
  end_ms INTEGER NOT NULL,
  notes TEXT,
  settled_by INTEGER NOT NULL,
  settled_at INTEGER NOT NULL,
  FOREIGN KEY(waiter_id) REFERENCES users(id),
  FOREIGN KEY(settled_by) REFERENCES users(id)
);
''');
            } catch (_) {}
          }

          if (oldV < 8) {
            try {
              await db.execute(
                "ALTER TABLE orders ADD COLUMN settled_id INTEGER",
              );
            } catch (_) {}

            try {
              await db.execute(
                "ALTER TABLE dining_tables ADD COLUMN waiter_id INTEGER",
              );
            } catch (_) {}
          }

          if (oldV < 9) {
            try {
              await db.execute(
                "ALTER TABLE payments ADD COLUMN order_id INTEGER",
              );
            } catch (_) {}
          }

          if (oldV < 11) {
            try {
              await db.execute('''
CREATE TABLE IF NOT EXISTS printed_sales(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  waiter_id INTEGER NOT NULL,
  order_id INTEGER NOT NULL,
  table_id INTEGER NOT NULL,
  amount_cents INTEGER NOT NULL DEFAULT 0,
  printed_at INTEGER NOT NULL,
  settled_id INTEGER,
  FOREIGN KEY(waiter_id) REFERENCES users(id),
  FOREIGN KEY(order_id) REFERENCES orders(id),
  FOREIGN KEY(table_id) REFERENCES dining_tables(id),
  FOREIGN KEY(settled_id) REFERENCES settlements(id)
);
''');
            } catch (_) {}
          }

          if (oldV < 12) {
            try {
              await db.execute(
                'ALTER TABLE settlements ADD COLUMN premium_cents INTEGER NOT NULL DEFAULT 0',
              );
            } catch (_) {}
          }

          if (oldV < 13) {
            try {
              await db.execute(
                'ALTER TABLE dining_tables ADD COLUMN owner_id INTEGER',
              );
            } catch (_) {}
          }

          if (oldV < 14) {
            try {
              await db.execute('''
CREATE TABLE IF NOT EXISTS app_settings(
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
);
''');
            } catch (_) {}
          }

          if (oldV < 15) {
            try {
              await db.execute('''
CREATE TABLE IF NOT EXISTS audit_logs(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  action TEXT NOT NULL,
  user_id INTEGER NOT NULL,
  target_id INTEGER,
  before_data TEXT NOT NULL,
  after_data TEXT NOT NULL,
  timestamp INTEGER NOT NULL,
  ip TEXT,
  FOREIGN KEY(user_id) REFERENCES users(id)
);
''');
            } catch (_) {}
          }

          await _createAll(db);
          await _seedDefaults(db);
        },
        onOpen: (db) async {
          await _ensureTableColumns(db);
        },
      ),
    );

    return _db!;
  }

  Future<void> _createAll(Database db) async {
    await db.execute('''
CREATE TABLE IF NOT EXISTS users(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  username TEXT NOT NULL UNIQUE,
  pass_hash TEXT NOT NULL,
  role TEXT NOT NULL, -- developer/superAdmin/admin/manager/waiter
  full_name TEXT,
  is_active INTEGER NOT NULL DEFAULT 1,
  on_shift INTEGER NOT NULL DEFAULT 0,
  shift_started_at INTEGER,
  created_at INTEGER NOT NULL
);
''');

    await db.execute('''
CREATE TABLE IF NOT EXISTS sales(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  waiter_id INTEGER NOT NULL,
  total_cents INTEGER NOT NULL,
  created_at INTEGER NOT NULL,
  FOREIGN KEY(waiter_id) REFERENCES users(id)
);
''');

    await db.execute('''
CREATE TABLE IF NOT EXISTS dining_tables(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'free', -- free/open/paid
  waiter_id INTEGER,
  owner_id INTEGER,
  is_active INTEGER NOT NULL DEFAULT 1,
  created_at INTEGER NOT NULL
);
''');

    await db.execute('''
CREATE TABLE IF NOT EXISTS categories(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL UNIQUE,
  sort_index INTEGER NOT NULL DEFAULT 0
);
''');

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

    await db.execute('''
CREATE TABLE IF NOT EXISTS orders(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  table_id INTEGER NOT NULL,
  waiter_id INTEGER NOT NULL,
  status TEXT NOT NULL, -- open/paid/cancelled
  total_cents INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL,
  closed_at INTEGER,
  settled_id INTEGER,
  FOREIGN KEY(table_id) REFERENCES dining_tables(id),
  FOREIGN KEY(waiter_id) REFERENCES users(id)
);
''');

    await db.execute('''
CREATE TABLE IF NOT EXISTS order_items(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  order_id INTEGER NOT NULL,
  product_id INTEGER NOT NULL,
  qty INTEGER NOT NULL,
  unit_price_cents INTEGER NOT NULL,
  line_total_cents INTEGER NOT NULL,
  note TEXT,
  is_printed INTEGER NOT NULL DEFAULT 0,
  FOREIGN KEY(order_id) REFERENCES orders(id),
  FOREIGN KEY(product_id) REFERENCES products(id)
);
''');

    await db.execute('''
CREATE TABLE IF NOT EXISTS payments(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  table_id INTEGER NOT NULL,
  order_id INTEGER,
  total_cents INTEGER NOT NULL,
  method TEXT NOT NULL, -- cash/card/mixed
  paid_at INTEGER NOT NULL,
  paid_by INTEGER NOT NULL,
  FOREIGN KEY(table_id) REFERENCES dining_tables(id),
  FOREIGN KEY(order_id) REFERENCES orders(id),
  FOREIGN KEY(paid_by) REFERENCES users(id)
);
''');

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

    await db.execute('''
CREATE TABLE IF NOT EXISTS settlements(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  waiter_id INTEGER NOT NULL,
  total_cents INTEGER NOT NULL,
  cash_cents INTEGER NOT NULL,
  card_cents INTEGER NOT NULL,
  expected_cash_cents INTEGER NOT NULL,
  difference_cents INTEGER NOT NULL,
  premium_cents INTEGER NOT NULL DEFAULT 0,
  start_ms INTEGER NOT NULL,
  end_ms INTEGER NOT NULL,
  notes TEXT,
  settled_by INTEGER NOT NULL,
  settled_at INTEGER NOT NULL,
  FOREIGN KEY(waiter_id) REFERENCES users(id),
  FOREIGN KEY(settled_by) REFERENCES users(id)
);
''');

    await db.execute('''
CREATE TABLE IF NOT EXISTS app_settings(
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
);
''');

    await db.execute('''
CREATE TABLE IF NOT EXISTS printed_sales(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  waiter_id INTEGER NOT NULL,
  order_id INTEGER NOT NULL,
  table_id INTEGER NOT NULL,
  amount_cents INTEGER NOT NULL DEFAULT 0,
  printed_at INTEGER NOT NULL,
  settled_id INTEGER,
  FOREIGN KEY(waiter_id) REFERENCES users(id),
  FOREIGN KEY(order_id) REFERENCES orders(id),
  FOREIGN KEY(table_id) REFERENCES dining_tables(id),
  FOREIGN KEY(settled_id) REFERENCES settlements(id)
);
''');

    await db.execute('''
CREATE TABLE IF NOT EXISTS audit_logs(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  action TEXT NOT NULL,
  user_id INTEGER NOT NULL,
  target_id INTEGER,
  before_data TEXT NOT NULL,
  after_data TEXT NOT NULL,
  timestamp INTEGER NOT NULL,
  ip TEXT,
  FOREIGN KEY(user_id) REFERENCES users(id)
);
''');
  }

  Future<void> _seedDefaults(Database db) async {
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
          'waiter_id': null,
          'is_active': 1,
          'created_at': now,
        });
      }
    }

    await _seedBasicData(db);
  }

  Future<void> _seedBasicData(Database db) async {
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
      if (catRows.isEmpty) continue;

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

  Future<void> _ensureTableColumns(Database db) async {
    final rows = await db.rawQuery('PRAGMA table_info(users)');
    final hasRole = rows.any((r) => r['name'] == 'role');

    if (!hasRole) {
      await db.execute(
        'ALTER TABLE users ADD COLUMN role TEXT NOT NULL DEFAULT "waiter"',
      );
    }
  }

  Future<int> getDatabaseSize() async {
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, 'restaurant_pos.db');
    return await File(dbPath).length();
  }

  Future<void> repairDatabase() async {
    final db = await this.db;
    await db.rawQuery('PRAGMA integrity_check');
    await db.execute('VACUUM');
  }
}

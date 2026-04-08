import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const int kDbVersion = 13;

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
          // MIGRATIONS (safe try/catch)

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

          await _createAll(db);
          await _seedDefaults(db);
        },
        onOpen: (db) async {
          try {
            await _ensureTableColumns(db);
          } catch (e) {
            print('Error ensuring columns on open: $e');
          }
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
  on_shift INTEGER NOT NULL DEFAULT 0,
  shift_started_at INTEGER,
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
  waiter_id INTEGER,
  owner_id INTEGER,
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
  settled_id INTEGER,
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
  is_printed INTEGER NOT NULL DEFAULT 0,
  FOREIGN KEY(order_id) REFERENCES orders(id),
  FOREIGN KEY(product_id) REFERENCES products(id)
);
''');

    // PAYMENTS
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

    // SETTLEMENTS
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

    // PRINTED SALES
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
    // dining_tables.status + waiter_id
    final dt = await db.rawQuery('PRAGMA table_info(dining_tables)');
    final dtCols = dt.map((r) => (r['name'] as String?) ?? '').toList();

    if (!dtCols.contains('status')) {
      try {
        await db.execute(
          "ALTER TABLE dining_tables ADD COLUMN status TEXT NOT NULL DEFAULT 'free'",
        );
        print('Added missing column `status` to dining_tables');
      } catch (e) {
        print('Failed to add `status`: $e');
      }
    }

    if (!dtCols.contains('waiter_id')) {
      try {
        await db.execute(
          "ALTER TABLE dining_tables ADD COLUMN waiter_id INTEGER",
        );
        print('Added missing column `waiter_id` to dining_tables');
      } catch (e) {
        print('Failed to add `waiter_id`: $e');
      }
    }

    if (!dtCols.contains('owner_id')) {
      try {
        await db.execute(
          "ALTER TABLE dining_tables ADD COLUMN owner_id INTEGER",
        );
        print('Added missing column `owner_id` to dining_tables');
      } catch (e) {
        print('Failed to add `owner_id`: $e');
      }
    }

    // order_items.note + is_printed
    final oi = await db.rawQuery('PRAGMA table_info(order_items)');
    final oiCols = oi.map((r) => (r['name'] as String?) ?? '').toList();

    if (!oiCols.contains('note')) {
      try {
        await db.execute('ALTER TABLE order_items ADD COLUMN note TEXT');
        print('Added missing column `note` to order_items');
      } catch (e) {
        print('Failed to add `note`: $e');
      }
    }

    if (!oiCols.contains('is_printed')) {
      try {
        await db.execute(
          'ALTER TABLE order_items ADD COLUMN is_printed INTEGER NOT NULL DEFAULT 0',
        );
        print('Added missing column `is_printed` to order_items');
      } catch (e) {
        print('Failed to add `is_printed`: $e');
      }
    }

    // users.shift_started_at + on_shift
    final uInfo = await db.rawQuery('PRAGMA table_info(users)');
    final uCols = uInfo.map((r) => (r['name'] as String?) ?? '').toList();

    if (!uCols.contains('shift_started_at')) {
      try {
        await db.execute(
          'ALTER TABLE users ADD COLUMN shift_started_at INTEGER',
        );
        print('Added missing column `shift_started_at` to users');
      } catch (e) {
        print('Failed to add `shift_started_at`: $e');
      }
    }

    if (!uCols.contains('on_shift')) {
      try {
        await db.execute(
          'ALTER TABLE users ADD COLUMN on_shift INTEGER NOT NULL DEFAULT 0',
        );
        print('Added missing column `on_shift` to users');
      } catch (e) {
        print('Failed to add `on_shift`: $e');
      }
    }

    // orders.settled_id
    final oInfo = await db.rawQuery('PRAGMA table_info(orders)');
    final oCols = oInfo.map((r) => (r['name'] as String?) ?? '').toList();

    if (!oCols.contains('settled_id')) {
      try {
        await db.execute('ALTER TABLE orders ADD COLUMN settled_id INTEGER');
        print('Added missing column `settled_id` to orders');
      } catch (e) {
        print('Failed to add `settled_id`: $e');
      }
    }

    // payments.order_id
    final pInfo = await db.rawQuery('PRAGMA table_info(payments)');
    final pCols = pInfo.map((r) => (r['name'] as String?) ?? '').toList();

    if (!pCols.contains('order_id')) {
      try {
        await db.execute('ALTER TABLE payments ADD COLUMN order_id INTEGER');
        print('Added missing column `order_id` to payments');
      } catch (e) {
        print('Failed to add `order_id`: $e');
      }
    }

    // settlements.premium_cents
    final sInfo = await db.rawQuery('PRAGMA table_info(settlements)');
    final sCols = sInfo.map((r) => (r['name'] as String?) ?? '').toList();

    if (!sCols.contains('premium_cents')) {
      try {
        await db.execute(
          'ALTER TABLE settlements ADD COLUMN premium_cents INTEGER NOT NULL DEFAULT 0',
        );
        print('Added missing column `premium_cents` to settlements');
      } catch (e) {
        print('Failed to add `premium_cents`: $e');
      }
    }

    // printed_sales table
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
    } catch (e) {
      print('Failed to ensure `printed_sales`: $e');
    }

    final psInfo = await db.rawQuery('PRAGMA table_info(printed_sales)');
    final psCols = psInfo.map((r) => (r['name'] as String?) ?? '').toList();

    if (!psCols.contains('settled_id')) {
      try {
        await db.execute(
          'ALTER TABLE printed_sales ADD COLUMN settled_id INTEGER',
        );
        print('Added missing column `settled_id` to printed_sales');
      } catch (e) {
        print('Failed to add `settled_id` to printed_sales: $e');
      }
    }
  }
}

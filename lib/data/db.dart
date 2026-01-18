import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const int kDbVersion = 1;

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
          await db.execute('''
CREATE TABLE users(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  username TEXT NOT NULL UNIQUE,
  pass_hash TEXT NOT NULL,
  role TEXT NOT NULL, -- admin/manager/waiter
  full_name TEXT,
  is_active INTEGER NOT NULL DEFAULT 1,
  created_at INTEGER NOT NULL
);
''');

          await db.execute('''
CREATE TABLE sales(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  waiter_id INTEGER NOT NULL,
  total_cents INTEGER NOT NULL,
  created_at INTEGER NOT NULL,
  FOREIGN KEY(waiter_id) REFERENCES users(id)
);
''');

          // Seed admin (username: admin, pass: admin123)
          // hash e bëjmë te AuthService, por për seed po vendosim plain placeholder
          // dhe e update-ojmë menjëherë në AuthService.ensureSeed().
        },
      ),
    );

    return _db!;
  }
}

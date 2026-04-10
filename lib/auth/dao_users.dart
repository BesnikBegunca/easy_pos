import 'package:easy_pos/data/db.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../auth/roles.dart';
import '../auth/auth_service.dart';

class AppUserRow {
  final int id;
  final String username;
  final String? fullName;
  final UserRole role;
  final bool isActive;
  final bool isOnShift;
  final int? shiftStartedAt;
  final int createdAt;
  final int dailySalaryCents;

  AppUserRow({
    required this.id,
    required this.username,
    required this.fullName,
    required this.role,
    required this.isActive,
    required this.isOnShift,
    required this.shiftStartedAt,
    required this.createdAt,
    this.dailySalaryCents = 0,
  });
}

class UsersDao {
  UsersDao._();
  static final UsersDao I = UsersDao._();

  Future<List<AppUserRow>> listUsers() async {
    final db = await AppDb.I.db;
    final rows = await db.query(
      'users',
      orderBy: 'is_active DESC, role ASC, username ASC',
    );

    return rows.map<AppUserRow>((u) {
      return AppUserRow(
        id: u['id'] as int,
        username: u['username'] as String,
        fullName: u['full_name'] as String?,
        role: roleFromString(u['role'] as String),
        isActive: (u['is_active'] as int) == 1,
        isOnShift: ((u['on_shift'] as int?) ?? 0) == 1,
        shiftStartedAt: (u['shift_started_at'] as int?),
        createdAt: u['created_at'] as int,
        dailySalaryCents: (u['daily_salary_cents'] as int?) ?? 0,
      );
    }).toList();
  }

  Future<int> createUser({
    required String username,
    required String password,
    required UserRole role,
    String? fullName,
  }) async {
    final db = await AppDb.I.db;
    final uname = username.trim();

    if (uname.isEmpty) throw Exception('Username është i zbrazët.');
    if (password.trim().length < 4)
      throw Exception('Password duhet min 4 karaktere.');

    try {
      final id = await db.insert('users', {
        'username': uname,
        'pass_hash': AuthService.I.hashPassword(password),
        'role': roleToString(role),
        'full_name': fullName?.trim(),
        'is_active': 1,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });
      return id;
    } on DatabaseException catch (e) {
      // username UNIQUE
      if (e.isUniqueConstraintError()) {
        throw Exception('Ky username ekziston. Zgjedh një tjetër.');
      }
      rethrow;
    }
  }

  Future<void> updateUser({
    required int id,
    required UserRole role,
    required bool isActive,
    required bool isOnShift,
    String? fullName,
  }) async {
    final db = await AppDb.I.db;
    await db.update(
      'users',
      {
        'role': roleToString(role),
        'full_name': fullName?.trim(),
        'is_active': isActive ? 1 : 0,
        'on_shift': isOnShift ? 1 : 0,
      },
      where: 'id=?',
      whereArgs: [id],
    );
  }

  Future<void> deleteUser(int id) async {
    final db = await AppDb.I.db;
    await db.delete('users', where: 'id=?', whereArgs: [id]);
  }

  Future<void> setActive(int id, bool active) async {
    final db = await AppDb.I.db;
    await db.update(
      'users',
      {'is_active': active ? 1 : 0},
      where: 'id=?',
      whereArgs: [id],
    );
  }

  Future<void> setShift(int id, bool onShift) async {
    final db = await AppDb.I.db;
    final values = <String, Object?>{
      'on_shift': onShift ? 1 : 0,
      'shift_started_at': onShift
          ? DateTime.now().millisecondsSinceEpoch
          : null,
    };
    await db.update('users', values, where: 'id=?', whereArgs: [id]);
  }

  Future<void> resetPassword(int id, String newPassword) async {
    if (newPassword.trim().length < 4)
      throw Exception('Password duhet min 4 karaktere.');
    await AuthService.I.setPassword(id, newPassword);
  }

  Future<void> resetAllPasswords() async {
    final db = await AppDb.I.db;
    await db.execute('UPDATE users SET pass_hash = ? WHERE id > 0', [
      AuthService.I.hashPassword('1234'),
    ]);
  }

  Future<int> createSuperAdmin(String fullName, String password) async {
    return createUser(
      username: 'superadmin',
      password: password,
      role: UserRole.superAdmin,
      fullName: fullName,
    );
  }

  Future<List<AppUserRow>> listAllUsersFullAccess() async {
    return listUsers();
  }

  Future<void> setDailySalary(int id, int dailySalaryCents) async {
    final db = await AppDb.I.db;
    await db.update(
      'users',
      {'daily_salary_cents': dailySalaryCents},
      where: 'id=?',
      whereArgs: [id],
    );
  }
}

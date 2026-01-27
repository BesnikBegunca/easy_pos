import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../data/db.dart';
import 'roles.dart';

class AuthUser {
  final int id;
  final String username;
  final UserRole role;
  final String? fullName;

  AuthUser({
    required this.id,
    required this.username,
    required this.role,
    this.fullName,
  });
}

class AuthService {
  AuthService._();
  static final AuthService I = AuthService._();

  String _hash(String input) {
    final bytes = utf8.encode(input);
    return sha256.convert(bytes).toString();
  }

  Future<void> ensureSeed() async {
    final db = await AppDb.I.db;
    final res = await db.query(
      'users',
      where: 'username=?',
      whereArgs: ['admin'],
    );
    if (res.isNotEmpty) return;

    await db.insert('users', {
      'username': 'admin',
      'pass_hash': _hash('admin123'),
      'role': 'admin',
      'full_name': 'Administrator',
      'is_active': 1,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<AuthUser?> login(String password) async {
    // Predefined passwords
    const adminPasswords = ['1234'];
    const waiterPasswords = ['1111'];

    UserRole? role;
    String username;
    String? fullName;

    if (adminPasswords.contains(password)) {
      role = UserRole.admin;
      username = 'admin';
      fullName = 'Administrator';
    } else if (waiterPasswords.contains(password)) {
      role = UserRole.waiter;
      username = 'waiter_${waiterPasswords.indexOf(password) + 1}';
      fullName = 'Waiter ${waiterPasswords.indexOf(password) + 1}';
    } else {
      return null; // Invalid password
    }

    // Check if user exists in DB, if not create
    final db = await AppDb.I.db;
    final rows = await db.query(
      'users',
      where: 'username=?',
      whereArgs: [username],
      limit: 1,
    );
    int userId;
    if (rows.isEmpty) {
      userId = await db.insert('users', {
        'username': username,
        'pass_hash': _hash(password),
        'role': roleToString(role),
        'full_name': fullName,
        'is_active': 1,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });
    } else {
      userId = rows.first['id'] as int;
    }

    return AuthUser(
      id: userId,
      username: username,
      role: role,
      fullName: fullName,
    );
  }

  // ✅ përdoret nga Users CRUD
  String hashPassword(String plain) => _hash(plain);

  Future<void> setPassword(int userId, String newPassword) async {
    final db = await AppDb.I.db;
    await db.update(
      'users',
      {'pass_hash': _hash(newPassword)},
      where: 'id=?',
      whereArgs: [userId],
    );
  }
}

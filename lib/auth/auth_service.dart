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
    final db = await AppDb.I.db;

    // First check predefined pins for admin
    if (password == '1234') {
      // Find active admin user
      final adminRows = await db.query(
        'users',
        where: 'role=? AND is_active=1',
        whereArgs: ['admin'],
        limit: 1,
      );
      if (adminRows.isNotEmpty) {
        final row = adminRows.first;
        return AuthUser(
          id: row['id'] as int,
          username: row['username'] as String,
          role: UserRole.admin,
          fullName: row['full_name'] as String?,
        );
      }
    }

    // Check existing users with matching password hash and active
    final hash = _hash(password);
    final rows = await db.query(
      'users',
      where: 'pass_hash=? AND is_active=1',
      whereArgs: [hash],
      limit: 1,
    );

    if (rows.isNotEmpty) {
      final row = rows.first;
      return AuthUser(
        id: row['id'] as int,
        username: row['username'] as String,
        role: roleFromString(row['role'] as String),
        fullName: row['full_name'] as String?,
      );
    }

    return null; // No matching active user found
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

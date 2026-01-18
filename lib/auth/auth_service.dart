import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../data/db.dart';
import 'roles.dart';

class AuthUser {
  final int id;
  final String username;
  final UserRole role;
  final String? fullName;

  AuthUser({required this.id, required this.username, required this.role, this.fullName});
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
    final res = await db.query('users', where: 'username=?', whereArgs: ['admin']);
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

  Future<AuthUser?> login(String username, String password) async {
    final db = await AppDb.I.db;
    final rows = await db.query('users', where: 'username=? AND is_active=1', whereArgs: [username], limit: 1);
    if (rows.isEmpty) return null;

    final u = rows.first;
    final passHash = u['pass_hash'] as String;
    if (passHash != _hash(password)) return null;

    return AuthUser(
      id: u['id'] as int,
      username: u['username'] as String,
      role: roleFromString(u['role'] as String),
      fullName: u['full_name'] as String?,
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

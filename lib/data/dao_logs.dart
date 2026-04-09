import 'dart:convert';
import '../data/db.dart';
import '../auth/session.dart';

class AuditLogRow {
  final int id;
  final String action;
  final int userId;
  final int? targetId;
  final String before;
  final String after;
  final int timestamp;
  final String? ip;

  AuditLogRow({
    required this.id,
    required this.action,
    required this.userId,
    this.targetId,
    required this.before,
    required this.after,
    required this.timestamp,
    this.ip,
  });
}

class LogsDao {
  LogsDao._();
  static final LogsDao I = LogsDao._();

  static Future<void> logAudit({
    required String action,
    int? targetId,
    Map<String, dynamic>? before,
    Map<String, dynamic>? after,
    String? ip,
  }) async {
    final db = await AppDb.I.db;
    final me = Session.I.current;
    if (me == null) return;

    await db.insert('audit_logs', {
      'action': action,
      'user_id': me.id,
      'target_id': targetId,
      'before_data': jsonEncode(before ?? {}),
      'after_data': jsonEncode(after ?? {}),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'ip': ip ?? 'local',
    });
  }

  Future<List<AuditLogRow>> listLogs({
    String? actionFilter,
    int? userIdFilter,
    DateTime? from,
    DateTime? to,
    int limit = 100,
  }) async {
    final db = await AppDb.I.db;
    var where = <String>[];
    var whereArgs = <dynamic>[];

    if (actionFilter != null) {
      where.add('action LIKE ?');
      whereArgs.add('%$actionFilter%');
    }
    if (userIdFilter != null) {
      where.add('user_id = ?');
      whereArgs.add(userIdFilter);
    }
    if (from != null) {
      where.add('timestamp >= ?');
      whereArgs.add(from.millisecondsSinceEpoch);
    }
    if (to != null) {
      where.add('timestamp <= ?');
      whereArgs.add(to.millisecondsSinceEpoch);
    }

    final rows = await db.query(
      'audit_logs',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: whereArgs,
      orderBy: 'timestamp DESC',
      limit: limit,
    );

    return rows
        .map(
          (r) => AuditLogRow(
            id: r['id'] as int,
            action: r['action'] as String,
            userId: r['user_id'] as int,
            targetId: r['target_id'] as int?,
            before: r['before_data'] as String,
            after: r['after_data'] as String,
            timestamp: r['timestamp'] as int,
            ip: r['ip'] as String?,
          ),
        )
        .toList();
  }
}

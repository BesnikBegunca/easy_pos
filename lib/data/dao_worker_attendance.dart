import 'db.dart';

class AttendanceRow {
  final int id;
  final int userId;
  final String workDate; // YYYY-MM-DD
  final bool worked;
  final int advanceCents;
  final String? note;
  final int createdAt;

  const AttendanceRow({
    required this.id,
    required this.userId,
    required this.workDate,
    required this.worked,
    required this.advanceCents,
    this.note,
    required this.createdAt,
  });

  AttendanceRow copyWith({bool? worked, int? advanceCents, String? note}) {
    return AttendanceRow(
      id: id,
      userId: userId,
      workDate: workDate,
      worked: worked ?? this.worked,
      advanceCents: advanceCents ?? this.advanceCents,
      note: note ?? this.note,
      createdAt: createdAt,
    );
  }
}

class WorkerAttendanceDao {
  WorkerAttendanceDao._();
  static final WorkerAttendanceDao I = WorkerAttendanceDao._();

  String _dateKey(int year, int month, int day) =>
      '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';

  Future<List<AttendanceRow>> getMonthAttendance(
    int userId,
    int year,
    int month,
  ) async {
    final db = await AppDb.I.db;
    final prefix =
        '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-';
    final rows = await db.query(
      'worker_attendance',
      where: 'user_id=? AND work_date LIKE ?',
      whereArgs: [userId, '$prefix%'],
      orderBy: 'work_date ASC',
    );
    return rows.map(_fromMap).toList();
  }

  Future<AttendanceRow?> getDay(int userId, String date) async {
    final db = await AppDb.I.db;
    final rows = await db.query(
      'worker_attendance',
      where: 'user_id=? AND work_date=?',
      whereArgs: [userId, date],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _fromMap(rows.first);
  }

  /// Inserts or updates a day record.
  Future<void> upsertDay({
    required int userId,
    required int year,
    required int month,
    required int day,
    required bool worked,
    required int advanceCents,
    String? note,
  }) async {
    final db = await AppDb.I.db;
    final date = _dateKey(year, month, day);
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.rawInsert(
      '''
INSERT INTO worker_attendance(user_id, work_date, worked, advance_cents, note, created_at)
VALUES(?, ?, ?, ?, ?, ?)
ON CONFLICT(user_id, work_date) DO UPDATE SET
  worked=excluded.worked,
  advance_cents=excluded.advance_cents,
  note=excluded.note
''',
      [userId, date, worked ? 1 : 0, advanceCents, note, now],
    );
  }

  /// Returns total worked days and total advances for a worker in a month.
  Future<({int workedDays, int advanceCents})> getMonthSummary(
    int userId,
    int year,
    int month,
  ) async {
    final rows = await getMonthAttendance(userId, year, month);
    final workedDays = rows.where((r) => r.worked).length;
    final advances = rows.fold<int>(0, (sum, r) => sum + r.advanceCents);
    return (workedDays: workedDays, advanceCents: advances);
  }

  /// Returns total worked days and total advances across all time for a worker.
  Future<({int workedDays, int advanceCents})> getAllTimeSummary(
    int userId,
  ) async {
    final db = await AppDb.I.db;
    final rows = await db.query(
      'worker_attendance',
      where: 'user_id=?',
      whereArgs: [userId],
    );
    final workedDays =
        rows.where((r) => (r['worked'] as int) == 1).length;
    final advances = rows.fold<int>(
      0,
      (sum, r) => sum + ((r['advance_cents'] as int?) ?? 0),
    );
    return (workedDays: workedDays, advanceCents: advances);
  }

  AttendanceRow _fromMap(Map<String, dynamic> m) {
    return AttendanceRow(
      id: m['id'] as int,
      userId: m['user_id'] as int,
      workDate: m['work_date'] as String,
      worked: (m['worked'] as int) == 1,
      advanceCents: (m['advance_cents'] as int?) ?? 0,
      note: m['note'] as String?,
      createdAt: m['created_at'] as int,
    );
  }
}

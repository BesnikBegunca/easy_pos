import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../data/db.dart';

class LicenseService {
  LicenseService._();
  static final LicenseService I = LicenseService._();

  static const _activationKey = 'license_activation';
  static const _expirationKey = 'license_expiration';
  static const _developerUnlockKey = '123';

  bool _initialized = false;
  bool _developerAccessGranted = false;
  DateTime? _activationDate;
  DateTime? _expirationDate;

  bool get isExpired =>
      _expirationDate != null && DateTime.now().isAfter(_expirationDate!);

  bool get developerAccessGranted => _developerAccessGranted;

  DateTime? get activationDate => _activationDate;
  DateTime? get expirationDate => _expirationDate;

  Future<void> init() async {
    if (_initialized) return;
    final db = await AppDb.I.db;
    _activationDate = await _loadDate(db, _activationKey);
    _expirationDate = await _loadDate(db, _expirationKey);

    if (_activationDate == null || _expirationDate == null) {
      final now = DateTime.now();
      _activationDate = now;
      _expirationDate = _addOneYear(now);
      await _saveDate(db, _activationKey, _activationDate!);
      await _saveDate(db, _expirationKey, _expirationDate!);
    }

    _initialized = true;
  }

  Future<bool> validateDeveloperKey(String key) async {
    await init();
    if (key.trim() == _developerUnlockKey) {
      _developerAccessGranted = true;
      return true;
    }
    return false;
  }

  void revokeDeveloperAccess() {
    _developerAccessGranted = false;
  }

  Future<void> extendOneYear() async {
    await init();
    final now = DateTime.now();
    final base = _expirationDate == null || _expirationDate!.isBefore(now)
        ? now
        : _expirationDate!;
    _expirationDate = _addOneYear(base);
    final db = await AppDb.I.db;
    await _saveDate(db, _expirationKey, _expirationDate!);
  }

  Future<void> setExpirationFromNow(Duration duration) async {
    await init();
    _expirationDate = DateTime.now().add(duration);
    final db = await AppDb.I.db;
    await _saveDate(db, _expirationKey, _expirationDate!);
  }

  Future<void> setExpirationInMonths(int months) async {
    await init();
    _expirationDate = _addMonths(DateTime.now(), months);
    final db = await AppDb.I.db;
    await _saveDate(db, _expirationKey, _expirationDate!);
  }

  DateTime _addOneYear(DateTime from) {
    return _addMonths(from, 12);
  }

  DateTime _addMonths(DateTime from, int months) {
    final year = from.year + ((from.month - 1 + months) ~/ 12);
    final month = ((from.month - 1 + months) % 12) + 1;
    final day = from.day;
    final maxDay = DateTime(year, month + 1, 0).day;
    return DateTime(
      year,
      month,
      day > maxDay ? maxDay : day,
      from.hour,
      from.minute,
      from.second,
      from.millisecond,
      from.microsecond,
    );
  }

  Future<DateTime?> _loadDate(Database db, String key) async {
    final rows = await db.query(
      'app_settings',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final value = rows.first['value'] as String?;
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }

  Future<void> _saveDate(Database db, String key, DateTime date) async {
    await db.insert('app_settings', {
      'key': key,
      'value': date.toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}

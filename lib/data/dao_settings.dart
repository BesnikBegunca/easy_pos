import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'db.dart';

class SettingsDao {
  SettingsDao._();
  static final SettingsDao I = SettingsDao._();

  // ── Display ───────────────────────────────────────────────────────────────
  static const String tableGridColumns = 'table_grid_columns';
  static const String productGridColumns = 'product_grid_columns';
  static const int defaultTableColumns = 7;
  static const int defaultProductColumns = 5;

  // ── Printer ───────────────────────────────────────────────────────────────
  static const String printerIp = 'printer_ip';
  static const String printerPort = 'printer_port';
  static const String printerType = 'printer_type'; // pos80 / a4
  static const int defaultPrinterPort = 9100;
  static const String defaultPrinterType = 'pos80';

  // ── Business ──────────────────────────────────────────────────────────────
  static const String businessName = 'business_name';
  static const String businessAddress = 'business_address';
  static const String businessPhone = 'business_phone';
  static const String businessFiscal = 'business_fiscal';
  static const String businessCurrency = 'business_currency';
  static const String businessLanguage = 'business_language';
  static const String defaultBusinessCurrency = 'EUR';
  static const String defaultBusinessLanguage = 'sq';

  // ── Receipt / Print ───────────────────────────────────────────────────────
  static const String receiptShowLogo = 'receipt_show_logo';
  static const String receiptShowVat = 'receipt_show_vat';
  static const String receiptShowCashier = 'receipt_show_cashier';
  static const String receiptShowDatetime = 'receipt_show_datetime';
  static const String receiptFooter = 'receipt_footer';
  static const String receiptAutoPrint = 'receipt_auto_print';

  // ── Business Mode ─────────────────────────────────────────────────────────
  static const String businessMode = 'business_mode'; // restaurant / market
  static const String featTables = 'feat_tables';
  static const String featWaiters = 'feat_waiters';
  static const String featTableTransfer = 'feat_table_transfer';
  static const String featSplitBill = 'feat_split_bill';
  static const String defaultBusinessMode = 'restaurant';

  // ── Tax & Payment ─────────────────────────────────────────────────────────
  static const String vatEnabled = 'vat_enabled';
  static const String vatPercent = 'vat_percent';
  static const String payMethodCash = 'pay_method_cash';
  static const String payMethodCard = 'pay_method_card';
  static const String payMethodBank = 'pay_method_bank';
  static const String payDefaultMethod = 'pay_default_method';
  static const int defaultVatPercent = 18;
  static const String defaultPayDefaultMethod = 'cash';

  // ── System ────────────────────────────────────────────────────────────────
  static const String autoLogoutMinutes = 'auto_logout_minutes';
  static const String zReportEnabled = 'z_report_enabled';
  static const String dailyResetEnabled = 'daily_reset_enabled';
  static const int defaultAutoLogoutMinutes = 0;

  // ── Permissions ───────────────────────────────────────────────────────────
  static const String permDeleteOrders = 'perm_delete_orders';
  static const String permDiscount = 'perm_discount';
  static const String permReports = 'perm_reports';
  static const String permTableTransfer = 'perm_table_transfer';
  static const String permSplitBill = 'perm_split_bill';

  // ── CRUD ──────────────────────────────────────────────────────────────────
  Future<String> getString(String key, String defaultValue) async {
    final db = await AppDb.I.db;
    try {
      final rows = await db.query(
        'app_settings',
        where: 'key=?',
        whereArgs: [key],
        limit: 1,
      );
      if (rows.isEmpty) return defaultValue;
      return (rows.first['value'] as String?) ?? defaultValue;
    } catch (_) {
      return defaultValue;
    }
  }

  Future<void> setString(String key, String value) async {
    final db = await AppDb.I.db;
    await db.insert(
      'app_settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> getInt(String key, int defaultValue) async {
    final db = await AppDb.I.db;
    try {
      final rows = await db.query(
        'app_settings',
        where: 'key=?',
        whereArgs: [key],
        limit: 1,
      );
      if (rows.isEmpty) return defaultValue;
      return int.tryParse(rows.first['value'] as String? ?? '') ?? defaultValue;
    } catch (_) {
      return defaultValue;
    }
  }

  Future<void> setInt(String key, int value) async {
    final db = await AppDb.I.db;
    await db.insert(
      'app_settings',
      {'key': key, 'value': value.toString()},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<bool> getBool(String key, bool defaultValue) async {
    return (await getInt(key, defaultValue ? 1 : 0)) == 1;
  }

  Future<void> setBool(String key, bool value) async {
    await setInt(key, value ? 1 : 0);
  }
}

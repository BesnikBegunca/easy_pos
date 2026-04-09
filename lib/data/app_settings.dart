import 'dao_settings.dart';

/// Runtime singleton — caches all settings in memory after [load].
/// Call [load] once at app startup (and after any settings save).
/// All other screens read from this object synchronously.
class AppSettings {
  AppSettings._();
  static final AppSettings I = AppSettings._();

  // ── Business ────────────────────────────────────────────────────────────────
  String businessName = '';
  String businessAddress = '';
  String currency = 'EUR';
  String language = 'sq';

  // ── Business mode ────────────────────────────────────────────────────────────
  String businessMode = 'restaurant';
  bool featTables = true;
  bool featWaiters = true;
  bool featTableTransfer = false;
  bool featSplitBill = false;

  // ── VAT ──────────────────────────────────────────────────────────────────────
  bool vatEnabled = true;
  int vatPercent = 18;

  // ── Payment methods ──────────────────────────────────────────────────────────
  bool payMethodCash = true;
  bool payMethodCard = true;
  bool payMethodBank = false;
  String payDefaultMethod = 'cash';

  // ── Printer / Receipt ────────────────────────────────────────────────────────
  String printerType = 'pos80';
  bool receiptAutoPrint = false;
  bool receiptShowLogo = false;
  bool receiptShowVat = true;
  bool receiptShowCashier = true;
  bool receiptShowDatetime = true;
  String receiptFooter = '';

  // ── System ───────────────────────────────────────────────────────────────────
  int autoLogoutMinutes = 0;
  bool zReportEnabled = true;

  // ── Permissions ──────────────────────────────────────────────────────────────
  bool permDeleteOrders = true;
  bool permDiscount = true;
  bool permReports = true;
  bool permTableTransfer = true;
  bool permSplitBill = true;

  // ── Display ──────────────────────────────────────────────────────────────────
  int tableColumns = 7;
  int productColumns = 5;

  // ── Loader ───────────────────────────────────────────────────────────────────

  Future<void> load() async {
    final d = SettingsDao.I;

    businessName = await d.getString(SettingsDao.businessName, '');
    businessAddress = await d.getString(SettingsDao.businessAddress, '');
    currency = await d.getString(
        SettingsDao.businessCurrency, SettingsDao.defaultBusinessCurrency);
    language = await d.getString(
        SettingsDao.businessLanguage, SettingsDao.defaultBusinessLanguage);

    businessMode = await d.getString(
        SettingsDao.businessMode, SettingsDao.defaultBusinessMode);
    featTables = await d.getBool(SettingsDao.featTables, true);
    featWaiters = await d.getBool(SettingsDao.featWaiters, true);
    featTableTransfer = await d.getBool(SettingsDao.featTableTransfer, false);
    featSplitBill = await d.getBool(SettingsDao.featSplitBill, false);

    vatEnabled = await d.getBool(SettingsDao.vatEnabled, true);
    vatPercent =
        await d.getInt(SettingsDao.vatPercent, SettingsDao.defaultVatPercent);

    payMethodCash = await d.getBool(SettingsDao.payMethodCash, true);
    payMethodCard = await d.getBool(SettingsDao.payMethodCard, true);
    payMethodBank = await d.getBool(SettingsDao.payMethodBank, false);
    payDefaultMethod = await d.getString(
        SettingsDao.payDefaultMethod, SettingsDao.defaultPayDefaultMethod);

    printerType = await d.getString(
        SettingsDao.printerType, SettingsDao.defaultPrinterType);
    receiptAutoPrint = await d.getBool(SettingsDao.receiptAutoPrint, false);
    receiptShowLogo = await d.getBool(SettingsDao.receiptShowLogo, false);
    receiptShowVat = await d.getBool(SettingsDao.receiptShowVat, true);
    receiptShowCashier = await d.getBool(SettingsDao.receiptShowCashier, true);
    receiptShowDatetime =
        await d.getBool(SettingsDao.receiptShowDatetime, true);
    receiptFooter = await d.getString(SettingsDao.receiptFooter, '');

    autoLogoutMinutes = await d.getInt(
        SettingsDao.autoLogoutMinutes, SettingsDao.defaultAutoLogoutMinutes);
    zReportEnabled = await d.getBool(SettingsDao.zReportEnabled, true);

    permDeleteOrders = await d.getBool(SettingsDao.permDeleteOrders, true);
    permDiscount = await d.getBool(SettingsDao.permDiscount, true);
    permReports = await d.getBool(SettingsDao.permReports, true);
    permTableTransfer = await d.getBool(SettingsDao.permTableTransfer, true);
    permSplitBill = await d.getBool(SettingsDao.permSplitBill, true);

    tableColumns = await d.getInt(
        SettingsDao.tableGridColumns, SettingsDao.defaultTableColumns);
    productColumns = await d.getInt(
        SettingsDao.productGridColumns, SettingsDao.defaultProductColumns);
  }

  // ── VAT helpers ──────────────────────────────────────────────────────────────

  /// VAT amount extracted from a VAT-inclusive total.
  /// Most POS systems work with inclusive pricing (VAT already in price).
  int vatFromInclusive(int totalCents) {
    if (!vatEnabled || vatPercent == 0) return 0;
    return (totalCents * vatPercent / (100 + vatPercent)).round();
  }

  /// Net (ex-VAT) amount from a VAT-inclusive total.
  int netFromInclusive(int totalCents) {
    return totalCents - vatFromInclusive(totalCents);
  }

  /// Format VAT label for receipts, e.g. "TVSh 18%".
  String get vatLabel => 'TVSh $vatPercent%';
}

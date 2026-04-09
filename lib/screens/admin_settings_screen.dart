import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../data/app_settings.dart';
import '../data/dao_settings.dart';
import '../l10n/app_l10n.dart';
import '../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Section definitions
// ─────────────────────────────────────────────────────────────────────────────
const _kSections = [
  (Icons.storefront_rounded, 'Biznesi', 'Informacionet e kompanisë'),
  (Icons.receipt_long_rounded, 'Printimi', 'Printer dhe fatura'),
  (Icons.restaurant_menu_rounded, 'Mënyra', 'Lloji i biznesit'),
  (Icons.percent_rounded, 'Tatimi', 'TVSh dhe pagesat'),
  (Icons.tune_rounded, 'Sistemi', 'Cilësimet e avancuara'),
  (Icons.shield_rounded, 'Lejet', 'Kontrolli i aksesit'),
  (Icons.grid_view_rounded, 'Ekrani', 'Paraqitja e rrjetës'),
];

// ─────────────────────────────────────────────────────────────────────────────
class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  bool _loading = true;
  bool _saving = false;
  int _section = 0;

  // ── Business ───────────────────────────────────────────────────────────────
  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _fiscalCtrl = TextEditingController();
  String _currency = SettingsDao.defaultBusinessCurrency;
  String _language = SettingsDao.defaultBusinessLanguage;

  // ── Printer / Receipt ──────────────────────────────────────────────────────
  final _ipCtrl = TextEditingController();
  final _portCtrl = TextEditingController();
  final _footerCtrl = TextEditingController();
  String _printerType = SettingsDao.defaultPrinterType;
  bool _receiptShowLogo = false;
  bool _receiptShowVat = true;
  bool _receiptShowCashier = true;
  bool _receiptShowDatetime = true;
  bool _receiptAutoPrint = false;

  // ── Business Mode ──────────────────────────────────────────────────────────
  String _businessMode = SettingsDao.defaultBusinessMode;
  bool _featTables = true;
  bool _featWaiters = true;
  bool _featTableTransfer = false;
  bool _featSplitBill = false;

  // ── Tax & Payment ──────────────────────────────────────────────────────────
  bool _vatEnabled = true;
  int _vatPercent = SettingsDao.defaultVatPercent;
  bool _payMethodCash = true;
  bool _payMethodCard = true;
  bool _payMethodBank = false;
  String _payDefaultMethod = SettingsDao.defaultPayDefaultMethod;

  // ── System ─────────────────────────────────────────────────────────────────
  int _autoLogoutMinutes = SettingsDao.defaultAutoLogoutMinutes;
  bool _zReportEnabled = true;
  bool _dailyResetEnabled = false;

  // ── Permissions ────────────────────────────────────────────────────────────
  bool _permDeleteOrders = true;
  bool _permDiscount = true;
  bool _permReports = true;
  bool _permTableTransfer = true;
  bool _permSplitBill = true;

  // ── Display ────────────────────────────────────────────────────────────────
  int _tableColumns = SettingsDao.defaultTableColumns;
  int _productColumns = SettingsDao.defaultProductColumns;

  // ── Backup ─────────────────────────────────────────────────────────────────
  String? _backupResult;
  bool _restoring = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _fiscalCtrl.dispose();
    _ipCtrl.dispose();
    _portCtrl.dispose();
    _footerCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final d = SettingsDao.I;
    final name = await d.getString(SettingsDao.businessName, '');
    final address = await d.getString(SettingsDao.businessAddress, '');
    final phone = await d.getString(SettingsDao.businessPhone, '');
    final fiscal = await d.getString(SettingsDao.businessFiscal, '');
    final currency = await d.getString(SettingsDao.businessCurrency, SettingsDao.defaultBusinessCurrency);
    final language = await d.getString(SettingsDao.businessLanguage, SettingsDao.defaultBusinessLanguage);

    final ip = await d.getString(SettingsDao.printerIp, '');
    final port = await d.getInt(SettingsDao.printerPort, SettingsDao.defaultPrinterPort);
    final footer = await d.getString(SettingsDao.receiptFooter, '');
    final printerType = await d.getString(SettingsDao.printerType, SettingsDao.defaultPrinterType);
    final showLogo = await d.getBool(SettingsDao.receiptShowLogo, false);
    final showVat = await d.getBool(SettingsDao.receiptShowVat, true);
    final showCashier = await d.getBool(SettingsDao.receiptShowCashier, true);
    final showDatetime = await d.getBool(SettingsDao.receiptShowDatetime, true);
    final autoPrint = await d.getBool(SettingsDao.receiptAutoPrint, false);

    final businessMode = await d.getString(SettingsDao.businessMode, SettingsDao.defaultBusinessMode);
    final featTables = await d.getBool(SettingsDao.featTables, true);
    final featWaiters = await d.getBool(SettingsDao.featWaiters, true);
    final featTableTransfer = await d.getBool(SettingsDao.featTableTransfer, false);
    final featSplitBill = await d.getBool(SettingsDao.featSplitBill, false);

    final vatEnabled = await d.getBool(SettingsDao.vatEnabled, true);
    final vatPercent = await d.getInt(SettingsDao.vatPercent, SettingsDao.defaultVatPercent);
    final payCash = await d.getBool(SettingsDao.payMethodCash, true);
    final payCard = await d.getBool(SettingsDao.payMethodCard, true);
    final payBank = await d.getBool(SettingsDao.payMethodBank, false);
    final payDefault = await d.getString(SettingsDao.payDefaultMethod, SettingsDao.defaultPayDefaultMethod);

    final autoLogout = await d.getInt(SettingsDao.autoLogoutMinutes, SettingsDao.defaultAutoLogoutMinutes);
    final zReport = await d.getBool(SettingsDao.zReportEnabled, true);
    final dailyReset = await d.getBool(SettingsDao.dailyResetEnabled, false);

    final tableColumns = await d.getInt(SettingsDao.tableGridColumns, SettingsDao.defaultTableColumns);
    final productColumns = await d.getInt(SettingsDao.productGridColumns, SettingsDao.defaultProductColumns);

    final permDelete = await d.getBool(SettingsDao.permDeleteOrders, true);
    final permDiscount = await d.getBool(SettingsDao.permDiscount, true);
    final permReports = await d.getBool(SettingsDao.permReports, true);
    final permTableTransfer = await d.getBool(SettingsDao.permTableTransfer, true);
    final permSplitBill = await d.getBool(SettingsDao.permSplitBill, true);

    if (!mounted) return;
    setState(() {
      _nameCtrl.text = name;
      _addressCtrl.text = address;
      _phoneCtrl.text = phone;
      _fiscalCtrl.text = fiscal;
      _currency = currency;
      _language = language;

      _ipCtrl.text = ip;
      _portCtrl.text = port.toString();
      _footerCtrl.text = footer;
      _printerType = printerType;
      _receiptShowLogo = showLogo;
      _receiptShowVat = showVat;
      _receiptShowCashier = showCashier;
      _receiptShowDatetime = showDatetime;
      _receiptAutoPrint = autoPrint;

      _businessMode = businessMode;
      _featTables = featTables;
      _featWaiters = featWaiters;
      _featTableTransfer = featTableTransfer;
      _featSplitBill = featSplitBill;

      _vatEnabled = vatEnabled;
      _vatPercent = vatPercent;
      _payMethodCash = payCash;
      _payMethodCard = payCard;
      _payMethodBank = payBank;
      _payDefaultMethod = payDefault;

      _autoLogoutMinutes = autoLogout;
      _zReportEnabled = zReport;
      _dailyResetEnabled = dailyReset;

      _tableColumns = tableColumns;
      _productColumns = productColumns;

      _permDeleteOrders = permDelete;
      _permDiscount = permDiscount;
      _permReports = permReports;
      _permTableTransfer = permTableTransfer;
      _permSplitBill = permSplitBill;

      _loading = false;
    });
  }

  Future<void> _save() async {
    // Validate required fields
    if (_section == 0 && _nameCtrl.text.trim().isEmpty) {
      _showToast('Emri i biznesit është i detyrueshëm!', isError: true);
      return;
    }
    if (_section == 1) {
      final port = int.tryParse(_portCtrl.text.trim());
      if (_ipCtrl.text.trim().isNotEmpty && (port == null || port < 1 || port > 65535)) {
        _showToast('Porta duhet të jetë numër i vlefshëm (1-65535)!', isError: true);
        return;
      }
    }

    setState(() => _saving = true);
    try {
      final d = SettingsDao.I;
      switch (_section) {
        case 0:
          await d.setString(SettingsDao.businessName, _nameCtrl.text.trim());
          await d.setString(SettingsDao.businessAddress, _addressCtrl.text.trim());
          await d.setString(SettingsDao.businessPhone, _phoneCtrl.text.trim());
          await d.setString(SettingsDao.businessFiscal, _fiscalCtrl.text.trim());
          await d.setString(SettingsDao.businessCurrency, _currency);
          await d.setString(SettingsDao.businessLanguage, _language);
          break;
        case 1:
          await d.setString(SettingsDao.printerIp, _ipCtrl.text.trim());
          await d.setInt(SettingsDao.printerPort, int.tryParse(_portCtrl.text.trim()) ?? SettingsDao.defaultPrinterPort);
          await d.setString(SettingsDao.receiptFooter, _footerCtrl.text.trim());
          await d.setString(SettingsDao.printerType, _printerType);
          await d.setBool(SettingsDao.receiptShowLogo, _receiptShowLogo);
          await d.setBool(SettingsDao.receiptShowVat, _receiptShowVat);
          await d.setBool(SettingsDao.receiptShowCashier, _receiptShowCashier);
          await d.setBool(SettingsDao.receiptShowDatetime, _receiptShowDatetime);
          await d.setBool(SettingsDao.receiptAutoPrint, _receiptAutoPrint);
          break;
        case 2:
          await d.setString(SettingsDao.businessMode, _businessMode);
          await d.setBool(SettingsDao.featTables, _featTables);
          await d.setBool(SettingsDao.featWaiters, _featWaiters);
          await d.setBool(SettingsDao.featTableTransfer, _featTableTransfer);
          await d.setBool(SettingsDao.featSplitBill, _featSplitBill);
          break;
        case 3:
          await d.setBool(SettingsDao.vatEnabled, _vatEnabled);
          await d.setInt(SettingsDao.vatPercent, _vatPercent);
          await d.setBool(SettingsDao.payMethodCash, _payMethodCash);
          await d.setBool(SettingsDao.payMethodCard, _payMethodCard);
          await d.setBool(SettingsDao.payMethodBank, _payMethodBank);
          await d.setString(SettingsDao.payDefaultMethod, _payDefaultMethod);
          break;
        case 4:
          await d.setInt(SettingsDao.autoLogoutMinutes, _autoLogoutMinutes);
          await d.setBool(SettingsDao.zReportEnabled, _zReportEnabled);
          await d.setBool(SettingsDao.dailyResetEnabled, _dailyResetEnabled);
          break;
        case 5:
          await d.setBool(SettingsDao.permDeleteOrders, _permDeleteOrders);
          await d.setBool(SettingsDao.permDiscount, _permDiscount);
          await d.setBool(SettingsDao.permReports, _permReports);
          await d.setBool(SettingsDao.permTableTransfer, _permTableTransfer);
          await d.setBool(SettingsDao.permSplitBill, _permSplitBill);
          break;
        case 6:
          await d.setInt(SettingsDao.tableGridColumns, _tableColumns);
          await d.setInt(SettingsDao.productGridColumns, _productColumns);
          break;
      }
      // Refresh runtime cache so changes take effect immediately.
      await AppSettings.I.load();
      // Sync locale if language was changed.
      AppL10n.I.setLocale(AppSettings.I.language);
      if (!mounted) return;
      _showToast('Cilësimet u ruajtën me sukses!');
    } catch (e) {
      if (!mounted) return;
      _showToast('Gabim gjatë ruajtjes: $e', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showToast(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline_rounded : Icons.check_circle_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? AppTheme.error : AppTheme.success,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Future<void> _backupDatabase() async {
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final sep = Platform.pathSeparator;
      final src = File('${docDir.path}${sep}restaurant_pos.db');
      if (!await src.exists()) {
        _showToast('Baza e të dhënave nuk u gjet!', isError: true);
        return;
      }
      final dateStr = DateFormat('yyyy-MM-dd_HH-mm').format(DateTime.now());
      final dest = File('${docDir.path}${sep}easypos_backup_$dateStr.db');
      await src.copy(dest.path);
      if (!mounted) return;
      setState(() => _backupResult = dest.path);
      _showToast('Backup u krijua me sukses!');
    } catch (e) {
      _showToast('Gabim gjatë backup: $e', isError: true);
    }
  }

  Future<void> _restoreDatabase() async {
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final sep = Platform.pathSeparator;
      // List all backup files sorted newest first.
      final dir = Directory(docDir.path);
      final backups = dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.contains('easypos_backup_') && f.path.endsWith('.db'))
          .toList()
        ..sort((a, b) => b.path.compareTo(a.path));

      if (!mounted) return;

      if (backups.isEmpty) {
        _showToast('Nuk u gjet asnjë backup!', isError: true);
        return;
      }

      final chosen = await showDialog<File>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Zgjedh Backup', style: AppTheme.titleSmall),
          content: SizedBox(
            width: 400,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: backups.length,
              separatorBuilder: (_, __) => Divider(color: AppTheme.border, height: 1),
              itemBuilder: (ctx, i) {
                final name = backups[i].path.split(sep).last;
                return ListTile(
                  leading: const Icon(Icons.restore_rounded, color: AppTheme.info),
                  title: Text(name, style: AppTheme.bodySmall),
                  onTap: () => Navigator.pop(ctx, backups[i]),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Anulo', style: TextStyle(color: AppTheme.textSecondary)),
            ),
          ],
        ),
      );

      if (chosen == null || !mounted) return;

      // Confirm before overwriting
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Konfirmo Rivendosjen', style: AppTheme.titleSmall),
          content: const Text(
            'Të gjitha të dhënat aktuale do të zëvendësohen me backup-in e zgjedhur. Vazhdoni?',
            style: AppTheme.bodyMedium,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Anulo', style: TextStyle(color: AppTheme.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Rivendos'),
            ),
          ],
        ),
      );

      if (ok != true || !mounted) return;
      setState(() => _restoring = true);

      final dest = File('${docDir.path}${sep}restaurant_pos.db');
      await chosen.copy(dest.path);
      if (!mounted) return;
      _showToast('Baza u rivendos me sukses! Rinisni aplikacionin.');
    } catch (e) {
      if (mounted) _showToast('Gabim gjatë rivendosjes: $e', isError: true);
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primary),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth > 620;
        if (wide) {
          return Row(
            children: [
              _buildSectionNav(vertical: true),
              Container(width: 1, color: AppTheme.border),
              Expanded(child: _buildContent()),
            ],
          );
        }
        return Column(
          children: [
            _buildSectionNav(vertical: false),
            Container(height: 1, color: AppTheme.border),
            Expanded(child: _buildContent()),
          ],
        );
      },
    );
  }

  // ── Section navigation ────────────────────────────────────────────────────

  Widget _buildSectionNav({required bool vertical}) {
    if (vertical) {
      return Container(
        width: 186,
        color: AppTheme.surface,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 6, bottom: 10),
              child: Text(
                'CILËSIMET',
                style: AppTheme.caption.copyWith(letterSpacing: 1.2),
              ),
            ),
            ..._kSections.asMap().entries.map((e) {
              return _NavItem(
                icon: e.value.$1,
                label: e.value.$2,
                active: _section == e.key,
                onTap: () => setState(() => _section = e.key),
              );
            }),
          ],
        ),
      );
    }
    // Horizontal compact nav
    return Container(
      color: AppTheme.surface,
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        children: _kSections.asMap().entries.map((e) {
          final active = _section == e.key;
          return GestureDetector(
            onTap: () => setState(() => _section = e.key),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: active
                    ? AppTheme.primary.withValues(alpha: 0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: active
                      ? AppTheme.primary.withValues(alpha: 0.35)
                      : Colors.transparent,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    e.value.$1,
                    size: 15,
                    color: active ? AppTheme.primary : AppTheme.textMuted,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    e.value.$2,
                    style: TextStyle(
                      color: active ? AppTheme.primary : AppTheme.textMuted,
                      fontSize: 12,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Content area ──────────────────────────────────────────────────────────

  Widget _buildContent() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 700),
                child: _buildSectionBody(),
              ),
            ),
          ),
        ),
        _buildSaveBar(),
      ],
    );
  }

  Widget _buildSaveBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            _kSections[_section].$3,
            style: AppTheme.bodySmall.copyWith(color: AppTheme.textMuted),
          ),
          const Spacer(),
          SizedBox(
            width: 160,
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save_rounded, size: 16),
              label: Text(_saving ? 'Duke ruajtur...' : 'Ruaj Ndryshimet'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionBody() {
    switch (_section) {
      case 0:
        return _buildSectionBusiness();
      case 1:
        return _buildSectionReceipt();
      case 2:
        return _buildSectionMode();
      case 3:
        return _buildSectionTax();
      case 4:
        return _buildSectionSystem();
      case 5:
        return _buildSectionPermissions();
      case 6:
        return _buildSectionDisplay();
      default:
        return const SizedBox.shrink();
    }
  }

  // ── Section 0: Business ───────────────────────────────────────────────────

  Widget _buildSectionBusiness() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          icon: Icons.storefront_rounded,
          color: AppTheme.primary,
          title: 'Informacionet e Biznesit',
          subtitle: 'Keto të dhëna shfaqen në fatura dhe raporte',
        ),
        const SizedBox(height: 20),
        _SettingsCard(
          title: 'Identiteti',
          children: [
            _SettingField(
              controller: _nameCtrl,
              label: 'Emri i biznesit *',
              hint: 'p.sh. Bar Restorant Tirana',
              icon: Icons.business_rounded,
              iconColor: AppTheme.primary,
              required: true,
            ),
            const SizedBox(height: 14),
            _SettingField(
              controller: _addressCtrl,
              label: 'Adresa',
              hint: 'Rruga, Qyteti, Kodi Postar',
              icon: Icons.location_on_rounded,
              iconColor: AppTheme.warning,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _SettingField(
                    controller: _phoneCtrl,
                    label: 'Numri i telefonit',
                    hint: '+355 69 ...',
                    icon: Icons.phone_rounded,
                    iconColor: AppTheme.info,
                    keyboardType: TextInputType.phone,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SettingField(
                    controller: _fiscalCtrl,
                    label: 'Nr. Fiskal / NIPT',
                    hint: 'L12345678A',
                    icon: Icons.receipt_rounded,
                    iconColor: AppTheme.orange,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        _SettingsCard(
          title: 'Preferencat',
          children: [
            Row(
              children: [
                Expanded(
                  child: _SettingDropdown<String>(
                    label: 'Monedha',
                    icon: Icons.currency_exchange_rounded,
                    iconColor: AppTheme.success,
                    value: _currency,
                    items: const [
                      DropdownMenuItem(value: 'EUR', child: Text('EUR — Euro')),
                      DropdownMenuItem(value: 'USD', child: Text('USD — Dollar')),
                      DropdownMenuItem(value: 'ALL', child: Text('ALL — Lek')),
                      DropdownMenuItem(value: 'GBP', child: Text('GBP — Pound')),
                      DropdownMenuItem(value: 'CHF', child: Text('CHF — Franc')),
                    ],
                    onChanged: (v) => setState(() => _currency = v!),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SettingDropdown<String>(
                    label: 'Gjuha',
                    icon: Icons.language_rounded,
                    iconColor: AppTheme.info,
                    value: _language,
                    items: const [
                      DropdownMenuItem(value: 'sq', child: Text('Shqip')),
                      DropdownMenuItem(value: 'en', child: Text('English')),
                    ],
                    onChanged: (v) => setState(() => _language = v!),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  // ── Section 1: Receipt / Print ────────────────────────────────────────────

  Widget _buildSectionReceipt() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          icon: Icons.receipt_long_rounded,
          color: AppTheme.info,
          title: 'Printer dhe Fatura',
          subtitle: 'Konfiguro printerit termik dhe përmbajtjen e faturave',
        ),
        const SizedBox(height: 20),
        _SettingsCard(
          title: 'Lidhja me Printerit',
          children: [
            _SettingDropdown<String>(
              label: 'Lloji i printerit',
              icon: Icons.print_rounded,
              iconColor: AppTheme.info,
              value: _printerType,
              items: const [
                DropdownMenuItem(value: 'pos80', child: Text('POS80 — Termik 80mm')),
                DropdownMenuItem(value: 'a4', child: Text('A4 — Lazer / Inkjet')),
              ],
              onChanged: (v) => setState(() => _printerType = v!),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: _SettingField(
                    controller: _ipCtrl,
                    label: 'IP e printerit',
                    hint: '192.168.1.100',
                    icon: Icons.wifi_rounded,
                    iconColor: AppTheme.primary,
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 100,
                  child: _SettingField(
                    controller: _portCtrl,
                    label: 'Port',
                    hint: '9100',
                    icon: Icons.settings_ethernet_rounded,
                    iconColor: AppTheme.textMuted,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        _SettingsCard(
          title: 'Përmbajtja e Faturës',
          children: [
            _SettingToggle(
              icon: Icons.image_rounded,
              iconColor: AppTheme.orange,
              title: 'Shfaq logon',
              subtitle: 'Logo e biznesit në krye të faturës',
              value: _receiptShowLogo,
              onChanged: (v) => setState(() => _receiptShowLogo = v),
            ),
            _SettingToggle(
              icon: Icons.percent_rounded,
              iconColor: AppTheme.warning,
              title: 'Shfaq TVSh',
              subtitle: 'Rreshti i TVSh-së në fundin e faturës',
              value: _receiptShowVat,
              onChanged: (v) => setState(() => _receiptShowVat = v),
            ),
            _SettingToggle(
              icon: Icons.person_rounded,
              iconColor: AppTheme.primary,
              title: 'Shfaq emrin e kamarjerit',
              subtitle: 'Kamarjeri/Kasieri që ka bërë shitjen',
              value: _receiptShowCashier,
              onChanged: (v) => setState(() => _receiptShowCashier = v),
            ),
            _SettingToggle(
              icon: Icons.access_time_rounded,
              iconColor: AppTheme.info,
              title: 'Shfaq datën dhe orën',
              subtitle: 'Timestamp i transaksionit',
              value: _receiptShowDatetime,
              onChanged: (v) => setState(() => _receiptShowDatetime = v),
            ),
            _SettingToggle(
              icon: Icons.print_rounded,
              iconColor: AppTheme.success,
              title: 'Printo automatikisht pas pagesës',
              subtitle: 'Faturat printohen pa konfirmim shtesë',
              value: _receiptAutoPrint,
              onChanged: (v) => setState(() => _receiptAutoPrint = v),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _SettingsCard(
          title: 'Mesazhi i Fundit',
          children: [
            _SettingField(
              controller: _footerCtrl,
              label: 'Teksti në fund të faturës',
              hint: 'p.sh. Faleminderit! Mirë se vini persëri.',
              icon: Icons.format_quote_rounded,
              iconColor: AppTheme.textMuted,
              maxLines: 2,
            ),
          ],
        ),
      ],
    );
  }

  // ── Section 2: Business Mode ──────────────────────────────────────────────

  Widget _buildSectionMode() {
    final isRestaurant = _businessMode == 'restaurant';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          icon: Icons.restaurant_menu_rounded,
          color: AppTheme.orange,
          title: 'Mënyra e Biznesit',
          subtitle: 'Konfiguro llojin e operacionit dhe veçoritë aktive',
        ),
        const SizedBox(height: 20),
        _SettingsCard(
          title: 'Lloji i Biznesit',
          children: [
            _ModeSelector(
              value: _businessMode,
              onChanged: (v) => setState(() => _businessMode = v),
            ),
          ],
        ),
        const SizedBox(height: 16),
        AnimatedOpacity(
          opacity: isRestaurant ? 1.0 : 0.4,
          duration: const Duration(milliseconds: 250),
          child: AbsorbPointer(
            absorbing: !isRestaurant,
            child: _SettingsCard(
              title: 'Veçoritë e Restorantit',
              badge: isRestaurant ? null : 'ÇAKTIVIZUAR',
              children: [
                _SettingToggle(
                  icon: Icons.table_restaurant_rounded,
                  iconColor: AppTheme.primary,
                  title: 'Sistemi i tavolinave',
                  subtitle: 'Menaxhim i tavolinave dhe urdherave aktive',
                  value: _featTables,
                  onChanged: (v) => setState(() => _featTables = v),
                ),
                _SettingToggle(
                  icon: Icons.groups_rounded,
                  iconColor: AppTheme.info,
                  title: 'Llogaritë e kamarjerëve',
                  subtitle: 'Çdo kamarjer hyn me fjalëkalim të vet',
                  value: _featWaiters,
                  onChanged: (v) => setState(() => _featWaiters = v),
                ),
                _SettingToggle(
                  icon: Icons.swap_horiz_rounded,
                  iconColor: AppTheme.warning,
                  title: 'Transferimi i tavolinës',
                  subtitle: 'Lëviz porosinë nga një tavolinë në tjetrën',
                  value: _featTableTransfer,
                  onChanged: (v) => setState(() => _featTableTransfer = v),
                ),
                _SettingToggle(
                  icon: Icons.call_split_rounded,
                  iconColor: AppTheme.orange,
                  title: 'Ndarja e faturës',
                  subtitle: 'Split bill mes klientëve të ndryshëm',
                  value: _featSplitBill,
                  onChanged: (v) => setState(() => _featSplitBill = v),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Section 3: Tax & Payment ──────────────────────────────────────────────

  Widget _buildSectionTax() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          icon: Icons.percent_rounded,
          color: AppTheme.warning,
          title: 'Tatimi dhe Pagesat',
          subtitle: 'Normat e TVSh-së dhe metodat e pranuara të pagesës',
        ),
        const SizedBox(height: 20),
        _SettingsCard(
          title: 'Tatimi mbi Vlerën e Shtuar (TVSh)',
          children: [
            _SettingToggle(
              icon: Icons.account_balance_rounded,
              iconColor: AppTheme.warning,
              title: 'Aktivizo TVSh',
              subtitle: 'Llogarit dhe shfaq TVSh-në në faturat',
              value: _vatEnabled,
              onChanged: (v) => setState(() => _vatEnabled = v),
            ),
            const SizedBox(height: 14),
            AnimatedOpacity(
              opacity: _vatEnabled ? 1.0 : 0.4,
              duration: const Duration(milliseconds: 200),
              child: AbsorbPointer(
                absorbing: !_vatEnabled,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Norma e TVSh-së',
                          style: AppTheme.bodySmall.copyWith(
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                          decoration: BoxDecoration(
                            gradient: AppTheme.warningGrad,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '$_vatPercent%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: _vatPercent.toDouble(),
                      min: 0,
                      max: 25,
                      divisions: 25,
                      activeColor: AppTheme.warning,
                      inactiveColor: AppTheme.warning.withValues(alpha: 0.15),
                      onChanged: (v) => setState(() => _vatPercent = v.round()),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('0%', style: AppTheme.caption),
                        Text('5%', style: AppTheme.caption),
                        Text('10%', style: AppTheme.caption),
                        Text('18%', style: AppTheme.caption),
                        Text('20%', style: AppTheme.caption),
                        Text('25%', style: AppTheme.caption),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _SettingsCard(
          title: 'Metodat e Pagesës',
          children: [
            _SettingToggle(
              icon: Icons.payments_rounded,
              iconColor: AppTheme.success,
              title: 'Cash',
              subtitle: 'Pagesa me para fizike',
              value: _payMethodCash,
              onChanged: (v) => setState(() => _payMethodCash = v),
            ),
            _SettingToggle(
              icon: Icons.credit_card_rounded,
              iconColor: AppTheme.info,
              title: 'Kartë',
              subtitle: 'Debit / Kredit / Kontaktles',
              value: _payMethodCard,
              onChanged: (v) => setState(() => _payMethodCard = v),
            ),
            _SettingToggle(
              icon: Icons.account_balance_rounded,
              iconColor: AppTheme.warning,
              title: 'Transfertë bankare',
              subtitle: 'Pagesa me urdhër pagese ose IBAN',
              value: _payMethodBank,
              onChanged: (v) => setState(() => _payMethodBank = v),
            ),
            const SizedBox(height: 14),
            _SettingDropdown<String>(
              label: 'Metoda e paracaktuar',
              icon: Icons.star_rounded,
              iconColor: AppTheme.orange,
              value: _payDefaultMethod,
              items: [
                if (_payMethodCash)
                  const DropdownMenuItem(value: 'cash', child: Text('Cash')),
                if (_payMethodCard)
                  const DropdownMenuItem(value: 'card', child: Text('Kartë')),
                if (_payMethodBank)
                  const DropdownMenuItem(value: 'bank', child: Text('Transfertë')),
                if (!_payMethodCash && !_payMethodCard && !_payMethodBank)
                  const DropdownMenuItem(value: 'cash', child: Text('(asnjë aktivë)')),
              ],
              onChanged: (v) => setState(() => _payDefaultMethod = v!),
            ),
          ],
        ),
      ],
    );
  }

  // ── Section 4: System ─────────────────────────────────────────────────────

  Widget _buildSectionSystem() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          icon: Icons.tune_rounded,
          color: AppTheme.error,
          title: 'Cilësimet e Sistemit',
          subtitle: 'Opsione të avancuara, backup dhe rivendosje',
        ),
        const SizedBox(height: 20),
        _SettingsCard(
          title: 'Siguria dhe Sesioni',
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.lock_clock_rounded, color: AppTheme.warning, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Dalje automatike',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        _autoLogoutMinutes == 0
                            ? 'E çaktivizuar'
                            : 'Pas $_autoLogoutMinutes minutave inaktiviteti',
                        style: AppTheme.caption,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: AppTheme.warning.withValues(alpha: 0.25)),
                  ),
                  child: Text(
                    _autoLogoutMinutes == 0 ? 'OFF' : '$_autoLogoutMinutes min',
                    style: const TextStyle(
                      color: AppTheme.warning,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            Slider(
              value: _autoLogoutMinutes.toDouble(),
              min: 0,
              max: 60,
              divisions: 12,
              activeColor: AppTheme.warning,
              inactiveColor: AppTheme.warning.withValues(alpha: 0.15),
              onChanged: (v) => setState(() => _autoLogoutMinutes = v.round()),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('OFF', style: AppTheme.caption),
                Text('5 min', style: AppTheme.caption),
                Text('15 min', style: AppTheme.caption),
                Text('30 min', style: AppTheme.caption),
                Text('60 min', style: AppTheme.caption),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        _SettingsCard(
          title: 'Funksionet e Ditës',
          children: [
            _SettingToggle(
              icon: Icons.summarize_rounded,
              iconColor: AppTheme.info,
              title: 'Aktivizo Z Report',
              subtitle: 'Raporti i fundit të ditës me totalet',
              value: _zReportEnabled,
              onChanged: (v) => setState(() => _zReportEnabled = v),
            ),
            _SettingToggle(
              icon: Icons.restart_alt_rounded,
              iconColor: AppTheme.orange,
              title: 'Rivendosja ditore',
              subtitle: 'Rivendos statistikat në mesnatë',
              value: _dailyResetEnabled,
              onChanged: (v) => setState(() => _dailyResetEnabled = v),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _SettingsCard(
          title: 'Backup dhe Rivendosje',
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Baza e të dhënave',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Kopjo bazën e të dhënave si skedar .db',
                        style: AppTheme.caption,
                      ),
                      if (_backupResult != null) ...[
                        const SizedBox(height: 6),
                        GestureDetector(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: _backupResult!));
                            _showToast('Shtigu u kopjua!');
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppTheme.success.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTheme.success.withValues(alpha: 0.25)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 13),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    _backupResult!,
                                    style: const TextStyle(
                                      color: AppTheme.success,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const Icon(Icons.copy_rounded, color: AppTheme.success, size: 12),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _backupDatabase,
                      icon: const Icon(Icons.download_rounded, size: 16),
                      label: const Text('Backup'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.info,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: _restoring ? null : _restoreDatabase,
                      icon: _restoring
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.restore_rounded, size: 16),
                      label: Text(_restoring ? 'Duke rivendosur...' : 'Rivendos'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.warning,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  // ── Section 5: Permissions ────────────────────────────────────────────────

  Widget _buildSectionPermissions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          icon: Icons.shield_rounded,
          color: AppTheme.error,
          title: 'Kontrolli i Aksesit',
          subtitle: 'Lejet e stafit — çfarë mund të bëjnë kamarjerët dhe menaxherët',
        ),
        const SizedBox(height: 20),
        _SettingsCard(
          title: 'Lejet e Stafit',
          children: [
            _SettingToggle(
              icon: Icons.delete_forever_rounded,
              iconColor: AppTheme.error,
              title: 'Fshi artikuj nga porosia',
              subtitle: 'Kamarjerët mund të fshijnë rreshta nga porosia aktive',
              value: _permDeleteOrders,
              onChanged: (v) => setState(() => _permDeleteOrders = v),
            ),
            _SettingToggle(
              icon: Icons.discount_rounded,
              iconColor: AppTheme.warning,
              title: 'Apliko zbritje',
              subtitle: 'Kamarjerët mund të japin zbritje në faturë',
              value: _permDiscount,
              onChanged: (v) => setState(() => _permDiscount = v),
            ),
            _SettingToggle(
              icon: Icons.bar_chart_rounded,
              iconColor: AppTheme.info,
              title: 'Shiko raportet',
              subtitle: 'Menaxherët mund të aksesojnë raportet e shitjeve',
              value: _permReports,
              onChanged: (v) => setState(() => _permReports = v),
            ),
            _SettingToggle(
              icon: Icons.swap_horiz_rounded,
              iconColor: AppTheme.primary,
              title: 'Transfero tavolina',
              subtitle: 'Lëviz porosi nga një tavolinë në tjetrën',
              value: _permTableTransfer,
              onChanged: (v) => setState(() => _permTableTransfer = v),
            ),
            _SettingToggle(
              icon: Icons.call_split_rounded,
              iconColor: AppTheme.orange,
              title: 'Ndaj faturën (Split bill)',
              subtitle: 'Lejon ndarjen e faturës mes klientëve',
              value: _permSplitBill,
              onChanged: (v) => setState(() => _permSplitBill = v),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.warning.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.warning.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline_rounded, color: AppTheme.warning, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Ndryshimet hyjnë në fuqi menjëherë pas ruajtjes. '
                  'Përdoruesit aktualë nuk do të çidentifikohen — '
                  'lejet do të kontrollohen në veprimet e radhës.',
                  style: AppTheme.caption.copyWith(color: AppTheme.warning),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Section 6: Display ────────────────────────────────────────────────────

  Widget _buildSectionDisplay() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          icon: Icons.grid_view_rounded,
          color: AppTheme.primary,
          title: 'Paraqitja e Ekranit',
          subtitle: 'Numri i kolonave në rrjetat e tavolinave dhe produkteve',
        ),
        const SizedBox(height: 20),
        _ColumnSettingCard(
          icon: Icons.table_restaurant_rounded,
          iconColor: AppTheme.primary,
          title: 'Kolonat e tavolinave',
          subtitle: 'Sa tavolina shfaqen në një rresht',
          value: _tableColumns,
          min: 3,
          max: 12,
          onChanged: (v) => setState(() => _tableColumns = v),
        ),
        const SizedBox(height: 16),
        _ColumnSettingCard(
          icon: Icons.local_cafe_rounded,
          iconColor: AppTheme.success,
          title: 'Kolonat e produkteve',
          subtitle: 'Sa produkte shfaqen në një rresht',
          value: _productColumns,
          min: 2,
          max: 8,
          onChanged: (v) => setState(() => _productColumns = v),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Private components
// ─────────────────────────────────────────────────────────────────────────────

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          gradient: active
              ? LinearGradient(
                  colors: [
                    AppTheme.primary.withValues(alpha: 0.18),
                    AppTheme.primary.withValues(alpha: 0.06),
                  ],
                )
              : null,
          borderRadius: BorderRadius.circular(12),
          border: active
              ? Border.all(color: AppTheme.primary.withValues(alpha: 0.30))
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: active
                    ? AppTheme.primary.withValues(alpha: 0.20)
                    : AppTheme.card,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 15,
                color: active ? AppTheme.primary : AppTheme.textMuted,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                color: active ? AppTheme.primary : AppTheme.textSecondary,
                fontSize: 13,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  const _SectionHeader({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withValues(alpha: 0.25), color.withValues(alpha: 0.10)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.30)),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTheme.titleMedium.copyWith(fontWeight: FontWeight.w800),
              ),
              Text(
                subtitle,
                style: AppTheme.bodySmall.copyWith(color: AppTheme.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final String? badge;

  const _SettingsCard({
    required this.title,
    required this.children,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.tile,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
            decoration: BoxDecoration(
              color: AppTheme.cardAlt,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
              border: Border(bottom: BorderSide(color: AppTheme.border)),
            ),
            child: Row(
              children: [
                Text(
                  title,
                  style: AppTheme.labelLarge.copyWith(
                    fontSize: 12,
                    letterSpacing: 0.6,
                    color: AppTheme.textSecondary,
                  ),
                ),
                if (badge != null) ...[
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.error.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppTheme.error.withValues(alpha: 0.25)),
                    ),
                    child: Text(
                      badge!,
                      style: const TextStyle(
                        color: AppTheme.error,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final Color iconColor;
  final TextInputType keyboardType;
  final int maxLines;
  final bool required;
  final List<TextInputFormatter>? inputFormatters;

  const _SettingField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    required this.iconColor,
    this.keyboardType = TextInputType.text,
    this.maxLines = 1,
    this.required = false,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      inputFormatters: inputFormatters,
      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 14, right: 10),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        labelStyle: TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 13,
        ),
        hintStyle: TextStyle(color: AppTheme.textMuted, fontSize: 13),
        filled: true,
        fillColor: AppTheme.card,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.primary, width: 1.4),
        ),
      ),
    );
  }
}

class _SettingDropdown<T> extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color iconColor;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  const _SettingDropdown({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      value: value,
      items: items,
      onChanged: onChanged,
      dropdownColor: AppTheme.card,
      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
      icon: const Icon(Icons.expand_more_rounded, color: AppTheme.textMuted, size: 18),
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 14, right: 10),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        labelStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        filled: true,
        fillColor: AppTheme.card,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.primary, width: 1.4),
        ),
      ),
    );
  }
}

class _SettingToggle extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingToggle({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: value
                  ? iconColor.withValues(alpha: 0.15)
                  : AppTheme.cardAlt,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: value
                    ? iconColor.withValues(alpha: 0.30)
                    : AppTheme.border,
              ),
            ),
            child: Icon(
              icon,
              size: 17,
              color: value ? iconColor : AppTheme.textMuted,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(subtitle, style: AppTheme.caption),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppTheme.primary,
            activeTrackColor: AppTheme.primary.withValues(alpha: 0.30),
            inactiveThumbColor: AppTheme.textMuted,
            inactiveTrackColor: AppTheme.border,
          ),
        ],
      ),
    );
  }
}

class _ModeSelector extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _ModeSelector({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ModeOption(
          icon: Icons.restaurant_rounded,
          label: 'Restorant / Bar',
          description: 'Tavolina, kamarjerë, menyja',
          selected: value == 'restaurant',
          color: AppTheme.primary,
          onTap: () => onChanged('restaurant'),
        ),
        const SizedBox(width: 12),
        _ModeOption(
          icon: Icons.store_rounded,
          label: 'Market / Dyqan',
          description: 'Barkod, kasa, rafte',
          selected: value == 'market',
          color: AppTheme.info,
          onTap: () => onChanged('market'),
        ),
      ],
    );
  }
}

class _ModeOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _ModeOption({
    required this.icon,
    required this.label,
    required this.description,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: selected
                ? LinearGradient(
                    colors: [color.withValues(alpha: 0.18), color.withValues(alpha: 0.06)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: selected ? null : AppTheme.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? color.withValues(alpha: 0.45) : AppTheme.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: selected
                      ? color.withValues(alpha: 0.22)
                      : AppTheme.cardAlt,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: selected ? color : AppTheme.textMuted, size: 20),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: selected ? color : AppTheme.textSecondary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                description,
                textAlign: TextAlign.center,
                style: AppTheme.caption,
              ),
              const SizedBox(height: 8),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: selected ? color : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? color : AppTheme.border,
                    width: 1.5,
                  ),
                ),
                child: selected
                    ? const Icon(Icons.check_rounded, color: Colors.white, size: 11)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ColumnSettingCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  const _ColumnSettingCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.tile,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w700)),
                    Text(subtitle, style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGrad,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: AppTheme.shadowGlowColor(AppTheme.primary, a: 0.25),
                ),
                child: Text(
                  '$value',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text('$min', style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary)),
              Expanded(
                child: Slider(
                  value: value.toDouble(),
                  min: min.toDouble(),
                  max: max.toDouble(),
                  divisions: max - min,
                  activeColor: AppTheme.primary,
                  inactiveColor: AppTheme.primary.withValues(alpha: 0.15),
                  onChanged: (v) => onChanged(v.round()),
                ),
              ),
              Text('$max', style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary)),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(value, (i) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  width: (200 / value).clamp(8, 28).toDouble(),
                  height: (200 / value).clamp(8, 28).toDouble(),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: iconColor.withValues(alpha: 0.40)),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

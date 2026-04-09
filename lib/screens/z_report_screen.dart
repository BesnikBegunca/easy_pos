import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../data/dao_z_report.dart';
import '../data/dao_settings.dart';
import '../util/money.dart';
import '../theme/app_theme.dart';

// ── Receipt constants ─────────────────────────────────────────────────────────
// 80mm thermal printer at default font = 48 chars per line
const int _kWidth = 48;

// ── ESC/POS byte helpers ──────────────────────────────────────────────────────
List<int> _init()     => [0x1B, 0x40];           // ESC @  – initialize
List<int> _center()   => [0x1B, 0x61, 0x01];     // ESC a 1 – center align
List<int> _left()     => [0x1B, 0x61, 0x00];     // ESC a 0 – left align
List<int> _boldOn()   => [0x1B, 0x45, 0x01];     // ESC E 1 – bold on
List<int> _boldOff()  => [0x1B, 0x45, 0x00];     // ESC E 0 – bold off
List<int> _lf()       => [0x0A];                  // line feed
List<int> _cut()      => [0x1D, 0x56, 0x42, 0x00]; // GS V B 0 – partial cut

/// Encode text to bytes (replaces Albanian diacritics for printer compat).
List<int> _bytes(String s) {
  return s
      .replaceAll('ë', 'e')
      .replaceAll('Ë', 'E')
      .replaceAll('ç', 'c')
      .replaceAll('Ç', 'C')
      .codeUnits;
}

/// Right-pad left, left-pad right to fill [width].
String _padLine(String left, String right, {int width = _kWidth}) {
  final gap = width - left.length - right.length;
  return left + (gap > 0 ? ' ' * gap : ' ') + right;
}

String _divider({int width = _kWidth}) => '-' * width;

/// Format cents as receipt-style string, e.g. "120.50 EUR".
String _receiptMoney(int cents) {
  final e = cents ~/ 100;
  final c = (cents % 100).toString().padLeft(2, '0');
  return '$e.${c}EUR';
}

// ── Build ESC/POS byte stream ─────────────────────────────────────────────────
List<int> buildZReportEscPos({
  required DateTime generatedAt,
  required List<ZReportRow> rows,
}) {
  final buf = <int>[];
  void add(List<int> b) => buf.addAll(b);
  void ln([int n = 1]) {
    for (var i = 0; i < n; i++) {
      add(_lf());
    }
  }
  void text(String s) => add(_bytes(s));

  final grandTotal = rows.fold(0, (s, r) => s + r.totalCents);

  final date =
      '${generatedAt.year.toString().padLeft(4, '0')}-'
      '${generatedAt.month.toString().padLeft(2, '0')}-'
      '${generatedAt.day.toString().padLeft(2, '0')}';
  final time =
      '${generatedAt.hour.toString().padLeft(2, '0')}:'
      '${generatedAt.minute.toString().padLeft(2, '0')}';

  add(_init());

  // ── Title block ──────────────────────────────────────────────────────────
  add(_center());
  add(_boldOn());
  text('Z REPORT');
  ln();
  add(_boldOff());
  text('$date  $time');
  ln(2);

  // ── Table header ─────────────────────────────────────────────────────────
  add(_left());
  text(_divider());
  ln();
  text(_padLine('Kamarjer', 'Total'));
  ln();
  text(_divider());
  ln();

  // ── Waiter rows ───────────────────────────────────────────────────────────
  if (rows.isEmpty) {
    add(_center());
    text('Nuk ka shitje sot.');
    ln();
    add(_left());
  } else {
    for (final r in rows) {
      // Truncate long names so they don't overflow the line
      final name = r.name.length > 28 ? '${r.name.substring(0, 27)}.' : r.name;
      text(_padLine(name, _receiptMoney(r.totalCents)));
      ln();
    }
  }

  // ── Grand total ───────────────────────────────────────────────────────────
  text(_divider());
  ln();
  add(_boldOn());
  text(_padLine('TOTAL', _receiptMoney(grandTotal)));
  ln();
  add(_boldOff());

  ln(4);  // feed paper before cut
  add(_cut());

  return buf;
}

// ── TCP print ─────────────────────────────────────────────────────────────────
Future<String?> _printViaTcp(String ip, int port, List<int> bytes) async {
  try {
    final socket = await Socket.connect(
      ip,
      port,
      timeout: const Duration(seconds: 5),
    );
    socket.add(Uint8List.fromList(bytes));
    await socket.flush();
    await socket.close();
    return null; // success
  } on SocketException catch (e) {
    return 'Nuk u lidh me printerin ($ip:$port): ${e.message}';
  } catch (e) {
    return 'Gabim gjatë printimit: $e';
  }
}

// ── Entry point ───────────────────────────────────────────────────────────────
Future<void> showZReportDialog(BuildContext context) {
  return showDialog(
    context: context,
    barrierDismissible: true,
    builder: (_) => const _ZReportDialog(),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// DIALOG
// ══════════════════════════════════════════════════════════════════════════════
class _ZReportDialog extends StatefulWidget {
  const _ZReportDialog();

  @override
  State<_ZReportDialog> createState() => _ZReportDialogState();
}

class _ZReportDialogState extends State<_ZReportDialog> {
  bool _loading = true;
  bool _printing = false;
  List<ZReportRow> _rows = [];
  late DateTime _generatedAt;
  String? _statusMsg;
  bool _statusIsError = false;

  int get _grandTotal => _rows.fold(0, (s, r) => s + r.totalCents);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _statusMsg = null;
    });
    _generatedAt = DateTime.now();
    final rows = await ZReportDao.I.todayByWaiter();
    if (!mounted) return;
    setState(() {
      _rows = rows;
      _loading = false;
    });
  }

  Future<void> _print() async {
    setState(() {
      _printing = true;
      _statusMsg = null;
    });

    final ip = await SettingsDao.I.getString(SettingsDao.printerIp, '');
    final port = await SettingsDao.I.getInt(
      SettingsDao.printerPort,
      SettingsDao.defaultPrinterPort,
    );

    if (ip.trim().isEmpty) {
      setState(() {
        _printing = false;
        _statusIsError = true;
        _statusMsg =
            'IP e printerit nuk është konfiguruar. Shko te Settings → Printer.';
      });
      return;
    }

    final bytes = buildZReportEscPos(
      generatedAt: _generatedAt,
      rows: _rows,
    );

    final err = await _printViaTcp(ip.trim(), port, bytes);
    if (!mounted) return;

    setState(() {
      _printing = false;
      if (err != null) {
        _statusIsError = true;
        _statusMsg = err;
      } else {
        _statusIsError = false;
        _statusMsg = 'Z Report u dërgua tek printeri me sukses.';
      }
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 680),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: AppTheme.radiusLarge,
            border: Border.all(color: AppTheme.border),
            boxShadow: AppTheme.shadowMd,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(56),
                  child: CircularProgressIndicator(color: AppTheme.primary),
                )
              else ...[
                Flexible(child: _buildBody()),
                _buildFooter(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    final date =
        '${_generatedAt.year.toString().padLeft(4, '0')}-'
        '${_generatedAt.month.toString().padLeft(2, '0')}-'
        '${_generatedAt.day.toString().padLeft(2, '0')}';
    final time =
        '${_generatedAt.hour.toString().padLeft(2, '0')}:'
        '${_generatedAt.minute.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.border)),
        gradient: LinearGradient(
          colors: [
            AppTheme.primary.withValues(alpha: 0.07),
            Colors.transparent,
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGrad,
              borderRadius: BorderRadius.circular(12),
              boxShadow: AppTheme.shadowGlowColor(AppTheme.primary, a: 0.28),
            ),
            child: const Icon(
              Icons.summarize_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Z REPORT',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  'Raport Fundi i Ditës  ·  $date  $time',
                  style: AppTheme.caption,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: AppTheme.textMuted),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'Mbyll',
          ),
        ],
      ),
    );
  }

  // ── Body (receipt preview) ────────────────────────────────────────────────
  Widget _buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Receipt card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: AppTheme.borderRadius,
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Column headers
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Kamarjer',
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 52,
                      child: Text(
                        'Porosi',
                        textAlign: TextAlign.center,
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 100,
                      child: Text(
                        'Total',
                        textAlign: TextAlign.right,
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Divider(color: AppTheme.border, height: 1),
                const SizedBox(height: 8),

                // Waiter rows
                if (_rows.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Text(
                      'Nuk ka shitje të regjistruara sot.',
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.textMuted,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  )
                else
                  ..._rows.map((r) => _WaiterRow(row: r)),

                const SizedBox(height: 8),
                const Divider(color: AppTheme.border, height: 1),
                const SizedBox(height: 12),

                // Grand total row
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'TOTAL',
                        style: AppTheme.titleSmall.copyWith(
                          color: AppTheme.primary,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 52),
                    SizedBox(
                      width: 100,
                      child: Text(
                        moneyFromCents(_grandTotal),
                        textAlign: TextAlign.right,
                        style: AppTheme.titleSmall.copyWith(
                          color: AppTheme.primary,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Status message
          if (_statusMsg != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: (_statusIsError ? AppTheme.error : AppTheme.success)
                    .withValues(alpha: 0.10),
                borderRadius: AppTheme.radiusSmall,
                border: Border.all(
                  color: (_statusIsError ? AppTheme.error : AppTheme.success)
                      .withValues(alpha: 0.30),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _statusIsError
                        ? Icons.error_outline_rounded
                        : Icons.check_circle_outline_rounded,
                    color: _statusIsError ? AppTheme.error : AppTheme.success,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _statusMsg!,
                      style: TextStyle(
                        color:
                            _statusIsError ? AppTheme.error : AppTheme.success,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Footer ────────────────────────────────────────────────────────────────
  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: [
          // Refresh
          OutlinedButton.icon(
            onPressed: _printing ? null : _load,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Rifresko'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.textSecondary,
              side: BorderSide(color: AppTheme.border),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
          const SizedBox(width: 12),
          // Print
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _printing || _rows.isEmpty ? null : _print,
              icon: _printing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.print_rounded, size: 16),
              label: Text(_printing ? 'Duke printuar...' : 'Printo Z Report'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                    AppTheme.primary.withValues(alpha: 0.30),
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Waiter row widget ─────────────────────────────────────────────────────────
class _WaiterRow extends StatelessWidget {
  final ZReportRow row;
  const _WaiterRow({required this.row});

  @override
  Widget build(BuildContext context) {
    final active = row.totalCents > 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          // Avatar dot
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              color: active
                  ? AppTheme.primary.withValues(alpha: 0.70)
                  : AppTheme.border,
              shape: BoxShape.circle,
            ),
          ),
          // Name
          Expanded(
            child: Text(
              row.name,
              style: AppTheme.bodyMedium.copyWith(
                color: active ? AppTheme.textPrimary : AppTheme.textMuted,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Order count
          SizedBox(
            width: 52,
            child: Text(
              row.orderCount > 0 ? '${row.orderCount}' : '-',
              textAlign: TextAlign.center,
              style: AppTheme.bodySmall.copyWith(color: AppTheme.textMuted),
            ),
          ),
          // Total
          SizedBox(
            width: 100,
            child: Text(
              active ? moneyFromCents(row.totalCents) : '-',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: active ? AppTheme.primaryLight : AppTheme.textMuted,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

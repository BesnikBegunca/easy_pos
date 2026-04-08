import 'dart:async';

import 'package:flutter/material.dart';
import '../data/dao_tables.dart';
import '../auth/session.dart';
import '../util/money.dart';
import '../theme/app_theme.dart';
import '../theme/app_widgets.dart';
import 'order_screen.dart';

class TablesScreen extends StatefulWidget {
  const TablesScreen({super.key});

  @override
  State<TablesScreen> createState() => _TablesScreenState();
}

class _TablesScreenState extends State<TablesScreen>
    with WidgetsBindingObserver {
  final StreamController<List<FullTableRow>> _tablesController =
      StreamController<List<FullTableRow>>.broadcast();

  Timer? _pollTimer;
  bool _isLoading = false;
  bool _didSeedTables = false;
  String _lastFingerprint = '';

  Stream<List<FullTableRow>> get _stream => _tablesController.stream;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startRealtimeRefresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    _tablesController.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _reloadNow(forceEmit: true);
      _restartPolling();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _pollTimer?.cancel();
    }
  }

  void _startRealtimeRefresh() {
    _reloadNow(forceEmit: true);
    _restartPolling();
  }

  void _restartPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(
      const Duration(milliseconds: 700),
      (_) => _reloadNow(),
    );
  }

  Future<List<FullTableRow>> _loadTables() async {
    final me = Session.I.current!;
    var tables = await TablesDao.I.listTablesWithWaiters(ownerId: me.id);

    if (tables.isEmpty && !_didSeedTables) {
      _didSeedTables = true;
      for (int i = 1; i <= 20; i++) {
        await TablesDao.I.addTable('Tavolina $i', ownerId: me.id);
      }
      tables = await TablesDao.I.listTablesWithWaiters(ownerId: me.id);
    }

    return tables;
  }

  String _buildFingerprint(List<FullTableRow> tables) {
    return tables
        .map(
          (t) =>
              '${t.id}|${t.name}|${t.waiterId}|${t.waiterName}|${t.openTotalCents}',
        )
        .join('||');
  }

  Future<void> _reloadNow({bool forceEmit = false}) async {
    if (_isLoading || _tablesController.isClosed) return;

    _isLoading = true;
    try {
      final tables = await _loadTables();
      final fingerprint = _buildFingerprint(tables);

      if (forceEmit || fingerprint != _lastFingerprint) {
        _lastFingerprint = fingerprint;
        if (!_tablesController.isClosed) {
          _tablesController.add(tables);
        }
      }
    } catch (e, st) {
      if (!_tablesController.isClosed) {
        _tablesController.addError(e, st);
      }
    } finally {
      _isLoading = false;
    }
  }

  Future<void> _refresh() async {
    await _reloadNow(forceEmit: true);
  }

  Future<void> _openTable(FullTableRow t) async {
    final me = Session.I.current!;

    await _reloadNow(forceEmit: true);

    FullTableRow currentTable = t;
    try {
      final latestTables = await _loadTables();
      final found = latestTables.where((x) => x.id == t.id);
      if (found.isNotEmpty) {
        currentTable = found.first;
      }
    } catch (_) {}

    if (currentTable.isOpen &&
        currentTable.waiterId != null &&
        currentTable.waiterId != me.id) {
      await showDialog<void>(
        context: context,
        builder: (_) => _PremiumInfoDialog(
          title: currentTable.name,
          message:
              'Kjo tavolinë është e hapur nga ${currentTable.waiterName ?? "kamarier tjetër"}.',
        ),
      );
      return;
    }

    await Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (ctx, a, sec) => OrderScreen(
          tableId: currentTable.id,
          tableName: currentTable.name,
          waiterId: me.id,
        ),
        transitionsBuilder: (ctx, a, sec, child) => FadeTransition(
          opacity: CurvedAnimation(parent: a, curve: Curves.easeOut),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 250),
      ),
    );

    if (!mounted) return;
    await _reloadNow(forceEmit: true);
  }

  Future<void> _addTableDialog() async {
    final me = Session.I.current!;
    final tables = await TablesDao.I.listTablesWithWaiters(ownerId: me.id);
    if (!mounted) return;

    final nextNum = tables.length + 1;
    final nameC = TextEditingController(text: 'Tavolina $nextNum');

    final ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: AppTheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: AppTheme.radiusLarge,
            ),
            title: Row(
              children: [
                IconBadge(
                  icon: Icons.add_rounded,
                  color: AppTheme.primary,
                  size: 36,
                  iconSize: 18,
                ),
                const SizedBox(width: 12),
                const Text('Shto Tavolinë', style: AppTheme.titleSmall),
              ],
            ),
            content: AppTextField(
              controller: nameC,
              hint: 'Emri i tavolinës',
              prefixIcon: Icons.table_restaurant_rounded,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  'Anulo',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: AppTheme.radiusSmall,
                  ),
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Shto',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ) ??
        false;

    final name = nameC.text.trim();
    nameC.dispose();

    if (!ok || name.isEmpty || !mounted) return;

    await TablesDao.I.addTable(name, ownerId: me.id);
    await _reloadNow(forceEmit: true);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<FullTableRow>>(
      stream: _stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return _buildLoading();
        }

        if (snapshot.hasError && !snapshot.hasData) {
          return _buildError();
        }

        final tables = snapshot.data ?? [];
        final openCount = tables.where((t) => t.openTotalCents > 0).length;
        final totalBilling = tables.fold<int>(
          0,
          (s, t) => s + t.openTotalCents,
        );

        return Column(
          children: [
            _buildStatsBar(tables.length, openCount, totalBilling),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                child: GridView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.05,
                  ),
                  itemCount: tables.length + 1,
                  itemBuilder: (_, i) {
                    if (i == tables.length) {
                      return _AddTableTile(onTap: _addTableDialog);
                    }

                    final table = tables[i];
                    return _PremiumTableCard(
                      key: ValueKey(
                        '${table.id}-${table.isOpen}-${table.waiterId}-${table.openTotalCents}',
                      ),
                      table: table,
                      onTap: () => _openTable(table),
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatsBar(
    int total,
    int open,
    int totalBillingCents,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: [
          _StatChip(
            icon: Icons.table_restaurant_rounded,
            label: 'Total',
            value: '$total',
            color: AppTheme.primary,
          ),
          const SizedBox(width: 8),
          _StatChip(
            icon: Icons.restaurant_rounded,
            label: 'Të hapura',
            value: '$open',
            color: AppTheme.warning,
          ),
          const SizedBox(width: 8),
          _StatChip(
            icon: Icons.event_seat_rounded,
            label: 'Të lira',
            value: '${total - open}',
            color: AppTheme.success,
          ),
          const Spacer(),
          if (totalBillingCents > 0) ...[
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 7,
              ),
              decoration: BoxDecoration(
                gradient: AppTheme.warningGrad,
                borderRadius: BorderRadius.circular(999),
                boxShadow: AppTheme.shadowGlowColor(
                  AppTheme.warning,
                  a: 0.30,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.receipt_rounded,
                    color: Colors.white,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    moneyFromCents(totalBillingCents),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
          ],
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: _refresh,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.card,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.border),
              ),
              child: const Icon(
                Icons.refresh_rounded,
                color: AppTheme.textSecondary,
                size: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Padding(
              padding: EdgeInsets.all(14),
              child: CircularProgressIndicator(
                color: AppTheme.primary,
                strokeWidth: 2.5,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Duke ngarkuar tavolinat…',
            style: AppTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const IconBadge(
            icon: Icons.error_outline_rounded,
            color: AppTheme.error,
            size: 56,
            iconSize: 28,
          ),
          const SizedBox(height: 16),
          const Text(
            'Gabim në ngarkimin e tavolinave',
            style: AppTheme.titleSmall,
          ),
          const SizedBox(height: 20),
          AppPrimaryButton(
            label: 'Provo Përsëri',
            icon: Icons.refresh_rounded,
            onPressed: _refresh,
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            '$value $label',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumTableCard extends StatelessWidget {
  final FullTableRow table;
  final VoidCallback onTap;

  const _PremiumTableCard({
    super.key,
    required this.table,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final occupied = table.openTotalCents > 0;
    final Color statusColor =
        occupied ? AppTheme.warning : AppTheme.textMuted;
    final String statusLabel = occupied ? 'E HAPUR' : 'E LIRË';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppTheme.borderRadius,
        splashColor: statusColor.withValues(alpha: 0.10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: occupied
                  ? [
                      const Color(0xFF1C1500),
                      AppTheme.card,
                    ]
                  : [
                      AppTheme.cardAlt,
                      AppTheme.card,
                    ],
            ),
            borderRadius: AppTheme.borderRadius,
            border: Border.all(
              color: occupied
                  ? AppTheme.warning.withValues(alpha: 0.40)
                  : AppTheme.border,
              width: occupied ? 1.5 : 1,
            ),
            boxShadow: occupied
                ? AppTheme.shadowGlowColor(AppTheme.warning, a: 0.14)
                : AppTheme.shadowSm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      occupied
                          ? Icons.restaurant_rounded
                          : Icons.event_seat_rounded,
                      size: 15,
                      color: statusColor,
                    ),
                  ),
                  const Spacer(),
                  if (occupied)
                    LiveDot(color: AppTheme.warning, size: 7)
                  else
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: AppTheme.textMuted,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
              const Spacer(),
              Text(
                table.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.titleSmall.copyWith(fontSize: 12),
              ),
              const SizedBox(height: 4),
              StatusBadge(label: statusLabel, color: statusColor),
              if (occupied && table.waiterName != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.person_outline_rounded,
                      size: 9,
                      color: AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        table.waiterName!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.bodySmall.copyWith(fontSize: 9),
                      ),
                    ),
                  ],
                ),
              ],
              if (occupied && table.openTotalCents > 0) ...[
                const SizedBox(height: 5),
                Text(
                  moneyFromCents(table.openTotalCents),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.warning,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AddTableTile extends StatelessWidget {
  final VoidCallback onTap;
  const _AddTableTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppTheme.borderRadius,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.04),
            borderRadius: AppTheme.borderRadius,
            border: Border.all(
              color: AppTheme.primary.withValues(alpha: 0.20),
              style: BorderStyle.solid,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.add_rounded,
                  color: AppTheme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Shto',
                style: TextStyle(
                  color: AppTheme.primary.withValues(alpha: 0.80),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PremiumInfoDialog extends StatelessWidget {
  final String title;
  final String message;

  const _PremiumInfoDialog({
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: AppTheme.radiusLarge),
      title: Row(
        children: [
          const IconBadge(
            icon: Icons.info_outline_rounded,
            color: AppTheme.info,
            size: 36,
            iconSize: 18,
          ),
          const SizedBox(width: 12),
          Text(title, style: AppTheme.titleSmall),
        ],
      ),
      content: Text(message, style: AppTheme.bodyMedium),
      actions: [
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: AppTheme.radiusSmall,
            ),
          ),
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'OK',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

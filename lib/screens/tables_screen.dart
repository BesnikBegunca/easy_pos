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

class _TablesScreenState extends State<TablesScreen> {
  late Future<List<FullTableRow>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<FullTableRow>> _load() async {
    var tables = await TablesDao.I.listTablesWithWaiters();
    if (tables.isEmpty) {
      for (int i = 1; i <= 30; i++) {
        await TablesDao.I.addTable('Tavolina $i');
      }
      tables = await TablesDao.I.listTablesWithWaiters();
    }
    return tables;
  }

  void _refresh() => setState(() => _future = _load());

  Future<void> _openTable(FullTableRow t) async {
    final me = Session.I.current!;

    // Table is occupied by a different waiter — show info only
    if (t.isOpen && t.waiterId != null && t.waiterId != me.id) {
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: AppTheme.surface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(t.name, style: AppTheme.titleSmall),
          content: Text(
            'Kjo tavolinë është e hapur nga ${t.waiterName ?? "kamarier tjetër"}.',
            style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OrderScreen(
          tableId: t.id,
          tableName: t.name,
          waiterId: me.id,
        ),
      ),
    );
    if (mounted) _refresh();
  }

  Future<void> _addTableDialog() async {
    final tables = await TablesDao.I.listTablesWithWaiters();
    if (!mounted) return;
    final nextNum = tables.length + 1;
    final nameC = TextEditingController(text: 'Tavolina $nextNum');

    final ok =
        await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: AppTheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text('Shto Tavolinë', style: AppTheme.titleSmall),
            content: AppTextField(
              controller: nameC,
              hint: 'Emri i tavolinës',
              prefixIcon: Icons.table_restaurant_rounded,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Anulo'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Shto'),
              ),
            ],
          ),
        ) ??
        false;

    final name = nameC.text.trim();
    nameC.dispose();

    if (!ok || name.isEmpty || !mounted) return;
    await TablesDao.I.addTable(name);
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      topBar: AppTopBar(
        title: 'Tavolinat',
        actions: [
          TopChip(
            icon: Icons.refresh_rounded,
            label: 'Rifresko',
            onTap: _refresh,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: FutureBuilder<List<FullTableRow>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Gabim në ngarkimin e tavolinave',
                    style: AppTheme.titleMedium,
                  ),
                  const SizedBox(height: 24),
                  AppPrimaryButton(
                    label: 'Provo Përsëri',
                    onPressed: _refresh,
                  ),
                ],
              ),
            );
          }

          final tables = snapshot.data ?? [];
          return GridView.builder(
            padding: const EdgeInsets.all(10),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 6,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1.05,
            ),
            itemCount: tables.length + 1,
            itemBuilder: (_, i) {
              if (i == tables.length) return _addTile();
              return _TableCard(
                table: tables[i],
                onTap: () => _openTable(tables[i]),
              );
            },
          );
        },
      ),
    );
  }

  Widget _addTile() {
    return InkWell(
      onTap: _addTableDialog,
      borderRadius: AppTheme.borderRadius,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.tile,
          borderRadius: AppTheme.borderRadius,
          border: Border.all(
            color: AppTheme.primary.withValues(alpha: 0.18),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_circle_outline_rounded,
              size: 22,
              color: AppTheme.primary.withValues(alpha: 0.45),
            ),
            const SizedBox(height: 5),
            Text(
              'Shto',
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.primary.withValues(alpha: 0.55),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Table card ───────────────────────────────────────────────────────────────

class _TableCard extends StatelessWidget {
  final FullTableRow table;
  final VoidCallback onTap;

  const _TableCard({required this.table, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final occupied = table.isOpen;
    final Color statusColor =
        occupied ? AppTheme.warning : const Color(0xFF4B5563);
    final String statusLabel = occupied ? 'E HAPUR' : 'E LIRË';

    return InkWell(
      onTap: onTap,
      borderRadius: AppTheme.borderRadius,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          borderRadius: AppTheme.borderRadius,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: occupied
                ? [const Color(0xFF1F1A0F), AppTheme.tile]
                : [AppTheme.tileAlt, AppTheme.tile],
          ),
          border: Border.all(
            color: occupied
                ? AppTheme.warning.withValues(alpha: 0.35)
                : Colors.white.withValues(alpha: 0.06),
            width: occupied ? 1.5 : 1,
          ),
          boxShadow: [
            if (occupied)
              BoxShadow(
                color: AppTheme.warning.withValues(alpha: 0.07),
                blurRadius: 12,
                spreadRadius: 1,
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon + status badge
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    occupied
                        ? Icons.restaurant_rounded
                        : Icons.event_seat_rounded,
                    size: 13,
                    color: statusColor,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 7,
                      color: statusColor,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),

            const Spacer(),

            // Table name
            Text(
              table.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.bodySmall.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),

            // Waiter name
            if (occupied && table.waiterName != null) ...[
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(
                    Icons.person_outline_rounded,
                    size: 9,
                    color: Colors.white.withValues(alpha: 0.35),
                  ),
                  const SizedBox(width: 3),
                  Expanded(
                    child: Text(
                      table.waiterName!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.bodySmall.copyWith(
                        fontSize: 9,
                        color: Colors.white54,
                      ),
                    ),
                  ),
                ],
              ),
            ],

            // Open total
            if (occupied && table.openTotalCents > 0) ...[
              const SizedBox(height: 3),
              Text(
                moneyFromCents(table.openTotalCents),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.warning,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../data/dao_tables.dart';
import '../auth/session.dart';
import '../theme/app_theme.dart';
import '../theme/app_widgets.dart';
import 'order_screen.dart';

class TablesScreen extends StatefulWidget {
  const TablesScreen({super.key});

  @override
  State<TablesScreen> createState() => _TablesScreenState();
}

class _TablesScreenState extends State<TablesScreen> {
  late Future<List<DiningTableRow>> _tablesFuture;
  int _refreshKey = 0; // Force rebuild on refresh

  @override
  void initState() {
    super.initState();
    _tablesFuture = _loadTables();
  }

  Future<List<DiningTableRow>> _loadTables() async {
    try {
      final list = await TablesDao.I.listTables();

      // If empty, seed default tables and reload
      if (list.isEmpty) {
        await TablesDao.I.seedDefaultTables();
        return await TablesDao.I.listTables();
      }
      return list;
    } catch (e) {
      print('Error loading tables: $e');
      rethrow;
    }
  }

  Future<void> _refresh() async {
    // Force rebuild by changing the key
    setState(() {
      _refreshKey++;
      _tablesFuture = _loadTables();
    });
  }

  Future<void> _addTableDialog() async {
    // Get current tables to suggest next number
    try {
      final currentTables = await TablesDao.I.listTables();
      final nextNum = currentTables.length + 1;

      final nameC = TextEditingController(text: 'Tavolina $nextNum');

      final ok =
          await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (_) => AlertDialog(
              backgroundColor: AppTheme.surface,
              title: Text('Shto Tavolinë', style: AppTheme.titleMedium),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppTextField(
                    controller: nameC,
                    hint: 'Emri i tavolinës',
                    prefixIcon: Icons.table_restaurant,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Anulo'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Shto'),
                ),
              ],
            ),
          ) ??
          false;

      if (!ok) {
        nameC.dispose();
        return;
      }

      final name = nameC.text.trim();
      nameC.dispose();

      if (name.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Emri nuk mund të jetë bosh')),
          );
        }
        return;
      }

      try {
        await TablesDao.I.addTable(name);
        if (mounted) {
          await _refresh();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Tavolina "$name" u shtua me sukses')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gabim në shtimin e tavolinës: $e')),
          );
        }
        rethrow;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gabim: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      topBar: AppTopBar(
        title: 'Tavolinat',
        actions: [
          TopChip(icon: Icons.refresh, label: 'Rifresko', onTap: _refresh),
        ],
      ),
      body: FutureBuilder<List<DiningTableRow>>(
        key: ValueKey(_refreshKey),
        future: _tablesFuture,
        builder: (context, snapshot) {
          // Loading state
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // Error state
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
                  const SizedBox(height: 8),
                  Text(
                    snapshot.error.toString(),
                    style: AppTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  AppPrimaryButton(label: 'Provo Përsëri', onPressed: _refresh),
                ],
              ),
            );
          }

          // Success state
          final tables = snapshot.data ?? [];

          return RefreshIndicator(
            onRefresh: _refresh,
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 6,
                crossAxisSpacing: AppTheme.spaceS,
                mainAxisSpacing: AppTheme.spaceS,
              ),
              padding: const EdgeInsets.all(AppTheme.spaceM),
              itemCount: tables.length + 1,
              itemBuilder: (context, index) {
                // Last item is the "Add Table" button
                if (index == tables.length) {
                  return _addTile();
                }

                final t = tables[index];
                return AppTableTile(
                  key: ValueKey(t.id),
                  name: t.name,
                  status: t.status,
                  totalCents: t.totalCents,
                  onTap: () async {
                    final waiterId = Session.I.current!.id;
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => OrderScreen(
                          tableId: t.id,
                          tableName: t.name,
                          waiterId: waiterId,
                        ),
                      ),
                    );
                    // Refresh after returning
                    if (mounted) {
                      await _refresh();
                    }
                  },
                );
              },
            ),
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
        padding: const EdgeInsets.all(AppTheme.spaceM),
        decoration: BoxDecoration(
          color: AppTheme.tile,
          borderRadius: AppTheme.borderRadius,
          border: AppTheme.border,
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_circle_outline, size: 28, color: Colors.white70),
              SizedBox(height: AppTheme.spaceXS),
              Text('Shto Tavolinë', style: AppTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

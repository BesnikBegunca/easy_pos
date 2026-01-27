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

  @override
  void initState() {
    super.initState();
    _tablesFuture = _loadTables();
  }

  Future<List<DiningTableRow>> _loadTables() async {
    try {
      final list = await TablesDao.I.listTables();
      if (list.isEmpty) {
        await TablesDao.I.seedDefaultTables();
        return await TablesDao.I.listTables();
      }
      return list;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _tablesFuture = _loadTables();
    });
  }

  Future<void> _addTableDialog() async {
    final tables = await _tablesFuture;
    final nameC = TextEditingController(text: 'Tavolina ${tables.length + 1}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AppCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Add Table', style: AppTheme.titleMedium),
            const SizedBox(height: AppTheme.spaceL),
            AppTextField(
              controller: nameC,
              hint: 'Table name',
              prefixIcon: Icons.table_restaurant,
            ),
            const SizedBox(height: AppTheme.spaceL),
            Row(
              children: [
                Expanded(
                  child: AppQuietButton(
                    label: 'Cancel',
                    onPressed: () => Navigator.pop(context, false),
                  ),
                ),
                const SizedBox(width: AppTheme.spaceM),
                Expanded(
                  child: AppPrimaryButton(
                    label: 'Add',
                    icon: Icons.add,
                    onPressed: () => Navigator.pop(context, true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    await TablesDao.I.addTable(nameC.text);
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      topBar: AppTopBar(
        title: 'Tables',
        actions: [
          TopChip(icon: Icons.refresh, label: 'Refresh', onTap: _refresh),
        ],
      ),
      body: FutureBuilder<List<DiningTableRow>>(
        future: _tablesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Error loading tables: ${snapshot.error}',
                    style: AppTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppTheme.spaceM),
                  AppPrimaryButton(label: 'Retry', onPressed: _refresh),
                ],
              ),
            );
          } else {
            final tables = snapshot.data ?? [];
            return RefreshIndicator(
              onRefresh: _refresh,
              child: GridView.count(
                crossAxisCount: 6, // denser grid
                crossAxisSpacing: AppTheme.spaceS,
                mainAxisSpacing: AppTheme.spaceS,
                padding: const EdgeInsets.all(AppTheme.spaceM),
                children: [
                  for (final t in tables)
                    AppTableTile(
                      name: t.name,
                      status: t.status,
                      totalCents: t.totalCents,
                      onTap: () {
                        final waiterId = Session.I.current!.id;
                        Navigator.of(context)
                            .push(
                              MaterialPageRoute(
                                builder: (_) => OrderScreen(
                                  tableId: t.id,
                                  tableName: t.name,
                                  waiterId: waiterId,
                                ),
                              ),
                            )
                            .then((_) => _refresh()); // Refresh after returning
                      },
                    ),
                  _addTile(),
                ],
              ),
            );
          }
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
              Text('Add Table', style: AppTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

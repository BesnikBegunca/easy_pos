import 'package:flutter/material.dart';
import '../data/dao_tables.dart';
import '../auth/session.dart';
import 'order_screen.dart';

class TablesScreen extends StatefulWidget {
  const TablesScreen({super.key});

  @override
  State<TablesScreen> createState() => _TablesScreenState();
}

class _TablesScreenState extends State<TablesScreen> {
  bool loading = true;
  List<DiningTableRow> tables = [];

  Future<void> _load() async {
    setState(() => loading = true);
    final list = await TablesDao.I.listTables();
    if (!mounted) return;
    setState(() {
      tables = list;
      loading = false;
    });
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _addTableDialog() async {
    final nameC = TextEditingController(text: 'Tavolina ${tables.length + 1}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Shto Tavolinë'),
        content: SizedBox(
          width: 420,
          child: TextField(
            controller: nameC,
            decoration: const InputDecoration(labelText: 'Emri'),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Anulo')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Shto')),
        ],
      ),
    );
    if (ok != true) return;
    await TablesDao.I.addTable(nameC.text);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final cols = 5; // desktop vibe

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Tavolinat', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),

          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : GridView.count(
              crossAxisCount: cols,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: [
                for (final t in tables) _tableCard(t),
                _addCard(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tableCard(DiningTableRow t) {
    return InkWell(
      onTap: () {
        final waiterId = Session.I.current!.id;
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => OrderScreen(tableId: t.id, tableName: t.name, waiterId: waiterId)),
        );
      },
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.table_restaurant, size: 28),
              const Spacer(),
              Text(t.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              const Text('Kliko për porosi', style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _addCard() {
    return InkWell(
      onTap: _addTableDialog,
      child: Card(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.add_circle_outline, size: 36),
              SizedBox(height: 8),
              Text('Shto tavolinë', style: TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    );
  }
}

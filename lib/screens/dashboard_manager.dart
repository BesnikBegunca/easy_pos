import 'package:flutter/material.dart';
import '../auth/session.dart';
import '../auth/roles.dart';
import '../data/dao_sales.dart';
import '../util/money.dart';

class DashboardManager extends StatefulWidget {
  const DashboardManager({super.key});

  @override
  State<DashboardManager> createState() => _DashboardManagerState();
}

class _DashboardManagerState extends State<DashboardManager> {
  RangeKind range = RangeKind.day;
  int totalAllCents = 0;
  List<WaiterTotalRow> perWaiter = [];
  bool loading = true;

  Future<void> _load() async {
    setState(() => loading = true);
    final sumAll = await SalesDao.I.sumTotalCents(range: range, anchor: DateTime.now());
    final rows = await SalesDao.I.totalsByWaiter(range: range, anchor: DateTime.now());
    if (!mounted) return;
    setState(() {
      totalAllCents = sumAll;
      perWaiter = rows;
      loading = false;
    });
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final u = Session.I.current!;
    if (!canViewReports(u.role)) {
      return const Center(child: Text('S’ke leje për këtë panel.'));
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Manager Dashboard', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),

          Row(
            children: [
              _rangeChip('Ditor', RangeKind.day),
              const SizedBox(width: 8),
              _rangeChip('Javor', RangeKind.week),
              const SizedBox(width: 8),
              _rangeChip('Mujor', RangeKind.month),
              const SizedBox(width: 8),
              _rangeChip('Vjetor', RangeKind.year),
              const Spacer(),
              IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
            ],
          ),

          const SizedBox(height: 16),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.bar_chart, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Totali i lokalit (${_rangeLabel(range)})', style: const TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        Text(
                          loading ? '...' : moneyFromCents(totalAllCents),
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 6),
                        const Text('Breakdown per waiter poshtë.'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          Expanded(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: loading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.separated(
                  itemCount: perWaiter.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final w = perWaiter[i];
                    final name = (w.fullName?.trim().isNotEmpty ?? false) ? w.fullName! : w.username;
                    return ListTile(
                      leading: const Icon(Icons.person),
                      title: Text(name),
                      subtitle: Text('@${w.username}'),
                      trailing: Text(
                        moneyFromCents(w.totalCents),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rangeChip(String label, RangeKind v) {
    return ChoiceChip(
      label: Text(label),
      selected: range == v,
      onSelected: (_) async {
        setState(() => range = v);
        await _load();
      },
    );
  }

  String _rangeLabel(RangeKind k) {
    switch (k) {
      case RangeKind.day:
        return 'ditor';
      case RangeKind.week:
        return 'javor';
      case RangeKind.month:
        return 'mujor';
      case RangeKind.year:
        return 'vjetor';
    }
  }
}

import 'package:flutter/material.dart';
import '../auth/session.dart';
import '../data/dao_sales.dart';
import '../util/money.dart';

class DashboardWaiter extends StatefulWidget {
  const DashboardWaiter({super.key});

  @override
  State<DashboardWaiter> createState() => _DashboardWaiterState();
}

class _DashboardWaiterState extends State<DashboardWaiter> {
  RangeKind range = RangeKind.day;
  int totalCents = 0;
  bool loading = true;

  Future<void> _load() async {
    setState(() => loading = true);
    final u = Session.I.current!;
    final sum = await SalesDao.I.sumTotalCents(range: range, anchor: DateTime.now(), waiterId: u.id);
    if (!mounted) return;
    setState(() {
      totalCents = sum;
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
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Mirësevjen, ${u.fullName ?? u.username}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
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
                  const Icon(Icons.point_of_sale, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Totali yt (${_rangeLabel(range)})', style: const TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        Text(
                          loading ? '...' : moneyFromCents(totalCents),
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 6),
                        const Text('Këtu shihen vetëm shitjet e tua.'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // ✅ vetëm për test (hiqe kur lidhim checkout real)
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: loading
                  ? null
                  : () async {
                // test: shto 5.00€
                await SalesDao.I.addSale(waiterId: u.id, totalCents: 500);
                _load();
              },
              icon: const Icon(Icons.add),
              label: const Text('TEST: Shto 5.00€ (hiqe ma vonë)'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rangeChip(String label, RangeKind v) {
    final selected = range == v;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
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

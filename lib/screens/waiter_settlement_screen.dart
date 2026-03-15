import 'package:flutter/material.dart';
import '../auth/dao_users.dart';
import '../auth/session.dart';
import '../auth/roles.dart';
import '../data/dao_settlements.dart';
import '../data/dao_orders.dart';
import '../util/money.dart';
import '../theme/app_theme.dart';

class WaiterSettlementScreen extends StatefulWidget {
  const WaiterSettlementScreen({super.key});

  @override
  State<WaiterSettlementScreen> createState() => _WaiterSettlementScreenState();
}

class _WaiterSettlementScreenState extends State<WaiterSettlementScreen> {
  bool loading = true;
  List<AppUserRow> waiters = [];
  AppUserRow? selectedWaiter;
  DateTime? startDate;
  DateTime? endDate;
  Map<String, int> totals = {};
  final actualCashC = TextEditingController();
  final notesC = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadWaiters();
  }

  Future<void> _loadWaiters() async {
    setState(() => loading = true);
    final all = await UsersDao.I.listUsers();
    waiters = all.where((u) => u.role == UserRole.waiter).toList();
    setState(() => loading = false);
  }

  Future<void> _calculateTotals() async {
    if (selectedWaiter == null) return;

    final startMs =
        startDate?.millisecondsSinceEpoch ??
        selectedWaiter!.shiftStartedAt ??
        DateTime.now().subtract(const Duration(days: 1)).millisecondsSinceEpoch;
    final endMs =
        endDate?.millisecondsSinceEpoch ??
        DateTime.now().millisecondsSinceEpoch;

    totals = await SettlementsDao.I.getUnsettledTotals(
      waiterId: selectedWaiter!.id,
      startMs: startMs,
      endMs: endMs,
    );

    setState(() {});
  }

  Future<void> _settle() async {
    if (selectedWaiter == null || startDate == null || endDate == null) return;

    final actualCash =
        (double.tryParse(actualCashC.text.replaceAll(',', '.')) ?? 0) * 100;

    final startMs = startDate!.millisecondsSinceEpoch;
    final endMs = endDate!.millisecondsSinceEpoch;

    await SettlementsDao.I.settleWaiter(
      waiterId: selectedWaiter!.id,
      startMs: startMs,
      endMs: endMs,
      totalCents: totals['total'] ?? 0,
      cashCents: totals['cash'] ?? 0,
      cardCents: totals['card'] ?? 0,
      expectedCashCents: totals['expectedCash'] ?? 0,
      actualCashCents: actualCash.toInt(),
      notes: notesC.text.trim().isEmpty ? null : notesC.text.trim(),
      settledBy: Session.I.current!.id,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Settlement completed successfully')),
    );

    // Reset form
    setState(() {
      selectedWaiter = null;
      startDate = null;
      endDate = null;
      totals = {};
      actualCashC.clear();
      notesC.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final me = Session.I.current!;
    if (me.role != UserRole.admin) {
      return const Center(child: Text('Access denied'));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Settlement / Settle Waiter')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Select Waiter',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButton<AppUserRow>(
                      value: selectedWaiter,
                      hint: const Text('Choose a waiter'),
                      isExpanded: true,
                      items: waiters.map((w) {
                        return DropdownMenuItem(
                          value: w,
                          child: Text(w.fullName ?? w.username),
                        );
                      }).toList(),
                      onChanged: (w) {
                        setState(() => selectedWaiter = w);
                        _calculateTotals();
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Shift Range',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: startDate ?? DateTime.now(),
                                firstDate: DateTime(2000),
                                lastDate: DateTime.now(),
                              );
                              if (date != null) {
                                setState(() => startDate = date);
                                _calculateTotals();
                              }
                            },
                            child: Text(
                              startDate == null
                                  ? 'Start Date'
                                  : '${startDate!.day}/${startDate!.month}/${startDate!.year}',
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: endDate ?? DateTime.now(),
                                firstDate: startDate ?? DateTime(2000),
                                lastDate: DateTime.now(),
                              );
                              if (date != null) {
                                setState(() => endDate = date);
                                _calculateTotals();
                              }
                            },
                            child: Text(
                              endDate == null
                                  ? 'End Date'
                                  : '${endDate!.day}/${endDate!.month}/${endDate!.year}',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (totals.isNotEmpty) ...[
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Settlement Summary for ${selectedWaiter!.fullName ?? selectedWaiter!.username}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Total Sales: ${moneyFromCents(totals['total'] ?? 0)}',
                              ),
                              Text(
                                'Cash Payments: ${moneyFromCents(totals['cash'] ?? 0)}',
                              ),
                              Text(
                                'Card/Mixed Payments: ${moneyFromCents(totals['card'] ?? 0)}',
                              ),
                              Text(
                                'Expected Cash: ${moneyFromCents(totals['expectedCash'] ?? 0)}',
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: actualCashC,
                                decoration: const InputDecoration(
                                  labelText: 'Actual Cash Counted (€)',
                                ),
                                keyboardType: TextInputType.number,
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: notesC,
                                decoration: const InputDecoration(
                                  labelText: 'Notes (optional)',
                                ),
                                maxLines: 3,
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _settle,
                                  child: const Text('SETTLE'),
                                ),
                              ),
                            ],
                          ),
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

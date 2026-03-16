import 'package:flutter/material.dart';
import '../auth/dao_users.dart';
import '../auth/session.dart';
import '../auth/roles.dart';
import '../data/dao_settlements.dart';
import '../util/money.dart';
import '../theme/app_theme.dart';

class WaiterSettlementScreen extends StatefulWidget {
  const WaiterSettlementScreen({super.key});

  @override
  State<WaiterSettlementScreen> createState() => _WaiterSettlementScreenState();
}

class _WaiterSettlementScreenState extends State<WaiterSettlementScreen> {
  bool loading = true;
  bool settling = false;

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

  @override
  void dispose() {
    actualCashC.dispose();
    notesC.dispose();
    super.dispose();
  }

  Future<void> _loadWaiters() async {
    setState(() => loading = true);

    try {
      final all = await UsersDao.I.listUsers();
      waiters = all.where((u) => u.role == UserRole.waiter).toList();
    } catch (e) {
      debugPrint('Error loading waiters: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gabim gjatë ngarkimit të kamarjerëve: $e')),
      );
    }

    if (!mounted) return;
    setState(() => loading = false);
  }

  int _startOfDayMs(DateTime d) {
    return DateTime(d.year, d.month, d.day).millisecondsSinceEpoch;
  }

  int _endOfDayExclusiveMs(DateTime d) {
    return DateTime(d.year, d.month, d.day + 1).millisecondsSinceEpoch;
  }

  String _fmtDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  Future<void> _calculateTotals() async {
    if (selectedWaiter == null) return;

    try {
      final now = DateTime.now();

      final startMs = startDate != null
          ? _startOfDayMs(startDate!)
          : (selectedWaiter!.shiftStartedAt ??
                now.subtract(const Duration(days: 1)).millisecondsSinceEpoch);

      final endMs = endDate != null
          ? _endOfDayExclusiveMs(endDate!)
          : now.millisecondsSinceEpoch;

      final data = await SettlementsDao.I.getUnsettledTotals(
        waiterId: selectedWaiter!.id,
        startMs: startMs,
        endMs: endMs,
      );

      if (!mounted) return;
      setState(() {
        totals = data;
      });
    } catch (e) {
      debugPrint('Error calculating totals: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gabim gjatë llogaritjes së totaleve: $e')),
      );
    }
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: startDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );

    if (picked == null) return;

    setState(() {
      startDate = picked;
      if (endDate != null && endDate!.isBefore(startDate!)) {
        endDate = picked;
      }
    });

    await _calculateTotals();
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: endDate ?? startDate ?? DateTime.now(),
      firstDate: startDate ?? DateTime(2000),
      lastDate: DateTime.now(),
    );

    if (picked == null) return;

    setState(() {
      endDate = picked;
    });

    await _calculateTotals();
  }

  Future<void> _settle() async {
    if (selectedWaiter == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Zgjedhe kamarjerin fillimisht.')),
      );
      return;
    }

    final now = DateTime.now();

    final startMs = startDate != null
        ? _startOfDayMs(startDate!)
        : (selectedWaiter!.shiftStartedAt ??
              now.subtract(const Duration(days: 1)).millisecondsSinceEpoch);

    final endMs = endDate != null
        ? _endOfDayExclusiveMs(endDate!)
        : now.millisecondsSinceEpoch;

    final actualCash =
        ((double.tryParse(actualCashC.text.trim().replaceAll(',', '.')) ?? 0) *
                100)
            .round();

    try {
      setState(() => settling = true);

      await SettlementsDao.I.settleWaiter(
        waiterId: selectedWaiter!.id,
        startMs: startMs,
        endMs: endMs,
        totalCents: totals['total'] ?? 0,
        cashCents: totals['cash'] ?? 0,
        cardCents: totals['card'] ?? 0,
        expectedCashCents: totals['expectedCash'] ?? 0,
        actualCashCents: actualCash,
        notes: notesC.text.trim().isEmpty ? null : notesC.text.trim(),
        settledBy: Session.I.current!.id,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settlement u kry me sukses.')),
      );

      setState(() {
        totals = {};
        actualCashC.clear();
        notesC.clear();
        startDate = null;
        endDate = null;
        selectedWaiter = null;
      });

      await _loadWaiters();
    } catch (e) {
      debugPrint('Error settling waiter: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gabim gjatë settlement: $e')));
    } finally {
      if (mounted) {
        setState(() => settling = false);
      }
    }
  }

  Widget _summaryRow(String label, int amount, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          Text(
            moneyFromCents(amount),
            style: AppTheme.bodyLarge.copyWith(
              fontWeight: FontWeight.w800,
              color: valueColor ?? AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final me = Session.I.current!;

    if (me.role != UserRole.admin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Settlement / Settle Waiter')),
        body: const Center(child: Text('Access denied')),
      );
    }

    final total = totals['total'] ?? 0;
    final cash = totals['cash'] ?? 0;
    final card = totals['card'] ?? 0;
    final expectedCash = totals['expectedCash'] ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settlement / Settle Waiter'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: loading ? null : _loadWaiters,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : waiters.isEmpty
            ? const Center(child: Text('Nuk ka kamarjerë aktivë.'))
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Zgjedh kamarjerin', style: AppTheme.titleMedium),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.tile,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.borderColor),
                      ),
                      child: DropdownButton<AppUserRow>(
                        value: selectedWaiter,
                        hint: const Text('Choose a waiter'),
                        isExpanded: true,
                        underline: const SizedBox(),
                        dropdownColor: AppTheme.surface,
                        items: waiters.map((w) {
                          return DropdownMenuItem<AppUserRow>(
                            value: w,
                            child: Text(w.fullName ?? w.username),
                          );
                        }).toList(),
                        onChanged: (w) async {
                          setState(() {
                            selectedWaiter = w;
                            totals = {};
                            actualCashC.clear();
                            notesC.clear();
                          });
                          await _calculateTotals();
                        },
                      ),
                    ),

                    const SizedBox(height: 20),

                    Text('Shift Range', style: AppTheme.titleMedium),
                    const SizedBox(height: 8),

                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _pickStartDate,
                            child: Text(
                              startDate == null
                                  ? 'Start Date'
                                  : _fmtDate(startDate!),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _pickEndDate,
                            child: Text(
                              endDate == null ? 'End Date' : _fmtDate(endDate!),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    if (selectedWaiter != null &&
                        selectedWaiter!.shiftStartedAt != null)
                      Text(
                        'Shift started: ${DateTime.fromMillisecondsSinceEpoch(selectedWaiter!.shiftStartedAt!).toString().substring(0, 19)}',
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),

                    const SizedBox(height: 20),

                    if (selectedWaiter != null)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _calculateTotals,
                          icon: const Icon(Icons.calculate_outlined),
                          label: const Text('Llogarit totalet'),
                        ),
                      ),

                    if (selectedWaiter != null) ...[
                      const SizedBox(height: 16),
                      Card(
                        color: AppTheme.tile,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(color: AppTheme.borderColor),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Settlement Summary for ${selectedWaiter!.fullName ?? selectedWaiter!.username}',
                                style: AppTheme.titleSmall,
                              ),
                              const SizedBox(height: 14),
                              _summaryRow('Total Sales', total),
                              _summaryRow('Cash Payments', cash),
                              _summaryRow('Card/Mixed Payments', card),
                              const Divider(height: 24),
                              _summaryRow(
                                'Expected Cash',
                                expectedCash,
                                valueColor: AppTheme.primary,
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: actualCashC,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: const InputDecoration(
                                  labelText: 'Actual Cash Counted (€)',
                                ),
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
                                  onPressed: settling ? null : _settle,
                                  child: Text(
                                    settling ? 'DUKE RUJT...' : 'SETTLE',
                                  ),
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

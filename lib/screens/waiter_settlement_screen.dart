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

  int get total => totals['total'] ?? 0;
  int get cash => totals['cash'] ?? 0;
  int get card => totals['card'] ?? 0;
  int get expectedCash => totals['expectedCash'] ?? 0;

  int get actualCash =>
      (((double.tryParse(actualCashC.text.trim().replaceAll(',', '.')) ?? 0) *
              100))
          .round();

  int get difference => actualCash - expectedCash;

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

    try {
      setState(() => settling = true);

      await SettlementsDao.I.settleWaiter(
        waiterId: selectedWaiter!.id,
        startMs: startMs,
        endMs: endMs,
        totalCents: total,
        cashCents: cash,
        cardCents: card,
        expectedCashCents: expectedCash,
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

  Widget _statCard({
    required String title,
    required String value,
    required IconData icon,
    Color? tint,
  }) {
    final color = tint ?? AppTheme.primary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.tile,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 46,
            width: 46,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.titleMedium.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: AppTheme.titleMedium.copyWith(
        fontWeight: FontWeight.w800,
        color: AppTheme.textPrimary,
      ),
    );
  }

  Widget _summaryRow(String label, int amount, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w600,
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

  Widget _dateButton({
    required String label,
    required String value,
    required VoidCallback onTap,
    required IconData icon,
  }) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.tile,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: Row(
            children: [
              Container(
                height: 42,
                width: 42,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppTheme.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: AppTheme.bodyMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _differenceCard() {
    final isPositive = difference >= 0;
    final diffColor = isPositive ? Colors.green : Colors.red;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: diffColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: diffColor.withOpacity(0.20)),
      ),
      child: Column(
        children: [
          Text(
            'Difference',
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            moneyFromCents(difference),
            style: AppTheme.bodyLarge.copyWith(
              fontSize: 26,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isPositive
                ? 'Ka më shumë cash se expected.'
                : 'Ka më pak cash se expected.',
            textAlign: TextAlign.center,
            style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary),
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
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : waiters.isEmpty
          ? const Center(child: Text('Nuk ka kamarjerë aktivë.'))
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 950),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionTitle('Zgjedh kamarjerin'),
                        const SizedBox(height: 10),

                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.tile,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: AppTheme.borderColor),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 16,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: DropdownButton<AppUserRow>(
                            value: selectedWaiter,
                            hint: const Text('Choose a waiter'),
                            isExpanded: true,
                            underline: const SizedBox(),
                            borderRadius: BorderRadius.circular(16),
                            dropdownColor: AppTheme.surface,
                            icon: const Icon(Icons.keyboard_arrow_down_rounded),
                            items: waiters.map((w) {
                              final name = w.fullName?.trim().isNotEmpty == true
                                  ? w.fullName!.trim()
                                  : w.username;

                              return DropdownMenuItem<AppUserRow>(
                                value: w,
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 18,
                                      backgroundColor: AppTheme.primary
                                          .withOpacity(0.12),
                                      child: Text(
                                        name.isNotEmpty
                                            ? name[0].toUpperCase()
                                            : 'W',
                                        style: TextStyle(
                                          color: AppTheme.primary,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        name,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTheme.bodyMedium.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
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

                        const SizedBox(height: 22),

                        _sectionTitle('Shift Range'),
                        const SizedBox(height: 10),

                        Row(
                          children: [
                            _dateButton(
                              label: 'Start Date',
                              value: startDate == null
                                  ? 'Select date'
                                  : _fmtDate(startDate!),
                              onTap: _pickStartDate,
                              icon: Icons.calendar_today_outlined,
                            ),
                            const SizedBox(width: 12),
                            _dateButton(
                              label: 'End Date',
                              value: endDate == null
                                  ? 'Select date'
                                  : _fmtDate(endDate!),
                              onTap: _pickEndDate,
                              icon: Icons.event_outlined,
                            ),
                          ],
                        ),

                        if (selectedWaiter != null &&
                            selectedWaiter!.shiftStartedAt != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            'Shift started: ${DateTime.fromMillisecondsSinceEpoch(selectedWaiter!.shiftStartedAt!).toString().substring(0, 19)}',
                            style: AppTheme.bodySmall.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],

                        if (selectedWaiter != null) ...[
                          const SizedBox(height: 18),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _calculateTotals,
                              icon: const Icon(Icons.calculate_outlined),
                              label: const Text('Llogarit totalet'),
                            ),
                          ),
                        ],

                        if (selectedWaiter != null) ...[
                          const SizedBox(height: 20),

                          GridView.count(
                            crossAxisCount:
                                MediaQuery.of(context).size.width < 700 ? 1 : 2,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio:
                                MediaQuery.of(context).size.width < 700
                                ? 3.8
                                : 2.8,
                            children: [
                              _statCard(
                                title: 'Total Sales',
                                value: moneyFromCents(total),
                                icon: Icons.receipt_long_outlined,
                                tint: Colors.blue,
                              ),
                              _statCard(
                                title: 'Cash Payments',
                                value: moneyFromCents(cash),
                                icon: Icons.payments_outlined,
                                tint: Colors.green,
                              ),
                              _statCard(
                                title: 'Card / Mixed Payments',
                                value: moneyFromCents(card),
                                icon: Icons.credit_card_outlined,
                                tint: Colors.deepPurple,
                              ),
                              _statCard(
                                title: 'Expected Cash',
                                value: moneyFromCents(expectedCash),
                                icon: Icons.account_balance_wallet_outlined,
                                tint: Colors.orange,
                              ),
                            ],
                          ),

                          const SizedBox(height: 18),

                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: AppTheme.tile,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppTheme.borderColor),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 18,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Settlement Summary for ${selectedWaiter!.fullName?.trim().isNotEmpty == true ? selectedWaiter!.fullName!.trim() : selectedWaiter!.username}',
                                  style: AppTheme.titleSmall.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 14),

                                _summaryRow('Total Sales', total),
                                _summaryRow('Cash Payments', cash),
                                _summaryRow('Card / Mixed Payments', card),

                                const Divider(height: 26),

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
                                  onChanged: (_) => setState(() {}),
                                  decoration: InputDecoration(
                                    labelText: 'Actual Cash Counted (€)',
                                    hintText: 'Shkruaj shumën reale të cash-it',
                                    prefixIcon: const Icon(Icons.euro_outlined),
                                    filled: true,
                                    fillColor: AppTheme.surface,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide(
                                        color: AppTheme.borderColor,
                                      ),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 14),

                                _differenceCard(),

                                const SizedBox(height: 14),

                                TextField(
                                  controller: notesC,
                                  maxLines: 3,
                                  decoration: InputDecoration(
                                    labelText: 'Notes (optional)',
                                    hintText: 'Shënim shtesë për settlement',
                                    prefixIcon: const Padding(
                                      padding: EdgeInsets.only(bottom: 48),
                                      child: Icon(Icons.notes_outlined),
                                    ),
                                    filled: true,
                                    fillColor: AppTheme.surface,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide(
                                        color: AppTheme.borderColor,
                                      ),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 18),

                                SizedBox(
                                  width: double.infinity,
                                  height: 54,
                                  child: ElevatedButton.icon(
                                    onPressed: settling ? null : _settle,
                                    icon: Icon(
                                      settling
                                          ? Icons.hourglass_top_rounded
                                          : Icons.verified_outlined,
                                    ),
                                    label: Text(
                                      settling
                                          ? 'DUKE RUJT...'
                                          : 'KRYEJ SETTLEMENT',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

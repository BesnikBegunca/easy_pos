import 'package:flutter/material.dart';
import '../auth/dao_users.dart';
import '../auth/roles.dart';
import '../auth/session.dart';
import '../data/dao_settlements.dart';
import '../theme/app_theme.dart';
import '../util/money.dart';

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

  Map<String, int> totals = const <String, int>{};

  final actualCashC = TextEditingController();
  final premiumC = TextEditingController();
  final notesC = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadWaiters();
  }

  @override
  void dispose() {
    actualCashC.dispose();
    premiumC.dispose();
    notesC.dispose();
    super.dispose();
  }

  int get total => totals['total'] ?? 0;
  int get cash => totals['cash'] ?? 0;
  int get card => totals['card'] ?? 0;
  int get expectedCash => totals['expectedCash'] ?? 0;

  int get actualCash {
    final value = double.tryParse(actualCashC.text.trim().replaceAll(',', '.')) ?? 0;
    return (value * 100).round();
  }

  int get premiumCents {
    final value = double.tryParse(premiumC.text.trim().replaceAll(',', '.')) ?? 0;
    return (value * 100).round();
  }

  int get difference => actualCash - expectedCash;

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

  int _defaultStartMsFor(AppUserRow waiter) {
    final now = DateTime.now();
    return waiter.shiftStartedAt ??
        now.subtract(const Duration(hours: 12)).millisecondsSinceEpoch;
  }

  int _currentEndMs() => DateTime.now().millisecondsSinceEpoch;

  Future<void> _calculateTotals() async {
    final waiter = selectedWaiter;
    if (waiter == null) return;

    try {
      final data = await SettlementsDao.I.getUnsettledTotals(
        waiterId: waiter.id,
        startMs: _defaultStartMsFor(waiter),
        endMs: _currentEndMs(),
      );

      if (!mounted) return;

      setState(() {
        totals = {
          'total': data['total'] ?? 0,
          'cash': data['cash'] ?? 0,
          'card': data['card'] ?? 0,
          'expectedCash': data['expectedCash'] ?? 0,
        };

        actualCashC.text = moneyFromCents(expectedCash).replaceAll('€', '').trim();
      });
    } catch (e) {
      debugPrint('Error calculating totals: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gabim gjatë llogaritjes së totaleve: $e')),
      );
    }
  }

  void _resetUiAfterSettlement() {
    setState(() {
      totals = const {
        'total': 0,
        'cash': 0,
        'card': 0,
        'expectedCash': 0,
      };
      actualCashC.clear();
      premiumC.clear();
      notesC.clear();
      selectedWaiter = null;
    });
  }

  Future<void> _settle() async {
    final waiter = selectedWaiter;

    if (waiter == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Zgjedhe kamarjerin fillimisht.')),
      );
      return;
    }

    if (settling) return;

    final startMs = _defaultStartMsFor(waiter);
    final endMs = _currentEndMs();

    try {
      setState(() => settling = true);

      await SettlementsDao.I.settleWaiter(
        waiterId: waiter.id,
        startMs: startMs,
        endMs: endMs,
        totalCents: total,
        cashCents: cash,
        cardCents: card,
        expectedCashCents: expectedCash,
        actualCashCents: actualCash,
        premiumCents: premiumCents,
        notes: notesC.text.trim().isEmpty ? null : notesC.text.trim(),
        settledBy: Session.I.current!.id,
      );

      if (!mounted) return;

      _resetUiAfterSettlement();
      await _loadWaiters();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Settlement u kry me sukses. Totali u kthye në 0.00 dhe shifti i ri mund të fillojë.',
          ),
        ),
      );
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
              color: diffColor,
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

  Widget _premiumCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.workspace_premium_outlined, color: Colors.amber.shade700, size: 20),
              const SizedBox(width: 8),
              Text(
                'Premium / Bonus',
                style: AppTheme.bodyMedium.copyWith(
                  color: Colors.amber.shade700,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: premiumC,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Premium (€)',
              hintText: '0.00',
              prefixIcon: const Icon(Icons.workspace_premium_outlined),
              filled: true,
              fillColor: AppTheme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.amber.withValues(alpha: 0.40)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.amber.shade700),
              ),
            ),
          ),
          if (premiumCents > 0) ...[
            const SizedBox(height: 10),
            Text(
              'Premium i regjistruar: ${moneyFromCents(premiumCents)}',
              style: AppTheme.bodySmall.copyWith(
                color: Colors.amber.shade700,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _waiterName(AppUserRow w) {
    final full = w.fullName?.trim() ?? '';
    return full.isNotEmpty ? full : w.username;
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
                                  final name = _waiterName(w);

                                  return DropdownMenuItem<AppUserRow>(
                                    value: w,
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 18,
                                          backgroundColor:
                                              AppTheme.primary.withOpacity(0.12),
                                          child: Text(
                                            name.isNotEmpty ? name[0].toUpperCase() : 'W',
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
                                    totals = const {};
                                    actualCashC.clear();
                                    premiumC.clear();
                                    notesC.clear();
                                  });

                                  await _calculateTotals();
                                },
                              ),
                            ),
                            if (selectedWaiter != null) ...[
                              const SizedBox(height: 18),
                              Text(
                                selectedWaiter!.shiftStartedAt == null
                                    ? 'Ky waiter ende nuk ka shift aktiv. Nëse llogaritja del 0.00, settlement mbyllet pa mbetje.'
                                    : 'Settlement po llogaritet vetëm për shiftin aktual dhe vetëm për pjesën e pabara settle.',
                                style: AppTheme.bodySmall.copyWith(
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: _calculateTotals,
                                  icon: const Icon(Icons.calculate_outlined),
                                  label: const Text('Llogarit totalet'),
                                ),
                              ),
                              const SizedBox(height: 20),
                              GridView.count(
                                crossAxisCount:
                                    MediaQuery.of(context).size.width < 700 ? 1 : 2,
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                childAspectRatio:
                                    MediaQuery.of(context).size.width < 700 ? 3.8 : 2.8,
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
                                      'Settlement Summary for ${_waiterName(selectedWaiter!)}',
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
                                    if (premiumCents > 0)
                                      _summaryRow(
                                        'Premium / Bonus',
                                        premiumCents,
                                        valueColor: Colors.amber.shade700,
                                      ),
                                    const SizedBox(height: 16),
                                    TextField(
                                      controller: actualCashC,
                                      keyboardType: const TextInputType.numberWithOptions(
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
                                    _premiumCard(),
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
                                          settling ? 'DUKE RUJT...' : 'KRYEJ SETTLEMENT',
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

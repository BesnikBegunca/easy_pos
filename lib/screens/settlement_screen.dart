import 'package:flutter/material.dart';
import '../auth/session.dart';
import '../data/dao_payments.dart';
import '../data/dao_day_sessions.dart';
import '../util/money.dart';

class SettlementScreen extends StatefulWidget {
  const SettlementScreen({super.key});

  @override
  State<SettlementScreen> createState() => _SettlementScreenState();
}

class _SettlementScreenState extends State<SettlementScreen> {
  bool loading = true;
  DaySessionRow? session;
  int cashSales = 0;
  int cardSales = 0;
  int totalSales = 0;

  final openingCashC = TextEditingController();
  final actualCashC = TextEditingController();
  final notesC = TextEditingController();

  Future<void> _load() async {
    setState(() => loading = true);

    final today = DateTime.now();
    final dateStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    session = await DaySessionsDao.I.getSessionForDate(dateStr);

    if (session == null) {
      // Create new session
      await DaySessionsDao.I.createSession(date: dateStr, openingCashCents: 0);
      session = await DaySessionsDao.I.getSessionForDate(dateStr);
    }

    // Calculate today's sales
    cashSales = await PaymentsDao.I.sumCashPayments(today);
    cardSales = await PaymentsDao.I.sumCardPayments(today);
    totalSales = cashSales + cardSales;

    // Update session totals
    await DaySessionsDao.I.updateSessionTotals(
      date: dateStr,
      cashSalesCents: cashSales,
      cardSalesCents: cardSales,
      discountsCents: 0,
      refundsCents: 0,
    );

    session = await DaySessionsDao.I.getSessionForDate(dateStr);

    if (session != null) {
      openingCashC.text = moneyFromCents(session!.openingCashCents);
      actualCashC.text = session!.actualCashCents != null
          ? moneyFromCents(session!.actualCashCents!)
          : '';
      notesC.text = session!.notes ?? '';
    }

    if (!mounted) return;
    setState(() => loading = false);
  }

  Future<void> _settle() async {
    if (session == null) return;

    final actualCash =
        (double.tryParse(actualCashC.text.replaceAll(',', '.')) ?? 0) * 100;

    await DaySessionsDao.I.settleSession(
      date: session!.date,
      actualCashCents: actualCash.toInt(),
      settledBy: Session.I.current!.id,
      notes: notesC.text.trim().isEmpty ? null : notesC.text.trim(),
    );

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Settlement')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final expectedCash = session!.openingCashCents + cashSales;
    final difference = session!.actualCashCents != null
        ? session!.actualCashCents! - expectedCash
        : 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('End of Day Settlement'),
        actions: [
          if (session!.settledAt == null)
            TextButton(
              onPressed: _settle,
              child: const Text(
                'Settle',
                style: TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Date: ${session!.date}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextField(
                      controller: openingCashC,
                      decoration: const InputDecoration(
                        labelText: 'Opening Cash (€)',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Cash Sales: ${moneyFromCents(cashSales)}',
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            'Card Sales: ${moneyFromCents(cardSales)}',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Total Sales: ${moneyFromCents(totalSales)}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Expected Cash: ${moneyFromCents(expectedCash)}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 16),
                    if (session!.settledAt == null)
                      TextField(
                        controller: actualCashC,
                        decoration: const InputDecoration(
                          labelText: 'Actual Cash Counted (€)',
                        ),
                        keyboardType: TextInputType.number,
                      )
                    else
                      Text(
                        'Actual Cash: ${moneyFromCents(session!.actualCashCents ?? 0)}',
                      ),
                    if (session!.settledAt != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Difference: ${moneyFromCents(difference)}',
                        style: TextStyle(
                          color: difference >= 0 ? Colors.green : Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    TextField(
                      controller: notesC,
                      decoration: const InputDecoration(
                        labelText: 'Notes (optional)',
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
            ),

            if (session!.settledAt != null) ...[
              const SizedBox(height: 16),
              Card(
                color: Colors.green.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Day settled on ${DateTime.fromMillisecondsSinceEpoch(session!.settledAt!).toString().substring(0, 19)}',
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

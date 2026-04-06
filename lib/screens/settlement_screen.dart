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

  final actualCashC = TextEditingController();

  int get totalSales => cashSales + cardSales;
  int get expectedCash => (session?.openingCashCents ?? 0) + cashSales;

  int get actualCash =>
      ((double.tryParse(actualCashC.text.replaceAll(',', '.')) ?? 0) * 100)
          .toInt();

  int get difference => actualCash - expectedCash;

  Future<void> _load() async {
    setState(() => loading = true);

    final today = DateTime.now();
    final date =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    session = await DaySessionsDao.I.getSessionForDate(date);

    if (session == null) {
      await DaySessionsDao.I.createSession(date: date, openingCashCents: 0);
      session = await DaySessionsDao.I.getSessionForDate(date);
    }

    cashSales = await PaymentsDao.I.sumCashPayments(today);
    cardSales = await PaymentsDao.I.sumCardPayments(today);

    if (!mounted) return;
    setState(() => loading = false);
  }

  Future<void> _settle() async {
    await DaySessionsDao.I.settleSession(
      date: session!.date,
      actualCashCents: actualCash,
      settledBy: Session.I.current!.id,
      notes: null,
    );

    Navigator.pop(context);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Widget statCard(String title, String value, {Color? color}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color ?? Colors.grey.shade100,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(title, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Day Settlement")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            /// STATS
            Row(
              children: [
                statCard("Cash", moneyFromCents(cashSales)),
                const SizedBox(width: 10),
                statCard("Card", moneyFromCents(cardSales)),
              ],
            ),

            const SizedBox(height: 10),

            Row(
              children: [
                statCard(
                  "Total",
                  moneyFromCents(totalSales),
                  color: Colors.blue.shade50,
                ),
                const SizedBox(width: 10),
                statCard(
                  "Expected",
                  moneyFromCents(expectedCash),
                  color: Colors.orange.shade50,
                ),
              ],
            ),

            const SizedBox(height: 20),

            /// INPUT
            TextField(
              controller: actualCashC,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Actual Cash (€)",
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),

            const SizedBox(height: 20),

            /// DIFFERENCE BIG
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: difference >= 0
                    ? Colors.green.shade50
                    : Colors.red.shade50,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Text("Difference"),
                  const SizedBox(height: 8),
                  Text(
                    moneyFromCents(difference),
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: difference >= 0 ? Colors.green : Colors.red,
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),

            /// BUTTON
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _settle,
                child: const Text("SETTLE"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

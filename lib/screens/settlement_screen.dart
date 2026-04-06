import 'package:flutter/material.dart';
import '../auth/session.dart';
import '../data/dao_day_sessions.dart';
import '../data/dao_payments.dart';
import '../util/money.dart';

class SettlementScreen extends StatefulWidget {
  const SettlementScreen({super.key});

  @override
  State<SettlementScreen> createState() => _SettlementScreenState();
}

class _SettlementScreenState extends State<SettlementScreen> {
  bool loading = true;
  bool settling = false;

  DaySessionRow? session;

  int cashSales = 0;
  int cardSales = 0;

  final actualCashC = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    actualCashC.dispose();
    super.dispose();
  }

  int get totalSales => cashSales + cardSales;
  int get expectedCash => (session?.openingCashCents ?? 0) + cashSales;

  int get actualCash {
    final value = double.tryParse(actualCashC.text.trim().replaceAll(',', '.')) ?? 0;
    return (value * 100).round();
  }

  int get difference => actualCash - expectedCash;

  String _todayKey(DateTime now) {
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> _load() async {
    setState(() => loading = true);

    final now = DateTime.now();
    final date = _todayKey(now);

    session = await DaySessionsDao.I.getSessionForDate(date);

    if (session == null) {
      await DaySessionsDao.I.createSession(
        date: date,
        openingCashCents: 0,
      );
      session = await DaySessionsDao.I.getSessionForDate(date);
    }

    cashSales = await PaymentsDao.I.sumCashPayments(now);
    cardSales = await PaymentsDao.I.sumCardPayments(now);

    if (!mounted) return;
    setState(() => loading = false);
  }

  Future<void> _settle() async {
    if (session == null || settling) return;

    setState(() => settling = true);

    try {
      await DaySessionsDao.I.settleSession(
        date: session!.date,
        actualCashCents: actualCash,
        settledBy: Session.I.current!.id,
        notes: null,
      );

      if (!mounted) return;

      setState(() {
        // Pas settlement-it ekrani resetohet menjëherë në 0.00
        // që të mos shfaqen prapë totalet e vjetra në UI.
        cashSales = 0;
        cardSales = 0;
        actualCashC.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Day settlement u kry me sukses.')),
      );

      Navigator.pop(context, true);
    } catch (e) {
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

  Widget _statCard(String title, String value, {Color? color}) {
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
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _differenceCard() {
    final ok = difference >= 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ok ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Text('Difference'),
          const SizedBox(height: 8),
          Text(
            moneyFromCents(difference),
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: ok ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Day Settlement')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                _statCard('Cash', moneyFromCents(cashSales)),
                const SizedBox(width: 10),
                _statCard('Card', moneyFromCents(cardSales)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _statCard(
                  'Total',
                  moneyFromCents(totalSales),
                  color: Colors.blue.shade50,
                ),
                const SizedBox(width: 10),
                _statCard(
                  'Expected',
                  moneyFromCents(expectedCash),
                  color: Colors.orange.shade50,
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: actualCashC,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Actual Cash (€)',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 20),
            _differenceCard(),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: settling ? null : _settle,
                child: Text(settling ? 'DUKE RUJT...' : 'SETTLE'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

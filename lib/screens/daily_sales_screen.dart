import 'package:flutter/material.dart';
import '../data/dao_orders.dart';
import '../util/money.dart';

const _kBg = Color(0xFF0A0E1A);
const _kSurface = Color(0xFF111827);
const _kCard = Color(0xFF1A2234);
const _kBorder = Color(0xFF1E3252);
const _kAccent = Color(0xFF4F6EF7);
const _kGreen = Color(0xFF22C55E);
const _kText = Color(0xFFE2E8F0);
const _kTextSub = Color(0xFF7C8DB0);

enum _SalesPeriod { today, week, month, custom }

class DailySalesScreen extends StatefulWidget {
  const DailySalesScreen({super.key});

  @override
  State<DailySalesScreen> createState() => _DailySalesScreenState();
}

class _DailySalesScreenState extends State<DailySalesScreen> {
  _SalesPeriod _period = _SalesPeriod.month;
  DateTime? _customStart;
  DateTime? _customEnd;
  bool _loading = true;
  List<DailySaleRow> _rows = [];
  int _totalCents = 0;
  int _totalOrders = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  int _startMs() {
    final now = DateTime.now();
    switch (_period) {
      case _SalesPeriod.today:
        return DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
      case _SalesPeriod.week:
        final weekday = now.weekday;
        final monday = now.subtract(Duration(days: weekday - 1));
        return DateTime(monday.year, monday.month, monday.day)
            .millisecondsSinceEpoch;
      case _SalesPeriod.month:
        return DateTime(now.year, now.month, 1).millisecondsSinceEpoch;
      case _SalesPeriod.custom:
        return _customStart?.millisecondsSinceEpoch ??
            DateTime(now.year, now.month, 1).millisecondsSinceEpoch;
    }
  }

  int _endMs() {
    final now = DateTime.now();
    if (_period == _SalesPeriod.custom && _customEnd != null) {
      return DateTime(
        _customEnd!.year,
        _customEnd!.month,
        _customEnd!.day,
        23,
        59,
        59,
        999,
      ).millisecondsSinceEpoch;
    }
    return DateTime(now.year, now.month, now.day, 23, 59, 59, 999)
        .millisecondsSinceEpoch;
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rows = await OrdersDao.I.getDailySales(
        startMs: _startMs(),
        endMs: _endMs(),
      );
      int total = 0;
      int orders = 0;
      for (final r in rows) {
        total += r.totalCents;
        orders += r.ordersCount;
      }
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _totalCents = total;
        _totalOrders = orders;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickCustomRange() async {
    final start = await showDatePicker(
      context: context,
      initialDate: _customStart ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (ctx, child) => _darkDatePicker(child),
    );
    if (start == null || !mounted) return;
    final end = await showDatePicker(
      context: context,
      initialDate: start,
      firstDate: start,
      lastDate: DateTime(2100),
      builder: (ctx, child) => _darkDatePicker(child),
    );
    if (end == null || !mounted) return;
    setState(() {
      _period = _SalesPeriod.custom;
      _customStart = start;
      _customEnd = end;
    });
    await _load();
  }

  Widget _darkDatePicker(Widget? child) {
    return Theme(
      data: ThemeData.dark().copyWith(
        colorScheme: const ColorScheme.dark(
          primary: _kAccent,
          onPrimary: Colors.white,
          surface: _kCard,
          onSurface: _kText,
        ),
        dialogTheme: const DialogThemeData(backgroundColor: _kSurface),
      ),
      child: child!,
    );
  }

  String _formatDay(String isoDay) {
    if (isoDay.isEmpty) return '';
    try {
      final dt = DateTime.parse(isoDay);
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'Maj', 'Qer',
        'Kor', 'Gus', 'Sht', 'Tet', 'Nën', 'Dhj',
      ];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return isoDay;
    }
  }

  String _periodLabel() {
    switch (_period) {
      case _SalesPeriod.today:
        return 'Sot';
      case _SalesPeriod.week:
        return 'Kjo Javë';
      case _SalesPeriod.month:
        return 'Ky Muaj';
      case _SalesPeriod.custom:
        if (_customStart == null || _customEnd == null) return 'Custom';
        return '${_customStart!.day}/${_customStart!.month} – ${_customEnd!.day}/${_customEnd!.month}/${_customEnd!.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildPeriodBar(),
            if (_loading)
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(color: _kAccent),
                ),
              )
            else
              Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _kCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _kBorder),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: _kText, size: 18),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Shitjet e Ditës',
                  style: TextStyle(
                    color: _kText,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  _periodLabel(),
                  style: const TextStyle(color: _kTextSub, fontSize: 13),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded, color: _kTextSub),
            tooltip: 'Refresh',
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        children: [
          _periodBtn(_SalesPeriod.today, 'Sot'),
          _periodBtn(_SalesPeriod.week, 'Javë'),
          _periodBtn(_SalesPeriod.month, 'Muaj'),
          Expanded(
            child: GestureDetector(
              onTap: _pickCustomRange,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _period == _SalesPeriod.custom
                      ? _kAccent
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.calendar_month_rounded,
                        size: 14,
                        color: _period == _SalesPeriod.custom
                            ? Colors.white
                            : _kTextSub,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Custom',
                        style: TextStyle(
                          color: _period == _SalesPeriod.custom
                              ? Colors.white
                              : _kTextSub,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _periodBtn(_SalesPeriod p, String label) {
    final active = _period == p;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _period = p);
          _load();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? _kAccent : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: active ? Colors.white : _kTextSub,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Summary cards
        Row(
          children: [
            Expanded(
              child: _summaryCard(
                label: 'Total Shitje',
                value: moneyFromCents(_totalCents),
                icon: Icons.euro_rounded,
                color: _kGreen,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _summaryCard(
                label: 'Porosi',
                value: '$_totalOrders',
                icon: Icons.receipt_long_rounded,
                color: _kAccent,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        if (_rows.isEmpty)
          Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: _kCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _kBorder),
            ),
            child: const Column(
              children: [
                Icon(Icons.receipt_long_outlined,
                    color: _kTextSub, size: 48),
                SizedBox(height: 12),
                Text(
                  'Asnjë shitje për këtë periudhë.',
                  style: TextStyle(color: _kTextSub, fontSize: 15),
                ),
              ],
            ),
          )
        else ...[
          const Text(
            'Shitjet sipas ditës',
            style: TextStyle(
              color: _kText,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          ..._rows.map((row) => _dayCard(row)),
        ],
      ],
    );
  }

  Widget _summaryCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: _kTextSub, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _dayCard(DailySaleRow row) {
    final pct = _totalCents > 0
        ? (row.totalCents / _totalCents).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _kAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.calendar_today_rounded,
                    color: _kAccent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatDay(row.day),
                      style: const TextStyle(
                        color: _kText,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${row.ordersCount} porosi',
                      style: const TextStyle(color: _kTextSub, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Text(
                moneyFromCents(row.totalCents),
                style: const TextStyle(
                  color: _kGreen,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: _kBorder,
              color: _kAccent,
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }
}

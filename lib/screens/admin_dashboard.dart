import 'package:flutter/material.dart';
import '../util/money.dart';
import '../auth/dao_users.dart';
import '../auth/session.dart';
import '../auth/roles.dart';
import '../data/db.dart';
import '../data/dao_orders.dart';
import '../data/dao_settlements.dart';
import '../data/dao_tables.dart';
import 'manage_users_screen.dart';
import 'waiter_settlement_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

enum Period { today, custom }

class _AdminDashboardState extends State<AdminDashboard> {
  bool loading = true;
  List<AppUserRow> waiters = [];

  Period period = Period.today;
  DateTime? customStart;
  DateTime? customEnd;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    final all = await UsersDao.I.listUsers();
    waiters = all.where((u) => u.role == UserRole.waiter).toList();
    setState(() => loading = false);
  }

  int _startMs() {
    if (period == Period.today) {
      final d = DateTime.now();
      final s = DateTime(d.year, d.month, d.day);
      return s.millisecondsSinceEpoch;
    }
    return customStart?.millisecondsSinceEpoch ?? 0;
  }

  int _endMs() {
    if (period == Period.today) {
      final d = DateTime.now();
      final e = DateTime(d.year, d.month, d.day, 23, 59, 59, 999);
      return e.millisecondsSinceEpoch;
    }
    return customEnd?.millisecondsSinceEpoch ??
        DateTime.now().millisecondsSinceEpoch;
  }

  Future<int> _getCurrentTotalForWaiter(int waiterId) async {
    final db = await AppDb.I.db;

    final rows = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(oi.line_total_cents), 0) AS total_cents
      FROM orders o
      LEFT JOIN order_items oi ON oi.order_id = o.id
      WHERE o.waiter_id = ?
      ''',
      [waiterId],
    );

    return (rows.first['total_cents'] as num?)?.toInt() ?? 0;
  }

  Future<int> _getCurrentDaySumForWaiter(int waiterId) async {
    final db = await AppDb.I.db;

    final start = _startMs();
    final end = _endMs();

    final rows = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(oi.line_total_cents), 0) AS total_cents
      FROM orders o
      LEFT JOIN order_items oi ON oi.order_id = o.id
      WHERE o.waiter_id = ?
        AND o.created_at >= ?
        AND o.created_at <= ?
      ''',
      [waiterId, start, end],
    );

    return (rows.first['total_cents'] as num?)?.toInt() ?? 0;
  }

  Future<void> _toggleShift(AppUserRow u) async {
    await UsersDao.I.setShift(u.id, !u.isOnShift);
    await _load();
  }

  Future<void> _pickCustomRange() async {
    final start = await showDatePicker(
      context: context,
      initialDate: customStart ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (start == null) return;

    final end = await showDatePicker(
      context: context,
      initialDate: start,
      firstDate: start,
      lastDate: DateTime(2100),
    );
    if (end == null) return;

    setState(() {
      period = Period.custom;
      customStart = DateTime(start.year, start.month, start.day);
      customEnd = DateTime(end.year, end.month, end.day, 23, 59, 59, 999);
    });
  }

  Future<void> _settleDialog(AppUserRow u) async {
    final start = u.shiftStartedAt ?? _startMs();
    final end = DateTime.now().millisecondsSinceEpoch;

    final totals = await SettlementsDao.I.getUnsettledTotals(
      waiterId: u.id,
      startMs: start,
      endMs: end,
    );

    final total = totals['total'] ?? 0;
    final cash = totals['cash'] ?? 0;
    final card = totals['card'] ?? 0;
    final expectedCash = totals['expectedCash'] ?? 0;

    final orders = await OrdersDao.I.countOrdersByWaiterInRange(
      u.id,
      start,
      end,
    );

    final actualCashC = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: const Color(0xFF121826),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF7C3AED), Color(0xFF3B82F6)],
                      ),
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Settle ${u.fullName ?? u.username}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _settleInfoRow('Total Sales', moneyFromCents(total)),
              _settleInfoRow('Cash Collected', moneyFromCents(cash)),
              _settleInfoRow('Card Payments', moneyFromCents(card)),
              _settleInfoRow('Expected Cash', moneyFromCents(expectedCash)),
              _settleInfoRow('Orders', '$orders'),
              const SizedBox(height: 16),
              TextField(
                controller: actualCashC,
                style: const TextStyle(color: Colors.white),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Actual Cash Counted (€)',
                  labelStyle: const TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.06),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: Colors.white.withOpacity(0.08),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: Colors.white.withOpacity(0.08),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFF7C3AED)),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: BorderSide(color: Colors.white.withOpacity(0.15)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: const Color(0xFF7C3AED),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text('Confirm Settlement'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (ok != true) return;

    final actualCash =
        (double.tryParse(actualCashC.text.replaceAll(',', '.')) ?? 0) * 100;

    await SettlementsDao.I.settleWaiter(
      waiterId: u.id,
      startMs: start,
      endMs: end,
      totalCents: total,
      cashCents: cash,
      cardCents: card,
      expectedCashCents: expectedCash,
      actualCashCents: actualCash.toInt(),
      notes: null,
      settledBy: Session.I.current!.id,
    );

    await UsersDao.I.setShift(u.id, false);

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Settlement recorded')));
    await _load();
  }

  Widget _settleInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteUser(AppUserRow u) async {
    final me = Session.I.current!;
    if (u.id == me.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot delete your own account')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete User'),
        content: Text(
          'Are you sure you want to delete ${u.fullName ?? u.username}? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await UsersDao.I.deleteUser(u.id);
      await _load();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('User ${u.fullName ?? u.username} deleted')),
      );
    }
  }

  String _formatRange() {
    if (period == Period.today) return 'Today';
    if (customStart == null || customEnd == null) return 'Custom';
    return '${customStart!.day}/${customStart!.month}/${customStart!.year} - '
        '${customEnd!.day}/${customEnd!.month}/${customEnd!.year}';
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required List<Color> colors,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: colors.last.withOpacity(0.22),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.16),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: Colors.white),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final me = Session.I.current!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F172A), Color(0xFF1E1B4B), Color(0xFF312E81)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF312E81).withOpacity(0.25),
            blurRadius: 28,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Wrap(
        runSpacing: 18,
        spacing: 18,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Icon(
              Icons.admin_panel_settings_rounded,
              size: 34,
              color: Colors.white,
            ),
          ),
          SizedBox(
            width: 420,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Admin Dashboard',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Welcome back, ${me.fullName ?? me.username}. Manage staff, shifts and settlements with a premium overview.',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildTopActions() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        ElevatedButton.icon(
          onPressed: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const ManageUsersScreen())),
          style: ElevatedButton.styleFrom(
            elevation: 0,
            backgroundColor: const Color(0xFF111827),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          icon: const Icon(Icons.people_alt_rounded),
          label: const Text('Manage Staff'),
        ),
        ElevatedButton.icon(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const WaiterSettlementScreen()),
          ),
          style: ElevatedButton.styleFrom(
            elevation: 0,
            backgroundColor: const Color(0xFF7C3AED),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          icon: const Icon(Icons.receipt_long_rounded),
          label: const Text('Settlement History'),
        ),
        OutlinedButton.icon(
          onPressed: _load,
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF111827),
            side: BorderSide(color: Colors.black.withOpacity(0.08)),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Refresh'),
        ),
      ],
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Wrap(
        spacing: 14,
        runSpacing: 14,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text(
            'Filter Period',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.black.withOpacity(0.06)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<Period>(
                value: period,
                borderRadius: BorderRadius.circular(18),
                items: const [
                  DropdownMenuItem(value: Period.today, child: Text('Today')),
                  DropdownMenuItem(value: Period.custom, child: Text('Custom')),
                ],
                onChanged: (v) async {
                  if (v == null) return;
                  if (v == Period.custom) {
                    await _pickCustomRange();
                  } else {
                    setState(() {
                      period = Period.today;
                      customStart = null;
                      customEnd = null;
                    });
                  }
                },
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.calendar_month_rounded,
                  size: 18,
                  color: Color(0xFF6B7280),
                ),
                const SizedBox(width: 8),
                Text(
                  _formatRange(),
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(AppUserRow u) {
    final displayName = (u.fullName?.trim().isNotEmpty ?? false)
        ? u.fullName!.trim()
        : u.username;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: LinearGradient(
                    colors: u.isOnShift
                        ? const [Color(0xFF10B981), Color(0xFF059669)]
                        : const [Color(0xFF94A3B8), Color(0xFF64748B)],
                  ),
                ),
                child: Icon(
                  u.role == UserRole.admin
                      ? Icons.security_rounded
                      : Icons.person_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: const TextStyle(
                        color: Color(0xFF111827),
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '@${u.username} • ${roleToString(u.role)}',
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              _statusBadge(u.isOnShift),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FutureBuilder<int>(
                future: _getCurrentTotalForWaiter(u.id),
                builder: (context, snap) {
                  return _miniMetric(
                    icon: Icons.payments_rounded,
                    label: 'Total',
                    value: moneyFromCents(snap.data ?? 0),
                  );
                },
              ),
              FutureBuilder<int>(
                future: _getCurrentDaySumForWaiter(u.id),
                builder: (context, snap) {
                  return _miniMetric(
                    icon: Icons.shopping_bag_rounded,
                    label: 'Daily Sum',
                    value: moneyFromCents(snap.data ?? 0),
                  );
                },
              ),
              FutureBuilder<int>(
                future: OrdersDao.I.countOpenOrdersByWaiter(u.id),
                builder: (context, snap) {
                  return _miniMetric(
                    icon: Icons.receipt_long_rounded,
                    label: 'Open Orders',
                    value: '${snap.data ?? 0}',
                  );
                },
              ),
              FutureBuilder<int>(
                future: TablesDao.I.countTablesByWaiter(u.id),
                builder: (context, snap) {
                  return _miniMetric(
                    icon: Icons.table_restaurant_rounded,
                    label: 'Tables',
                    value: '${snap.data ?? 0}',
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ElevatedButton.icon(
                onPressed: () => _toggleShift(u),
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: u.isOnShift
                      ? const Color(0xFFEF4444)
                      : const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: Icon(
                  u.isOnShift ? Icons.pause_circle : Icons.play_circle,
                ),
                label: Text(u.isOnShift ? 'End Shift' : 'Start Shift'),
              ),
              ElevatedButton.icon(
                onPressed: () => _settleDialog(u),
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: const Color(0xFF7C3AED),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.account_balance_wallet_rounded),
                label: const Text('Settle'),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ManageUsersScreen(),
                    ),
                  );
                  await _load();
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF111827),
                  side: BorderSide(color: Colors.black.withOpacity(0.08)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.settings_rounded),
                label: const Text('Manage'),
              ),
              OutlinedButton.icon(
                onPressed: () => _deleteUser(u),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: BorderSide(color: Colors.red.withOpacity(0.20)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Delete'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniMetric({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      constraints: const BoxConstraints(minWidth: 170),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: const Color(0xFF7C3AED)),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  color: Color(0xFF111827),
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: active
            ? const Color(0xFF10B981).withOpacity(0.12)
            : Colors.grey.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        active ? 'Active Shift' : 'Inactive',
        style: TextStyle(
          color: active ? const Color(0xFF059669) : Colors.grey[700],
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final me = Session.I.current!;
    if (me.role != UserRole.admin) {
      return const Scaffold(
        body: Center(
          child: Text('Vetëm Admin mundet me hy te Admin Dashboard'),
        ),
      );
    }

    final activeCount = waiters.where((e) => e.isOnShift).length;
    final inactiveCount = waiters.length - activeCount;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: SafeArea(
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.all(18),
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 18),
                    _buildTopActions(),
                    const SizedBox(height: 18),
                    LayoutBuilder(
                      builder: (context, c) {
                        final wide = c.maxWidth > 900;
                        if (!wide) {
                          return Column(
                            children: [
                              _buildStatCard(
                                icon: Icons.groups_rounded,
                                title: 'Total Waiters',
                                value: '${waiters.length}',
                                colors: const [
                                  Color(0xFF0EA5E9),
                                  Color(0xFF2563EB),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _buildStatCard(
                                icon: Icons.play_circle_fill_rounded,
                                title: 'Active Shifts',
                                value: '$activeCount',
                                colors: const [
                                  Color(0xFF10B981),
                                  Color(0xFF059669),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _buildStatCard(
                                icon: Icons.pause_circle_filled_rounded,
                                title: 'Inactive Staff',
                                value: '$inactiveCount',
                                colors: const [
                                  Color(0xFFF59E0B),
                                  Color(0xFFD97706),
                                ],
                              ),
                            ],
                          );
                        }

                        return Row(
                          children: [
                            Expanded(
                              child: _buildStatCard(
                                icon: Icons.groups_rounded,
                                title: 'Total Waiters',
                                value: '${waiters.length}',
                                colors: const [
                                  Color(0xFF0EA5E9),
                                  Color(0xFF2563EB),
                                ],
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: _buildStatCard(
                                icon: Icons.play_circle_fill_rounded,
                                title: 'Active Shifts',
                                value: '$activeCount',
                                colors: const [
                                  Color(0xFF10B981),
                                  Color(0xFF059669),
                                ],
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: _buildStatCard(
                                icon: Icons.pause_circle_filled_rounded,
                                title: 'Inactive Staff',
                                value: '$inactiveCount',
                                colors: const [
                                  Color(0xFFF59E0B),
                                  Color(0xFFD97706),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 18),
                    _buildFilterBar(),
                    const SizedBox(height: 18),
                    const Text(
                      'Staff Overview',
                      style: TextStyle(
                        color: Color(0xFF111827),
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Modern overview of waiter activity, totals, open orders and actions.',
                      style: TextStyle(color: Color(0xFF6B7280), fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    if (waiters.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: const Center(
                          child: Text(
                            'No waiter accounts found.',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ),
                      )
                    else
                      ...waiters.map(_buildUserCard),
                  ],
                ),
              ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../util/money.dart';
import '../auth/dao_users.dart';
import '../auth/session.dart';
import '../auth/roles.dart';
import '../data/dao_sales.dart';
import '../data/dao_payments.dart';
import '../data/dao_orders.dart';
import '../data/dao_settlements.dart';
import '../data/dao_tables.dart';
import '../theme/app_theme.dart';
import '../theme/app_widgets.dart';
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

  // period
  Period period = Period.today;
  DateTime? customStart;
  DateTime? customEnd;

  Future<void> _load() async {
    setState(() => loading = true);
    final all = await UsersDao.I.listUsers();
    // filter waiters only
    waiters = all.where((u) => u.role == UserRole.waiter).toList();
    // ensure totals loaded via SalesDao
    setState(() => loading = false);
  }

  @override
  void initState() {
    super.initState();
    _load();
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

  Future<void> _toggleShift(AppUserRow u) async {
    await UsersDao.I.setShift(u.id, !u.isOnShift);
    await _load();
  }

  Widget _waiterCard(AppUserRow u) {
    final textColor = Theme.of(context).colorScheme.onBackground;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  child: Icon(
                    u.role == UserRole.admin ? Icons.security : Icons.person,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        u.fullName?.isNotEmpty ?? false
                            ? u.fullName!
                            : u.username,
                        style: AppTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(roleToString(u.role), style: AppTheme.bodySmall),
                    ],
                  ),
                ),
                Column(
                  children: [
                    if (u.isOnShift)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.success.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Active',
                          style: TextStyle(
                            color: AppTheme.success,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Inactive',
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () => _toggleShift(u),
                      child: Text(u.isOnShift ? 'End Shift' : 'Start Shift'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            FutureBuilder<int>(
              future: OrdersDao.I.getDaySum(
                u.id,
                u.shiftStartedAt ?? DateTime.now().millisecondsSinceEpoch,
              ),
              builder: (context, snap) {
                final daySum = snap.data ?? 0;
                return Text(
                  'DaySum: ${moneyFromCents(daySum)}',
                  style: AppTheme.bodyMedium.copyWith(color: textColor),
                );
              },
            ),
            const SizedBox(height: 6),
            FutureBuilder<int>(
              future: OrdersDao.I.countOpenOrdersByWaiter(u.id),
              builder: (context, snap) {
                final open = snap.data ?? 0;
                if (open > 0) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.warning.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Open: $open',
                      style: TextStyle(
                        color: AppTheme.warning,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  );
                }
                return Text(
                  'Open orders: 0',
                  style: AppTheme.bodySmall.copyWith(color: textColor),
                );
              },
            ),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      // open settlement dialog
                      await _settleDialog(u);
                    },
                    child: const Text('Settle'),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () async {
                    // open edit user screen
                    await Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => ManageUsersScreen()),
                    );
                    await _load();
                  },
                  child: const Text('Manage'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _settleDialog(AppUserRow u) async {
    // compute totals for waiter's shift
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
      builder: (_) => AlertDialog(
        title: Text('Settle ${u.fullName ?? u.username}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total Sales: ${moneyFromCents(total)}'),
            Text('Cash Collected: ${moneyFromCents(cash)}'),
            Text('Card Payments: ${moneyFromCents(card)}'),
            Text('Expected Cash: ${moneyFromCents(expectedCash)}'),
            Text('Orders: $orders'),
            const SizedBox(height: 16),
            TextField(
              controller: actualCashC,
              decoration: const InputDecoration(
                labelText: 'Actual Cash Counted (€)',
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Settle'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    final actualCash =
        (double.tryParse(actualCashC.text.replaceAll(',', '.')) ?? 0) * 100;

    // create settlement and mark orders as settled
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Settlement recorded')));
    await _load();
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('User ${u.fullName ?? u.username} deleted')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = Session.I.current!;
    if (me.role != UserRole.admin) {
      return const Center(
        child: Text('Vetëm Admin mundet me hy te Admin Dashboard'),
      );
    }

    final textColor = Theme.of(context).colorScheme.onBackground;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
          const SizedBox(width: 6),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => ManageUsersScreen()),
                  ),
                  icon: const Icon(Icons.people),
                  label: const Text('Manage Staff'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const WaiterSettlementScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.calculate),
                  label: const Text('Settlement'),
                ),
                const SizedBox(width: 12),
                Text('Staff / Waiters', style: TextStyle(color: textColor)),
                const Spacer(),
                DropdownButton<Period>(
                  value: period,
                  items: const [
                    DropdownMenuItem(value: Period.today, child: Text('Today')),
                    DropdownMenuItem(
                      value: Period.custom,
                      child: Text('Custom'),
                    ),
                  ],
                  onChanged: (v) async {
                    if (v == Period.custom) {
                      final start = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
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
                        customStart = DateTime(
                          start.year,
                          start.month,
                          start.day,
                        );
                        customEnd = DateTime(
                          end.year,
                          end.month,
                          end.day,
                          23,
                          59,
                          59,
                          999,
                        );
                      });
                    } else {
                      setState(() => period = Period.today);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columns: [
                            DataColumn(
                              label: Text(
                                'Name',
                                style: TextStyle(color: textColor),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Role',
                                style: TextStyle(color: textColor),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Shift',
                                style: TextStyle(color: textColor),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Total',
                                style: TextStyle(color: textColor),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Tables',
                                style: TextStyle(color: textColor),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Actions',
                                style: TextStyle(color: textColor),
                              ),
                            ),
                          ],
                          rows: waiters.map((u) {
                            return DataRow(
                              cells: [
                                DataCell(
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        child: Icon(
                                          u.role == UserRole.admin
                                              ? Icons.security
                                              : Icons.person,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            u.fullName?.isNotEmpty ?? false
                                                ? u.fullName!
                                                : u.username,
                                            style: AppTheme.titleSmall,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '@${u.username}',
                                            style: AppTheme.bodySmall,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    roleToString(u.role),
                                    style: TextStyle(color: textColor),
                                  ),
                                ),
                                DataCell(
                                  u.isOnShift
                                      ? Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppTheme.success.withOpacity(
                                              0.12,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Text(
                                            'Active',
                                            style: TextStyle(
                                              color: AppTheme.success,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        )
                                      : Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.withOpacity(
                                              0.12,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Text(
                                            'Inactive',
                                            style: TextStyle(
                                              color: Colors.grey[700],
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                ),
                                DataCell(
                                  FutureBuilder<int>(
                                    future: SalesDao.I.sumTotalCents(
                                      range: RangeKind.day,
                                      anchor: DateTime.now(),
                                      waiterId: u.id,
                                    ),
                                    builder: (context, snap) {
                                      final total = snap.data ?? 0;
                                      return Text(
                                        moneyFromCents(total),
                                        style: TextStyle(color: textColor),
                                      );
                                    },
                                  ),
                                ),
                                DataCell(
                                  FutureBuilder<int>(
                                    future: TablesDao.I.countTablesByWaiter(
                                      u.id,
                                    ),
                                    builder: (context, snap) {
                                      final tables = snap.data ?? 0;
                                      return Text(
                                        '$tables',
                                        style: TextStyle(color: textColor),
                                      );
                                    },
                                  ),
                                ),
                                DataCell(
                                  Row(
                                    children: [
                                      ElevatedButton(
                                        onPressed: () => _settleDialog(u),
                                        child: const Text('Settle'),
                                      ),
                                      const SizedBox(width: 8),
                                      OutlinedButton(
                                        onPressed: () async {
                                          await Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  ManageUsersScreen(),
                                            ),
                                          );
                                          await _load();
                                        },
                                        child: const Text('Manage'),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        onPressed: () => _deleteUser(u),
                                        icon: const Icon(
                                          Icons.delete,
                                          color: Colors.red,
                                        ),
                                        tooltip: 'Delete User',
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

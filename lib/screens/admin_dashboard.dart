import 'package:flutter/material.dart';
import '../auth/dao_users.dart';
import '../auth/roles.dart';
import '../auth/session.dart';
import '../data/dao_orders.dart';
import '../data/dao_settlements.dart';
import '../data/dao_tables.dart';
import '../util/money.dart';
import 'daily_sales_screen.dart';
import 'manage_users_screen.dart';

// ── Palette ──────────────────────────────────────────────────────────────────
const _kBg = Color(0xFF060C18);
const _kSurface = Color(0xFF0F1825);
const _kCard = Color(0xFF141E30);
const _kBorder = Color(0xFF1E3050);
const _kAccent = Color(0xFF4F6EF7);
const _kAccentLight = Color(0xFF6C83F8);
const _kGreen = Color(0xFF22C55E);
const _kGreenDim = Color(0xFF15803D);
const _kRed = Color(0xFFEF4444);
const _kAmber = Color(0xFFFBBF24);
const _kPurple = Color(0xFFA855F7);
const _kText = Color(0xFFE2E8F0);
const _kTextSub = Color(0xFF7C8DB0);
const _kTextMuted = Color(0xFF3D5070);

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _tab = 0;
  bool _loading = true;

  List<AppUserRow> _waiters = [];

  // overview stats
  int _todayTotal = 0;
  int _todayOrders = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final all = await UsersDao.I.listUsers();
      final todayTotal = await OrdersDao.I.getTodayTotal();
      final todayOrders = await OrdersDao.I.getTodayOrderCount();
      if (!mounted) return;
      setState(() {
        _waiters = all.where((u) => u.role == UserRole.waiter).toList();
        _todayTotal = todayTotal;
        _todayOrders = todayOrders;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Navigation labels ──────────────────────────────────────────────────────
  static const _navItems = [
    (Icons.dashboard_rounded, 'Pasqyra'),
    (Icons.groups_rounded, 'Punonjësit'),
    (Icons.table_restaurant_rounded, 'Tavolinat'),
  ];

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final me = Session.I.current!;
    if (me.role != UserRole.admin) {
      return const Scaffold(
        backgroundColor: _kBg,
        body: Center(
          child: Text('Access denied', style: TextStyle(color: _kText)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (ctx, constraints) {
            final wide = constraints.maxWidth > 820;
            if (wide) {
              return Row(
                children: [
                  _buildSidebar(),
                  Expanded(child: _buildBody()),
                ],
              );
            }
            return Column(
              children: [
                Expanded(child: _buildBody()),
                _buildBottomNav(),
              ],
            );
          },
        ),
      ),
    );
  }

  // ── Sidebar (desktop) ──────────────────────────────────────────────────────
  Widget _buildSidebar() {
    final me = Session.I.current!;
    return Container(
      width: 220,
      decoration: const BoxDecoration(
        color: _kSurface,
        border: Border(right: BorderSide(color: _kBorder)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 28),
          // Logo area
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_kAccent, _kPurple],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.point_of_sale_rounded,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 10),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('EasyPOS',
                        style: TextStyle(
                            color: _kText,
                            fontWeight: FontWeight.w900,
                            fontSize: 15)),
                    Text('Admin Panel',
                        style: TextStyle(color: _kTextSub, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          // Nav items
          ..._navItems.asMap().entries.map((e) {
            final i = e.key;
            final item = e.value;
            return _sidebarItem(
                icon: item.$1, label: item.$2, index: i);
          }),
          const Spacer(),
          // Sales button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: _actionBtn(
              icon: Icons.bar_chart_rounded,
              label: 'Shitjet e Ditës',
              color: _kAmber,
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const DailySalesScreen())),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: _actionBtn(
              icon: Icons.manage_accounts_rounded,
              label: 'Menaxho Staff',
              color: _kAccent,
              onTap: () async {
                await Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ManageUsersScreen()));
                _load();
              },
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _kCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _kBorder),
              ),
              child: Row(
                children: [
                  _avatar(me.fullName ?? me.username, 32),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          me.fullName ?? me.username,
                          style: const TextStyle(
                              color: _kText,
                              fontWeight: FontWeight.w700,
                              fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const Text('Admin',
                            style:
                                TextStyle(color: _kTextSub, fontSize: 11)),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Session.I.logout();
                      Navigator.of(context)
                          .pushReplacementNamed('/login');
                    },
                    child: const Icon(Icons.logout_rounded,
                        color: _kRed, size: 18),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sidebarItem(
      {required IconData icon, required String label, required int index}) {
    final active = _tab == index;
    return GestureDetector(
      onTap: () => setState(() => _tab = index),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: active
              ? _kAccent.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: active
              ? Border.all(color: _kAccent.withValues(alpha: 0.30))
              : null,
        ),
        child: Row(
          children: [
            Icon(icon,
                color: active ? _kAccentLight : _kTextSub, size: 20),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: active ? _kAccentLight : _kTextSub,
                fontWeight:
                    active ? FontWeight.w700 : FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  // ── Bottom nav (mobile) ───────────────────────────────────────────────────
  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: _kSurface,
        border: Border(top: BorderSide(color: _kBorder)),
      ),
      child: Row(
        children: _navItems.asMap().entries.map((e) {
          final i = e.key;
          final item = e.value;
          final active = _tab == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _tab = i),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(item.$1,
                        color: active ? _kAccentLight : _kTextMuted,
                        size: 22),
                    const SizedBox(height: 4),
                    Text(
                      item.$2,
                      style: TextStyle(
                        color: active ? _kAccentLight : _kTextMuted,
                        fontSize: 11,
                        fontWeight: active
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Main body ─────────────────────────────────────────────────────────────
  Widget _buildBody() {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: _kAccent));
    }
    return IndexedStack(
      index: _tab,
      children: [
        _OverviewTab(
          waiters: _waiters,
          todayTotal: _todayTotal,
          todayOrders: _todayOrders,
          onRefresh: _load,
          onNavigateSales: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const DailySalesScreen())),
        ),
        _StaffTab(waiters: _waiters, onRefresh: _load),
        _TablesTab(onRefresh: _load),
      ],
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  Widget _avatar(String name, double size) {
    final letter = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_kAccent, _kPurple],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size / 3),
      ),
      child: Center(
        child: Text(
          letter,
          style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: size * 0.42),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 1: OVERVIEW
// ══════════════════════════════════════════════════════════════════════════════
class _OverviewTab extends StatelessWidget {
  final List<AppUserRow> waiters;
  final int todayTotal;
  final int todayOrders;
  final VoidCallback onRefresh;
  final VoidCallback onNavigateSales;

  const _OverviewTab({
    required this.waiters,
    required this.todayTotal,
    required this.todayOrders,
    required this.onRefresh,
    required this.onNavigateSales,
  });

  int get _activeCount => waiters.where((w) => w.isOnShift).length;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      color: _kAccent,
      backgroundColor: _kCard,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildTopBar(context),
          const SizedBox(height: 24),
          _buildHeroCard(),
          const SizedBox(height: 16),
          _buildStatsRow(),
          const SizedBox(height: 24),
          _buildQuickActions(context),
          const SizedBox(height: 24),
          _buildWaiterSummary(),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    final me = Session.I.current!;
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Mirëmëngjes'
        : hour < 18
            ? 'Mirëdita'
            : 'Mirëmbrëma';

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$greeting, ${me.fullName?.split(' ').first ?? me.username}!',
                style: const TextStyle(
                    color: _kText,
                    fontSize: 22,
                    fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              Text(
                _formatDate(DateTime.now()),
                style:
                    const TextStyle(color: _kTextSub, fontSize: 13),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: onRefresh,
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _kCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _kBorder),
            ),
            child: const Icon(Icons.refresh_rounded,
                color: _kTextSub, size: 20),
          ),
        ),
      ],
    );
  }

  Widget _buildHeroCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A2860), Color(0xFF0F1A40), _kBg],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _kAccent.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _kGreen.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: _kGreen.withValues(alpha: 0.30)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.circle, color: _kGreen, size: 8),
                    SizedBox(width: 6),
                    Text('Live',
                        style: TextStyle(
                            color: _kGreen,
                            fontWeight: FontWeight.w700,
                            fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Total Shitjet Sot',
            style: TextStyle(color: _kTextSub, fontSize: 14),
          ),
          const SizedBox(height: 6),
          Text(
            moneyFromCents(todayTotal),
            style: const TextStyle(
              color: _kText,
              fontSize: 38,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _heroMini(
                  icon: Icons.receipt_rounded,
                  label: 'Porosi',
                  value: '$todayOrders'),
              const SizedBox(width: 16),
              _heroMini(
                  icon: Icons.groups_rounded,
                  label: 'Aktiv',
                  value: '$_activeCount'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroMini(
      {required IconData icon,
      required String label,
      required String value}) {
    return Row(
      children: [
        Icon(icon, color: _kTextSub, size: 16),
        const SizedBox(width: 6),
        Text(label,
            style:
                const TextStyle(color: _kTextSub, fontSize: 13)),
        const SizedBox(width: 4),
        Text(value,
            style: const TextStyle(
                color: _kText,
                fontWeight: FontWeight.w800,
                fontSize: 13)),
      ],
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(
          child: _statCard(
            icon: Icons.people_alt_rounded,
            label: 'Punonjës',
            value: '${waiters.length}',
            color: _kAccent,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statCard(
            icon: Icons.play_circle_rounded,
            label: 'Në Shift',
            value: '$_activeCount',
            color: _kGreen,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statCard(
            icon: Icons.pause_circle_rounded,
            label: 'Jo Aktiv',
            value: '${waiters.length - _activeCount}',
            color: _kAmber,
          ),
        ),
      ],
    );
  }

  Widget _statCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 10),
          Text(value,
              style: const TextStyle(
                  color: _kText,
                  fontSize: 24,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(label,
              style:
                  const TextStyle(color: _kTextSub, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Aksionet e Shpejta',
            style: TextStyle(
                color: _kText,
                fontSize: 16,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _quickBtn(
                icon: Icons.bar_chart_rounded,
                label: 'Shitjet e Ditës',
                color: _kAmber,
                onTap: onNavigateSales,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _quickBtn(
                icon: Icons.manage_accounts_rounded,
                label: 'Menaxho Staff',
                color: _kAccent,
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ManageUsersScreen())),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _quickBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18),
          border:
              Border.all(color: color.withValues(alpha: 0.20)),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 19),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 13),
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                color: color.withValues(alpha: 0.50), size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildWaiterSummary() {
    if (waiters.isEmpty) return const SizedBox();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Punonjësit',
            style: TextStyle(
                color: _kText,
                fontSize: 16,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        ...waiters.map((w) => _waiterSummaryRow(w)),
      ],
    );
  }

  Widget _waiterSummaryRow(AppUserRow w) {
    final name =
        w.fullName?.trim().isNotEmpty == true ? w.fullName! : w.username;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: w.isOnShift ? _kGreen : _kTextMuted,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(name,
                style: const TextStyle(
                    color: _kText,
                    fontWeight: FontWeight.w700,
                    fontSize: 14)),
          ),
          Text(
            w.isOnShift ? 'Aktiv' : 'Jo aktiv',
            style: TextStyle(
                color: w.isOnShift ? _kGreen : _kTextMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Janar', 'Shkurt', 'Mars', 'Prill', 'Maj', 'Qershor',
      'Korrik', 'Gusht', 'Shtator', 'Tetor', 'Nëntor', 'Dhjetor',
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 2: STAFF
// ══════════════════════════════════════════════════════════════════════════════
class _StaffTab extends StatefulWidget {
  final List<AppUserRow> waiters;
  final VoidCallback onRefresh;

  const _StaffTab({required this.waiters, required this.onRefresh});

  @override
  State<_StaffTab> createState() => _StaffTabState();
}

class _StaffTabState extends State<_StaffTab> {
  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => widget.onRefresh(),
      color: _kAccent,
      backgroundColor: _kCard,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Punonjësit',
                        style: TextStyle(
                            color: _kText,
                            fontSize: 22,
                            fontWeight: FontWeight.w900)),
                    SizedBox(height: 4),
                    Text('Menaxho shifts dhe barazimet',
                        style: TextStyle(
                            color: _kTextSub, fontSize: 13)),
                  ],
                ),
              ),
              GestureDetector(
                onTap: widget.onRefresh,
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: _kCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _kBorder),
                  ),
                  child: const Icon(Icons.refresh_rounded,
                      color: _kTextSub, size: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (widget.waiters.isEmpty)
            _emptyState(
                icon: Icons.groups_outlined,
                message: 'Nuk ka punonjës të regjistruar.')
          else
            ...widget.waiters.map((w) => _WaiterCard(
                  waiter: w,
                  onRefresh: widget.onRefresh,
                )),
        ],
      ),
    );
  }
}

// ── Waiter Card ───────────────────────────────────────────────────────────────
class _WaiterCard extends StatefulWidget {
  final AppUserRow waiter;
  final VoidCallback onRefresh;

  const _WaiterCard({required this.waiter, required this.onRefresh});

  @override
  State<_WaiterCard> createState() => _WaiterCardState();
}

class _WaiterCardState extends State<_WaiterCard> {
  int _unsettled = 0;
  int _openOrders = 0;
  bool _loadingStats = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  @override
  void didUpdateWidget(_WaiterCard old) {
    super.didUpdateWidget(old);
    if (old.waiter.id != widget.waiter.id ||
        old.waiter.shiftStartedAt != widget.waiter.shiftStartedAt) {
      _loadStats();
    }
  }

  Future<void> _loadStats() async {
    setState(() => _loadingStats = true);
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final startMs = widget.waiter.shiftStartedAt ??
          DateTime.now()
              .subtract(const Duration(hours: 12))
              .millisecondsSinceEpoch;
      final totals = await SettlementsDao.I.getUnsettledTotals(
        waiterId: widget.waiter.id,
        startMs: startMs,
        endMs: now,
      );
      final orders = await OrdersDao.I
          .countOpenOrdersByWaiter(widget.waiter.id);
      if (!mounted) return;
      setState(() {
        _unsettled = totals['total'] ?? 0;
        _openOrders = orders;
      });
    } finally {
      if (mounted) setState(() => _loadingStats = false);
    }
  }

  Future<void> _toggleShift() async {
    await UsersDao.I.setShift(
        widget.waiter.id, !widget.waiter.isOnShift);
    widget.onRefresh();
  }

  Future<void> _showSettle() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _SettleDialog(
        waiter: widget.waiter,
        onDone: () {
          widget.onRefresh();
          _loadStats();
        },
      ),
    );
  }

  Future<void> _closeAllTables() async {
    final ok = await _darkDialog(
      context: context,
      title: 'Mbyll Të Gjitha Tavolinat',
      message:
          'Do të mbyllen të gjitha tavolinat e ${_displayName(widget.waiter)}. Porositë e hapura do të anulohen.',
      confirmLabel: 'Mbyll',
      confirmColor: _kRed,
    );
    if (ok != true) return;
    await TablesDao.I.closeAllTablesForWaiter(widget.waiter.id);
    if (!mounted) return;
    _showSnack('Tavolinat u mbyllën.');
    widget.onRefresh();
    _loadStats();
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  String _displayName(AppUserRow w) =>
      w.fullName?.trim().isNotEmpty == true ? w.fullName! : w.username;

  @override
  Widget build(BuildContext context) {
    final w = widget.waiter;
    final name = _displayName(w);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _avatarWidget(name, 48),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: const TextStyle(
                              color: _kText,
                              fontSize: 17,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 3),
                      Text('@${w.username}',
                          style: const TextStyle(
                              color: _kTextSub, fontSize: 12)),
                    ],
                  ),
                ),
                _shiftBadge(w.isOnShift),
              ],
            ),
          ),
          // Stats row
          Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _kSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _kBorder),
            ),
            child: _loadingStats
                ? const Center(
                    child: SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: _kAccent)))
                : Row(
                    children: [
                      _statChip(
                          label: 'Balancë',
                          value: moneyFromCents(_unsettled),
                          color: _unsettled > 0 ? _kAmber : _kTextSub),
                      _vDivider(),
                      _statChip(
                          label: 'Porosi hapur',
                          value: '$_openOrders',
                          color: _openOrders > 0
                              ? _kAccent
                              : _kTextSub),
                      _vDivider(),
                      _statChip(
                          label: 'Shift',
                          value: w.isOnShift ? 'Aktiv' : 'Jo',
                          color: w.isOnShift ? _kGreen : _kTextMuted),
                    ],
                  ),
          ),
          // Action buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _cardBtn(
                  icon: Icons.account_balance_wallet_rounded,
                  label: 'Barazo',
                  color: _kGreen,
                  onTap: _showSettle,
                ),
                _cardBtn(
                  icon: w.isOnShift
                      ? Icons.stop_circle_outlined
                      : Icons.play_circle_outlined,
                  label:
                      w.isOnShift ? 'Mbaro Shift' : 'Fillo Shift',
                  color: w.isOnShift ? _kRed : _kAccent,
                  onTap: _toggleShift,
                ),
                _cardBtn(
                  icon: Icons.table_restaurant_rounded,
                  label: 'Mbyll Tavolinat',
                  color: _kAmber,
                  onTap: _closeAllTables,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarWidget(String name, double size) {
    final letter = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: widget.waiter.isOnShift
              ? const [Color(0xFF22C55E), Color(0xFF15803D)]
              : const [Color(0xFF4F6EF7), Color(0xFFA855F7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size / 3),
      ),
      child: Center(
        child: Text(letter,
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: size * 0.42)),
      ),
    );
  }

  Widget _shiftBadge(bool active) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: active
            ? _kGreen.withValues(alpha: 0.15)
            : _kTextMuted.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: active
              ? _kGreen.withValues(alpha: 0.35)
              : _kBorder,
        ),
      ),
      child: Text(
        active ? '● Aktiv' : '○ Jo aktiv',
        style: TextStyle(
          color: active ? _kGreen : _kTextSub,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _statChip(
      {required String label,
      required String value,
      required Color color}) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w900,
                  fontSize: 14)),
          const SizedBox(height: 3),
          Text(label,
              style: const TextStyle(
                  color: _kTextSub, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _vDivider() {
    return Container(
        width: 1, height: 30, color: _kBorder);
  }

  Widget _cardBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SETTLE DIALOG
// ══════════════════════════════════════════════════════════════════════════════
class _SettleDialog extends StatefulWidget {
  final AppUserRow waiter;
  final VoidCallback onDone;

  const _SettleDialog({required this.waiter, required this.onDone});

  @override
  State<_SettleDialog> createState() => _SettleDialogState();
}

class _SettleDialogState extends State<_SettleDialog> {
  final _actualCashC = TextEditingController();
  final _premiumC = TextEditingController();
  final _notesC = TextEditingController();

  bool _loading = true;
  bool _confirming = false;

  Map<String, int> _totals = {};

  int get _total => _totals['total'] ?? 0;
  int get _cash => _totals['cash'] ?? 0;
  int get _card => _totals['card'] ?? 0;
  int get _expectedCash => _totals['expectedCash'] ?? 0;

  int get _actualCashCents {
    final v = double.tryParse(
            _actualCashC.text.trim().replaceAll(',', '.')) ??
        0;
    return (v * 100).round();
  }

  int get _premiumCents {
    final v = double.tryParse(
            _premiumC.text.trim().replaceAll(',', '.')) ??
        0;
    return (v * 100).round();
  }

  int get _difference => _actualCashCents - _expectedCash;

  int get _startMs =>
      widget.waiter.shiftStartedAt ??
      DateTime.now()
          .subtract(const Duration(hours: 12))
          .millisecondsSinceEpoch;

  @override
  void initState() {
    super.initState();
    _loadTotals();
  }

  @override
  void dispose() {
    _actualCashC.dispose();
    _premiumC.dispose();
    _notesC.dispose();
    super.dispose();
  }

  Future<void> _loadTotals() async {
    setState(() => _loading = true);
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final data = await SettlementsDao.I.getUnsettledTotals(
        waiterId: widget.waiter.id,
        startMs: _startMs,
        endMs: now,
      );
      if (!mounted) return;
      setState(() {
        _totals = data;
        _actualCashC.text =
            (_expectedCash / 100).toStringAsFixed(2);
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirm() async {
    if (_confirming) return;
    setState(() => _confirming = true);
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await SettlementsDao.I.settleWaiter(
        waiterId: widget.waiter.id,
        startMs: _startMs,
        endMs: now,
        totalCents: _total,
        cashCents: _cash,
        cardCents: _card,
        expectedCashCents: _expectedCash,
        actualCashCents: _actualCashCents,
        premiumCents: _premiumCents,
        notes: _notesC.text.trim().isEmpty
            ? null
            : _notesC.text.trim(),
        settledBy: Session.I.current!.id,
      );
      if (!mounted) return;
      Navigator.pop(context);
      widget.onDone();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '${widget.waiter.fullName ?? widget.waiter.username} u barazua. Totali → 0.00 ✓'),
          backgroundColor: _kGreenDim,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Gabim: $e')));
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.waiter.fullName?.trim().isNotEmpty == true
        ? widget.waiter.fullName!
        : widget.waiter.username;

    return Dialog(
      backgroundColor: _kSurface,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24)),
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [_kAccent, _kPurple],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Icon(
                        Icons.account_balance_wallet_rounded,
                        color: Colors.white,
                        size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Barazo Punonjësin',
                            style: TextStyle(
                                color: _kText,
                                fontWeight: FontWeight.w800,
                                fontSize: 16)),
                        Text(name,
                            style: const TextStyle(
                                color: _kTextSub, fontSize: 13)),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close_rounded,
                        color: _kTextSub, size: 22),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (_loading)
                const Center(
                    child: Padding(
                  padding: EdgeInsets.all(24),
                  child:
                      CircularProgressIndicator(color: _kAccent),
                ))
              else ...[
                // Totals grid
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _kCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _kBorder),
                  ),
                  child: Column(
                    children: [
                      _infoRow('Total Shitje',
                          moneyFromCents(_total), _kText),
                      _infoRow('Cash',
                          moneyFromCents(_cash), _kGreen),
                      _infoRow('Kartë/Mix',
                          moneyFromCents(_card), _kAccent),
                      const Divider(color: _kBorder, height: 20),
                      _infoRow('Cash Pritshmëri',
                          moneyFromCents(_expectedCash), _kAmber),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Actual cash field
                _darkField(
                  controller: _actualCashC,
                  label: 'Cash Reale (€)',
                  icon: Icons.euro_rounded,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                // Difference card
                _differenceCard(),
                const SizedBox(height: 12),
                // Premium field
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _kAmber.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: _kAmber.withValues(alpha: 0.25)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.workspace_premium_rounded,
                              color: _kAmber, size: 16),
                          const SizedBox(width: 6),
                          const Text('Premium / Bonus',
                              style: TextStyle(
                                  color: _kAmber,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _darkField(
                        controller: _premiumC,
                        label: 'Premium (€) - optional',
                        icon: Icons.workspace_premium_outlined,
                        onChanged: (_) => setState(() {}),
                        accentColor: _kAmber,
                      ),
                      if (_premiumCents > 0) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Premium: ${moneyFromCents(_premiumCents)}',
                          style: const TextStyle(
                              color: _kAmber,
                              fontWeight: FontWeight.w700,
                              fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Notes
                _darkField(
                  controller: _notesC,
                  label: 'Shënime (opsionale)',
                  icon: Icons.notes_rounded,
                  maxLines: 2,
                ),
                const SizedBox(height: 20),
                // Warning
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _kRed.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: _kRed.withValues(alpha: 0.20)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline_rounded,
                          color: _kRed, size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Pas barazimit, tavolinat mbyllen dhe totali del 00. Shifti i ri fillon menjëherë.',
                          style: TextStyle(
                              color: _kRed,
                              fontSize: 11,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          height: 50,
                          decoration: BoxDecoration(
                            color: _kCard,
                            borderRadius:
                                BorderRadius.circular(14),
                            border: Border.all(color: _kBorder),
                          ),
                          child: const Center(
                            child: Text('Anulo',
                                style: TextStyle(
                                    color: _kTextSub,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: GestureDetector(
                        onTap: _confirming ? null : _confirm,
                        child: Container(
                          height: 50,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [_kGreen, Color(0xFF15803D)],
                            ),
                            borderRadius:
                                BorderRadius.circular(14),
                          ),
                          child: Center(
                            child: _confirming
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child:
                                        CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2))
                                : const Text('KRYEJ BARAZIMIN',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight:
                                            FontWeight.w800,
                                        fontSize: 13)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    color: _kTextSub, fontSize: 13)),
          ),
          Text(value,
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: 14)),
        ],
      ),
    );
  }

  Widget _differenceCard() {
    final pos = _difference >= 0;
    final color = pos ? _kGreen : _kRed;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(
            pos
                ? Icons.arrow_upward_rounded
                : Icons.arrow_downward_rounded,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              pos
                  ? 'Ka më shumë cash se pritshmëria'
                  : 'Ka më pak cash se pritshmëria',
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            moneyFromCents(_difference),
            style: TextStyle(
                color: color,
                fontWeight: FontWeight.w900,
                fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _darkField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    void Function(String)? onChanged,
    Color accentColor = _kAccent,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      maxLines: maxLines,
      style: const TextStyle(color: _kText),
      keyboardType: maxLines == 1
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.multiline,
      decoration: InputDecoration(
        labelText: label,
        labelStyle:
            const TextStyle(color: _kTextSub, fontSize: 13),
        prefixIcon: Icon(icon, color: _kTextSub, size: 18),
        filled: true,
        fillColor: _kCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _kBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _kBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: accentColor),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 3: TABLES
// ══════════════════════════════════════════════════════════════════════════════
class _TablesTab extends StatefulWidget {
  final VoidCallback onRefresh;

  const _TablesTab({required this.onRefresh});

  @override
  State<_TablesTab> createState() => _TablesTabState();
}

class _TablesTabState extends State<_TablesTab> {
  bool _loading = true;
  List<FullTableRow> _tables = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final tables = await TablesDao.I.listTablesWithWaiters();
      if (!mounted) return;
      setState(() => _tables = tables);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _closeTable(FullTableRow t) async {
    final ok = await _darkDialog(
      context: context,
      title: 'Mbyll ${t.name}',
      message:
          'Tavolina do të mbyllet dhe porositë e hapura do të anulohen. Rifillon nga zero.',
      confirmLabel: 'Mbyll Tavolinen',
      confirmColor: _kRed,
    );
    if (ok != true) return;
    await TablesDao.I.closeTableForcefully(t.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${t.name} u mbyll. Rifillon nga 0.')));
    _load();
    widget.onRefresh();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => _load(),
      color: _kAccent,
      backgroundColor: _kCard,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tavolinat',
                        style: TextStyle(
                            color: _kText,
                            fontSize: 22,
                            fontWeight: FontWeight.w900)),
                    SizedBox(height: 4),
                    Text('Menaxho dhe mbyll tavolinat',
                        style:
                            TextStyle(color: _kTextSub, fontSize: 13)),
                  ],
                ),
              ),
              GestureDetector(
                onTap: _load,
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: _kCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _kBorder),
                  ),
                  child: const Icon(Icons.refresh_rounded,
                      color: _kTextSub, size: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_loading)
            const Center(
                child: CircularProgressIndicator(color: _kAccent))
          else if (_tables.isEmpty)
            _emptyState(
                icon: Icons.table_restaurant_outlined,
                message: 'Nuk ka tavolina.')
          else
            ..._tables.map((t) => _tableCard(t)),
        ],
      ),
    );
  }

  Widget _tableCard(FullTableRow t) {
    final isOpen = t.isOpen;
    final statusColor = isOpen ? _kAmber : _kGreen;
    final statusLabel = isOpen ? 'E Hapur' : 'E Lirë';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOpen
              ? _kAmber.withValues(alpha: 0.30)
              : _kBorder,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.table_restaurant_rounded,
                color: statusColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.name,
                    style: const TextStyle(
                        color: _kText,
                        fontWeight: FontWeight.w800,
                        fontSize: 15)),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 5),
                    Text(statusLabel,
                        style: TextStyle(
                            color: statusColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                    if (t.waiterName != null) ...[
                      const Text(' · ',
                          style: TextStyle(
                              color: _kTextMuted, fontSize: 12)),
                      Text(t.waiterName!,
                          style: const TextStyle(
                              color: _kTextSub, fontSize: 12)),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (isOpen) ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(moneyFromCents(t.openTotalCents),
                    style: const TextStyle(
                        color: _kAmber,
                        fontWeight: FontWeight.w900,
                        fontSize: 15)),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () => _closeTable(t),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: _kRed.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: _kRed.withValues(alpha: 0.30)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.close_rounded,
                            color: _kRed, size: 14),
                        SizedBox(width: 4),
                        Text('Mbyll Tavolinen',
                            style: TextStyle(
                                color: _kRed,
                                fontSize: 12,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// HELPERS
// ══════════════════════════════════════════════════════════════════════════════
Widget _emptyState(
    {required IconData icon, required String message}) {
  return Container(
    padding: const EdgeInsets.all(40),
    decoration: BoxDecoration(
      color: _kCard,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: _kBorder),
    ),
    child: Column(
      children: [
        Icon(icon, color: _kTextMuted, size: 48),
        const SizedBox(height: 12),
        Text(message,
            style: const TextStyle(color: _kTextSub, fontSize: 14)),
      ],
    ),
  );
}

Future<bool?> _darkDialog({
  required BuildContext context,
  required String title,
  required String message,
  required String confirmLabel,
  required Color confirmColor,
}) {
  return showDialog<bool>(
    context: context,
    builder: (_) => Dialog(
      backgroundColor: _kSurface,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    color: _kText,
                    fontWeight: FontWeight.w800,
                    fontSize: 17)),
            const SizedBox(height: 10),
            Text(message,
                style:
                    const TextStyle(color: _kTextSub, fontSize: 13)),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context, false),
                    child: Container(
                      height: 46,
                      decoration: BoxDecoration(
                        color: _kCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _kBorder),
                      ),
                      child: const Center(
                        child: Text('Anulo',
                            style: TextStyle(
                                color: _kTextSub,
                                fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context, true),
                    child: Container(
                      height: 46,
                      decoration: BoxDecoration(
                        color: confirmColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: confirmColor.withValues(alpha: 0.35)),
                      ),
                      child: Center(
                        child: Text(
                          confirmLabel,
                          style: TextStyle(
                              color: confirmColor,
                              fontWeight: FontWeight.w800,
                              fontSize: 13),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

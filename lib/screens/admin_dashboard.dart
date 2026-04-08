import 'package:flutter/material.dart';
import '../auth/auth_service.dart';
import '../auth/dao_users.dart';
import '../auth/roles.dart';
import '../auth/session.dart';
import '../data/dao_orders.dart';
import '../data/dao_settlements.dart';
import '../data/dao_tables.dart';
import '../util/money.dart';
import '../theme/app_theme.dart';
import '../theme/app_widgets.dart';
import 'daily_sales_screen.dart';
import 'manage_users_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _tab = 0;
  bool _loading = true;

  List<AppUserRow> _waiters = [];
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
      if (!mounted) { return; }
      setState(() {
        _waiters = all.where((u) => u.role == UserRole.waiter).toList();
        _todayTotal = todayTotal;
        _todayOrders = todayOrders;
      });
    } finally {
      if (mounted) { setState(() => _loading = false); }
    }
  }

  static const _navItems = [
    (Icons.dashboard_rounded, 'Pasqyra'),
    (Icons.groups_rounded, 'Punonjësit'),
    (Icons.table_restaurant_rounded, 'Tavolinat'),
  ];

  @override
  Widget build(BuildContext context) {
    final me = Session.I.current!;
    if (me.role != UserRole.admin) {
      return const Scaffold(
        backgroundColor: AppTheme.bg,
        body: Center(child: Text('Access denied', style: AppTheme.bodyMedium)),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (ctx, constraints) {
            final wide = constraints.maxWidth > 820;
            if (wide) {
              return Row(
                children: [
                  _buildSidebar(me),
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

  // ── Sidebar ───────────────────────────────────────────────────────────────
  Widget _buildSidebar(AuthUser me) {
    final name = me.fullName?.trim().isNotEmpty == true
        ? me.fullName!
        : me.username;

    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(right: BorderSide(color: AppTheme.border)),
      ),
      child: Column(
        children: [
          // Logo area
          Container(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: AppTheme.border)),
            ),
            child: Row(
              children: [
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGrad,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: AppTheme.shadowGlowColor(
                        AppTheme.primary, a: 0.35),
                  ),
                  child: const Icon(Icons.point_of_sale_rounded,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('EasyPOS',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text('Admin Panel',
                        style: AppTheme.caption),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Nav items
          ..._navItems.asMap().entries.map((e) {
            final i = e.key;
            final item = e.value;
            return _SidebarNavItem(
              icon: item.$1,
              label: item.$2,
              active: _tab == i,
              onTap: () => setState(() => _tab = i),
            );
          }),

          const Spacer(),

          // Action buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              children: [
                _SidebarActionBtn(
                  icon: Icons.bar_chart_rounded,
                  label: 'Shitjet e Ditës',
                  color: AppTheme.warning,
                  onTap: () => Navigator.push(context,
                    MaterialPageRoute(
                        builder: (_) => const DailySalesScreen())),
                ),
                const SizedBox(height: 8),
                _SidebarActionBtn(
                  icon: Icons.manage_accounts_rounded,
                  label: 'Menaxho Staff',
                  color: AppTheme.primary,
                  onTap: () async {
                    await Navigator.push(context,
                      MaterialPageRoute(
                          builder: (_) => const ManageUsersScreen()));
                    _load();
                  },
                ),
              ],
            ),
          ),

          // User card
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: AppTheme.borderRadius,
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
              children: [
                _Avatar(name: name, size: 34),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: AppTheme.bodyMedium.copyWith(
                            fontWeight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Text('Administrator',
                          style: AppTheme.caption),
                    ],
                  ),
                ),
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () {
                    Session.I.logout();
                    Navigator.of(context)
                        .pushReplacementNamed('/login');
                  },
                  child: Container(
                    width: 30, height: 30,
                    decoration: BoxDecoration(
                      color: AppTheme.error.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.logout_rounded,
                        color: AppTheme.error, size: 16),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: _navItems.asMap().entries.map((e) {
          final i = e.key;
          final item = e.value;
          final active = _tab == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _tab = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: active ? AppTheme.primary : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(item.$1,
                      color: active
                          ? AppTheme.primary
                          : AppTheme.textMuted,
                      size: 22,
                    ),
                    const SizedBox(height: 4),
                    Text(item.$2,
                      style: TextStyle(
                        color: active
                            ? AppTheme.primary
                            : AppTheme.textMuted,
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

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primary),
      );
    }
    return IndexedStack(
      index: _tab,
      children: [
        _OverviewTab(
          waiters: _waiters,
          todayTotal: _todayTotal,
          todayOrders: _todayOrders,
          onRefresh: _load,
          onNavigateSales: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const DailySalesScreen())),
        ),
        _StaffTab(waiters: _waiters, onRefresh: _load),
        _TablesTab(onRefresh: _load),
      ],
    );
  }
}

// ── Sidebar components ────────────────────────────────────────────────────────
class _SidebarNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _SidebarNavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          gradient: active
              ? LinearGradient(
                  colors: [
                    AppTheme.primary.withValues(alpha: 0.18),
                    AppTheme.primary.withValues(alpha: 0.06),
                  ],
                )
              : null,
          borderRadius: AppTheme.radiusSmall,
          border: active
              ? Border.all(color: AppTheme.primary.withValues(alpha: 0.30))
              : null,
        ),
        child: Row(
          children: [
            Icon(icon,
              color: active ? AppTheme.primary : AppTheme.textMuted,
              size: 18,
            ),
            const SizedBox(width: 12),
            Text(label,
              style: TextStyle(
                color: active
                    ? AppTheme.primaryLight
                    : AppTheme.textSecondary,
                fontWeight:
                    active ? FontWeight.w700 : FontWeight.w500,
                fontSize: 14,
              ),
            ),
            if (active) ...[
              const Spacer(),
              Container(
                width: 4, height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SidebarActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _SidebarActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: AppTheme.radiusSmall,
          border: Border.all(color: color.withValues(alpha: 0.20)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 10),
            Text(label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            const Spacer(),
            Icon(Icons.arrow_forward_ios_rounded,
                color: color.withValues(alpha: 0.50), size: 12),
          ],
        ),
      ),
    );
  }
}

// ── Avatar ────────────────────────────────────────────────────────────────────
class _Avatar extends StatelessWidget {
  final String name;
  final double size;
  const _Avatar({required this.name, required this.size});

  @override
  Widget build(BuildContext context) {
    final letter = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGrad,
        borderRadius: BorderRadius.circular(size / 3),
      ),
      child: Center(
        child: Text(
          letter,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: size * 0.42,
          ),
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
    final hour = DateTime.now().hour;
    final me = Session.I.current!;
    final greeting = hour < 12
        ? 'Mirëmëngjes'
        : hour < 18 ? 'Mirëdita' : 'Mirëmbrëma';
    final firstName =
        me.fullName?.split(' ').first ?? me.username;

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      color: AppTheme.primary,
      backgroundColor: AppTheme.card,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // ── Greeting row ───────────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$greeting, $firstName!',
                      style: AppTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(_formatDate(DateTime.now()),
                      style: AppTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  const LiveDot(),
                  const SizedBox(width: 6),
                  const Text('Live',
                    style: TextStyle(
                      color: AppTheme.success,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 14),
                  _IconBtn(
                    icon: Icons.refresh_rounded,
                    onTap: onRefresh,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── Hero revenue card ──────────────────────────────────────────────
          _HeroCard(
            todayTotal: todayTotal,
            todayOrders: todayOrders,
            activeCount: _activeCount,
          ),
          const SizedBox(height: 16),

          // ── Stat row ───────────────────────────────────────────────────────
          Row(
            children: [
              Expanded(child: PremiumStatCard(
                label: 'Punonjës',
                value: '${waiters.length}',
                icon: Icons.people_alt_rounded,
                color: AppTheme.primary,
              )),
              const SizedBox(width: 10),
              Expanded(child: PremiumStatCard(
                label: 'Aktiv',
                value: '$_activeCount',
                icon: Icons.play_circle_rounded,
                color: AppTheme.success,
              )),
              const SizedBox(width: 10),
              Expanded(child: PremiumStatCard(
                label: 'Jo aktiv',
                value: '${waiters.length - _activeCount}',
                icon: Icons.pause_circle_rounded,
                color: AppTheme.warning,
              )),
            ],
          ),
          const SizedBox(height: 24),

          // ── Quick actions ──────────────────────────────────────────────────
          const SectionHeader(
            title: 'Veprime të Shpejta',
            subtitle: 'Akseso funksionet kryesore',
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _QuickActionCard(
                  icon: Icons.bar_chart_rounded,
                  label: 'Shitjet e Ditës',
                  subtitle: 'Raport i detajuar',
                  color: AppTheme.warning,
                  onTap: onNavigateSales,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _QuickActionCard(
                  icon: Icons.manage_accounts_rounded,
                  label: 'Menaxho Staff',
                  subtitle: 'CRUD punonjës',
                  color: AppTheme.primary,
                  onTap: () => Navigator.push(context,
                    MaterialPageRoute(
                        builder: (_) => const ManageUsersScreen())),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── Waiter summary ─────────────────────────────────────────────────
          if (waiters.isNotEmpty) ...[
            SectionHeader(
              title: 'Punonjësit',
              subtitle: '${waiters.length} kamarjerë',
              action: _IconBtn(icon: Icons.refresh_rounded, onTap: onRefresh),
            ),
            const SizedBox(height: 12),
            ...waiters.map((w) => _WaiterSummaryRow(w)),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Janar','Shkurt','Mars','Prill','Maj','Qershor',
      'Korrik','Gusht','Shtator','Tetor','Nëntor','Dhjetor',
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }
}

// ── Hero card ─────────────────────────────────────────────────────────────────
class _HeroCard extends StatelessWidget {
  final int todayTotal;
  final int todayOrders;
  final int activeCount;
  const _HeroCard({
    required this.todayTotal,
    required this.todayOrders,
    required this.activeCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1F4E), Color(0xFF0D0F1C), AppTheme.bg],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppTheme.radiusLarge,
        border: Border.all(
            color: AppTheme.primary.withValues(alpha: 0.25)),
        boxShadow: AppTheme.shadowGlowColor(AppTheme.primary, a: 0.10),
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
                  color: AppTheme.success.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                      color: AppTheme.success.withValues(alpha: 0.30)),
                ),
                child: Row(
                  children: [
                    const LiveDot(color: AppTheme.success, size: 7),
                    const SizedBox(width: 6),
                    const Text('Live Today',
                      style: TextStyle(
                        color: AppTheme.success,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Total Shitjet Sot',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            moneyFromCents(todayTotal),
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 40,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.5,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _HeroMini(
                icon: Icons.receipt_rounded,
                label: 'Porosi',
                value: '$todayOrders',
              ),
              const SizedBox(width: 20),
              _HeroMini(
                icon: Icons.groups_rounded,
                label: 'Aktiv',
                value: '$activeCount',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroMini extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _HeroMini({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.textSecondary, size: 14),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 12)),
          const SizedBox(width: 4),
          Text(value,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              )),
        ],
      ),
    );
  }
}

// ── Quick action card ─────────────────────────────────────────────────────────
class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: AppTheme.borderRadius,
          border: Border.all(color: color.withValues(alpha: 0.20)),
          boxShadow: AppTheme.shadowGlowColor(color, a: 0.06),
        ),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                    style: AppTheme.bodyMedium
                        .copyWith(fontWeight: FontWeight.w700),
                  ),
                  Text(subtitle, style: AppTheme.caption),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                color: color.withValues(alpha: 0.50), size: 13),
          ],
        ),
      ),
    );
  }
}

// ── Waiter summary row ────────────────────────────────────────────────────────
class _WaiterSummaryRow extends StatelessWidget {
  final AppUserRow w;
  const _WaiterSummaryRow(this.w);

  @override
  Widget build(BuildContext context) {
    final name = w.fullName?.trim().isNotEmpty == true ? w.fullName! : w.username;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: AppTheme.radiusSmall,
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          _Avatar(name: name, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Text(name,
              style: AppTheme.bodyMedium
                  .copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: w.isOnShift
                  ? AppTheme.success.withValues(alpha: 0.12)
                  : AppTheme.textMuted.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: w.isOnShift
                    ? AppTheme.success.withValues(alpha: 0.30)
                    : AppTheme.border,
              ),
            ),
            child: Text(
              w.isOnShift ? 'Aktiv' : 'Jo aktiv',
              style: TextStyle(
                color: w.isOnShift
                    ? AppTheme.success
                    : AppTheme.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Icon button ───────────────────────────────────────────────────────────────
class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38, height: 38,
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.border),
        ),
        child: Icon(icon, color: AppTheme.textSecondary, size: 18),
      ),
    );
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
      color: AppTheme.primary,
      backgroundColor: AppTheme.card,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          SectionHeader(
            title: 'Punonjësit',
            subtitle: 'Menaxho shifts dhe barazimet',
            action: _IconBtn(
                icon: Icons.refresh_rounded, onTap: widget.onRefresh),
          ),
          const SizedBox(height: 20),
          if (widget.waiters.isEmpty)
            _EmptyState(
              icon: Icons.groups_outlined,
              message: 'Nuk ka punonjës të regjistruar.',
            )
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

// ── Waiter card ───────────────────────────────────────────────────────────────
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
      final orders =
          await OrdersDao.I.countOpenOrdersByWaiter(widget.waiter.id);
      if (!mounted) { return; }
      setState(() {
        _unsettled = totals['total'] ?? 0;
        _openOrders = orders;
      });
    } finally {
      if (mounted) { setState(() => _loadingStats = false); }
    }
  }

  Future<void> _toggleShift() async {
    await UsersDao.I.setShift(widget.waiter.id, !widget.waiter.isOnShift);
    widget.onRefresh();
  }

  Future<void> _showSettle() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _SettleDialog(
        waiter: widget.waiter,
        onDone: () { widget.onRefresh(); _loadStats(); },
      ),
    );
  }

  Future<void> _closeAllTables() async {
    final ok = await _confirmDialog(
      context: context,
      title: 'Mbyll Të Gjitha Tavolinat',
      message:
          'Do të mbyllen të gjitha tavolinat e ${_dname(widget.waiter)}. Porositë e hapura do të anulohen.',
      confirmLabel: 'Mbyll',
      confirmColor: AppTheme.error,
    );
    if (ok != true) { return; }
    await TablesDao.I.closeAllTablesForWaiter(widget.waiter.id);
    if (!mounted) { return; }
    _snack('Tavolinat u mbyllën.');
    widget.onRefresh();
    _loadStats();
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  String _dname(AppUserRow w) =>
      w.fullName?.trim().isNotEmpty == true ? w.fullName! : w.username;

  @override
  Widget build(BuildContext context) {
    final w = widget.waiter;
    final name = _dname(w);
    final shiftColor = w.isOnShift ? AppTheme.success : AppTheme.textMuted;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: AppTheme.radiusLarge,
        border: Border.all(
          color: w.isOnShift
              ? AppTheme.success.withValues(alpha: 0.20)
              : AppTheme.border,
        ),
        boxShadow: w.isOnShift
            ? AppTheme.shadowGlowColor(AppTheme.success, a: 0.06)
            : AppTheme.shadowSm,
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _Avatar(name: name, size: 44),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                        style: AppTheme.titleSmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            width: 7, height: 7,
                            decoration: BoxDecoration(
                              color: shiftColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            w.isOnShift ? 'Aktiv' : 'Jo aktiv',
                            style: TextStyle(
                              color: shiftColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Shift toggle
                GestureDetector(
                  onTap: _toggleShift,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: w.isOnShift
                          ? AppTheme.error.withValues(alpha: 0.10)
                          : AppTheme.success.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: w.isOnShift
                            ? AppTheme.error.withValues(alpha: 0.30)
                            : AppTheme.success.withValues(alpha: 0.30),
                      ),
                    ),
                    child: Text(
                      w.isOnShift ? 'Mbyll Shift' : 'Hap Shift',
                      style: TextStyle(
                        color: w.isOnShift ? AppTheme.error : AppTheme.success,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Stats
          if (_loadingStats)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: LinearProgressIndicator(
                  color: AppTheme.primary, minHeight: 2),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  _MiniStat(
                    icon: Icons.receipt_long_rounded,
                    label: 'Porosi hapura',
                    value: '$_openOrders',
                    color: AppTheme.warning,
                  ),
                  const SizedBox(width: 10),
                  _MiniStat(
                    icon: Icons.account_balance_wallet_rounded,
                    label: 'Pa barazuar',
                    value: moneyFromCents(_unsettled),
                    color: AppTheme.primary,
                  ),
                ],
              ),
            ),

          // Actions
          Container(
            decoration: BoxDecoration(
              color: AppTheme.cardAlt,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
              border: Border(top: BorderSide(color: AppTheme.border)),
            ),
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: _CardActionBtn(
                    icon: Icons.close_rounded,
                    label: 'Mbyll Tavolinat',
                    color: AppTheme.error,
                    onTap: _closeAllTables,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _CardActionBtn(
                    icon: Icons.account_balance_wallet_rounded,
                    label: 'Barazo',
                    color: AppTheme.primary,
                    onTap: _showSettle,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _MiniStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: AppTheme.radiusSmall,
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  Text(label,
                    style: AppTheme.caption.copyWith(fontSize: 10)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _CardActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: AppTheme.radiusSmall,
          border: Border.all(color: color.withValues(alpha: 0.20)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 6),
            Text(label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 3: TABLES (ACTIVE ONLY)
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
      final tables = await TablesDao.I.listOpenTables();
      if (!mounted) { return; }
      setState(() => _tables = tables);
    } finally {
      if (mounted) { setState(() => _loading = false); }
    }
  }

  Future<void> _closeTable(FullTableRow t) async {
    final ok = await _confirmDialog(
      context: context,
      title: 'Mbyll ${t.name}',
      message:
          'Tavolina do të mbyllet dhe porositë e hapura do të anulohen.',
      confirmLabel: 'Mbyll',
      confirmColor: AppTheme.error,
    );
    if (ok != true) { return; }
    await TablesDao.I.closeTableForcefully(t.id);
    if (!mounted) { return; }
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${t.name} u mbyll.')));
    _load();
    widget.onRefresh();
  }

  @override
  Widget build(BuildContext context) {
    final totalCents =
        _tables.fold<int>(0, (s, t) => s + t.openTotalCents);

    return RefreshIndicator(
      onRefresh: () async => _load(),
      color: AppTheme.primary,
      backgroundColor: AppTheme.card,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          SectionHeader(
            title: 'Tavolinat Aktive',
            subtitle: 'Vetëm tavolinat me porosi të hapura',
            action: _IconBtn(icon: Icons.refresh_rounded, onTap: _load),
          ),
          const SizedBox(height: 16),

          if (!_loading && _tables.isNotEmpty) ...[
            // Billing summary card
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1C1500), AppTheme.card],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: AppTheme.borderRadius,
                border: Border.all(
                    color: AppTheme.warning.withValues(alpha: 0.30)),
                boxShadow: AppTheme.shadowGlowColor(AppTheme.warning, a: 0.08),
              ),
              child: Row(
                children: [
                  IconBadge(
                      icon: Icons.receipt_long_rounded,
                      color: AppTheme.warning,
                      size: 44,
                      iconSize: 22),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${_tables.length} tavolinë aktive',
                            style: AppTheme.caption),
                        const Text('Faturimi Total',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    moneyFromCents(totalCents),
                    style: const TextStyle(
                      color: AppTheme.warning,
                      fontWeight: FontWeight.w900,
                      fontSize: 24,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(color: AppTheme.primary),
              ),
            )
          else if (_tables.isEmpty)
            _EmptyState(
              icon: Icons.table_restaurant_outlined,
              message: 'Nuk ka tavolina aktive për momentin.',
            )
          else
            ..._tables.map((t) => _ActiveTableCard(
                  table: t,
                  onClose: () => _closeTable(t),
                )),
        ],
      ),
    );
  }
}

// ── Active table card ─────────────────────────────────────────────────────────
class _ActiveTableCard extends StatelessWidget {
  final FullTableRow table;
  final VoidCallback onClose;
  const _ActiveTableCard({required this.table, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: AppTheme.borderRadius,
        border: Border.all(color: AppTheme.warning.withValues(alpha: 0.25)),
        boxShadow: AppTheme.shadowGlowColor(AppTheme.warning, a: 0.05),
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: AppTheme.warning.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.restaurant_rounded,
                color: AppTheme.warning, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(table.name, style: AppTheme.titleSmall),
                const SizedBox(height: 4),
                Row(
                  children: [
                    LiveDot(color: AppTheme.warning, size: 6),
                    const SizedBox(width: 5),
                    Text('E Hapur',
                      style: const TextStyle(
                        color: AppTheme.warning,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (table.waiterName != null) ...[
                      const Text(' · ',
                        style: TextStyle(
                            color: AppTheme.textMuted, fontSize: 11)),
                      Flexible(
                        child: Text(table.waiterName!,
                          style: AppTheme.bodySmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                moneyFromCents(table.openTotalCents),
                style: const TextStyle(
                  color: AppTheme.warning,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: onClose,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppTheme.error.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.close_rounded,
                          color: AppTheme.error, size: 12),
                      SizedBox(width: 4),
                      Text('Mbyll',
                        style: TextStyle(
                          color: AppTheme.error,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
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
  final _actualCashC  = TextEditingController();
  final _premiumC     = TextEditingController();
  final _notesC       = TextEditingController();
  bool _loading       = true;
  bool _confirming    = false;
  Map<String, int> _totals = {};

  int get _total         => _totals['total'] ?? 0;
  int get _cash          => _totals['cash'] ?? 0;
  int get _card          => _totals['card'] ?? 0;
  int get _expectedCash  => _totals['expectedCash'] ?? 0;

  int get _actualCashCents {
    final v = double.tryParse(
        _actualCashC.text.trim().replaceAll(',', '.')) ?? 0;
    return (v * 100).round();
  }
  int get _premiumCents {
    final v = double.tryParse(
        _premiumC.text.trim().replaceAll(',', '.')) ?? 0;
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
      if (!mounted) { return; }
      setState(() {
        _totals = data;
        _actualCashC.text = (_expectedCash / 100).toStringAsFixed(2);
      });
    } finally {
      if (mounted) { setState(() => _loading = false); }
    }
  }

  Future<void> _confirm() async {
    if (_confirming) { return; }
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
        notes: _notesC.text.trim().isEmpty ? null : _notesC.text.trim(),
        settledBy: Session.I.current!.id,
      );
      if (!mounted) { return; }
      Navigator.pop(context);
      widget.onDone();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${widget.waiter.fullName ?? widget.waiter.username} u barazua.'),
          backgroundColor: AppTheme.successDim,
        ),
      );
    } catch (e) {
      if (!mounted) { return; }
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Gabim: $e')));
    } finally {
      if (mounted) { setState(() => _confirming = false); }
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.waiter.fullName?.trim().isNotEmpty == true
        ? widget.waiter.fullName!
        : widget.waiter.username;

    return Dialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: AppTheme.radiusLarge),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
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
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGrad,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.account_balance_wallet_rounded,
                        color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Barazo Punonjësin',
                            style: AppTheme.titleSmall),
                        Text(name, style: AppTheme.bodySmall),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close_rounded,
                        color: AppTheme.textSecondary, size: 22),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              if (_loading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(
                        color: AppTheme.primary),
                  ),
                )
              else ...[
                // Totals
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.card,
                    borderRadius: AppTheme.borderRadius,
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Column(
                    children: [
                      _InfoRow('Total Shitje',
                          moneyFromCents(_total), AppTheme.textPrimary),
                      _InfoRow('Cash',
                          moneyFromCents(_cash), AppTheme.success),
                      _InfoRow('Kartë/Mix',
                          moneyFromCents(_card), AppTheme.primary),
                      const PremiumDivider(),
                      const SizedBox(height: 8),
                      _InfoRow('Cash Pritshmëri',
                          moneyFromCents(_expectedCash), AppTheme.warning),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Actual cash
                AppTextField(
                  controller: _actualCashC,
                  label: 'Cash Reale (€)',
                  prefixIcon: Icons.euro_rounded,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 10),

                // Difference
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _difference >= 0
                        ? AppTheme.success.withValues(alpha: 0.07)
                        : AppTheme.error.withValues(alpha: 0.07),
                    borderRadius: AppTheme.radiusSmall,
                    border: Border.all(
                      color: _difference >= 0
                          ? AppTheme.success.withValues(alpha: 0.25)
                          : AppTheme.error.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text('Diferenca',
                          style: AppTheme.bodyMedium
                              .copyWith(color: AppTheme.textSecondary)),
                      const Spacer(),
                      Text(
                        (_difference >= 0 ? '+' : '') +
                            moneyFromCents(_difference),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: _difference >= 0
                              ? AppTheme.success
                              : AppTheme.error,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Premium
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.warning.withValues(alpha: 0.06),
                    borderRadius: AppTheme.borderRadius,
                    border: Border.all(
                        color: AppTheme.warning.withValues(alpha: 0.20)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.workspace_premium_rounded,
                              color: AppTheme.warning, size: 15),
                          SizedBox(width: 6),
                          Text('Premium / Bonus',
                            style: TextStyle(
                              color: AppTheme.warning,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      AppTextField(
                        controller: _premiumC,
                        label: 'Premium (€) - opsionale',
                        prefixIcon: Icons.workspace_premium_outlined,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        onChanged: (_) => setState(() {}),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Notes
                AppTextField(
                  controller: _notesC,
                  label: 'Shënime (opsionale)',
                  prefixIcon: Icons.notes_rounded,
                  maxLines: 2,
                ),
                const SizedBox(height: 20),

                // Warning
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withValues(alpha: 0.06),
                    borderRadius: AppTheme.radiusSmall,
                    border: Border.all(
                        color: AppTheme.error.withValues(alpha: 0.18)),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.warning_amber_rounded,
                          color: AppTheme.error, size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Ky veprim nuk mund të zhbëhet. Totali do të resetohet.',
                          style: TextStyle(
                            color: AppTheme.error,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Confirm
                GradientButton(
                  label: _confirming ? 'Duke u barazuar…' : 'Konfirmo Barazimin',
                  icon: _confirming
                      ? Icons.hourglass_empty_rounded
                      : Icons.check_rounded,
                  height: 52,
                  gradient: AppTheme.primaryGrad,
                  onTap: _confirming ? null : _confirm,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _InfoRow(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Text(label, style: AppTheme.bodyMedium),
          const Spacer(),
          Text(value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                color: AppTheme.textMuted.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, color: AppTheme.textMuted, size: 30),
            ),
            const SizedBox(height: 16),
            Text(message, style: AppTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────
Future<bool?> _confirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  required String confirmLabel,
  required Color confirmColor,
}) {
  return showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: AppTheme.radiusLarge),
      title: Text(title, style: AppTheme.titleSmall),
      content: Text(message, style: AppTheme.bodyMedium),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('Anulo',
              style: TextStyle(color: AppTheme.textSecondary)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: confirmColor,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: AppTheme.radiusSmall),
          ),
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel,
              style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );
}

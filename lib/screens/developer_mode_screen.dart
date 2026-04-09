import 'package:flutter/material.dart';
import '../auth/roles.dart';
import '../auth/session.dart';
import '../auth/dao_users.dart';
import '../data/db.dart';
import '../theme/app_theme.dart';
import 'manage_users_screen.dart';
import 'license_manager_screen.dart';

class DeveloperModeScreen extends StatefulWidget {
  const DeveloperModeScreen({super.key});

  @override
  State<DeveloperModeScreen> createState() => _DeveloperModeScreenState();
}

class _DeveloperModeScreenState extends State<DeveloperModeScreen> {
  bool _loading = false;
  List<AppUserRow> _users = [];
  int _dbSize = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final users = await UsersDao.I.listUsers();
      final dbSize = await AppDb.I.getDatabaseSize();
      if (mounted) {
        setState(() {
          _users = users;
          _dbSize = dbSize;
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resetPwAll() async {
    final ok = await _confirm(
      'Reset All Passwords',
      'This will reset ALL user passwords to "1234". Continue?',
    );
    if (!ok) return;
    await UsersDao.I.resetAllPasswords();
    _snack('All passwords reset to 1234', success: true);
    _load();
  }

  Future<void> _openManageRole(UserRole role) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ManageUsersScreen(initialRoleFilter: roleToString(role)),
      ),
    );
    _load();
  }

  Future<void> _dbRepair() async {
    final ok = await _confirm(
      'Database Repair',
      'Run PRAGMA integrity_check and VACUUM?',
    );
    if (!ok) return;
    await AppDb.I.repairDatabase();
    _snack('DB repaired', success: true);
    _load();
  }

  Future<void> _openLicenseManager() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LicenseManagerScreen()),
    );
  }

  Future<bool> _confirm(String title, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _snack(String msg, {required bool success}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  int get _waiterCount => _users.where((u) => u.role == UserRole.waiter).length;
  int get _managerCount =>
      _users.where((u) => u.role == UserRole.manager).length;
  int get _adminCount => _users.where((u) => u.role == UserRole.admin).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('Developer Mode'),
        backgroundColor: Colors.red.withOpacity(0.2),
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 760;
                final sidebar = Container(
                  width: isNarrow ? double.infinity : 220,
                  decoration: BoxDecoration(
                    color: Colors.red.shade700,
                    borderRadius: isNarrow
                        ? const BorderRadius.vertical(
                            bottom: Radius.circular(16),
                          )
                        : const BorderRadius.horizontal(
                            right: Radius.circular(16),
                          ),
                  ),
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Developer Sidebar',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Menaxho role të punonjësve dhe performancën e DB.',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      const SizedBox(height: 20),
                      _SidebarButton(
                        icon: Icons.room_service_outlined,
                        label: 'Waiters',
                        count: _waiterCount,
                        onTap: () => _openManageRole(UserRole.waiter),
                      ),
                      const SizedBox(height: 10),
                      _SidebarButton(
                        icon: Icons.group_outlined,
                        label: 'Managers',
                        count: _managerCount,
                        onTap: () => _openManageRole(UserRole.manager),
                      ),
                      const SizedBox(height: 10),
                      _SidebarButton(
                        icon: Icons.admin_panel_settings_outlined,
                        label: 'Admins',
                        count: _adminCount,
                        onTap: () => _openManageRole(UserRole.admin),
                      ),
                      const SizedBox(height: 20),
                      const Divider(color: Colors.white24),
                      const SizedBox(height: 12),
                      _SidebarStat('DB Size', '${_dbSize ~/ 1024} KB'),
                      _SidebarStat('Total Users', '${_users.length}'),
                      _SidebarStat(
                        'Active Users',
                        '${_users.where((u) => u.isActive).length}',
                      ),
                    ],
                  ),
                );

                final content = Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      _ToolCard(
                        icon: Icons.password_rounded,
                        title: 'Reset All Passwords',
                        description: 'Set all user passwords to "1234"',
                        color: Colors.orange,
                        onTap: _resetPwAll,
                      ),
                      _ToolCard(
                        icon: Icons.build_rounded,
                        title: 'DB Repair',
                        description: 'PRAGMA integrity_check + VACUUM',
                        color: Colors.green,
                        onTap: _dbRepair,
                      ),
                      _ToolCard(
                        icon: Icons.vpn_key_rounded,
                        title: 'License Manager',
                        description: 'Manage application licenses and renewals',
                        color: Colors.blue,
                        onTap: _openLicenseManager,
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: () {
                          Session.I.exitDevMode();
                          Navigator.of(context).pushReplacementNamed('/login');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        icon: const Icon(Icons.exit_to_app),
                        label: const Text('Exit Dev Mode'),
                      ),
                    ],
                  ),
                );

                return isNarrow
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Flexible(
                            child: SingleChildScrollView(child: sidebar),
                          ),
                          const SizedBox(height: 16),
                          content,
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [sidebar, content],
                      );
              },
            ),
    );
  }

  Widget _SidebarStat(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(color: Colors.white70)),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final VoidCallback onTap;

  const _SidebarButton({
    required this.icon,
    required this.label,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final VoidCallback onTap;

  const _ToolCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppTheme.card,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppTheme.borderRadius,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTheme.titleMedium),
                    Text(description, style: AppTheme.bodySmall),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: color.withOpacity(0.5)),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String label;
  final String value;

  const _InfoCard(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppTheme.cardAlt,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(child: Text(label, style: AppTheme.bodyMedium)),
            Text(value, style: AppTheme.titleSmall),
          ],
        ),
      ),
    );
  }
}

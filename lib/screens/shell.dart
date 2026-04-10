import 'dart:async';
import 'package:flutter/material.dart';
import '../auth/license_service.dart';
import '../auth/roles.dart';
import '../auth/session.dart';
import '../data/app_settings.dart';
import '../data/dao_settings.dart';
import '../theme/app_theme.dart';
import 'admin_dashboard.dart';
import 'developer_mode_screen.dart';
import 'market_pos_screen.dart';
import 'tables_screen.dart';

class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkLicense());
  }

  Future<void> _checkLicense() async {
    await LicenseService.I.init();
    if (!mounted) return;
    if (LicenseService.I.isExpired) {
      Navigator.of(context).pushReplacementNamed('/license-lock');
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = Session.I.current!;
    Widget body;
    if (Session.I.isDeveloperMode) {
      body = const DeveloperModeScreen();
    } else if (canAccessAdminPanel(u.role)) {
      body = const AdminDashboard();
    } else {
      body = const _WaiterShell();
    }

    return Scaffold(backgroundColor: AppTheme.bg, body: body);
  }
}

// ── Waiter/Manager shell — mode-aware ────────────────────────────────────────
class _WaiterShell extends StatefulWidget {
  const _WaiterShell();

  @override
  State<_WaiterShell> createState() => _WaiterShellState();
}

class _WaiterShellState extends State<_WaiterShell> {
  String? _mode; // null = still loading
  Timer? _inactivityTimer;

  @override
  void initState() {
    super.initState();
    _loadMode();
    _resetInactivityTimer();
  }

  @override
  void dispose() {
    _inactivityTimer?.cancel();
    super.dispose();
  }

  void _resetInactivityTimer() {
    final minutes = AppSettings.I.autoLogoutMinutes;
    if (minutes <= 0) return; // feature disabled
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(Duration(minutes: minutes), _autoLogout);
  }

  void _autoLogout() {
    if (!mounted) return;
    Session.I.logout();
    Navigator.of(context).pushReplacementNamed('/login');
  }

  Future<void> _loadMode() async {
    final mode = await SettingsDao.I.getString(
      SettingsDao.businessMode,
      SettingsDao.defaultBusinessMode,
    );
    if (!mounted) return;
    setState(() => _mode = mode);
  }

  @override
  Widget build(BuildContext context) {
    if (_mode == 'market') {
      return const MarketPosScreen();
    }

    final u = Session.I.current!;
    final name = u.fullName?.trim().isNotEmpty == true
        ? u.fullName!.split(' ').first
        : u.username;
    final roleLabel = u.role == UserRole.manager ? 'Manager' : 'Kamarjer';

    Widget body;
    if (_mode == null) {
      body = const Center(
        child: CircularProgressIndicator(color: AppTheme.primary),
      );
    } else {
      body = const TablesScreen();
    }

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _resetInactivityTimer(),
      onPointerMove: (_) => _resetInactivityTimer(),
      child: Scaffold(
        backgroundColor: AppTheme.bg,
        body: Column(
          children: [
            _WaiterTopBar(name: name, roleLabel: roleLabel, mode: _mode),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}

class _WaiterTopBar extends StatelessWidget {
  final String name;
  final String roleLabel;
  final String? mode;
  const _WaiterTopBar({required this.name, required this.roleLabel, this.mode});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 10,
        bottom: 10,
        left: 20,
        right: 16,
      ),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(bottom: BorderSide(color: AppTheme.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Logo
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGrad,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.point_of_sale_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          // Title
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'EasyPOS',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  letterSpacing: -0.3,
                ),
              ),
              Text(
                mode == 'market' ? 'Kasa' : 'Tavolinat',
                style: AppTheme.caption.copyWith(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const Spacer(),
          // User info chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGrad,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      name[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      roleLabel,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Logout button
          _LogoutButton(),
        ],
      ),
    );
  }
}

class _LogoutButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Dil',
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              backgroundColor: AppTheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text('Dil nga sistemi', style: AppTheme.titleSmall),
              content: const Text(
                'Jeni të sigurt që doni të dilni?',
                style: AppTheme.bodyMedium,
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(
                    'Anulo',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.error,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Dil'),
                ),
              ],
            ),
          ).then((ok) {
            if (ok == true && context.mounted) {
              Session.I.logout();
              Navigator.of(context).pushReplacementNamed('/login');
            }
          });
        },
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppTheme.error.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.error.withValues(alpha: 0.20)),
          ),
          child: const Icon(
            Icons.logout_rounded,
            color: AppTheme.error,
            size: 18,
          ),
        ),
      ),
    );
  }
}

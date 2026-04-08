import 'package:flutter/material.dart';
import '../auth/session.dart';
import '../auth/roles.dart';
import '../theme/app_theme.dart';
import 'admin_dashboard.dart';
import 'tables_screen.dart';

class ShellScreen extends StatelessWidget {
  const ShellScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final u = Session.I.current!;
    if (u.role == UserRole.admin) {
      return const AdminDashboard();
    }
    return const _WaiterShell();
  }
}

// ── Waiter/Manager shell with premium top-bar ─────────────────────────────────
class _WaiterShell extends StatelessWidget {
  const _WaiterShell();

  @override
  Widget build(BuildContext context) {
    final u = Session.I.current!;
    final name = u.fullName?.trim().isNotEmpty == true
        ? u.fullName!.split(' ').first
        : u.username;
    final roleLabel = u.role == UserRole.manager ? 'Manager' : 'Kamarjer';

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Column(
        children: [
          // ── Premium top bar ───────────────────────────────────────────────
          _WaiterTopBar(name: name, roleLabel: roleLabel),
          // ── Tables content ────────────────────────────────────────────────
          const Expanded(child: TablesScreen()),
        ],
      ),
    );
  }
}

class _WaiterTopBar extends StatelessWidget {
  final String name;
  final String roleLabel;
  const _WaiterTopBar({required this.name, required this.roleLabel});

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
            width: 36, height: 36,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGrad,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.point_of_sale_rounded,
                color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          // Title
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('EasyPOS',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  letterSpacing: -0.3,
                ),
              ),
              Text('Tavolinat',
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
                  width: 24, height: 24,
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
                    Text(name,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    Text(roleLabel,
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
              title: const Text('Dil nga sistemi',
                style: AppTheme.titleSmall),
              content: const Text(
                'Jeni të sigurt që doni të dilni?',
                style: AppTheme.bodyMedium,
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text('Anulo',
                    style: TextStyle(color: AppTheme.textSecondary)),
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
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: AppTheme.error.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.error.withValues(alpha: 0.20)),
          ),
          child: const Icon(Icons.logout_rounded,
              color: AppTheme.error, size: 18),
        ),
      ),
    );
  }
}

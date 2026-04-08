import 'dart:ui';

import 'package:easy_pos/auth/dao_users.dart';
import 'package:flutter/material.dart';

import '../auth/roles.dart';
import '../auth/session.dart';

class ManageUsersScreen extends StatefulWidget {
  const ManageUsersScreen({super.key});

  @override
  State<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> {
  bool loading = true;
  List<AppUserRow> users = [];
  String search = '';
  String roleFilter = 'all';

  static const Color _bg = Color(0xFF07111F);
  static const Color _panel = Color(0xFF0E1A2B);
  static const Color _panelSoft = Color(0xFF12233A);
  static const Color _line = Color(0x1FFFFFFF);
  static const Color _textPrimary = Colors.white;
  static const Color _textSecondary = Color(0xFF9FB0C7);
  static const Color _accent = Color(0xFF7C3AED);
  static const Color _accent2 = Color(0xFF06B6D4);

  Future<void> _load() async {
    setState(() => loading = true);
    final list = await UsersDao.I.listUsers();
    if (!mounted) return;
    setState(() {
      users = list;
      loading = false;
    });
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _guardAdmin() {
    final u = Session.I.current!;
    if (u.role != UserRole.admin) {
      throw Exception('Forbidden: only admin');
    }
  }

  List<AppUserRow> get filteredUsers {
    return users.where((u) {
      final q = search.trim().toLowerCase();
      final name = (u.fullName ?? '').toLowerCase();
      final username = u.username.toLowerCase();
      final role = roleToString(u.role).toLowerCase();

      final matchesSearch =
          q.isEmpty ||
          name.contains(q) ||
          username.contains(q) ||
          role.contains(q);

      final matchesRole =
          roleFilter == 'all' ||
          (roleFilter == 'admin' && u.role == UserRole.admin) ||
          (roleFilter == 'manager' && u.role == UserRole.manager) ||
          (roleFilter == 'waiter' && u.role == UserRole.waiter);

      return matchesSearch && matchesRole;
    }).toList();
  }

  Future<void> _createUserDialog() async {
    _guardAdmin();

    final usernameC = TextEditingController();
    final fullNameC = TextEditingController();
    final passC = TextEditingController();
    UserRole role = UserRole.waiter;
    bool obscure = true;

    final ok = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.72),
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setS) {
            return _PremiumDialogShell(
              width: 560,
              title: 'Krijo user të ri',
              subtitle: 'Shto account të ri me stil modern dhe të pastër.',
              icon: Icons.person_add_alt_1_rounded,
              gradient: const [Color(0xFF8B5CF6), Color(0xFF06B6D4)],
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _premiumField(
                    controller: usernameC,
                    label: 'Username (unik)',
                    icon: Icons.alternate_email_rounded,
                  ),
                  const SizedBox(height: 14),
                  _premiumField(
                    controller: fullNameC,
                    label: 'Emri i plotë',
                    icon: Icons.badge_outlined,
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<UserRole>(
                    value: role,
                    dropdownColor: const Color(0xFF10233A),
                    style: const TextStyle(color: Colors.white),
                    items: const [
                      DropdownMenuItem(
                        value: UserRole.waiter,
                        child: Text('Waiter'),
                      ),
                      DropdownMenuItem(
                        value: UserRole.manager,
                        child: Text('Manager'),
                      ),
                    ],
                    onChanged: (v) => setS(() => role = v ?? UserRole.waiter),
                    decoration: _inputDecoration(
                      'Roli',
                      Icons.admin_panel_settings_outlined,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: passC,
                    obscureText: obscure,
                    style: const TextStyle(color: Colors.white),
                    decoration:
                        _inputDecoration(
                          'Password (min 4)',
                          Icons.lock_outline_rounded,
                        ).copyWith(
                          suffixIcon: IconButton(
                            onPressed: () => setS(() => obscure = !obscure),
                            icon: Icon(
                              obscure
                                  ? Icons.visibility_rounded
                                  : Icons.visibility_off_rounded,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                  ),
                  const SizedBox(height: 22),
                  _dialogActions(
                    cancelText: 'Anulo',
                    confirmText: 'Ruaj Userin',
                    onCancel: () => Navigator.pop(context, false),
                    onConfirm: () => Navigator.pop(context, true),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (ok != true) return;

    try {
      await UsersDao.I.createUser(
        username: usernameC.text,
        password: passC.text,
        role: role,
        fullName: fullNameC.text,
      );
      await _load();
      if (!mounted) return;
      _success('Useri u krijua me sukses ✅');
    } catch (e) {
      if (!mounted) return;
      _err(e.toString());
    }
  }

  Future<void> _editUserDialog(AppUserRow u) async {
    _guardAdmin();

    final fullNameC = TextEditingController(text: u.fullName ?? '');
    UserRole role = u.role;
    bool active = u.isActive;

    final ok = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.72),
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setS) {
            return _PremiumDialogShell(
              width: 560,
              title: 'Ndrysho @${u.username}',
              subtitle: 'Përditëso rolin, emrin dhe gjendjen e account-it.',
              icon: Icons.edit_rounded,
              gradient: const [Color(0xFF0EA5E9), Color(0xFF2563EB)],
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _premiumField(
                    controller: fullNameC,
                    label: 'Emri i plotë',
                    icon: Icons.badge_outlined,
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<UserRole>(
                    value: role,
                    dropdownColor: const Color(0xFF10233A),
                    style: const TextStyle(color: Colors.white),
                    items: const [
                      DropdownMenuItem(
                        value: UserRole.waiter,
                        child: Text('Waiter'),
                      ),
                      DropdownMenuItem(
                        value: UserRole.manager,
                        child: Text('Manager'),
                      ),
                      DropdownMenuItem(
                        value: UserRole.admin,
                        child: Text('Admin'),
                      ),
                    ],
                    onChanged: (v) => setS(() => role = v ?? u.role),
                    decoration: _inputDecoration(
                      'Roli',
                      Icons.admin_panel_settings_outlined,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    decoration: _glassBoxDecoration(radius: 20),
                    child: SwitchListTile(
                      value: active,
                      onChanged: (v) => setS(() => active = v),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      activeColor: Colors.white,
                      activeTrackColor: const Color(0xFF10B981),
                      inactiveThumbColor: Colors.white,
                      inactiveTrackColor: Colors.white24,
                      title: const Text(
                        'Statusi i account-it',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      subtitle: Text(
                        active
                            ? 'Useri ka qasje në sistem'
                            : 'Useri është i çaktivizuar',
                        style: const TextStyle(color: _textSecondary),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () async {
                        Navigator.pop(context, false);
                        await _resetPasswordDialog(u);
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 8,
                        ),
                      ),
                      icon: const Icon(Icons.lock_reset_rounded),
                      label: const Text('Reset Password'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _dialogActions(
                    cancelText: 'Anulo',
                    confirmText: 'Ruaj Ndryshimet',
                    onCancel: () => Navigator.pop(context, false),
                    onConfirm: () => Navigator.pop(context, true),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (ok != true) return;

    final meId = Session.I.current!.id;
    if (u.id == meId && !active) {
      _err('S’munesh me ç’aktivizu vetveten.');
      return;
    }

    try {
      await UsersDao.I.updateUser(
        id: u.id,
        role: role,
        isActive: active,
        isOnShift: u.isOnShift,
        fullName: fullNameC.text,
      );
      await _load();
      if (!mounted) return;
      _success('Useri u përditësua me sukses ✅');
    } catch (e) {
      if (!mounted) return;
      _err(e.toString());
    }
  }

  Future<void> _resetPasswordDialog(AppUserRow u) async {
    _guardAdmin();

    final passC = TextEditingController();
    bool obscure = true;

    final ok = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.72),
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setS) {
            return _PremiumDialogShell(
              width: 520,
              title: 'Reset password',
              subtitle: '@${u.username}',
              icon: Icons.lock_reset_rounded,
              gradient: const [Color(0xFFF59E0B), Color(0xFFEA580C)],
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: passC,
                    obscureText: obscure,
                    style: const TextStyle(color: Colors.white),
                    decoration:
                        _inputDecoration(
                          'Password i ri (min 4)',
                          Icons.lock_outline_rounded,
                        ).copyWith(
                          suffixIcon: IconButton(
                            onPressed: () => setS(() => obscure = !obscure),
                            icon: Icon(
                              obscure
                                  ? Icons.visibility_rounded
                                  : Icons.visibility_off_rounded,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                  ),
                  const SizedBox(height: 22),
                  _dialogActions(
                    cancelText: 'Anulo',
                    confirmText: 'Ruaj Passwordin',
                    onCancel: () => Navigator.pop(context, false),
                    onConfirm: () => Navigator.pop(context, true),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (ok != true) return;

    try {
      await UsersDao.I.resetPassword(u.id, passC.text);
      if (!mounted) return;
      _success('Password u ndryshua ✅');
    } catch (e) {
      _err(e.toString());
    }
  }

  Future<void> _toggleActive(AppUserRow u) async {
    final me = Session.I.current!;
    if (u.id == me.id && u.isActive) {
      _err('S’munesh me ç’aktivizu vetveten.');
      return;
    }

    await UsersDao.I.setActive(u.id, !u.isActive);
    await _load();
  }

  IconData _roleIcon(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return Icons.security_rounded;
      case UserRole.manager:
        return Icons.manage_accounts_rounded;
      case UserRole.waiter:
        return Icons.person_rounded;
    }
  }

  List<Color> _roleGradient(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return const [Color(0xFFEF4444), Color(0xFF7F1D1D)];
      case UserRole.manager:
        return const [Color(0xFF06B6D4), Color(0xFF2563EB)];
      case UserRole.waiter:
        return const [Color(0xFF10B981), Color(0xFF047857)];
    }
  }

  Color _roleBadgeColor(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return const Color(0xFFFDA4AF);
      case UserRole.manager:
        return const Color(0xFF7DD3FC);
      case UserRole.waiter:
        return const Color(0xFF86EFAC);
    }
  }

  String _roleShort(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return 'Admin';
      case UserRole.manager:
        return 'Manager';
      case UserRole.waiter:
        return 'Waiter';
    }
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: _textSecondary),
      prefixIcon: Icon(icon, color: Colors.white70),
      filled: true,
      fillColor: Colors.white.withOpacity(0.05),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: _accent2, width: 1.4),
      ),
    );
  }

  Widget _premiumField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      decoration: _inputDecoration(label, icon),
    );
  }

  BoxDecoration _glassBoxDecoration({double radius = 28}) {
    return BoxDecoration(
      color: Colors.white.withOpacity(0.08),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: Colors.white.withOpacity(0.10)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.18),
          blurRadius: 30,
          offset: const Offset(0, 20),
        ),
      ],
    );
  }

  void _err(String msg) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.72),
      builder: (_) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0F1C2C),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text('Gabim', style: TextStyle(color: Colors.white)),
          content: Text(msg, style: const TextStyle(color: _textSecondary)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Mbyll'),
            ),
          ],
        );
      },
    );
  }

  void _success(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF0B7A57),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Widget _dialogActions({
    required String cancelText,
    required String confirmText,
    required VoidCallback onCancel,
    required VoidCallback onConfirm,
  }) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: onCancel,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white70,
              side: BorderSide(color: Colors.white.withOpacity(0.12)),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: Text(cancelText),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF8B5CF6), Color(0xFF06B6D4)],
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF06B6D4).withOpacity(0.28),
                  blurRadius: 22,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: onConfirm,
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: Text(confirmText),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(bool isCompact) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: Stack(
        children: [
          Container(
            padding: EdgeInsets.all(isCompact ? 20 : 28),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF111827),
                  Color(0xFF1D4ED8),
                  Color(0xFF7C3AED),
                ],
              ),
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF7C3AED).withOpacity(0.24),
                  blurRadius: 34,
                  offset: const Offset(0, 22),
                ),
              ],
            ),
            child: isCompact
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _headerTopBar(),
                      const SizedBox(height: 16),
                      _headerTexts(),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _headerTopBar(),
                      const SizedBox(width: 18),
                      Expanded(child: _headerTexts()),
                      const SizedBox(width: 16),
                      _highlightPill(),
                    ],
                  ),
          ),
          Positioned(
            right: -20,
            top: -25,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.08),
              ),
            ),
          ),
          Positioned(
            right: 90,
            bottom: -50,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.06),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerTopBar() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: () => Navigator.of(context).maybePop(),
          borderRadius: BorderRadius.circular(18),
          child: Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withOpacity(0.14)),
            ),
            child: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFFFFF), Color(0xFFD8B4FE)],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(
            Icons.people_alt_rounded,
            color: Color(0xFF312E81),
            size: 30,
          ),
        ),
      ],
    );
  }

  Widget _headerTexts() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Manage Users',
          style: TextStyle(
            color: Colors.white,
            fontSize: 30,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.4,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Panel premium për krijim, editim, filtër, status dhe reset password me pamje moderne dark-glass.',
          style: TextStyle(
            color: Color(0xFFE5EEF9),
            fontSize: 14.5,
            height: 1.55,
          ),
        ),
      ],
    );
  }

  Widget _highlightPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.workspace_premium_rounded,
            color: Colors.amberAccent,
            size: 18,
          ),
          SizedBox(width: 8),
          Text(
            'Premium Admin Panel',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required List<Color> colors,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: colors.last.withOpacity(0.25),
            blurRadius: 26,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.16),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar(bool isCompact) {
    final searchBox = Expanded(
      flex: isCompact ? 0 : 2,
      child: TextField(
        onChanged: (v) => setState(() => search = v),
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Search user, username, role...',
          hintStyle: const TextStyle(color: _textSecondary),
          prefixIcon: const Icon(Icons.search_rounded, color: Colors.white70),
          filled: true,
          fillColor: Colors.white.withOpacity(0.05),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: _accent2),
          ),
        ),
      ),
    );

    final roleDropdown = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: roleFilter,
          dropdownColor: const Color(0xFF10233A),
          style: const TextStyle(color: Colors.white),
          borderRadius: BorderRadius.circular(18),
          items: const [
            DropdownMenuItem(value: 'all', child: Text('All Roles')),
            DropdownMenuItem(value: 'admin', child: Text('Admin')),
            DropdownMenuItem(value: 'manager', child: Text('Manager')),
            DropdownMenuItem(value: 'waiter', child: Text('Waiter')),
          ],
          onChanged: (v) {
            if (v == null) return;
            setState(() => roleFilter = v);
          },
        ),
      ),
    );

    final addBtn = DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF8B5CF6), Color(0xFF06B6D4)],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF06B6D4).withOpacity(0.25),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: _createUserDialog,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Shto User'),
      ),
    );

    final refreshBtn = OutlinedButton.icon(
      onPressed: _load,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: BorderSide(color: Colors.white.withOpacity(0.10)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      icon: const Icon(Icons.refresh_rounded),
      label: const Text('Refresh'),
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _glassBoxDecoration(radius: 28),
      child: isCompact
          ? Column(
              children: [
                SizedBox(width: double.infinity, child: searchBox),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: roleDropdown),
                    const SizedBox(width: 10),
                    Expanded(child: addBtn),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(width: double.infinity, child: refreshBtn),
              ],
            )
          : Row(
              children: [
                searchBox,
                const SizedBox(width: 12),
                roleDropdown,
                const SizedBox(width: 12),
                addBtn,
                const SizedBox(width: 12),
                refreshBtn,
              ],
            ),
    );
  }

  Widget _buildUserCard(AppUserRow u, bool isCompact) {
    final me = Session.I.current!;
    final title = (u.fullName?.trim().isNotEmpty ?? false)
        ? u.fullName!.trim()
        : u.username;
    final gradient = _roleGradient(u.role);

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.08),
                Colors.white.withOpacity(0.04),
              ],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withOpacity(0.10)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.18),
                blurRadius: 32,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 62,
                    height: 62,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(colors: gradient),
                    ),
                    child: Icon(
                      _roleIcon(u.role),
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            _statusChip(u.isActive),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '@${u.username}',
                          style: const TextStyle(
                            color: _textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _miniPill(
                              Icons.verified_user_outlined,
                              _roleShort(u.role),
                              _roleBadgeColor(u.role),
                            ),
                            _miniPill(
                              Icons.schedule_rounded,
                              u.isOnShift ? 'On Shift' : 'Off Shift',
                              u.isOnShift
                                  ? const Color(0xFF7DD3FC)
                                  : const Color(0xFFCBD5E1),
                            ),
                            if (u.id == me.id)
                              _miniPill(
                                Icons.star_rounded,
                                'Current Account',
                                const Color(0xFFFDE68A),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (isCompact)
                Column(
                  children: [
                    SizedBox(width: double.infinity, child: _primaryAction(u)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: _toggleAction(u)),
                        const SizedBox(width: 10),
                        Expanded(child: _resetAction(u)),
                      ],
                    ),
                  ],
                )
              else
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _primaryAction(u),
                    _toggleAction(u),
                    _resetAction(u),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _primaryAction(AppUserRow u) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3B82F6), Color(0xFF06B6D4)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ElevatedButton.icon(
        onPressed: () => _editUserDialog(u),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        icon: const Icon(Icons.edit_rounded),
        label: const Text('Ndrysho'),
      ),
    );
  }

  Widget _toggleAction(AppUserRow u) {
    final active = u.isActive;
    return ElevatedButton.icon(
      onPressed: () => _toggleActive(u),
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: active
            ? const Color(0xFF7F1D1D)
            : const Color(0xFF064E3B),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      icon: Icon(active ? Icons.block_rounded : Icons.check_circle_rounded),
      label: Text(active ? 'Disable' : 'Enable'),
    );
  }

  Widget _resetAction(AppUserRow u) {
    return OutlinedButton.icon(
      onPressed: () => _resetPasswordDialog(u),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: BorderSide(color: Colors.white.withOpacity(0.10)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      icon: const Icon(Icons.lock_reset_rounded),
      label: const Text('Reset Password'),
    );
  }

  Widget _miniPill(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: active
            ? const Color(0xFF10B981).withOpacity(0.14)
            : const Color(0xFFEF4444).withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: active
              ? const Color(0xFF10B981).withOpacity(0.24)
              : const Color(0xFFEF4444).withOpacity(0.20),
        ),
      ),
      child: Text(
        active ? 'Active' : 'Disabled',
        style: TextStyle(
          color: active ? const Color(0xFF86EFAC) : const Color(0xFFFCA5A5),
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 34),
      decoration: _glassBoxDecoration(radius: 28),
      child: const Column(
        children: [
          Icon(Icons.people_outline_rounded, size: 52, color: Colors.white54),
          SizedBox(height: 14),
          Text(
            'Nuk u gjet asnjë user',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Ndrysho search ose filtrin e roleve për me pa rezultatet.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _textSecondary, height: 1.5),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final me = Session.I.current!;
    final isAdmin = me.role == UserRole.admin;

    if (!isAdmin) {
      return const Scaffold(
        body: Center(child: Text('Vetëm Admin mundet me menaxhu users.')),
      );
    }

    final totalUsers = users.length;
    final admins = users.where((e) => e.role == UserRole.admin).length;
    final managers = users.where((e) => e.role == UserRole.manager).length;
    final waiters = users.where((e) => e.role == UserRole.waiter).length;

    return Scaffold(
      backgroundColor: _bg,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF07111F), Color(0xFF091728), Color(0xFF0A1220)],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -120,
              left: -60,
              child: _bgGlow(const Color(0xFF7C3AED), 260),
            ),
            Positioned(
              right: -90,
              top: 140,
              child: _bgGlow(const Color(0xFF06B6D4), 300),
            ),
            SafeArea(
              child: loading
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: _accent,
                      backgroundColor: const Color(0xFF0F1C2C),
                      child: LayoutBuilder(
                        builder: (context, c) {
                          final isCompact = c.maxWidth < 900;

                          return ListView(
                            padding: EdgeInsets.all(isCompact ? 16 : 22),
                            children: [
                              _buildHeader(isCompact),
                              const SizedBox(height: 18),
                              if (isCompact)
                                Column(
                                  children: [
                                    _buildStatCard(
                                      icon: Icons.groups_rounded,
                                      title: 'Total Users',
                                      value: '$totalUsers',
                                      colors: const [
                                        Color(0xFF8B5CF6),
                                        Color(0xFF5B21B6),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    _buildStatCard(
                                      icon: Icons.security_rounded,
                                      title: 'Admins',
                                      value: '$admins',
                                      colors: const [
                                        Color(0xFFEF4444),
                                        Color(0xFF7F1D1D),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    _buildStatCard(
                                      icon: Icons.manage_accounts_rounded,
                                      title: 'Managers',
                                      value: '$managers',
                                      colors: const [
                                        Color(0xFF06B6D4),
                                        Color(0xFF1D4ED8),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    _buildStatCard(
                                      icon: Icons.person_rounded,
                                      title: 'Waiters',
                                      value: '$waiters',
                                      colors: const [
                                        Color(0xFF10B981),
                                        Color(0xFF047857),
                                      ],
                                    ),
                                  ],
                                )
                              else
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildStatCard(
                                        icon: Icons.groups_rounded,
                                        title: 'Total Users',
                                        value: '$totalUsers',
                                        colors: const [
                                          Color(0xFF8B5CF6),
                                          Color(0xFF5B21B6),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildStatCard(
                                        icon: Icons.security_rounded,
                                        title: 'Admins',
                                        value: '$admins',
                                        colors: const [
                                          Color(0xFFEF4444),
                                          Color(0xFF7F1D1D),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildStatCard(
                                        icon: Icons.manage_accounts_rounded,
                                        title: 'Managers',
                                        value: '$managers',
                                        colors: const [
                                          Color(0xFF06B6D4),
                                          Color(0xFF1D4ED8),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildStatCard(
                                        icon: Icons.person_rounded,
                                        title: 'Waiters',
                                        value: '$waiters',
                                        colors: const [
                                          Color(0xFF10B981),
                                          Color(0xFF047857),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              const SizedBox(height: 18),
                              _buildToolbar(isCompact),
                              const SizedBox(height: 18),
                              if (filteredUsers.isEmpty)
                                _emptyState()
                              else
                                ...filteredUsers.map(
                                  (u) => _buildUserCard(u, isCompact),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bgGlow(Color color, double size) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color.withOpacity(0.22), color.withOpacity(0.0)],
          ),
        ),
      ),
    );
  }
}

class _PremiumDialogShell extends StatelessWidget {
  final double width;
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> gradient;
  final Widget child;

  const _PremiumDialogShell({
    required this.width,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            width: width,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF0F1C2C).withOpacity(0.96),
                  const Color(0xFF12233A).withOpacity(0.96),
                ],
              ),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.white.withOpacity(0.10)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.34),
                  blurRadius: 36,
                  offset: const Offset(0, 22),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          gradient: LinearGradient(colors: gradient),
                        ),
                        child: Icon(icon, color: Colors.white, size: 30),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              subtitle,
                              style: const TextStyle(
                                color: Color(0xFF9FB0C7),
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  child,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'dart:math';

import 'package:easy_pos/auth/dao_users.dart';
import 'package:flutter/material.dart';

import '../auth/roles.dart';
import '../auth/session.dart';

class ManageUsersScreen extends StatefulWidget {
  final String initialRoleFilter;

  const ManageUsersScreen({super.key, this.initialRoleFilter = 'all'});

  @override
  State<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> {
  bool loading = true;
  List<AppUserRow> users = [];
  String search = '';
  String roleFilter = 'all';
  String statusFilter = 'all'; // all | active | inactive
  int currentPage = 1;
  static const int pageSize = 8;

  // ─── Colors ───────────────────────────────────────────────────────────────
  static const Color _bg = Color(0xFF0A0F1C);
  static const Color _surface = Color(0xFF111827);
  static const Color _surfaceAlt = Color(0xFF1A2335);
  static const Color _border = Color(0xFF1F2D40);
  static const Color _textPrimary = Color(0xFFF1F5F9);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _textMuted = Color(0xFF334155);
  static const Color _accent = Color(0xFF3B82F6);
  static const Color _danger = Color(0xFFEF4444);
  static const Color _success = Color(0xFF10B981);
  static const Color _warning = Color(0xFFF59E0B);

  // ─── Data ─────────────────────────────────────────────────────────────────
  Future<void> _load() async {
    setState(() => loading = true);
    final list = await UsersDao.I.listUsers();
    if (!mounted) return;
    setState(() {
      users = list;
      loading = false;
      currentPage = 1;
    });
  }

  @override
  void initState() {
    super.initState();
    roleFilter = widget.initialRoleFilter;
    _load();
  }

  void _guardAdmin() {
    final me = Session.I.current!;
    if (me.role != UserRole.admin &&
        me.role != UserRole.superAdmin &&
        me.role != UserRole.developer) {
      throw Exception('Forbidden: only admin/superAdmin/developer');
    }
  }

  List<AppUserRow> get filteredUsers {
    return users.where((u) {
      final q = search.trim().toLowerCase();
      final name = (u.fullName ?? '').toLowerCase();
      final username = u.username.toLowerCase();
      final role = roleToString(u.role).toLowerCase();

      final matchSearch =
          q.isEmpty ||
          name.contains(q) ||
          username.contains(q) ||
          role.contains(q);

      final matchRole =
          roleFilter == 'all' ||
          (roleFilter == 'admin' && u.role == UserRole.admin) ||
          (roleFilter == 'manager' && u.role == UserRole.manager) ||
          (roleFilter == 'waiter' && u.role == UserRole.waiter);

      final matchStatus =
          statusFilter == 'all' ||
          (statusFilter == 'active' && u.isActive) ||
          (statusFilter == 'inactive' && !u.isActive);

      return matchSearch && matchRole && matchStatus;
    }).toList();
  }

  List<AppUserRow> get pagedUsers {
    final all = filteredUsers;
    final start = (currentPage - 1) * pageSize;
    final end = min(start + pageSize, all.length);
    if (start >= all.length) return [];
    return all.sublist(start, end);
  }

  int get totalPages => max(1, (filteredUsers.length / pageSize).ceil());

  // ─── Dialogs ──────────────────────────────────────────────────────────────
  Future<void> _createUserDialog() async {
    _guardAdmin();
    final usernameC = TextEditingController();
    final fullNameC = TextEditingController();
    final passC = TextEditingController();
    UserRole role = UserRole.waiter;
    bool obscure = true;

    final ok = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.70),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => _DialogShell(
          title: 'Krijo User të Ri',
          subtitle: 'Shto account të ri në sistem',
          icon: Icons.person_add_alt_1_rounded,
          iconColor: _accent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _field(
                controller: usernameC,
                label: 'Username',
                icon: Icons.alternate_email_rounded,
              ),
              const SizedBox(height: 12),
              _field(
                controller: fullNameC,
                label: 'Emri i plotë',
                icon: Icons.badge_outlined,
              ),
              const SizedBox(height: 12),
              _roleDropdown(
                role,
                (v) => setS(() => role = v ?? UserRole.waiter),
              ),
              const SizedBox(height: 12),
              _passField(passC, obscure, () => setS(() => obscure = !obscure)),
              const SizedBox(height: 22),
              _dialogActions(
                'Anulo',
                'Ruaj',
                () => Navigator.pop(ctx, false),
                () => Navigator.pop(ctx, true),
              ),
            ],
          ),
        ),
      ),
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
      _snack('Useri u krijua me sukses', success: true);
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString(), success: false);
    }
  }

  Future<void> _editUserDialog(AppUserRow u) async {
    _guardAdmin();
    final fullNameC = TextEditingController(text: u.fullName ?? '');
    UserRole role = u.role;
    bool active = u.isActive;

    final ok = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.70),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => _DialogShell(
          title: 'Ndrysho @${u.username}',
          subtitle: 'Përditëso rolin, emrin dhe statusin',
          icon: Icons.edit_rounded,
          iconColor: const Color(0xFF8B5CF6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _field(
                controller: fullNameC,
                label: 'Emri i plotë',
                icon: Icons.badge_outlined,
              ),
              const SizedBox(height: 12),
              _roleDropdown(
                role,
                (v) => setS(() => role = v ?? u.role),
                includeAdmin: true,
              ),
              const SizedBox(height: 12),
              _switchTile(
                value: active,
                onChanged: (v) => setS(() => active = v),
                title: 'Statusi i account-it',
                subtitle: active ? 'Aktiv — ka qasje' : 'Çaktivizuar',
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () async {
                    Navigator.pop(ctx, false);
                    await _resetPasswordDialog(u);
                  },
                  style: TextButton.styleFrom(foregroundColor: _textSecondary),
                  icon: const Icon(Icons.lock_reset_rounded, size: 16),
                  label: const Text(
                    'Reset Password',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _dialogActions(
                'Anulo',
                'Ruaj Ndryshimet',
                () => Navigator.pop(ctx, false),
                () => Navigator.pop(ctx, true),
              ),
            ],
          ),
        ),
      ),
    );
    if (ok != true) return;

    final meId = Session.I.current!.id;
    if (u.id == meId && !active) {
      _snack('S\'munesh me ç\'aktivizu vetveten.', success: false);
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
      _snack('Useri u përditësua', success: true);
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString(), success: false);
    }
  }

  Future<void> _resetPasswordDialog(AppUserRow u) async {
    _guardAdmin();
    final passC = TextEditingController();
    bool obscure = true;

    final ok = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.70),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => _DialogShell(
          title: 'Reset Password',
          subtitle: '@${u.username}',
          icon: Icons.lock_reset_rounded,
          iconColor: _warning,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _passField(
                passC,
                obscure,
                () => setS(() => obscure = !obscure),
                label: 'Password i ri (min 4)',
              ),
              const SizedBox(height: 22),
              _dialogActions(
                'Anulo',
                'Ruaj',
                () => Navigator.pop(ctx, false),
                () => Navigator.pop(ctx, true),
              ),
            ],
          ),
        ),
      ),
    );
    if (ok != true) return;
    try {
      await UsersDao.I.resetPassword(u.id, passC.text);
      if (!mounted) return;
      _snack('Password u ndryshua', success: true);
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString(), success: false);
    }
  }

  Future<void> _deleteUserDialog(AppUserRow u) async {
    _guardAdmin();
    final me = Session.I.current!;
    if (u.id == me.id) {
      _snack('S\'munesh me fshi vetveten.', success: false);
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.70),
      builder: (_) => _DialogShell(
        title: 'Fshi Userin',
        subtitle: 'Kjo veprim nuk mund të kthehet prapa.',
        icon: Icons.delete_forever_rounded,
        iconColor: _danger,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _danger.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _danger.withOpacity(0.20)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: _danger.withOpacity(0.8),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'A je i sigurt që dëshiron të fshish @${u.username}?',
                      style: TextStyle(
                        color: _danger.withOpacity(0.9),
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: _outlineBtn(
                    'Anulo',
                    () => Navigator.pop(context, false),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _solidBtn(
                    'Fshi',
                    () => Navigator.pop(context, true),
                    color: _danger,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      await UsersDao.I.deleteUser(u.id);
      await _load();
      if (!mounted) return;
      _snack('Useri u fshi', success: true);
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString(), success: false);
    }
  }

  // ─── Form helpers ─────────────────────────────────────────────────────────
  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: _textPrimary, fontSize: 14),
      decoration: _dec(label, icon),
    );
  }

  Widget _passField(
    TextEditingController c,
    bool obscure,
    VoidCallback toggle, {
    String label = 'Password (min 4)',
  }) {
    return TextField(
      controller: c,
      obscureText: obscure,
      style: const TextStyle(color: _textPrimary, fontSize: 14),
      decoration: _dec(label, Icons.lock_outline_rounded).copyWith(
        suffixIcon: IconButton(
          onPressed: toggle,
          icon: Icon(
            obscure ? Icons.visibility_rounded : Icons.visibility_off_rounded,
            color: _textSecondary,
            size: 18,
          ),
        ),
      ),
    );
  }

  Widget _roleDropdown(
    UserRole value,
    ValueChanged<UserRole?> onChanged, {
    bool includeAdmin = false,
  }) {
    return DropdownButtonFormField<UserRole>(
      value: value,
      dropdownColor: _surfaceAlt,
      style: const TextStyle(color: _textPrimary, fontSize: 14),
      decoration: _dec('Roli', Icons.admin_panel_settings_outlined),
      items: [
        const DropdownMenuItem(value: UserRole.waiter, child: Text('Waiter')),
        const DropdownMenuItem(value: UserRole.manager, child: Text('Manager')),
        if (includeAdmin)
          const DropdownMenuItem(value: UserRole.admin, child: Text('Admin')),
      ],
      onChanged: onChanged,
    );
  }

  Widget _switchTile({
    required bool value,
    required ValueChanged<bool> onChanged,
    required String title,
    required String subtitle,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        activeColor: Colors.white,
        activeTrackColor: _success,
        inactiveThumbColor: Colors.white,
        inactiveTrackColor: _border,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        title: Text(
          title,
          style: const TextStyle(
            color: _textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: _textSecondary, fontSize: 12.5),
        ),
      ),
    );
  }

  Widget _dialogActions(
    String cancel,
    String confirm,
    VoidCallback onCancel,
    VoidCallback onConfirm,
  ) {
    return Row(
      children: [
        Expanded(child: _outlineBtn(cancel, onCancel)),
        const SizedBox(width: 10),
        Expanded(child: _solidBtn(confirm, onConfirm)),
      ],
    );
  }

  Widget _outlineBtn(String label, VoidCallback onTap) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: _textSecondary,
        side: const BorderSide(color: _border),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }

  Widget _solidBtn(String label, VoidCallback onTap, {Color color = _accent}) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }

  InputDecoration _dec(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: _textSecondary, fontSize: 13.5),
      prefixIcon: Icon(icon, color: _textSecondary, size: 18),
      filled: true,
      fillColor: _surfaceAlt,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _accent, width: 1.5),
      ),
    );
  }

  void _snack(String msg, {required bool success}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              success ? Icons.check_circle_rounded : Icons.error_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(msg, style: const TextStyle(fontSize: 13.5))),
          ],
        ),
        backgroundColor: success
            ? const Color(0xFF065F46)
            : const Color(0xFF7F1D1D),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ─── Role helpers ─────────────────────────────────────────────────────────
  String _roleName(UserRole r) {
    switch (r) {
      case UserRole.developer:
        return 'Developer';
      case UserRole.superAdmin:
        return 'Super Admin';
      case UserRole.admin:
        return 'Admin';
      case UserRole.manager:
        return 'Manager';
      case UserRole.waiter:
        return 'Waiter';
    }
  }

  Color _roleColor(UserRole r) {
    switch (r) {
      case UserRole.developer:
        return const Color(0xFFFF6B6B);
      case UserRole.superAdmin:
        return const Color(0xFF4ECDC4);
      case UserRole.admin:
        return const Color(0xFFF87171);
      case UserRole.manager:
        return const Color(0xFF60A5FA);
      case UserRole.waiter:
        return const Color(0xFF34D399);
    }
  }

  Color _roleBg(UserRole r) {
    return switch (r) {
      UserRole.developer => const Color(0xFF8B0000),
      UserRole.superAdmin => const Color(0xFF006666),
      UserRole.admin => const Color(0xFF7F1D1D),
      UserRole.manager => const Color(0xFF1E3A5F),
      UserRole.waiter => const Color(0xFF064E3B),
    };
  }

  IconData _roleIcon(UserRole r) {
    return switch (r) {
      UserRole.developer => Icons.code_rounded,
      UserRole.superAdmin => Icons.admin_panel_settings_rounded,
      UserRole.admin => Icons.security_rounded,
      UserRole.manager => Icons.manage_accounts_rounded,
      UserRole.waiter => Icons.person_rounded,
    };
  }

  String _joinedLabel(AppUserRow u) {
    final dt = DateTime.fromMillisecondsSinceEpoch(u.createdAt);
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return 'Sot';
    if (diff.inDays == 1) return 'Dje';
    if (diff.inDays < 7) return '${diff.inDays}d';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}j';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}m';
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
  }

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final me = Session.I.current!;
    if (!canManageUsers(me.role)) {
      return Scaffold(
        backgroundColor: _bg,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.admin_panel_settings_outlined,
                size: 64,
                color: _textSecondary,
              ),
              const SizedBox(height: 16),
              Text(
                'Vetëm Admin/Super Admin/Developer mundet me menaxhu users.',
                style: TextStyle(color: _textSecondary, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final activeCount = users.where((u) => u.isActive).length;

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: loading
            ? const Center(
                child: CircularProgressIndicator(
                  color: _accent,
                  strokeWidth: 2,
                ),
              )
            : LayoutBuilder(
                builder: (ctx, c) {
                  final compact = c.maxWidth < 800;
                  return Column(
                    children: [
                      _buildTopBar(compact, activeCount),
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: _load,
                          color: _accent,
                          backgroundColor: _surface,
                          child: ListView(
                            padding: EdgeInsets.symmetric(
                              horizontal: compact ? 16 : 28,
                              vertical: 20,
                            ),
                            children: [
                              _buildFilters(compact),
                              const SizedBox(height: 16),
                              _buildTable(compact),
                              const SizedBox(height: 16),
                              _buildPagination(),
                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
      ),
    );
  }

  // ─── Top bar ──────────────────────────────────────────────────────────────
  Widget _buildTopBar(bool compact, int activeCount) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 16 : 28,
        vertical: 16,
      ),
      decoration: const BoxDecoration(
        color: _surface,
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _topBarLeft(),
                const SizedBox(height: 12),
                _topBarStats(activeCount),
                const SizedBox(height: 12),
                _topBarActions(),
              ],
            )
          : Row(
              children: [
                _topBarLeft(),
                const Spacer(),
                _topBarStats(activeCount),
                const SizedBox(width: 24),
                _topBarActions(),
              ],
            ),
    );
  }

  Widget _topBarLeft() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () => Navigator.of(context).maybePop(),
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _surfaceAlt,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _border),
            ),
            child: const Icon(
              Icons.arrow_back_rounded,
              color: _textSecondary,
              size: 18,
            ),
          ),
        ),
        const SizedBox(width: 14),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'User Management',
              style: TextStyle(
                color: _textPrimary,
                fontSize: 19,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Menaxho accountet e sistemit',
              style: TextStyle(color: _textSecondary, fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }

  Widget _topBarStats(int activeCount) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _statPill('Total Users', '${users.length}', _accent),
        const SizedBox(width: 10),
        _statPill('Active Users', '$activeCount', _success),
      ],
    );
  }

  Widget _statPill(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color.withOpacity(0.8),
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _topBarActions() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _iconBtn(Icons.refresh_rounded, 'Refresh', _load),
        const SizedBox(width: 8),
        _addUserBtn(),
      ],
    );
  }

  Widget _iconBtn(IconData icon, String tooltip, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _surfaceAlt,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _border),
          ),
          child: Icon(icon, color: _textSecondary, size: 18),
        ),
      ),
    );
  }

  Widget _addUserBtn() {
    return ElevatedButton.icon(
      onPressed: _createUserDialog,
      style: ElevatedButton.styleFrom(
        backgroundColor: _accent,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      icon: const Icon(Icons.add_rounded, size: 18),
      label: const Text(
        'Add User',
        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
      ),
    );
  }

  // ─── Filters ──────────────────────────────────────────────────────────────
  Widget _buildFilters(bool compact) {
    final searchBar = Expanded(
      flex: 2,
      child: SizedBox(
        height: 42,
        child: TextField(
          onChanged: (v) => setState(() {
            search = v;
            currentPage = 1;
          }),
          style: const TextStyle(color: _textPrimary, fontSize: 13.5),
          decoration: InputDecoration(
            hintText: 'Kërko sipas emrit, username, rolit...',
            hintStyle: const TextStyle(color: _textMuted, fontSize: 13),
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: _textSecondary,
              size: 18,
            ),
            filled: true,
            fillColor: _surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _accent),
            ),
          ),
        ),
      ),
    );

    final roleDD = Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: roleFilter,
          dropdownColor: _surfaceAlt,
          style: const TextStyle(color: _textPrimary, fontSize: 13.5),
          borderRadius: BorderRadius.circular(10),
          items: const [
            DropdownMenuItem(value: 'all', child: Text('All Roles')),
            DropdownMenuItem(value: 'admin', child: Text('Admin')),
            DropdownMenuItem(value: 'manager', child: Text('Manager')),
            DropdownMenuItem(value: 'waiter', child: Text('Waiter')),
          ],
          onChanged: (v) {
            if (v != null)
              setState(() {
                roleFilter = v;
                currentPage = 1;
              });
          },
        ),
      ),
    );

    final statusTabs = _StatusTabs(
      selected: statusFilter,
      onChanged: (v) => setState(() {
        statusFilter = v;
        currentPage = 1;
      }),
    );

    return compact
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [searchBar]),
              const SizedBox(height: 10),
              Row(
                children: [
                  roleDD,
                  const SizedBox(width: 10),
                  Expanded(child: statusTabs),
                ],
              ),
            ],
          )
        : Row(
            children: [
              searchBar,
              const SizedBox(width: 10),
              roleDD,
              const SizedBox(width: 10),
              statusTabs,
            ],
          );
  }

  // ─── Table ────────────────────────────────────────────────────────────────
  Widget _buildTable(bool compact) {
    final rows = pagedUsers;
    final me = Session.I.current!;

    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          if (!compact) _tableHeader(),
          if (rows.isEmpty)
            _emptyState()
          else
            Column(
              children: rows.map((u) => _tableRow(u, me.id, compact)).toList(),
            ),
          _tableFooter(),
        ],
      ),
    );
  }

  Widget _tableHeader() {
    const style = TextStyle(
      color: _textSecondary,
      fontSize: 11.5,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.3,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        color: _surfaceAlt,
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: const Row(
        children: [
          Expanded(flex: 3, child: Text('EMRI', style: style)),
          Expanded(flex: 2, child: Text('ROLI', style: style)),
          Expanded(flex: 2, child: Text('STATUSI', style: style)),
          Expanded(flex: 2, child: Text('SHIFT', style: style)),
          Expanded(flex: 2, child: Text('REGJISTRUAR', style: style)),
          SizedBox(
            width: 160,
            child: Text('VEPRIMET', style: style, textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }

  Widget _tableRow(AppUserRow u, int meId, bool compact) {
    final displayName = (u.fullName?.trim().isNotEmpty ?? false)
        ? u.fullName!.trim()
        : u.username;
    final isMe = u.id == meId;

    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: compact
          ? _compactRow(u, displayName, isMe)
          : _fullRow(u, displayName, isMe),
    );
  }

  Widget _fullRow(AppUserRow u, String displayName, bool isMe) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Expanded(flex: 3, child: _nameCell(u, displayName, isMe)),
          Expanded(flex: 2, child: _roleBadge(u.role)),
          Expanded(flex: 2, child: _statusBadge(u.isActive)),
          Expanded(flex: 2, child: _shiftBadge(u.isOnShift)),
          Expanded(
            flex: 2,
            child: Text(
              _joinedLabel(u),
              style: const TextStyle(color: _textSecondary, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(flex: 2, child: _rowActions(u, isMe)),
        ],
      ),
    );
  }

  Widget _compactRow(AppUserRow u, String displayName, bool isMe) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _avatar(u, size: 42),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            displayName,
                            style: const TextStyle(
                              color: _textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        if (isMe) ...[
                          const SizedBox(width: 6),
                          _pill(
                            'Unë',
                            const Color(0xFFFBBF24),
                            const Color(0xFF451A03),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '@${u.username}',
                      style: const TextStyle(
                        color: _textSecondary,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              _statusBadge(u.isActive),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _roleBadge(u.role),
              _shiftBadge(u.isOnShift),
              _pill(_joinedLabel(u), _textSecondary, _surfaceAlt),
            ],
          ),
          const SizedBox(height: 12),
          _rowActions(u, isMe),
        ],
      ),
    );
  }

  Widget _nameCell(AppUserRow u, String displayName, bool isMe) {
    return Row(
      children: [
        _avatar(u, size: 36),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      displayName,
                      style: const TextStyle(
                        color: _textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 6),
                    _pill(
                      'Unë',
                      const Color(0xFFFBBF24),
                      const Color(0xFF451A03),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                '@${u.username}',
                style: const TextStyle(color: _textSecondary, fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _avatar(AppUserRow u, {double size = 36}) {
    final raw = (u.fullName?.trim() ?? '');
    final initials = raw.isNotEmpty
        ? raw
              .split(' ')
              .map((w) => w.isNotEmpty ? w[0] : '')
              .take(2)
              .join()
              .toUpperCase()
        : u.username.substring(0, min(2, u.username.length)).toUpperCase();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _roleBg(u.role),
        borderRadius: BorderRadius.circular(size * 0.28),
        border: Border.all(color: _roleColor(u.role).withOpacity(0.30)),
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: _roleColor(u.role),
            fontWeight: FontWeight.w800,
            fontSize: size * 0.34,
          ),
        ),
      ),
    );
  }

  Widget _roleBadge(UserRole r) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _roleBg(r),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _roleColor(r).withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_roleIcon(r), size: 13, color: _roleColor(r)),
          const SizedBox(width: 5),
          Text(
            _roleName(r),
            style: TextStyle(
              color: _roleColor(r),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: active ? const Color(0xFF064E3B) : const Color(0xFF450A0A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: active
              ? _success.withOpacity(0.30)
              : _danger.withOpacity(0.30),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active ? _success : _danger,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            active ? 'Active' : 'Inactive',
            style: TextStyle(
              color: active ? _success : _danger,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _shiftBadge(bool onShift) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: onShift ? const Color(0xFF1E3A5F) : _surfaceAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: onShift ? const Color(0xFF60A5FA).withOpacity(0.30) : _border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            onShift ? Icons.work_rounded : Icons.work_off_rounded,
            size: 13,
            color: onShift ? const Color(0xFF60A5FA) : _textSecondary,
          ),
          const SizedBox(width: 5),
          Text(
            onShift ? 'On Shift' : 'Off',
            style: TextStyle(
              color: onShift ? const Color(0xFF60A5FA) : _textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill(String text, Color fg, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _border),
      ),
      child: Text(
        text,
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _rowActions(AppUserRow u, bool isMe) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        _actionBtn(
          label: 'Edit',
          icon: Icons.edit_rounded,
          color: _accent,
          onTap: () => _editUserDialog(u),
        ),
        const SizedBox(width: 8),
        _actionBtn(
          label: 'Delete',
          icon: Icons.delete_outline_rounded,
          color: _danger,
          onTap: isMe ? null : () => _deleteUserDialog(u),
        ),
      ],
    );
  }

  Widget _actionBtn({
    required String label,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    final disabled = onTap == null;
    return Opacity(
      opacity: disabled ? 0.35 : 1.0,
      child: InkWell(
        onTap: disabled ? null : onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: color.withOpacity(0.10),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.22)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: _surfaceAlt,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _border),
              ),
              child: const Icon(
                Icons.people_outline_rounded,
                color: _textSecondary,
                size: 26,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Nuk u gjet asnjë user',
              style: TextStyle(
                color: _textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Ndrysho filtrat ose shto user të ri.',
              style: TextStyle(color: _textSecondary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tableFooter() {
    final filtered = filteredUsers;
    final start = filtered.isEmpty ? 0 : (currentPage - 1) * pageSize + 1;
    final end = min(currentPage * pageSize, filtered.length);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        color: _surfaceAlt,
        border: Border(top: BorderSide(color: _border)),
      ),
      child: Text(
        filtered.isEmpty
            ? '0 rezultate'
            : 'Duke shfaqur $start – $end nga ${filtered.length}',
        style: const TextStyle(color: _textSecondary, fontSize: 12.5),
      ),
    );
  }

  // ─── Pagination ───────────────────────────────────────────────────────────
  Widget _buildPagination() {
    if (totalPages <= 1) return const SizedBox.shrink();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _pageBtn(
          Icons.chevron_left_rounded,
          currentPage > 1 ? () => setState(() => currentPage--) : null,
        ),
        const SizedBox(width: 6),
        ...List.generate(totalPages, (i) {
          final page = i + 1;
          final active = page == currentPage;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: InkWell(
              onTap: () => setState(() => currentPage = page),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: active ? _accent : _surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: active ? _accent : _border),
                ),
                child: Center(
                  child: Text(
                    '$page',
                    style: TextStyle(
                      color: active ? Colors.white : _textSecondary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
        const SizedBox(width: 6),
        _pageBtn(
          Icons.chevron_right_rounded,
          currentPage < totalPages ? () => setState(() => currentPage++) : null,
        ),
      ],
    );
  }

  Widget _pageBtn(IconData icon, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Opacity(
        opacity: onTap == null ? 0.3 : 1.0,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _border),
          ),
          child: Icon(icon, color: _textSecondary, size: 18),
        ),
      ),
    );
  }
}

// ─── Status Tabs ──────────────────────────────────────────────────────────────
class _StatusTabs extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const _StatusTabs({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF1F2D40)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _tab('all', 'All'),
          _tab('active', 'Active'),
          _tab('inactive', 'Inactive'),
        ],
      ),
    );
  }

  Widget _tab(String value, String label) {
    final active = selected == value;
    return GestureDetector(
      onTap: () => onChanged(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF3B82F6) : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : const Color(0xFF64748B),
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

// ─── Dialog Shell ─────────────────────────────────────────────────────────────
class _DialogShell extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final Widget child;

  const _DialogShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        width: 520,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF1F2D40)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 40,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: iconColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: iconColor.withOpacity(0.22)),
                    ),
                    child: Icon(icon, color: iconColor, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Color(0xFFF1F5F9),
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(false),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A2335),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF1F2D40)),
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        color: Color(0xFF64748B),
                        size: 16,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(color: Color(0xFF1F2D40), height: 1),
              const SizedBox(height: 20),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

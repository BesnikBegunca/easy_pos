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
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setS) => Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              width: 520,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: const Color(0xFF111827),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.30),
                    blurRadius: 30,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            gradient: const LinearGradient(
                              colors: [Color(0xFF7C3AED), Color(0xFF2563EB)],
                            ),
                          ),
                          child: const Icon(
                            Icons.person_add_alt_1,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Text(
                            'Create New User',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    _premiumField(
                      controller: usernameC,
                      label: 'Username (unik)',
                      icon: Icons.alternate_email_rounded,
                    ),
                    const SizedBox(height: 12),
                    _premiumField(
                      controller: fullNameC,
                      label: 'Emri i plotë (opsional)',
                      icon: Icons.badge_outlined,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<UserRole>(
                      value: role,
                      dropdownColor: const Color(0xFF1F2937),
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
                    const SizedBox(height: 12),
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
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                                color: Colors.white70,
                              ),
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
                              side: BorderSide(
                                color: Colors.white.withOpacity(0.14),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            child: const Text('Anulo'),
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
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            child: const Text('Ruaj Userin'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
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
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setS) => Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              width: 520,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: const Color(0xFF111827),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.30),
                    blurRadius: 30,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            gradient: const LinearGradient(
                              colors: [Color(0xFF0EA5E9), Color(0xFF2563EB)],
                            ),
                          ),
                          child: const Icon(
                            Icons.edit_rounded,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            'Edit @${u.username}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    _premiumField(
                      controller: fullNameC,
                      label: 'Emri i plotë',
                      icon: Icons.badge_outlined,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<UserRole>(
                      value: role,
                      dropdownColor: const Color(0xFF1F2937),
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
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.08),
                        ),
                      ),
                      child: SwitchListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 4,
                        ),
                        value: active,
                        onChanged: (v) => setS(() => active = v),
                        title: const Text(
                          'Aktiv',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: Text(
                          active
                              ? 'Useri ka qasje në sistem'
                              : 'Useri është disabled',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          Navigator.pop(context, false);
                          await _resetPasswordDialog(u);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(
                            color: Colors.white.withOpacity(0.14),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: const Icon(Icons.lock_reset_rounded),
                        label: const Text('Reset Password'),
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
                              side: BorderSide(
                                color: Colors.white.withOpacity(0.14),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            child: const Text('Anulo'),
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
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            child: const Text('Ruaj Ndryshimet'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
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
      _err(e.toString());
    }
  }

  Future<void> _resetPasswordDialog(AppUserRow u) async {
    _guardAdmin();

    final passC = TextEditingController();
    bool obscure = true;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setS) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: 500,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: const Color(0xFF111827),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.30),
                  blurRadius: 30,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        gradient: const LinearGradient(
                          colors: [Color(0xFFF59E0B), Color(0xFFEA580C)],
                        ),
                      ),
                      child: const Icon(
                        Icons.lock_reset_rounded,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'Reset password: @${u.username}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
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
                            obscure ? Icons.visibility : Icons.visibility_off,
                            color: Colors.white70,
                          ),
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
                          side: BorderSide(
                            color: Colors.white.withOpacity(0.14),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: const Text('Anulo'),
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
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: const Text('Ruaj Passwordin'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
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
        return const [Color(0xFFEF4444), Color(0xFFB91C1C)];
      case UserRole.manager:
        return const [Color(0xFF0EA5E9), Color(0xFF2563EB)];
      case UserRole.waiter:
        return const [Color(0xFF10B981), Color(0xFF059669)];
    }
  }

  Color _roleBadgeColor(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return const Color(0xFFDC2626);
      case UserRole.manager:
        return const Color(0xFF2563EB);
      case UserRole.waiter:
        return const Color(0xFF059669);
    }
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      prefixIcon: Icon(icon, color: Colors.white70),
      filled: true,
      fillColor: Colors.white.withOpacity(0.06),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFF7C3AED)),
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

  void _err(String msg) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Gabim'),
        content: Text(msg),
      ),
    );
  }

  void _success(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  Widget _buildHeader() {
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => Navigator.of(context).maybePop(),
            borderRadius: BorderRadius.circular(18),
            child: Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.10),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withOpacity(0.12)),
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.10),
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Icon(
              Icons.people_alt_rounded,
              size: 34,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Manage Users',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 29,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Krijo usera të rinj, menaxho role, aktivizo ose çaktivizo accounts dhe bëj reset password me një UI premium.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ],
            ),
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
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.14),
              borderRadius: BorderRadius.circular(16),
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

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 280,
            child: TextField(
              onChanged: (v) => setState(() => search = v),
              decoration: InputDecoration(
                hintText: 'Search user...',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: roleFilter,
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
          ),
          ElevatedButton.icon(
            onPressed: _createUserDialog,
            style: ElevatedButton.styleFrom(
              elevation: 0,
              backgroundColor: const Color(0xFF7C3AED),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            icon: const Icon(Icons.person_add_alt_1_rounded),
            label: const Text('Shto User'),
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
      ),
    );
  }

  Widget _buildUserCard(AppUserRow u) {
    final me = Session.I.current!;
    final title = (u.fullName?.trim().isNotEmpty ?? false)
        ? u.fullName!.trim()
        : u.username;

    final gradient = _roleGradient(u.role);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
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
                  gradient: LinearGradient(colors: gradient),
                ),
                child: Icon(_roleIcon(u.role), color: Colors.white, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFF111827),
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '@${u.username}',
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              _statusChip(u.isActive),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _infoBadge(
                icon: Icons.verified_user_outlined,
                label: 'Role',
                value: roleToString(u.role),
                valueColor: _roleBadgeColor(u.role),
              ),
              _infoBadge(
                icon: Icons.power_settings_new_rounded,
                label: 'Status',
                value: u.isActive ? 'Active' : 'Disabled',
                valueColor: u.isActive
                    ? const Color(0xFF059669)
                    : const Color(0xFFDC2626),
              ),
              _infoBadge(
                icon: Icons.schedule_rounded,
                label: 'Shift',
                value: u.isOnShift ? 'On Shift' : 'Off Shift',
                valueColor: u.isOnShift
                    ? const Color(0xFF2563EB)
                    : const Color(0xFF6B7280),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ElevatedButton.icon(
                onPressed: () => _editUserDialog(u),
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: const Color(0xFF0EA5E9),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.edit_rounded),
                label: const Text('Ndrysho'),
              ),
              ElevatedButton.icon(
                onPressed: () => _toggleActive(u),
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: u.isActive
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
                  u.isActive ? Icons.block_rounded : Icons.check_circle_rounded,
                ),
                label: Text(u.isActive ? 'Disable' : 'Enable'),
              ),
              OutlinedButton.icon(
                onPressed: () => _resetPasswordDialog(u),
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
                icon: const Icon(Icons.lock_reset_rounded),
                label: const Text('Reset Password'),
              ),
              if (u.id == me.id)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text(
                    'Current account',
                    style: TextStyle(
                      color: Color(0xFF6B7280),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoBadge({
    required IconData icon,
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Container(
      constraints: const BoxConstraints(minWidth: 160),
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
                style: TextStyle(
                  color: valueColor,
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

  Widget _statusChip(bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: active
            ? const Color(0xFF10B981).withOpacity(0.12)
            : const Color(0xFFEF4444).withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        active ? 'Active' : 'Disabled',
        style: TextStyle(
          color: active ? const Color(0xFF059669) : const Color(0xFFDC2626),
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
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
                    LayoutBuilder(
                      builder: (context, c) {
                        final wide = c.maxWidth > 900;
                        if (!wide) {
                          return Column(
                            children: [
                              _buildStatCard(
                                icon: Icons.groups_rounded,
                                title: 'Total Users',
                                value: '$totalUsers',
                                colors: const [
                                  Color(0xFF7C3AED),
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
                                  Color(0xFFB91C1C),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _buildStatCard(
                                icon: Icons.manage_accounts_rounded,
                                title: 'Managers',
                                value: '$managers',
                                colors: const [
                                  Color(0xFF0EA5E9),
                                  Color(0xFF2563EB),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _buildStatCard(
                                icon: Icons.person_rounded,
                                title: 'Waiters',
                                value: '$waiters',
                                colors: const [
                                  Color(0xFF10B981),
                                  Color(0xFF059669),
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
                                title: 'Total Users',
                                value: '$totalUsers',
                                colors: const [
                                  Color(0xFF7C3AED),
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
                                  Color(0xFFB91C1C),
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
                                  Color(0xFF0EA5E9),
                                  Color(0xFF2563EB),
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
                                  Color(0xFF059669),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 18),
                    _buildToolbar(),
                    const SizedBox(height: 18),
                    const Text(
                      'Users Overview',
                      style: TextStyle(
                        color: Color(0xFF111827),
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${filteredUsers.length} usera të gjetur',
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (filteredUsers.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: const Center(
                          child: Text(
                            'Nuk u gjet asnjë user.',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ),
                      )
                    else
                      ...filteredUsers.map(_buildUserCard),
                  ],
                ),
              ),
      ),
    );
  }
}

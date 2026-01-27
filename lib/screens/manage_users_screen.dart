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

  Future<void> _createUserDialog() async {
    _guardAdmin();

    final usernameC = TextEditingController();
    final fullNameC = TextEditingController();
    final passC = TextEditingController();
    UserRole role = UserRole.waiter;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setS) => AlertDialog(
            title: const Text('Shto User'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: usernameC,
                    decoration: const InputDecoration(
                      labelText: 'Username (unik)',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: fullNameC,
                    decoration: const InputDecoration(
                      labelText: 'Emri (opsional)',
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<UserRole>(
                    value: role,
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
                    decoration: const InputDecoration(labelText: 'Roli'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: passC,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password (min 4)',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Anulo'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Ruaj'),
              ),
            ],
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
          builder: (context, setS) => AlertDialog(
            title: Text('Edit: @${u.username}'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: fullNameC,
                    decoration: const InputDecoration(labelText: 'Emri'),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<UserRole>(
                    value: role,
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
                    decoration: const InputDecoration(labelText: 'Roli'),
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: active,
                    onChanged: (v) => setS(() => active = v),
                    title: const Text('Aktiv'),
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        Navigator.pop(context, false);
                        await _resetPasswordDialog(u);
                      },
                      icon: const Icon(Icons.lock_reset),
                      label: const Text('Reset Password'),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Anulo'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Ruaj'),
              ),
            ],
          ),
        );
      },
    );

    if (ok != true) return;

    // mos lejo admin-in me e ç’aktivizu veten pa dashje
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
        fullName: fullNameC.text,
      );
      await _load();
    } catch (e) {
      _err(e.toString());
    }
  }

  Future<void> _resetPasswordDialog(AppUserRow u) async {
    _guardAdmin();

    final passC = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Reset password: @${u.username}'),
        content: SizedBox(
          width: 420,
          child: TextField(
            controller: passC,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Password i ri (min 4)',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Anulo'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Ruaj'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await UsersDao.I.resetPassword(u.id, passC.text);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Password u ndryshua ✅')));
    } catch (e) {
      _err(e.toString());
    }
  }

  void _err(String msg) {
    showDialog(
      context: context,
      builder: (_) =>
          AlertDialog(title: const Text('Gabim'), content: Text(msg)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final me = Session.I.current!;
    final isAdmin = me.role == UserRole.admin;

    if (!isAdmin) {
      return const Center(child: Text('Vetëm Admin mundet me menaxhu users.'));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Users'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
          const SizedBox(width: 6),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _createUserDialog,
                        icon: const Icon(Icons.person_add),
                        label: const Text('Shto User'),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Këtu krijon Manager/Waiter accounts, aktivizon/çaktivizon, reset pass.',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Card(
                      child: ListView.separated(
                        itemCount: users.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final u = users[i];
                          final title = (u.fullName?.trim().isNotEmpty ?? false)
                              ? u.fullName!
                              : u.username;

                          return ListTile(
                            leading: Icon(
                              u.role == UserRole.admin
                                  ? Icons.security
                                  : u.role == UserRole.manager
                                  ? Icons.manage_accounts
                                  : Icons.person,
                            ),
                            title: Text(title),
                            subtitle: Text(
                              '@${u.username} • ${roleToString(u.role)} • ${u.isActive ? "active" : "disabled"}',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Edit',
                                  onPressed: () => _editUserDialog(u),
                                  icon: const Icon(Icons.edit),
                                ),
                                IconButton(
                                  tooltip: u.isActive ? 'Disable' : 'Enable',
                                  onPressed: () async {
                                    // mos e disable vetveten
                                    if (u.id == me.id && u.isActive) {
                                      _err('S’munesh me ç’aktivizu vetveten.');
                                      return;
                                    }
                                    await UsersDao.I.setActive(
                                      u.id,
                                      !u.isActive,
                                    );
                                    await _load();
                                  },
                                  icon: Icon(
                                    u.isActive
                                        ? Icons.block
                                        : Icons.check_circle,
                                  ),
                                ),
                              ],
                            ),
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
}

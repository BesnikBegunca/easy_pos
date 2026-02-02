import 'package:easy_pos/screens/tables_screen.dart';
import 'package:flutter/material.dart';
import '../auth/session.dart';
import '../auth/roles.dart';
import 'admin_dashboard.dart';

class ShellScreen extends StatelessWidget {
  const ShellScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final u = Session.I.current!;
    Widget body;

    // brenda ShellScreen build:
    if (u.role == UserRole.waiter)
      body = const TablesScreen();
    else if (u.role == UserRole.manager)
      body = const TablesScreen(); // + ma vonë reports
    else if (u.role == UserRole.admin)
      body = const AdminDashboard();
    else
      body = const TablesScreen(); // fallback

    return Scaffold(
      appBar: AppBar(
        title: Text('POS — ${u.username} (${roleToString(u.role)})'),
        actions: [
          TextButton(
            onPressed: () {
              Session.I.logout();
              Navigator.of(context).pushReplacementNamed('/login');
            },
            child: const Text('Logout'),
          ),
        ],
      ),
      body: body,
    );
  }
}

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

    // Admin has its own full-screen scaffold with custom nav
    if (u.role == UserRole.admin) {
      return const AdminDashboard();
    }

    // Waiter / manager
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
      body: const TablesScreen(),
    );
  }
}

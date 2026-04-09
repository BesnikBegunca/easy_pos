import 'package:flutter/material.dart';
import 'roles.dart';
import 'session.dart';

void requireReportsAccess(BuildContext context) {
  final u = Session.I.current!;
  if (!canViewReports(u.role)) {
    showDialog(
      context: context,
      builder: (_) => const AlertDialog(
        title: Text('S’ke leje'),
        content: Text(
          'Raportet i shohin vetëm Developer/Super Admin/Admin/Manager.',
        ),
      ),
    );
    throw Exception('Forbidden');
  }
}

void requireDevMode(BuildContext context) {
  if (!Session.I.isDeveloperMode) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Developer Mode Required'),
        content: const Text(
          'This feature requires Developer Mode (dev123 PIN).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    throw Exception('Developer Mode Required');
  }
}

void requireSuperAdmin(BuildContext context) {
  final u = Session.I.current!;
  if (u.role != UserRole.superAdmin && !Session.I.isDeveloperMode) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Super Admin Required'),
        content: const Text(
          'This action requires Super Admin or Developer Mode.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    throw Exception('Super Admin Required');
  }
}

void requireManagerOrHigher(BuildContext context) {
  final u = Session.I.current!;
  if (roleLevel(u.role) < 2) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Manager Required'),
        content: const Text('This feature requires Manager or higher role.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    throw Exception('Manager or Higher Required');
  }
}

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
        content: Text('Raportet i shohin vetëm Manager/Admin.'),
      ),
    );
    throw Exception('Forbidden');
  }
}

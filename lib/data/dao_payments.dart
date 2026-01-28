import 'db.dart';

import 'package:sqflite_common/sqlite_api.dart';

class PaymentRow {
  final int id;
  final int tableId;
  final int totalCents;
  final String method; // cash/card/mixed
  final int paidAt;
  final int paidBy;

  PaymentRow({
    required this.id,
    required this.tableId,
    required this.totalCents,
    required this.method,
    required this.paidAt,
    required this.paidBy,
  });
}

class PaymentsDao {
  PaymentsDao._();
  static final PaymentsDao I = PaymentsDao._();

  /// ✅ Create payment using existing DB executor (txn or db)
  Future<int> createPayment({
    required DatabaseExecutor ex,
    required int tableId,
    required int totalCents,
    required String method, // cash/card/mixed
    required int paidBy,
  }) async {
    return ex.insert('payments', {
      'table_id': tableId,
      'total_cents': totalCents,
      'method': method,
      'paid_at': DateTime.now().millisecondsSinceEpoch,
      'paid_by': paidBy,
    });
  }
}

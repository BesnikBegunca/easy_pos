import 'package:sqflite_common/sqlite_api.dart';
import 'db.dart';
import 'dao_payments.dart';

class OrderLine {
  final int itemId;
  final int productId;
  final String name;
  final int qty;
  final int unitPriceCents;
  final int lineTotalCents;
  final String? note;

  OrderLine({
    required this.itemId,
    required this.productId,
    required this.name,
    required this.qty,
    required this.unitPriceCents,
    required this.lineTotalCents,
    this.note,
  });
}

class OrdersDao {
  OrdersDao._();
  static final OrdersDao I = OrdersDao._();

  Future<int> getOrCreateOpenOrder({
    required int tableId,
    required int waiterId,
  }) async {
    final db = await AppDb.I.db;

    final existing = await db.query(
      'orders',
      where: 'table_id=? AND status=?',
      whereArgs: [tableId, 'open'],
      limit: 1,
    );
    if (existing.isNotEmpty) return existing.first['id'] as int;

    try {
      return await db.transaction((txn) async {
        final updated = await txn.update(
          'dining_tables',
          {'status': 'open', 'waiter_id': waiterId},
          where: 'id=?',
          whereArgs: [tableId],
        );
        if (updated == 0) {
          throw Exception('Table not found or inactive: $tableId');
        }

        final waiterRows = await txn.query(
          'users',
          where: 'id=?',
          whereArgs: [waiterId],
          limit: 1,
        );
        if (waiterRows.isEmpty) {
          throw Exception('Waiter not found: $waiterId');
        }

        final id = await txn.insert('orders', {
          'table_id': tableId,
          'waiter_id': waiterId,
          'status': 'open',
          'total_cents': 0,
          'created_at': DateTime.now().millisecondsSinceEpoch,
          'closed_at': null,
          'settled_id': null,
        });

        return id;
      });
    } catch (e, st) {
      print('Error creating/opening order for table $tableId: $e\n$st');
      rethrow;
    }
  }

  Future<List<OrderLine>> getOrderLines(int orderId) async {
    final db = await AppDb.I.db;
    final rows = await db.rawQuery(
      '''
SELECT 
  oi.id AS item_id,
  oi.product_id,
  p.name AS product_name,
  oi.qty,
  oi.unit_price_cents,
  oi.line_total_cents,
  oi.note
FROM order_items oi
JOIN products p ON p.id = oi.product_id
WHERE oi.order_id=?
ORDER BY oi.id DESC
''',
      [orderId],
    );

    return rows
        .map(
          (e) => OrderLine(
            itemId: e['item_id'] as int,
            productId: e['product_id'] as int,
            name: (e['product_name'] as String?) ?? 'Unknown Product',
            qty: (e['qty'] as int?) ?? 0,
            unitPriceCents: (e['unit_price_cents'] as int?) ?? 0,
            lineTotalCents: (e['line_total_cents'] as int?) ?? 0,
            note: e['note'] as String?,
          ),
        )
        .toList();
  }

  Future<int> getOrderTotalCents(int orderId) async {
    final db = await AppDb.I.db;
    final rows = await db.rawQuery(
      'SELECT COALESCE(SUM(line_total_cents),0) AS s FROM order_items WHERE order_id=?',
      [orderId],
    );
    return (rows.first['s'] as int?) ?? 0;
  }

  Future<void> addProductToOrder({
    required int orderId,
    required int productId,
    required int unitPriceCents,
  }) async {
    final db = await AppDb.I.db;
    final ex = await db.query(
      'order_items',
      where: 'order_id=? AND product_id=?',
      whereArgs: [orderId, productId],
      limit: 1,
    );

    if (ex.isEmpty) {
      await db.insert('order_items', {
        'order_id': orderId,
        'product_id': productId,
        'qty': 1,
        'unit_price_cents': unitPriceCents,
        'line_total_cents': unitPriceCents,
        'note': null,
      });
    } else {
      final id = ex.first['id'] as int;
      final qty = (ex.first['qty'] as int?) ?? 0;
      final newQty = qty + 1;
      final newTotal = newQty * unitPriceCents;

      await db.update(
        'order_items',
        {'qty': newQty, 'line_total_cents': newTotal},
        where: 'id=?',
        whereArgs: [id],
      );
    }

    await _recalcOrderTotal(orderId);
  }

  Future<void> changeQty({
    required int itemId,
    required int orderId,
    required int newQty,
  }) async {
    final db = await AppDb.I.db;

    if (newQty <= 0) {
      await db.delete('order_items', where: 'id=?', whereArgs: [itemId]);
      await _recalcOrderTotal(orderId);
      return;
    }

    final row = await db.query(
      'order_items',
      where: 'id=?',
      whereArgs: [itemId],
      limit: 1,
    );
    if (row.isEmpty) return;

    final unit = (row.first['unit_price_cents'] as int?) ?? 0;

    await db.update(
      'order_items',
      {'qty': newQty, 'line_total_cents': newQty * unit},
      where: 'id=?',
      whereArgs: [itemId],
    );

    await _recalcOrderTotal(orderId);
  }

  Future<void> updateNote({required int itemId, required String? note}) async {
    final db = await AppDb.I.db;
    await db.update(
      'order_items',
      {'note': note},
      where: 'id=?',
      whereArgs: [itemId],
    );
  }

  Future<void> checkout({
    required int orderId,
    required String paymentMethod, // cash/card/mixed
    required int paidBy,
  }) async {
    final db = await AppDb.I.db;

    await db.transaction((txn) async {
      final orderRows = await txn.query(
        'orders',
        where: 'id=?',
        whereArgs: [orderId],
        limit: 1,
      );
      if (orderRows.isEmpty) return;

      final order = orderRows.first;
      final tableId = order['table_id'] as int;
      final waiterId = order['waiter_id'] as int;

      final totalRows = await txn.rawQuery(
        'SELECT COALESCE(SUM(line_total_cents),0) AS s FROM order_items WHERE order_id=?',
        [orderId],
      );
      final total = (totalRows.first['s'] as int?) ?? 0;

      // close order
      await txn.update(
        'orders',
        {
          'status': 'paid',
          'total_cents': total,
          'closed_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id=?',
        whereArgs: [orderId],
      );

      // ✅ payment with order_id
      await PaymentsDao.I.createPayment(
        ex: txn,
        tableId: tableId,
        orderId: orderId,
        totalCents: total,
        method: paymentMethod,
        paidBy: paidBy,
      );

      // ✅ sales row (ONLY ONCE)
      await txn.insert('sales', {
        'waiter_id': waiterId,
        'total_cents': total,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });

      // free table
      await txn.update(
        'dining_tables',
        {'status': 'free', 'waiter_id': null},
        where: 'id=?',
        whereArgs: [tableId],
      );
    });
  }

  Future<void> _recalcOrderTotal(int orderId) async {
    final db = await AppDb.I.db;
    final rows = await db.rawQuery(
      'SELECT COALESCE(SUM(line_total_cents),0) AS s FROM order_items WHERE order_id=?',
      [orderId],
    );
    final total = (rows.first['s'] as int?) ?? 0;
    await db.update(
      'orders',
      {'total_cents': total},
      where: 'id=?',
      whereArgs: [orderId],
    );
  }

  Future<int> countOpenOrdersByWaiter(int waiterId) async {
    final db = await AppDb.I.db;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM orders WHERE waiter_id = ? AND status = "open"',
      [waiterId],
    );
    return (rows.first['c'] as int?) ?? 0;
  }

  Future<int> countOrdersByWaiterInRange(
    int waiterId,
    int startMs,
    int endMs,
  ) async {
    final db = await AppDb.I.db;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM orders WHERE waiter_id = ? AND created_at >= ? AND created_at < ?',
      [waiterId, startMs, endMs],
    );
    return (rows.first['c'] as int?) ?? 0;
  }

  Future<int> getDaySum(int waiterId, int startMs) async {
    final db = await AppDb.I.db;
    final rows = await db.rawQuery(
      'SELECT COALESCE(SUM(oi.line_total_cents), 0) AS total FROM orders o JOIN order_items oi ON o.id = oi.order_id WHERE o.waiter_id = ? AND o.created_at >= ? AND oi.is_printed = 1',
      [waiterId, startMs],
    );
    return (rows.first['total'] as int?) ?? 0;
  }

  Future<void> markItemsAsPrinted(int orderId) async {
    final db = await AppDb.I.db;
    await db.update(
      'order_items',
      {'is_printed': 1},
      where: 'order_id = ?',
      whereArgs: [orderId],
    );
  }
}

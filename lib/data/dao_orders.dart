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

  /// ✅ Returns open order id for this table, creates it if missing.
  /// Also ensures the table exists and marks it 'open' when order is created.
  Future<int> getOrCreateOpenOrder({
    required int tableId,
    required int waiterId,
  }) async {
    final db = await AppDb.I.db;

    // ✅ Ensure table exists (optional safety)
    final tableExists = await db.query(
      'dining_tables',
      where: 'id=?',
      whereArgs: [tableId],
      limit: 1,
    );

    if (tableExists.isEmpty) {
      // ⚠️ Don't set explicit id unless you really need it.
      // But keeping your original behavior:
      await db.insert('dining_tables', {
        'id': tableId,
        'name': 'Tavolina $tableId',
        'status': 'free',
        'is_active': 1,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });
    }

    // ✅ If open order exists return it
    final existing = await db.query(
      'orders',
      where: 'table_id=? AND status=?',
      whereArgs: [tableId, 'open'],
      limit: 1,
    );

    if (existing.isNotEmpty) return existing.first['id'] as int;

    // ✅ Mark table status open
    await db.update(
      'dining_tables',
      {'status': 'open'},
      where: 'id=?',
      whereArgs: [tableId],
    );

    // ✅ Create new open order
    return db.insert('orders', {
      'table_id': tableId,
      'waiter_id': waiterId,
      'status': 'open',
      'total_cents': 0,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// ✅ Order lines (cart)
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

  /// ✅ Total from items (source of truth)
  Future<int> getOrderTotalCents(int orderId) async {
    final db = await AppDb.I.db;
    final rows = await db.rawQuery(
      'SELECT COALESCE(SUM(line_total_cents),0) AS s FROM order_items WHERE order_id=?',
      [orderId],
    );
    return (rows.first['s'] as int?) ?? 0;
  }

  /// ✅ Add product to order (qty increments if exists)
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
        'note': null, // ✅ requires note column (migrated)
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

  /// ✅ Change qty (0 -> delete)
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

  /// ✅ Update note text for an item
  Future<void> updateNote({required int itemId, required String? note}) async {
    final db = await AppDb.I.db;
    await db.update(
      'order_items',
      {'note': note},
      where: 'id=?',
      whereArgs: [itemId],
    );
  }

  /// ✅ Checkout transaction: payment + close order + free table + sales row
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

      // ✅ compute total inside txn
      final totalRows = await txn.rawQuery(
        'SELECT COALESCE(SUM(line_total_cents),0) AS s FROM order_items WHERE order_id=?',
        [orderId],
      );
      final total = (totalRows.first['s'] as int?) ?? 0;

      // ✅ close order
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

      // ✅ create payment using txn executor
      await PaymentsDao.I.createPayment(
        ex: txn,
        tableId: tableId,
        totalCents: total,
        method: paymentMethod,
        paidBy: paidBy,
      );

      // ✅ table back to free
      await txn.update(
        'dining_tables',
        {'status': 'free'},
        where: 'id=?',
        whereArgs: [tableId],
      );

      // ✅ sales row for dashboards
      await txn.insert('sales', {
        'waiter_id': waiterId,
        'total_cents': total,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });
    });
  }

  /// ✅ Recalculate order total and store in orders.total_cents
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
}

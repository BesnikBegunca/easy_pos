import 'db.dart';

class OrderLine {
  final int itemId;
  final int productId;
  final String name;
  final int qty;
  final int unitPriceCents;
  final int lineTotalCents;

  OrderLine({
    required this.itemId,
    required this.productId,
    required this.name,
    required this.qty,
    required this.unitPriceCents,
    required this.lineTotalCents,
  });
}

class OrdersDao {
  OrdersDao._();
  static final OrdersDao I = OrdersDao._();

  Future<int> getOrCreateOpenOrder({required int tableId, required int waiterId}) async {
    final db = await AppDb.I.db;

    final existing = await db.query(
      'orders',
      where: 'table_id=? AND status=?',
      whereArgs: [tableId, 'open'],
      limit: 1,
    );

    if (existing.isNotEmpty) return existing.first['id'] as int;

    return db.insert('orders', {
      'table_id': tableId,
      'waiter_id': waiterId,
      'status': 'open',
      'total_cents': 0,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<List<OrderLine>> getOrderLines(int orderId) async {
    final db = await AppDb.I.db;
    final rows = await db.rawQuery('''
SELECT 
  oi.id AS item_id,
  oi.product_id,
  p.name,
  oi.qty,
  oi.unit_price_cents,
  oi.line_total_cents
FROM order_items oi
JOIN products p ON p.id = oi.product_id
WHERE oi.order_id=?
ORDER BY oi.id DESC
''', [orderId]);

    return rows.map((e) => OrderLine(
      itemId: e['item_id'] as int,
      productId: e['product_id'] as int,
      name: e['name'] as String,
      qty: e['qty'] as int,
      unitPriceCents: e['unit_price_cents'] as int,
      lineTotalCents: e['line_total_cents'] as int,
    )).toList();
  }

  Future<int> getOrderTotalCents(int orderId) async {
    final db = await AppDb.I.db;
    final rows = await db.rawQuery('SELECT COALESCE(SUM(line_total_cents),0) AS s FROM order_items WHERE order_id=?', [orderId]);
    return (rows.first['s'] as int?) ?? 0;
  }

  Future<void> addProductToOrder({required int orderId, required int productId, required int unitPriceCents}) async {
    final db = await AppDb.I.db;

    // nëse ekziston item me të njëjtin produkt -> qty +1
    final ex = await db.query('order_items', where: 'order_id=? AND product_id=?', whereArgs: [orderId, productId], limit: 1);

    if (ex.isEmpty) {
      await db.insert('order_items', {
        'order_id': orderId,
        'product_id': productId,
        'qty': 1,
        'unit_price_cents': unitPriceCents,
        'line_total_cents': unitPriceCents,
      });
    } else {
      final id = ex.first['id'] as int;
      final qty = ex.first['qty'] as int;
      final newQty = qty + 1;
      final newTotal = newQty * unitPriceCents;

      await db.update('order_items', {
        'qty': newQty,
        'line_total_cents': newTotal,
      }, where: 'id=?', whereArgs: [id]);
    }

    await _recalcOrderTotal(orderId);
  }

  Future<void> changeQty({required int itemId, required int orderId, required int newQty}) async {
    final db = await AppDb.I.db;
    if (newQty <= 0) {
      await db.delete('order_items', where: 'id=?', whereArgs: [itemId]);
    } else {
      final row = await db.query('order_items', where: 'id=?', whereArgs: [itemId], limit: 1);
      final unit = row.first['unit_price_cents'] as int;
      await db.update('order_items', {
        'qty': newQty,
        'line_total_cents': newQty * unit,
      }, where: 'id=?', whereArgs: [itemId]);
    }
    await _recalcOrderTotal(orderId);
  }

  Future<void> checkout({required int orderId}) async {
    final db = await AppDb.I.db;

    final order = (await db.query('orders', where: 'id=?', whereArgs: [orderId], limit: 1)).first;
    final waiterId = order['waiter_id'] as int;

    final total = await getOrderTotalCents(orderId);

    await db.update('orders', {
      'status': 'paid',
      'total_cents': total,
      'closed_at': DateTime.now().millisecondsSinceEpoch,
    }, where: 'id=?', whereArgs: [orderId]);

    // shkruaj në sales (për totals te dashboards)
    await db.insert('sales', {
      'waiter_id': waiterId,
      'total_cents': total,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> _recalcOrderTotal(int orderId) async {
    final db = await AppDb.I.db;
    final total = await getOrderTotalCents(orderId);
    await db.update('orders', {'total_cents': total}, where: 'id=?', whereArgs: [orderId]);
  }
}

import 'db.dart';
import 'dao_payments.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Models
// ─────────────────────────────────────────────────────────────────────────────

class OrderLine {
  final int itemId;
  final int productId;
  final String name;
  final int qty;
  final int unitPriceCents;
  final int lineTotalCents;
  final String? note;

  const OrderLine({
    required this.itemId,
    required this.productId,
    required this.name,
    required this.qty,
    required this.unitPriceCents,
    required this.lineTotalCents,
    this.note,
  });
}

class DailySaleRow {
  final String day;
  final int ordersCount;
  final int totalCents;

  const DailySaleRow({
    required this.day,
    required this.ordersCount,
    required this.totalCents,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// DAO
// ─────────────────────────────────────────────────────────────────────────────

class OrdersDao {
  OrdersDao._();
  static final OrdersDao I = OrdersDao._();

  /// Returns existing open order id for the table, or creates a new one.
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

    return db.transaction((txn) async {
      await txn.update(
        'dining_tables',
        {'status': 'open', 'waiter_id': waiterId},
        where: 'id=?',
        whereArgs: [tableId],
      );
      return txn.insert('orders', {
        'table_id': tableId,
        'waiter_id': waiterId,
        'status': 'open',
        'total_cents': 0,
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'closed_at': null,
        'settled_id': null,
      });
    });
  }

  // ── Line items ─────────────────────────────────────────────────────────────

  Future<List<OrderLine>> getOrderLines(int orderId) async {
    final db = await AppDb.I.db;
    final rows = await db.rawQuery(
      '''
      SELECT oi.id AS item_id, oi.product_id, p.name AS product_name,
             oi.qty, oi.unit_price_cents, oi.line_total_cents, oi.note
      FROM order_items oi
      JOIN products p ON p.id = oi.product_id
      WHERE oi.order_id = ?
      ORDER BY oi.id ASC
      ''',
      [orderId],
    );
    return rows
        .map(
          (e) => OrderLine(
            itemId: e['item_id'] as int,
            productId: e['product_id'] as int,
            name: (e['product_name'] as String?) ?? 'Unknown',
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

  /// Adds 1 unit of a product, or increments qty if already in cart.
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
        'is_printed': 0,
      });
    } else {
      final id = ex.first['id'] as int;
      final qty = (ex.first['qty'] as int?) ?? 0;
      final newQty = qty + 1;
      await db.update(
        'order_items',
        {'qty': newQty, 'line_total_cents': newQty * unitPriceCents},
        where: 'id=?',
        whereArgs: [id],
      );
    }
    await _recalcOrderTotal(orderId);
  }

  /// Sets the quantity of an item. If newQty <= 0, removes the item entirely.
  Future<void> setItemQty({
    required int itemId,
    required int orderId,
    required int newQty,
  }) async {
    final db = await AppDb.I.db;

    if (newQty <= 0) {
      await db.delete('order_items', where: 'id=?', whereArgs: [itemId]);
    } else {
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
    }
    await _recalcOrderTotal(orderId);
  }

  /// Deletes a single line item.
  Future<void> removeOrderItem(int itemId, int orderId) async {
    final db = await AppDb.I.db;
    await db.delete('order_items', where: 'id=?', whereArgs: [itemId]);
    await _recalcOrderTotal(orderId);
  }

  /// Updates the note on a line item.
  Future<void> updateItemNote(int itemId, String? note) async {
    final db = await AppDb.I.db;
    await db.update(
      'order_items',
      {'note': note},
      where: 'id=?',
      whereArgs: [itemId],
    );
  }

  // ── Payment / Checkout ─────────────────────────────────────────────────────

  /// Full checkout: records payment, marks order paid, frees table.
  /// Also creates a printed_sale record for waiter settlement tracking.
  Future<void> payAndClose({
    required int orderId,
    required int tableId,
    required int waiterId,
    required String paymentMethod, // 'cash' | 'card' | 'mixed'
  }) async {
    final db = await AppDb.I.db;

    await db.transaction((txn) async {
      final nowMs = DateTime.now().millisecondsSinceEpoch;

      // Calculate order total from items
      final totalRows = await txn.rawQuery(
        'SELECT COALESCE(SUM(line_total_cents),0) AS s FROM order_items WHERE order_id=?',
        [orderId],
      );
      final totalCents = (totalRows.first['s'] as int?) ?? 0;

      // Mark order as paid
      await txn.update(
        'orders',
        {'status': 'paid', 'total_cents': totalCents, 'closed_at': nowMs},
        where: 'id=?',
        whereArgs: [orderId],
      );

      // Record the payment
      await PaymentsDao.I.createPayment(
        ex: txn,
        tableId: tableId,
        orderId: orderId,
        totalCents: totalCents,
        method: paymentMethod,
        paidBy: waiterId,
      );

      // Record in printed_sales for waiter settlement
      await txn.insert('printed_sales', {
        'waiter_id': waiterId,
        'order_id': orderId,
        'table_id': tableId,
        'amount_cents': totalCents,
        'printed_at': nowMs,
        'settled_id': null,
      });

      // Free the table
      await txn.update(
        'dining_tables',
        {'status': 'free', 'waiter_id': null},
        where: 'id=?',
        whereArgs: [tableId],
      );
    });
  }

  /// Mark items as printed (for kitchen display systems).
  Future<void> markItemsAsPrinted(int orderId) async {
    final db = await AppDb.I.db;
    await db.update(
      'order_items',
      {'is_printed': 1},
      where: 'order_id=?',
      whereArgs: [orderId],
    );
  }

  // ── Stats ──────────────────────────────────────────────────────────────────

  Future<int> countOpenOrdersByWaiter(int waiterId) async {
    final db = await AppDb.I.db;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM orders WHERE waiter_id=? AND status="open"',
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
      'SELECT COUNT(*) AS c FROM orders WHERE waiter_id=? AND created_at>=? AND created_at<?',
      [waiterId, startMs, endMs],
    );
    return (rows.first['c'] as int?) ?? 0;
  }

  Future<int> getTotalSalesInRange(int startMs, int endMs) async {
    final db = await AppDb.I.db;
    final rows = await db.rawQuery(
      "SELECT COALESCE(SUM(total_cents),0) AS s FROM orders WHERE status='paid' AND closed_at>=? AND closed_at<=?",
      [startMs, endMs],
    );
    return (rows.first['s'] as int?) ?? 0;
  }

  Future<int> getTodayTotal() async {
    final now = DateTime.now();
    return getTotalSalesInRange(
      DateTime(now.year, now.month, now.day).millisecondsSinceEpoch,
      DateTime(now.year, now.month, now.day, 23, 59, 59, 999)
          .millisecondsSinceEpoch,
    );
  }

  Future<int> getTodayOrderCount() async {
    final now = DateTime.now();
    final startMs =
        DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final endMs = DateTime(now.year, now.month, now.day, 23, 59, 59, 999)
        .millisecondsSinceEpoch;
    final db = await AppDb.I.db;
    final rows = await db.rawQuery(
      "SELECT COUNT(*) AS c FROM orders WHERE status='paid' AND closed_at>=? AND closed_at<=?",
      [startMs, endMs],
    );
    return (rows.first['c'] as int?) ?? 0;
  }

  Future<List<DailySaleRow>> getDailySales({
    required int startMs,
    required int endMs,
  }) async {
    final db = await AppDb.I.db;
    final rows = await db.rawQuery(
      '''
      SELECT
        date(closed_at/1000,'unixepoch','localtime') AS day,
        COUNT(*) AS orders_count,
        COALESCE(SUM(total_cents),0) AS total_cents
      FROM orders
      WHERE status='paid' AND closed_at IS NOT NULL
        AND closed_at>=? AND closed_at<=?
      GROUP BY day
      ORDER BY day DESC
      ''',
      [startMs, endMs],
    );
    return rows
        .map(
          (r) => DailySaleRow(
            day: r['day'] as String? ?? '',
            ordersCount: (r['orders_count'] as int?) ?? 0,
            totalCents: (r['total_cents'] as int?) ?? 0,
          ),
        )
        .toList();
  }

  // ── Private helpers ────────────────────────────────────────────────────────

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

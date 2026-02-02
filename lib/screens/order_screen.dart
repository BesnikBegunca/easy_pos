import 'dart:async';
import 'package:flutter/material.dart';

import '../data/dao_orders.dart';
import '../data/dao_products.dart';
import '../util/money.dart';
import '../theme/app_theme.dart';
import '../theme/app_widgets.dart';

class OrderScreen extends StatefulWidget {
  final int tableId;
  final String tableName;
  final int waiterId;

  const OrderScreen({
    super.key,
    required this.tableId,
    required this.tableName,
    required this.waiterId,
  });

  @override
  State<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> {
  bool loading = true;

  int orderId = 0;
  int totalCents = 0;
  String? initError;

  List<CategoryRow> categories = [];
  int? selectedCategoryId;

  final searchC = TextEditingController();
  List<ProductRow> products = [];
  List<OrderLine> lines = [];

  /// Items qe ende s’jan commit ne DB (dhe zakonisht s’jan printu ende).
  /// productId -> { name, qty, unitPriceCents }
  final Map<int, Map<String, dynamic>> pendingItems = {};

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    searchC.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      setState(() {
        loading = true;
        initError = null;
      });

      orderId = await OrdersDao.I
          .getOrCreateOpenOrder(
            tableId: widget.tableId,
            waiterId: widget.waiterId,
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw TimeoutException('Order creation timeout'),
          );

      categories = await ProductsDao.I.listCategories().timeout(
        const Duration(seconds: 10),
        onTimeout: () => <CategoryRow>[],
      );

      selectedCategoryId = categories.isEmpty ? null : categories.first.id;

      await _reloadProducts();
      await _refreshCart();

      if (!mounted) return;
      setState(() => loading = false);
    } catch (e) {
      debugPrint('Error initializing order: $e');
      if (!mounted) return;

      final msg = e.toString();
      setState(() {
        loading = false;
        initError = msg;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gabim në hapjen e tavolinës: $msg')),
      );
    }
  }

  Future<void> _reloadProducts() async {
    products = await ProductsDao.I.listActiveProducts(
      categoryId: selectedCategoryId,
      search: searchC.text,
    );
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _refreshCart() async {
    if (orderId == 0) return;

    lines = await OrdersDao.I.getOrderLines(orderId);
    final dbTotal = await OrdersDao.I.getOrderTotalCents(orderId);

    final pendingTotal = pendingItems.values.fold<int>(
      0,
      (sum, item) =>
          sum + (item['qty'] as int) * (item['unitPriceCents'] as int),
    );

    totalCents = dbTotal + pendingTotal;

    if (!mounted) return;
    setState(() {});
  }

  void _addToPending(ProductRow p) {
    setState(() {
      if (pendingItems.containsKey(p.id)) {
        pendingItems[p.id]!['qty'] = (pendingItems[p.id]!['qty'] as int) + 1;
      } else {
        pendingItems[p.id] = {
          'name': p.name,
          'qty': 1,
          'unitPriceCents': p.priceCents,
        };
      }
    });
    _refreshCart(); // ✅ me u update total-i menjehere
  }

  Future<void> _checkout() async {
    if (totalCents <= 0) return;

    // ✅ kombinim DB lines + pending items per me i pa krejt ne checkout
    final combined = <Map<String, dynamic>>[];

    for (final l in lines) {
      combined.add({
        'name': l.name,
        'qty': l.qty,
        'unitPriceCents': l.unitPriceCents,
      });
    }
    for (final entry in pendingItems.entries) {
      final item = entry.value;
      combined.add({
        'name': item['name'] as String,
        'qty': item['qty'] as int,
        'unitPriceCents': item['unitPriceCents'] as int,
      });
    }

    final paymentMethod = await showDialog<String>(
      context: context,
      builder: (_) => AppCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Checkout ${widget.tableName}', style: AppTheme.titleMedium),
            const SizedBox(height: AppTheme.spaceL),
            const Text('Items:', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: AppTheme.spaceS),
            SizedBox(
              height: 140,
              child: ListView(
                children: [
                  for (final it in combined)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Expanded(child: Text('${it['qty']}x ${it['name']}')),
                          Text(
                            moneyFromCents(
                              (it['qty'] as int) *
                                  (it['unitPriceCents'] as int),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const Divider(),
            Text(
              'Total: ${moneyFromCents(totalCents)}',
              style: AppTheme.bodyLarge,
            ),
            const SizedBox(height: AppTheme.spaceL),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                AppPrimaryButton(
                  label: 'Cash',
                  onPressed: () => Navigator.pop(context, 'cash'),
                ),
                AppPrimaryButton(
                  label: 'Card',
                  onPressed: () => Navigator.pop(context, 'card'),
                ),
                AppPrimaryButton(
                  label: 'Mixed',
                  onPressed: () => Navigator.pop(context, 'mixed'),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (paymentMethod == null) return;

    await OrdersDao.I.checkout(
      orderId: orderId,
      paymentMethod: paymentMethod,
      paidBy: widget.waiterId,
    );

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _onPrintPressed() async {
    if (pendingItems.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("S'ka produkte për print.")));
      return;
    }

    try {
      // Commit pending items to DB
      for (final entry in pendingItems.entries) {
        final productId = entry.key;
        final item = entry.value;
        final qty = item['qty'] as int;
        final unitPriceCents = item['unitPriceCents'] as int;

        for (int i = 0; i < qty; i++) {
          await OrdersDao.I.addProductToOrder(
            orderId: orderId,
            productId: productId,
            unitPriceCents: unitPriceCents,
          );
        }
      }

      // Clear pending + refresh
      if (!mounted) return;
      setState(() => pendingItems.clear());
      await _refreshCart();

      // ✅ Pa popup fare + kthehu te Tables screen
      if (!mounted) return;
      Navigator.pop(context, true); // true => me bo refresh te Tables screen
    } catch (e) {
      debugPrint('Print/commit error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Gabim në print: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return AppScaffold(
        topBar: AppTopBar(title: widget.tableName),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (orderId == 0) {
      return AppScaffold(
        topBar: AppTopBar(title: widget.tableName),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Gabim në hapjen e tavolinës', style: AppTheme.titleMedium),
              if (initError != null) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28.0),
                  child: Text(
                    initError!,
                    textAlign: TextAlign.center,
                    style: AppTheme.bodySmall,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              AppPrimaryButton(
                label: 'Kthehu',
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      );
    }

    final canPrint = pendingItems.isNotEmpty; // ✅ ky eshte kriteri i printit

    return AppScaffold(
      topBar: AppTopBar(
        title: widget.tableName,
        actions: [
          TopChip(
            icon: Icons.payments,
            label: 'PAGUAJ (${moneyFromCents(totalCents)})',
            onTap: totalCents <= 0 ? () {} : () => _checkout(),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: ElevatedButton(
              onPressed: canPrint ? _onPrintPressed : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: canPrint
                    ? AppTheme.success
                    : AppTheme.success.withOpacity(0.45),
                foregroundColor: Colors.white,
                fixedSize: const Size(120, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: const Text(
                'PRINTO',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
      body: Row(
        children: [
          // ✅ SIDEBAR KATEGORI
          Container(
            width: 240,
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(color: Colors.grey.withOpacity(0.2)),
              ),
            ),
            child: Column(
              children: [
                const SizedBox(height: 10),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Kategoritë',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView(
                    children: [
                      for (final c in categories)
                        _catItem(
                          title: c.name,
                          selected: selectedCategoryId == c.id,
                          onTap: () async {
                            setState(() => selectedCategoryId = c.id);
                            await _reloadProducts();
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ✅ MAIN: SEARCH + GRID PRODUKTE
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: searchC,
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.search),
                            labelText: 'Kërko produkt…',
                          ),
                          onChanged: (_) => _reloadProducts(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        tooltip: 'Refresh',
                        onPressed: () async {
                          searchC.clear();
                          await _reloadProducts();
                        },
                        icon: const Icon(Icons.refresh),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: products.isEmpty
                        ? const Center(
                            child: Text('S’ka produkte në këtë kategori.'),
                          )
                        : GridView.count(
                            crossAxisCount: 4,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            children: [
                              for (final p in products)
                                InkWell(
                                  onTap: () => _addToPending(p),
                                  child: Card(
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Icon(
                                            Icons.local_cafe,
                                            size: 22,
                                          ),
                                          const Spacer(),
                                          Text(
                                            p.name,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            moneyFromCents(p.priceCents),
                                            style: const TextStyle(
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),

          // ✅ CART
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Shporta',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: (lines.isEmpty && pendingItems.isEmpty)
                            ? const Center(child: Text('Shto produkte…'))
                            : ListView.separated(
                                itemCount: lines.length + pendingItems.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 1),
                                itemBuilder: (_, i) {
                                  if (i < lines.length) {
                                    final l = lines[i];
                                    return ListTile(
                                      title: Text(
                                        l.name,
                                        style: const TextStyle(
                                          color: Colors.grey,
                                        ),
                                      ),
                                      subtitle: Text(
                                        '${moneyFromCents(l.unitPriceCents)} x ${l.qty}',
                                        style: const TextStyle(
                                          color: Colors.grey,
                                        ),
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            onPressed: null,
                                            icon: const Icon(
                                              Icons.remove_circle_outline,
                                              color: Colors.grey,
                                            ),
                                          ),
                                          Text(
                                            '${l.qty}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w900,
                                              color: Colors.grey,
                                            ),
                                          ),
                                          IconButton(
                                            onPressed: null,
                                            icon: const Icon(
                                              Icons.add_circle_outline,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  } else {
                                    final pendingIndex = i - lines.length;
                                    final productId = pendingItems.keys
                                        .elementAt(pendingIndex);
                                    final item = pendingItems[productId]!;
                                    final name = item['name'] as String;
                                    final qty = item['qty'] as int;
                                    final unitPriceCents =
                                        item['unitPriceCents'] as int;

                                    return ListTile(
                                      title: Text('$name (Pending)'),
                                      subtitle: Text(
                                        '${moneyFromCents(unitPriceCents)} x $qty',
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            onPressed: () {
                                              setState(() {
                                                if (qty > 1) {
                                                  pendingItems[productId]!['qty'] =
                                                      qty - 1;
                                                } else {
                                                  pendingItems.remove(
                                                    productId,
                                                  );
                                                }
                                              });
                                              _refreshCart();
                                            },
                                            icon: const Icon(
                                              Icons.remove_circle_outline,
                                            ),
                                          ),
                                          Text(
                                            '$qty',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                          IconButton(
                                            onPressed: () {
                                              setState(() {
                                                pendingItems[productId]!['qty'] =
                                                    qty + 1;
                                              });
                                              _refreshCart();
                                            },
                                            icon: const Icon(
                                              Icons.add_circle_outline,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }
                                },
                              ),
                      ),
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: Row(
                          children: [
                            const Text(
                              'Totali:',
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                            const Spacer(),
                            Text(
                              moneyFromCents(totalCents),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _catItem({
    required String title,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: selected
                ? Colors.black.withOpacity(0.08)
                : Colors.transparent,
            border: Border.all(color: Colors.grey.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Icon(
                selected ? Icons.check_circle : Icons.circle_outlined,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

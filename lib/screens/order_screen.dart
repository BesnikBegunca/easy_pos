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

    _refreshCart();
  }

  Future<void> _checkout() async {
    if (totalCents <= 0) return;

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
      barrierDismissible: true,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: AppCard(
          padding: const EdgeInsets.all(AppTheme.spaceL),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Checkout ${widget.tableName}',
                  style: AppTheme.titleMedium,
                ),
                const SizedBox(height: AppTheme.spaceL),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Items:',
                    style: AppTheme.bodyMedium.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.spaceS),
                Container(
                  height: 180,
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: AppTheme.borderRadius,
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      for (final it in combined)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${it['qty']}x ${it['name']}',
                                  style: AppTheme.bodyMedium,
                                ),
                              ),
                              Text(
                                moneyFromCents(
                                  (it['qty'] as int) *
                                      (it['unitPriceCents'] as int),
                                ),
                                style: AppTheme.bodyMedium.copyWith(
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.spaceM),
                Divider(color: Colors.white.withOpacity(0.08)),
                const SizedBox(height: AppTheme.spaceS),
                Row(
                  children: [
                    Text(
                      'Totali',
                      style: AppTheme.bodyLarge.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      moneyFromCents(totalCents),
                      style: AppTheme.titleSmall.copyWith(
                        color: AppTheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spaceL),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: [
                    AppPrimaryButton(
                      label: 'Cash',
                      icon: Icons.payments_outlined,
                      onPressed: () => Navigator.pop(context, 'cash'),
                    ),
                    AppPrimaryButton(
                      label: 'Card',
                      icon: Icons.credit_card,
                      onPressed: () => Navigator.pop(context, 'card'),
                    ),
                    AppPrimaryButton(
                      label: 'Mixed',
                      icon: Icons.account_balance_wallet_outlined,
                      onPressed: () => Navigator.pop(context, 'mixed'),
                    ),
                  ],
                ),
              ],
            ),
          ),
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

      if (!mounted) return;
      setState(() => pendingItems.clear());
      await _refreshCart();

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      debugPrint('Print/commit error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Gabim në print: $e")));
    }
  }

  void _increasePendingQty(int productId) {
    setState(() {
      pendingItems[productId]!['qty'] =
          (pendingItems[productId]!['qty'] as int) + 1;
    });
    _refreshCart();
  }

  void _decreasePendingQty(int productId) {
    final qty = pendingItems[productId]!['qty'] as int;

    setState(() {
      if (qty > 1) {
        pendingItems[productId]!['qty'] = qty - 1;
      } else {
        pendingItems.remove(productId);
      }
    });

    _refreshCart();
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
                icon: Icons.arrow_back,
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      );
    }

    final canPrint = pendingItems.isNotEmpty;

    return AppScaffold(
      topBar: AppTopBar(
        title: widget.tableName,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: TopChip(
              icon: Icons.payments,
              label: 'PAGUAJ (${moneyFromCents(totalCents)})',
              onTap: totalCents <= 0 ? () {} : _checkout,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8),
            child: ElevatedButton(
              onPressed: canPrint ? _onPrintPressed : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: canPrint
                    ? AppTheme.success
                    : AppTheme.success.withOpacity(0.45),
                foregroundColor: Colors.white,
                fixedSize: const Size(120, 44),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
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
          Container(
            width: 240,
            decoration: BoxDecoration(
              color: AppTheme.surface,
              border: Border(
                right: BorderSide(color: Colors.white.withOpacity(0.08)),
              ),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Kategoritë', style: AppTheme.titleSmall),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 10),
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

          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: AppTextField(
                          controller: searchC,
                          label: 'Kërko produkt…',
                          prefixIcon: Icons.search,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Material(
                        color: AppTheme.tile,
                        borderRadius: BorderRadius.circular(12),
                        child: IconButton(
                          tooltip: 'Refresh',
                          onPressed: () async {
                            searchC.clear();
                            await _reloadProducts();
                          },
                          icon: const Icon(Icons.refresh),
                          color: AppTheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: products.isEmpty
                        ? Center(
                            child: Text(
                              'S’ka produkte në këtë kategori.',
                              style: AppTheme.bodyMedium,
                            ),
                          )
                        : GridView.builder(
                            itemCount: products.length,
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 4,
                                  crossAxisSpacing: 10,
                                  mainAxisSpacing: 10,
                                  childAspectRatio: 1.1,
                                ),
                            itemBuilder: (_, i) {
                              final p = products[i];
                              return _productCard(p);
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),

          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Material(
                color: AppTheme.tile,
                borderRadius: AppTheme.borderRadius,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: AppTheme.borderRadius,
                    border: Border.all(color: AppTheme.borderColor),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.25),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Shporta', style: AppTheme.titleSmall),
                        const SizedBox(height: 10),
                        Expanded(
                          child: (lines.isEmpty && pendingItems.isEmpty)
                              ? Center(
                                  child: Text(
                                    'Shto produkte…',
                                    style: AppTheme.bodyMedium,
                                  ),
                                )
                              : ListView.separated(
                                  itemCount: lines.length + pendingItems.length,
                                  separatorBuilder: (_, __) => Divider(
                                    height: 1,
                                    color: Colors.white.withOpacity(0.08),
                                  ),
                                  itemBuilder: (_, i) {
                                    if (i < lines.length) {
                                      final l = lines[i];
                                      return ListTile(
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                        title: Text(
                                          l.name,
                                          style: AppTheme.bodyMedium.copyWith(
                                            color: Colors.grey.shade400,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        subtitle: Text(
                                          '${moneyFromCents(l.unitPriceCents)} x ${l.qty}',
                                          style: AppTheme.bodySmall.copyWith(
                                            color: Colors.grey.shade500,
                                          ),
                                        ),
                                        trailing: Text(
                                          moneyFromCents(
                                            l.unitPriceCents * l.qty,
                                          ),
                                          style: AppTheme.bodyMedium.copyWith(
                                            color: Colors.grey.shade400,
                                            fontWeight: FontWeight.w700,
                                          ),
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
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                        title: Text(
                                          '$name (Pending)',
                                          style: AppTheme.bodyMedium.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        subtitle: Text(
                                          '${moneyFromCents(unitPriceCents)} x $qty',
                                          style: AppTheme.bodySmall,
                                        ),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Material(
                                              color: Colors.transparent,
                                              child: IconButton(
                                                onPressed: () =>
                                                    _decreasePendingQty(
                                                      productId,
                                                    ),
                                                icon: const Icon(
                                                  Icons.remove_circle_outline,
                                                ),
                                                color: AppTheme.primary,
                                              ),
                                            ),
                                            Text(
                                              '$qty',
                                              style: AppTheme.bodyMedium
                                                  .copyWith(
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                            ),
                                            Material(
                                              color: Colors.transparent,
                                              child: IconButton(
                                                onPressed: () =>
                                                    _increasePendingQty(
                                                      productId,
                                                    ),
                                                icon: const Icon(
                                                  Icons.add_circle_outline,
                                                ),
                                                color: AppTheme.primary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }
                                  },
                                ),
                        ),
                        Divider(
                          height: 1,
                          color: Colors.white.withOpacity(0.08),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(10),
                          child: Row(
                            children: [
                              Text(
                                'Totali:',
                                style: AppTheme.bodyLarge.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                moneyFromCents(totalCents),
                                style: AppTheme.titleSmall.copyWith(
                                  color: AppTheme.primary,
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
          ),
        ],
      ),
    );
  }

  Widget _productCard(ProductRow p) {
    return Material(
      color: AppTheme.tile,
      borderRadius: AppTheme.borderRadius,
      child: InkWell(
        borderRadius: AppTheme.borderRadius,
        onTap: () => _addToPending(p),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: AppTheme.borderRadius,
            border: Border.all(color: AppTheme.borderColor),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppTheme.tile, AppTheme.surface],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.22),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.local_cafe, size: 22, color: AppTheme.primary),
              const Spacer(),
              Text(
                p.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.bodyMedium.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                moneyFromCents(p.priceCents),
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
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
      child: Material(
        color: selected
            ? AppTheme.primary.withOpacity(0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected
                    ? AppTheme.primary.withOpacity(0.45)
                    : Colors.white.withOpacity(0.10),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  selected ? Icons.check_circle : Icons.circle_outlined,
                  size: 18,
                  color: selected ? AppTheme.primary : Colors.white70,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: AppTheme.bodyMedium.copyWith(
                      fontWeight: FontWeight.w800,
                      color: selected ? AppTheme.primary : AppTheme.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

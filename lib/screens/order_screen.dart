import 'package:flutter/material.dart';
import '../data/dao_orders.dart';
import '../data/dao_products.dart';
import '../util/money.dart';

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

  List<CategoryRow> categories = [];
  int? selectedCategoryId;

  final searchC = TextEditingController();
  List<ProductRow> products = [];
  List<OrderLine> lines = [];

  Future<void> _init() async {
    setState(() => loading = true);

    orderId = await OrdersDao.I.getOrCreateOpenOrder(
      tableId: widget.tableId,
      waiterId: widget.waiterId,
    );

    categories = await ProductsDao.I.listCategories();

    // nëse s’ka kategori, prap mos me crash
    selectedCategoryId = categories.isEmpty ? null : categories.first.id;

    await _reloadProducts();
    await _refreshCart();

    if (!mounted) return;
    setState(() => loading = false);
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
    lines = await OrdersDao.I.getOrderLines(orderId);
    totalCents = await OrdersDao.I.getOrderTotalCents(orderId);
    if (!mounted) return;
    setState(() {});
  }

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

  Future<void> _checkout() async {
    if (totalCents <= 0) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Checkout'),
        content: Text('Me e mbyll porosinë për ${widget.tableName}?\nTotali: ${moneyFromCents(totalCents)}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Anulo')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Paguaj')),
        ],
      ),
    );
    if (ok != true) return;

    await OrdersDao.I.checkout(orderId: orderId);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.tableName)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Porosia — ${widget.tableName}'),
        actions: [
          TextButton.icon(
            onPressed: totalCents <= 0 ? null : _checkout,
            icon: const Icon(Icons.payments),
            label: Text('Checkout (${moneyFromCents(totalCents)})'),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: Row(
        children: [
          // ✅ SIDEBAR KATEGORI
          Container(
            width: 240,
            decoration: BoxDecoration(
              border: Border(right: BorderSide(color: Colors.grey.withOpacity(0.2))),
            ),
            child: Column(
              children: [
                const SizedBox(height: 10),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Kategoritë', style: TextStyle(fontWeight: FontWeight.w900)),
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
                        ? const Center(child: Text('S’ka produkte në këtë kategori.'))
                        : GridView.count(
                      crossAxisCount: 4,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      children: [
                        for (final p in products)
                          InkWell(
                            onTap: () async {
                              await OrdersDao.I.addProductToOrder(
                                orderId: orderId,
                                productId: p.id,
                                unitPriceCents: p.priceCents,
                              );
                              await _refreshCart();
                            },
                            child: Card(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.local_cafe, size: 22),
                                    const Spacer(),
                                    Text(
                                      p.name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontWeight: FontWeight.w900),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(moneyFromCents(p.priceCents), style: const TextStyle(fontSize: 12)),
                                  ],
                                ),
                              ),
                            ),
                          )
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
                      const Text('Shporta', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 10),

                      Expanded(
                        child: lines.isEmpty
                            ? const Center(child: Text('Shto produkte…'))
                            : ListView.separated(
                          itemCount: lines.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final l = lines[i];
                            return ListTile(
                              title: Text(l.name),
                              subtitle: Text('${moneyFromCents(l.unitPriceCents)} x ${l.qty}'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    onPressed: () async {
                                      await OrdersDao.I.changeQty(
                                        itemId: l.itemId,
                                        orderId: orderId,
                                        newQty: l.qty - 1,
                                      );
                                      await _refreshCart();
                                    },
                                    icon: const Icon(Icons.remove_circle_outline),
                                  ),
                                  Text('${l.qty}', style: const TextStyle(fontWeight: FontWeight.w900)),
                                  IconButton(
                                    onPressed: () async {
                                      await OrdersDao.I.changeQty(
                                        itemId: l.itemId,
                                        orderId: orderId,
                                        newQty: l.qty + 1,
                                      );
                                      await _refreshCart();
                                    },
                                    icon: const Icon(Icons.add_circle_outline),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),

                      const Divider(height: 1),

                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: Row(
                          children: [
                            const Text('Totali:', style: TextStyle(fontWeight: FontWeight.w900)),
                            const Spacer(),
                            Text(moneyFromCents(totalCents), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                          ],
                        ),
                      ),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: totalCents <= 0 ? null : _checkout,
                          icon: const Icon(Icons.payments),
                          label: Text('Checkout (${moneyFromCents(totalCents)})'),
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

  Widget _catItem({required String title, required bool selected, required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: selected ? Colors.black.withOpacity(0.08) : Colors.transparent,
            border: Border.all(color: Colors.grey.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Icon(selected ? Icons.check_circle : Icons.circle_outlined, size: 18),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800))),
            ],
          ),
        ),
      ),
    );
  }
}
